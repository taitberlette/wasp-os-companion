import 'package:flutter/material.dart';

class StatusWidget extends StatefulWidget {
  const StatusWidget({Key key, @required this.state, @required this.watch})
      : super(key: key);

  final int state;
  final String watch;

  @override
  _StatusWidgetState createState() => _StatusWidgetState();
}

class _StatusWidgetState extends State<StatusWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 25),
        Text(
          widget.state == 0
              ? "Connect a wasp-os device to view data."
              : widget.state == 1
                  ? "Searching for wasp-os devices..."
                  : widget.state == 2
                      ? "Connecting to ${widget.watch == null ? "unknown wasp-os device" : widget.watch}..."
                      : "Syncing ${widget.watch == null ? "unknown wasp-os device" : widget.watch}...",
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
        SizedBox(height: 25),
      ],
    );
  }
}
