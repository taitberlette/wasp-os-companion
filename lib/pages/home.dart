import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waspos/pages/connect.dart';
import 'package:waspos/pages/widgets/layout.dart';
import 'package:waspos/scripts/apps.dart';
import 'package:waspos/scripts/device.dart';

// home screen widget

class Home extends StatefulWidget {
  const Home({
    Key key,
  }) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  StreamSubscription<Device> deviceSubscription;

  @override
  void initState() {
    super.initState();

    deviceSubscription = Device.deviceStream.listen(data);

    if (Device.device.askingNotifications) {
      Device.device.askingNotifications = false;

      WidgetsBinding.instance.addPostFrameCallback((_) => showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Enable watch notifications?"),
                content: Text(
                    "If you would like your notifications to show on your watch you need to enable the notification listener."),
                actions: [
                  OutlinedButton(
                    child: Text("Accept"),
                    onPressed: () {
                      Navigator.pop(context);
                      Device.acceptNotifications();
                    },
                  ),
                  OutlinedButton(
                    child: Text("Cancel"),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              );
            },
          ));
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
        StreamBuilder(
            stream: Device.deviceStream,
            builder: (BuildContext context, AsyncSnapshot<Device> snapshot) {
              if (!snapshot.hasData || snapshot.data.syncing == true) {
                return Column(
                  children: [
                    LinearProgressIndicator(),
                    Container(
                      padding: EdgeInsets.only(top: 48),
                      child: Text("Syncing..."),
                    ),
                  ],
                );
              }

              return Column(
                children: WatchApps.getApps(),
              );
            }),
      ],
      fab: FloatingActionButton(
        onPressed: () {
          Device.disconnect();
        },
        child: Icon(Icons.close),
        tooltip: "Disconnect",
        focusElevation: 30,
      ),
      refresh: Device.sync,
    );
  }
}
