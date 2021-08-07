import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:waspos/pages/connect.dart';
import 'package:waspos/pages/widgets/layout.dart';
import 'package:waspos/scripts/debug.dart';
import 'package:waspos/scripts/device.dart';

// widget to view the uart console, upload files, and download files

class Devtools extends StatefulWidget {
  const Devtools({
    Key key,
  }) : super(key: key);

  @override
  _DevtoolsState createState() => _DevtoolsState();
}

class _DevtoolsState extends State<Devtools> {
  StreamSubscription<Device> deviceSubscription;
  StreamSubscription<String> uartSubscription;

  // modify the scroll location of the uart console
  ScrollController uartScrollController;

  // is a file currently being transferred
  bool transferActive;

  @override
  void initState() {
    super.initState();

    deviceSubscription = Device.deviceStream.listen(data);
    uartSubscription = Debug.uartStream.listen(uart);
    uartScrollController = ScrollController();
  }

  @override
  void dispose() {
    super.dispose();

    deviceSubscription.cancel();
    uartSubscription.cancel();
  }

  void data(Device data) {
    if (data.connectState == 0 && !Device.device.updating && mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => Connect()));
    }
  }

  // when new uart data is available update the console
  void uart(String data) {
    if (mounted) {
      setState(() {});
      uartScrollController.jumpTo(
        uartScrollController.position.maxScrollExtent + 24,
      );
    }
  }

  // send a file from local file system to the watch
  void uploadFile() async {
    if (transferActive == true) {
      return;
    }

    FilePickerResult result = await FilePicker.platform.pickFiles();

    if (result == null) {
      return;
    }

    TextEditingController filePathController =
        TextEditingController(text: result.files.single.name);

    String path = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Enter the name you would like the file saved as."),
          content: TextField(
            autocorrect: false,
            controller: filePathController,
            decoration: InputDecoration(hintText: result.files.single.name),
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context, filePathController.text);
              },
              child: Text("Continue"),
            ),
            OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, null);
                },
                child: Text("Cancel"))
          ],
        );
      },
    );

    if (path == null) {
      path = result.files.single.name;
    }

    bool verify = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Start Upload?"),
              content: Text(
                  "Please make sure this is the correct file you would like to upload:\n\n${result.files.single.name + (path != result.files.single.name ? " as $path" : "")}"),
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

    transferActive = true;

    final snackBar = SnackBar(
      content: Text(
          "Uploading ${result.files.single.name + (path != result.files.single.name ? " as $path" : "")} started. Do not leave this page."),
      duration: Duration(minutes: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    File file = File(result.files.single.path);

    Uint8List bytes = await file.readAsBytes();

    await Device.uploadFile(path, bytes.toList());

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBarDone = SnackBar(
      content: Text("Uploading ${result.files.single.name} finished!"),
      duration: Duration(minutes: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBarDone);

    transferActive = false;
  }

  // download a file from the the watch to the local file system
  void downloadFile() async {
    if (transferActive == true) {
      return;
    }

    TextEditingController filePathController = TextEditingController();

    String path = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Enter the file you would like to download."),
          content: TextField(
            autocorrect: false,
            controller: filePathController,
            decoration: InputDecoration(hintText: 'hrs.data'),
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context, filePathController.text);
              },
              child: Text("Download"),
            ),
            OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, "");
                },
                child: Text("Cancel"))
          ],
        );
      },
    );

    if (path.trim() == "") {
      return;
    }

    transferActive = true;

    final snackBar = SnackBar(
      content: Text("Downloading $path started. Do not leave this page."),
      duration: Duration(minutes: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    List<int> data = await Device.downloadFile(path);

    if (data == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final snackBar = SnackBar(
        content: Text("Downloading $path failed!"),
        duration: Duration(minutes: 1),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }

    Uint8List bytes = Uint8List.fromList(data);

    transferActive = false;

    await FileSaver.instance.saveAs(path, bytes, "bin", MimeType.OTHER);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBarDone = SnackBar(
      content: Text("Downloading $path finished!"),
      duration: Duration(minutes: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBarDone);
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      children: [
        Text(
          "${Device.device.name} devtools.",
          style: TextStyle(fontSize: 20),
        ),
        Container(
          height: 48,
        ),
        Column(
          children: [
            Container(
                height: MediaQuery.of(context).size.height / 3,
                child: SingleChildScrollView(
                  controller: uartScrollController,
                  physics: BouncingScrollPhysics(),
                  child: Text(Debug.uart),
                )),
            TextField(
              autocorrect: false,
              onSubmitted: (String data) {
                Device.message(data);
              },
              decoration: InputDecoration(hintText: 'wasp.system.run()'),
            ),
            Container(
              height: 48,
            ),
            Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Push file to ${Device.device.name}"),
                  OutlinedButton(
                      onPressed: () {
                        uploadFile();
                      },
                      child: Container(
                        child: Text("Upload"),
                      ))
                ],
              ),
            ),
            Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Pull file from ${Device.device.name}"),
                  OutlinedButton(
                      onPressed: () {
                        downloadFile();
                      },
                      child: Container(
                        child: Text("Download"),
                      ))
                ],
              ),
            ),
            Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Collect memory on ${Device.device.name}"),
                  OutlinedButton(
                      onPressed: () {
                        Device.collectMemory();
                      },
                      child: Container(
                        child: Text("Collect"),
                      ))
                ],
              ),
            ),
            Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Clear UART console"),
                  OutlinedButton(
                      onPressed: () {
                        Debug.clear();
                      },
                      child: Container(
                        child: Text("Clear"),
                      ))
                ],
              ),
            )
          ],
        )
      ],
      fab: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: Icon(Icons.arrow_back),
        tooltip: "Back",
        focusElevation: 30,
      ),
    );
  }
}
