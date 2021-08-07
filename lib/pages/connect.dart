import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waspos/pages/home.dart';
import 'package:waspos/pages/widgets/layout.dart';
import 'package:waspos/scripts/device.dart';

// widget to connect to the watch

class Connect extends StatefulWidget {
  const Connect({
    Key key,
  }) : super(key: key);

  @override
  _ConnectState createState() => _ConnectState();
}

class _ConnectState extends State<Connect> {
  StreamSubscription<Device> deviceSubscription;

  // details
  String message = "Connect to your wasp-os device.";
  bool sync = true;

  @override
  void initState() {
    super.initState();

    deviceSubscription = Device.deviceStream.listen(data);
  }

  @override
  void dispose() {
    super.dispose();

    deviceSubscription.cancel();
  }

  // update the ui when the device state changes
  void data(Device data) {
    String newMessage = "";
    bool newSync = false;

    switch (data.connectState) {
      case 1:
        newMessage = "Searching for nearby wasp-os devices...";
        break;
      case 2:
        newMessage = "Connecting to ${data.name}...";
        break;
      case 3:
        newMessage = "Connected to ${data.name}!";
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => Home()));
        }
        break;
      default:
        newMessage =
            "Failed to connect${data.name != "" ? " to ${data.name}!" : "."}";
        newSync = true;
    }

    if (mounted) {
      setState(() {
        message = newMessage;
        sync = newSync;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      children: [
        !sync ? LinearProgressIndicator() : Container(),
        Container(
          padding: EdgeInsets.only(top: !sync ? 48 : 0),
          child: Text(message),
        ),
      ],
      fab: sync
          ? FloatingActionButton(
              onPressed: () {
                Device.connect();
              },
              child: Icon(Icons.sync),
              tooltip: "Connect",
              focusElevation: 30,
            )
          : null,
    );
  }
}
