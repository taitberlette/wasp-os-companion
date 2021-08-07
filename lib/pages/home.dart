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
