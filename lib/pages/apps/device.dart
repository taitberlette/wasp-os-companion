import 'package:flutter/material.dart';
import 'package:waspos/pages/device.dart';
import 'package:waspos/scripts/device.dart';

// view device details

class DeviceWidget extends StatefulWidget {
  const DeviceWidget({
    Key key,
  }) : super(key: key);

  @override
  _DeviceWidgetState createState() => _DeviceWidgetState();
}

class _DeviceWidgetState extends State<DeviceWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: () {
          if (mounted) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => DeviceOptions()));
          }
        },
        borderRadius: BorderRadius.all(
          Radius.circular(5),
        ),
        child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white60,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 5,
                  blurRadius: 20,
                  offset: Offset(2, 2),
                )
              ],
              borderRadius: BorderRadius.all(
                Radius.circular(5),
              ),
            ),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                  Image.asset(
                    'assets/images/watches/${Device.device.name}.png',
                    height: 75,
                    width: 75,
                  ),
                  Padding(padding: EdgeInsets.only(left: 20)),
                  RichText(
                    text: TextSpan(
                        text: Device.device.name,
                        style: TextStyle(fontSize: 24, color: Colors.black),
                        children: <TextSpan>[
                          TextSpan(
                            text:
                                '\nBattery: ${Device.device.state.batteryLevel}%\nLast Synced: ${Device.device.syncTime.hour.toString()}:${Device.device.syncTime.minute.toString().padLeft(2, "0")}',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black45),
                          ),
                        ]),
                  ),
                ]),
              ],
            )));
  }
}
