import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nordic_dfu/flutter_nordic_dfu.dart';
import 'package:http/http.dart';
import 'package:waspos/pages/connect.dart';
import 'package:waspos/pages/widgets/layout.dart';
import 'package:waspos/scripts/device.dart';
import 'package:waspos/scripts/util.dart';

// widget to send updates to the watch

// where the user want to upload from
enum UpdateLocation { Release, Action, Local }

class Update extends StatefulWidget {
  const Update({
    Key key,
  }) : super(key: key);

  @override
  _UpdateState createState() => _UpdateState();
}

class _UpdateState extends State<Update> {
  StreamSubscription<Device> deviceSubscription;

  // arrays of recent updates
  List<Map<String, dynamic>> release = [];
  List<Map<String, dynamic>> action = [];

  // updating message
  String message = "";

  // details
  bool updateRunning = false;
  double updateProgress;
  bool failed = false;

  @override
  void initState() {
    super.initState();

    deviceSubscription = Device.deviceStream.listen(data);

    refresh();
  }

  @override
  void dispose() {
    super.dispose();

    deviceSubscription.cancel();
  }

  void data(Device data) {
    if (data.connectState == 0 && !Device.device.updating && mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => Connect()));
    }
  }

  // download an update either from github releases or github actions
  void downloadUpdate(UpdateLocation location, int index) async {
    try {
      Map<String, dynamic> details =
          location == UpdateLocation.Action ? action[index] : release[index];
      String type = location == UpdateLocation.Action ? "action" : "release";

      bool verify = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Start Update?"),
                content: Text(
                    "Please make sure this is the correct ${location == UpdateLocation.Action ? "action" : "release"} you would like to install:\n\n${details["name"]}"),
                actions: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    child: Text("Accept"),
                  ),
                  OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      child: Text("Cancel"))
                ],
              );
            },
          ) ??
          false;

      if (!verify) {
        return;
      }

      if (mounted) {
        setState(() {
          updateRunning = true;
          message = "Downloading $type...";
          failed = false;
        });
      }

      Uri server = Uri.parse(
          "https://wasp-os-companion.glitch.me/api/${type}s/${details["version"]}/${Device.device.name}");

      Response serverResponse = await get(server);

      dynamic serverData = jsonDecode(serverResponse.body);

      bool error = serverData["error"];

      if (error) throw serverData["message"];

      String downloadUrl = serverData["url"];

      HttpClient client = new HttpClient();
      dynamic fileReq = await client.getUrl(Uri.parse(downloadUrl));
      dynamic fileRes = await fileReq.close();
      List<int> bytes = await consolidateHttpClientResponseBytes(fileRes);
      File micropython = await getFile("micropython.zip");
      await micropython.writeAsBytes(bytes);

      startUpdate(micropython);
    } catch (error) {
      final snackBar = SnackBar(
        content: Text(error.toString()),
        duration: Duration(minutes: 1),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            downloadUpdate(location, index);
          },
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      if (mounted) {
        setState(() {
          message = "Download failed!";
          updateRunning = false;
        });
      }
    }
  }

  // access an update from a file on the local system
  void localUpdate() async {
    FilePickerResult result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ["zip"]);

    if (result != null && result.files.single.extension == "zip") {
      bool verify = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Start Update?"),
                content: Text(
                    "Please make sure this is the correct file you would like to install:\n\n${result.files.single.name}"),
                actions: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    child: Text("Accept"),
                  ),
                  OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      child: Text("Cancel"))
                ],
              );
            },
          ) ??
          false;

      if (verify) {
        startUpdate(File(result.files.single.path));
      }
    }
  }

  // upload the file to the watch
  void startUpdate(File micropython) async {
    try {
      if (mounted) {
        setState(() {
          updateRunning = true;
          message = "Rebooting device...";
          failed = false;
        });
      }

      Device.updateState(true);

      await Device.message("import machine");
      Device.message("machine.enter_ota_dfu()");

      String main = Device.device.uuid.substring(0, 15);
      String value = Device.device.uuid.substring(15, 17);
      int number = int.parse(value, radix: 16);
      number++;
      number = number & 0xFF;
      value = number.toRadixString(16);
      value = value.toUpperCase();
      String uuid = "$main$value";

      if (mounted) {
        setState(() {
          updateRunning = true;
          message = "Starting update...";
        });
      }

      await FlutterNordicDfu.startDfu(uuid, micropython.path,
          enableUnsafeExperimentalButtonlessServiceInSecureDfu: true,
          name: Device.device.name,
          numberOfPackets: 16, progressListener:
              DefaultDfuProgressListenerAdapter(onProgressChangedHandle: (
        deviceAddress,
        percent,
        speed,
        avgSpeed,
        currentPart,
        partsTotal,
      ) {
        if (mounted) {
          setState(() {
            message = "Updating...";
            updateProgress = percent / 100;
          });
        }
      }));

      Device.updateState(false);

      if (mounted) {
        setState(() {
          message = "Finishing update...";
          Navigator.pop(context);
        });
      }
    } catch (error) {
      final snackBar = SnackBar(
        content: Text(error.toString()),
        duration: Duration(minutes: 1),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            startUpdate(micropython);
          },
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      if (mounted) {
        setState(() {
          message = "Updated failed!";
          failed = true;
          updateRunning = false;
        });
      }
    }
  }

  // download details about recent github releases and github actions
  void refresh() async {
    Uri releaseUri = Uri.parse(
        "https://api.github.com/repos/daniel-thompson/wasp-os/releases");

    Response releaseResponse = await get(releaseUri);

    dynamic releaseData = jsonDecode(releaseResponse.body);

    for (int i = 0; i < releaseData.length; i++) {
      release.add({
        "name": releaseData[i]["name"],
        "details": releaseData[i]["body"],
        "version": releaseData[i]["id"]
      });
    }

    Uri actionUri = Uri.parse(
        "https://api.github.com/repos/daniel-thompson/wasp-os/actions/runs");

    Response actionResponse = await get(actionUri);

    List<dynamic> actionData = jsonDecode(actionResponse.body)["workflow_runs"];

    actionData.removeWhere((element) =>
        element["name"] != "wasp-os binary distribution" ||
        element["conclusion"] != "success");

    for (int i = 0; i < actionData.length; i++) {
      dynamic data = {
        "name": actionData[i]["head_commit"]["message"].split("\n")[0],
        "details": "",
        "version": actionData[i]["id"]
      };

      List<String> lines = actionData[i]["head_commit"]["message"].split("\n");

      lines.removeAt(0);

      data["details"] = lines.join("\n");

      action.add(data);
    }

    if (mounted) {
      setState(() {
        release = release;
        action = action;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      children: [
        message == ""
            ? Column(
                children: [
                  Text(
                    "${Device.device.name} update options.",
                    style: TextStyle(fontSize: 20),
                  ),
                  Container(
                    height: 48,
                  ),
                  ExpansionTile(
                    title: Text("Release"),
                    children: [
                      release.length == 0
                          ? LinearProgressIndicator()
                          : Column(
                              children: [
                                for (int i = 0; i < release.length; i++)
                                  ListTile(
                                    contentPadding: EdgeInsets.all(8),
                                    minVerticalPadding: 16,
                                    title:
                                        Text(release[i]["name"] ?? "No name."),
                                    subtitle: Text(
                                        release[i]["details"] ?? "No details."),
                                    onTap: () {
                                      downloadUpdate(UpdateLocation.Release, i);
                                    },
                                  )
                              ],
                            )
                    ],
                  ),
                  ExpansionTile(
                    title: Text("Github Actions"),
                    children: [
                      action.length == 0
                          ? LinearProgressIndicator()
                          : Column(
                              children: [
                                for (int i = 0; i < action.length; i++)
                                  ListTile(
                                    contentPadding: EdgeInsets.all(8),
                                    minVerticalPadding: 16,
                                    title:
                                        Text(action[i]["name"] ?? "No name."),
                                    subtitle: Text(
                                        action[i]["details"] ?? "No details."),
                                    onTap: () {
                                      downloadUpdate(UpdateLocation.Action, i);
                                    },
                                  )
                              ],
                            )
                    ],
                  ),
                  Container(
                    height: 24,
                  ),
                  OutlinedButton(
                    onPressed: () {
                      localUpdate();
                    },
                    child: Text("Local File"),
                  )
                ],
              )
            : Column(
                children: [
                  updateRunning
                      ? LinearProgressIndicator(value: updateProgress)
                      : Container(),
                  Container(
                    padding: EdgeInsets.only(top: updateRunning ? 48 : 0),
                    child: Text(message),
                  ),
                ],
              )
      ],
      fab: !updateRunning
          ? FloatingActionButton(
              onPressed: () {
                if (failed && mounted) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (builder) => Connect()));
                } else {
                  Navigator.pop(context);
                }
              },
              child: Icon(Icons.arrow_back),
              tooltip: "Back",
              focusElevation: 30,
            )
          : null,
    );
  }
}
