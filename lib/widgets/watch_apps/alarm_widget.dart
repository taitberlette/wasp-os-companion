import 'package:flutter/material.dart';

class AlarmWidget extends StatefulWidget {
  const AlarmWidget({
    Key key,
    @required this.sendString,
    @required this.appPath,
    @required this.enabled,
    @required this.hours,
    @required this.minutes,
    @required this.time,
    this.onChanged,
  }) : super(key: key);

  final Function sendString;
  final Function appPath;
  final bool enabled;
  final int hours;
  final int minutes;
  final String time;

  final Function onChanged;

  @override
  _AlarmWidgetState createState() => _AlarmWidgetState();
}

class _AlarmWidgetState extends State<AlarmWidget> {
  bool enabled;
  int hours;
  int minutes;
  String time;

  @override
  void initState() {
    super.initState();
    enabled = widget.enabled;
    hours = widget.hours;
    minutes = widget.minutes;
    time = widget.time;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Divider(height: 16),
          SizedBox(height: 15),
          Text("Alarm", style: TextStyle(fontSize: 16, color: Colors.black)),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Enabled:",
                  style: TextStyle(fontSize: 14, color: Colors.black)),
              Checkbox(
                  value: widget.enabled,
                  onChanged: (value) {
                    setState(() {
                      enabled = value;
                      widget.onChanged(enabled, hours, minutes, time);
                    });

                    widget.sendString(
                        "${widget.appPath("AlarmApp")}.active.state = ${value ? "True" : "False"}");

                    widget.sendString(
                        "${widget.appPath("AlarmApp")}._set_current_alarm()");

                    widget.sendString("wasp.system.app._draw()");
                  }),
            ],
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Time:    ",
                style: TextStyle(fontSize: 14, color: Colors.black)),
            OutlinedButton(
                child: Text(widget.time),
                onPressed: () async {
                  final TimeOfDay timePicker = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null)
                    setState(() {
                      hours = timePicker.hour;
                      minutes = timePicker.minute;
                      time = timePicker.format(context);
                      widget.onChanged(enabled, hours, minutes, time);
                    });

                  widget.sendString(
                      "${widget.appPath("AlarmApp")}.hours.value = $hours");

                  widget.sendString(
                      "${widget.appPath("AlarmApp")}.minutes.value = $minutes");

                  widget.sendString(
                      "${widget.appPath("AlarmApp")}._set_current_alarm()");

                  widget.sendString("wasp.system.app._draw()");
                })
          ]),
        ],
      ),
    );
  }
}
