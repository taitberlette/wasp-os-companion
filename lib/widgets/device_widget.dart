import 'package:flutter/material.dart';

class DeviceWidget extends StatefulWidget {
  const DeviceWidget({
    Key key,
    @required this.sendString,
    @required this.appPath,
    @required this.name,
    @required this.batteryLevel,
    @required this.lastSync,
    this.onChanged,
  }) : super(key: key);

  final Function sendString;
  final Function appPath;
  final String name;
  final int batteryLevel;
  final DateTime lastSync;

  final Function onChanged;

  @override
  _DeviceWidgetState createState() => _DeviceWidgetState();
}

class _DeviceWidgetState extends State<DeviceWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          SizedBox(height: 10),
          Container(
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
                      'assets/images/watches/${widget.name}.png',
                      height: 75,
                      width: 75,
                    ),
                    Padding(padding: EdgeInsets.only(left: 20)),
                    RichText(
                      text: TextSpan(
                          text: widget.name,
                          style: TextStyle(fontSize: 24, color: Colors.black),
                          children: <TextSpan>[
                            TextSpan(
                              text:
                                  '\nBattery: ${widget.batteryLevel.toString()}%\nLast Synced: ${widget.lastSync.hour}:${widget.lastSync.minute}',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.black45),
                            ),
                          ]),
                    ),
                  ]),
                ],
              )),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
