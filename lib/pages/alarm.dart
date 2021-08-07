import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waspos/pages/connect.dart';
import 'package:waspos/pages/widgets/layout.dart';
import 'package:waspos/pages/apps/alarm.dart';
import 'package:waspos/scripts/device.dart';

// widget to edit an alarm on the watch

class AlarmEdit extends StatefulWidget {
  const AlarmEdit({Key key, this.alarmId = 0}) : super(key: key);

  final int alarmId;

  @override
  _AlarmEditState createState() => _AlarmEditState();
}

class _AlarmEditState extends State<AlarmEdit> {
  StreamSubscription<Device> deviceSubscription;

  // options (in the same order as the bits used on the watch)
  List<String> options = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
    "Enabled"
  ];

  // details
  Map<String, dynamic> alarm = {};

  @override
  void initState() {
    super.initState();

    deviceSubscription = Device.deviceStream.listen(data);

    alarm = Device.device.state.apps["Alarm"][this.widget.alarmId.toString()];
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
          "Editing alarm ${this.widget.alarmId}.",
          style: TextStyle(fontSize: 20),
        ),
        Container(
          height: 48,
        ),
        InkWell(
          onTap: () async {
            final TimeOfDay newTime = await showTimePicker(
              context: context,
              initialTime:
                  TimeOfDay(hour: alarm["hours"], minute: alarm["minutes"]),
            );

            if (newTime != null && mounted) {
              setState(() {
                alarm["hours"] = newTime.hour;
                alarm["minutes"] = newTime.minute;

                Device.device.state.apps["Alarm"]
                    [this.widget.alarmId.toString()] = alarm;

                Device.message(
                    "${Device.appPath("AlarmApp")}.alarms[${this.widget.alarmId}][0] = ${alarm["hours"]}");

                Device.message(
                    "${Device.appPath("AlarmApp")}.alarms[${this.widget.alarmId}][1] = ${alarm["minutes"]}");

                Device.message("wasp.system.app._draw()");
              });
            }
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(16),
            width: double.infinity,
            child: Center(
              child: Text(
                "${alarm["hours"].toString()}:${alarm["minutes"].toString().padLeft(2, "0")}",
                style: TextStyle(fontSize: 64, color: Colors.blue),
              ),
            ),
          ),
        ),
        Text(alarm["state"] & AlarmWidget.every == AlarmWidget.weekdays
            ? "Weekdays"
            : alarm["state"] & AlarmWidget.every == AlarmWidget.weekends
                ? "Weekends"
                : alarm["state"] & AlarmWidget.every == AlarmWidget.every
                    ? "Everyday"
                    : alarm["state"] & AlarmWidget.every == 0
                        ? "Only Once"
                        : "Custom Range"),
        for (int i = 0; i < options.length; i++)
          Container(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(options[i]),
              Checkbox(
                  value: ((alarm["state"] >> i) & 1) == 1 ? true : false,
                  onChanged: (bool enabled) {
                    if (mounted) {
                      setState(() {
                        int num = enabled ? 1 : 0;
                        alarm["state"] ^= (-num ^ alarm["state"]) & (1 << i);

                        Device.message(
                            "${Device.appPath("AlarmApp")}.alarms[${this.widget.alarmId}][2] = ${alarm["state"]}");

                        Device.message("wasp.system.app._draw()");
                      });
                    }
                  })
            ],
          )),
        OutlinedButton(
            onPressed: () {
              Device.message(
                  "${Device.appPath("AlarmApp")}._remove_alarm(${this.widget.alarmId})");

              Device.message("wasp.system.app._draw()");

              Device.sync();

              Navigator.pop(context);
            },
            child: Icon(Icons.delete))
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
