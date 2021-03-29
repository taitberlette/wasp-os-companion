import 'package:flutter/material.dart';

class ClockWidget extends StatefulWidget {
  const ClockWidget({
    Key key,
    @required this.sendString,
    @required this.appPath,
    @required this.faceId,
    @required this.clockPath,
    this.onChanged,
  }) : super(key: key);

  final Function sendString;
  final Function appPath;
  final int faceId;
  final String clockPath;

  final Function onChanged;

  @override
  _ClockWidgetState createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  int clockFaceId;

  @override
  void initState() {
    super.initState();
    clockFaceId = widget.faceId;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Divider(height: 16),
          SizedBox(height: 15),
          Text("Clock", style: TextStyle(fontSize: 16, color: Colors.black)),
          SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Clock Face:",
                style: TextStyle(fontSize: 14, color: Colors.black)),
            DropdownButton(
              style: TextStyle(fontSize: 14, color: Colors.black),
              value: clockFaceId,
              items: [
                DropdownMenuItem(
                  child: Text("Digital Clock"),
                  value: 1,
                ),
                DropdownMenuItem(
                  child: Text("Fibonacci Clock"),
                  value: 2,
                ),
                DropdownMenuItem(
                  child: Text("Analogue Clock"),
                  value: 3,
                ),
                DropdownMenuItem(
                  child: Text("Word Clock"),
                  value: 4,
                ),
                DropdownMenuItem(
                  child: Text("Dual Clock"),
                  value: 5,
                )
              ],
              onChanged: (value) {
                setState(() {
                  clockFaceId = value;
                  if (value == 1) {
                    widget.sendString("from apps.clock import ClockApp");
                    widget.sendString("${widget.clockPath} = ClockApp()");
                  } else if (value == 2) {
                    widget.sendString(
                        "from apps.fibonacci_clock import FibonacciClockApp");
                    widget.sendString(
                        "${widget.clockPath} = FibonacciClockApp()");
                  } else if (value == 3) {
                    widget.sendString("from apps.chrono import ChronoApp");
                    widget.sendString("${widget.clockPath} = ChronoApp()");
                  } else if (value == 4) {
                    widget
                        .sendString("from apps.word_clock import WordClockApp");
                    widget.sendString("${widget.clockPath} = WordClockApp()");
                  } else if (value == 5) {
                    widget
                        .sendString("from apps.dual_clock import DualClockApp");
                    widget.sendString("${widget.clockPath} = DualClockApp()");
                  }
                  widget.sendString("wasp.system.switch(${widget.clockPath})");

                  widget.onChanged(clockFaceId);
                });
              },
              hint: Text("Select a clock face."),
            ),
          ]),
        ],
      ),
    );
  }
}
