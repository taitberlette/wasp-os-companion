import 'package:flutter/material.dart';

class UploadWidget extends StatefulWidget {
  const UploadWidget({Key key, @required this.progress, @required this.state})
      : super(key: key);

  final int progress;
  final int state;

  @override
  _UploadWidgetState createState() => _UploadWidgetState();
}

class _UploadWidgetState extends State<UploadWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 25),
        Row(
          children: [
            Text(
              widget.state == 0
                  ? "Updating your watch..."
                  : "Downloading latest version...",
              style: TextStyle(fontSize: 16, color: Colors.black),
            )
          ],
        ),
        SizedBox(height: 10),
        widget.progress >= 1
            ? LinearProgressIndicator(
                value: widget.progress.toDouble() / 100,
              )
            : LinearProgressIndicator(),
        SizedBox(height: 25),
      ],
    );
  }
}
