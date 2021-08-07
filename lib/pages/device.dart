import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waspos/pages/connect.dart';
import 'package:waspos/pages/devtools.dart';
import 'package:waspos/pages/update.dart';
import 'package:waspos/pages/widgets/layout.dart';
import 'package:waspos/scripts/device.dart';

// widget to update, view devtools, or reset the watch

class DeviceOptions extends StatefulWidget {
  const DeviceOptions({
    Key key,
  }) : super(key: key);

  @override
  _DeviceOptionsState createState() => _DeviceOptionsState();
}

class _DeviceOptionsState extends State<DeviceOptions> {
  StreamSubscription<Device> deviceSubscription;

  // menu options
  List<Map<String, dynamic>> options = [];

  @override
  void initState() {
    super.initState();

    deviceSubscription = Device.deviceStream.listen(data);

    if (mounted) {
      setState(() {
        options = [
          {
            "title": "Update",
            "subtitle": "Update your watch software to a new version.",
            "tap": () {
              if (mounted) {
                Navigator.push(
                    context, MaterialPageRoute(builder: (builder) => Update()));
              }
            }
          },
          {
            "title": "Devtools",
            "subtitle": "Open devtools for advanced features.",
            "tap": () {
              if (mounted) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (builder) => Devtools()));
              }
            }
          },
          {
            "title": "Restart",
            "subtitle": "Restart your watch.",
            "tap": () async {
              bool verify = await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("Reboot?"),
                        content:
                            Text("Are you sure would would like to reboot?"),
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
              Device.message("import machine");
              Device.message("machine.reset()");

              Navigator.pop(context);

              Device.disconnected();
            }
          }
        ];
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      children: [
        Text(
          "${Device.device.name} options.",
          style: TextStyle(fontSize: 20),
        ),
        Container(
          height: 48,
        ),
        ...options.map((Map<String, dynamic> option) => ListTile(
              contentPadding: EdgeInsets.all(8),
              minVerticalPadding: 16,
              title: Text(option["title"]),
              subtitle: Text(option["subtitle"]),
              onTap: option["tap"],
            ))
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
