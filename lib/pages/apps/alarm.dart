import 'package:flutter/material.dart';
import 'package:waspos/pages/alarm.dart';
import 'package:waspos/scripts/apps.dart';
import 'package:waspos/scripts/device.dart';

// widget to view alarms

class AlarmWidget extends StatefulWidget {
  static int monday = 1;
  static int tuesday = 1 << 1;
  static int wednesday = 1 << 2;
  static int thursday = 1 << 3;
  static int friday = 1 << 4;
  static int saturday = 1 << 5;
  static int sunday = 1 << 6;

  static int weekdays = monday | tuesday | wednesday | thursday | friday;
  static int weekends = saturday | sunday;
  static int every = weekdays | weekends;

  const AlarmWidget({
    Key key,
  }) : super(key: key);

  @override
  _AlarmWidgetState createState() => _AlarmWidgetState();
}

class _AlarmWidgetState extends State<AlarmWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // create a new alarm
  void newAlarm() async {
    Map<String, dynamic> alarmApp = Device.device.state.apps["Alarm"];

    int currentAlarms =
        await Device.message("${Device.appPath("AlarmApp")}.num_alarms")
            .then((SendResponse value) => int.parse(value.text));

    if (currentAlarms >= 4) {
      return;
    }

    alarmApp[(currentAlarms + 1).toString()] = {
      "hours": 8,
      "minutes": 0,
      "state": 0
    };

    alarmApp["number"] = currentAlarms + 1;

    if (mounted) {
      setState(() {
        Device.device.state.apps["Alarm"] = alarmApp;
      });
    }

    await WatchApps.apps["Alarm"].update();
  }

  // create a list of the alarms
  List<Widget> getChildren() {
    List<Widget> children = [];

    Map<String, dynamic> alarmApp = Device.device.state.apps["Alarm"];

    for (int i = 0; i < alarmApp["number"] ?? 0; i++) {
      Map<String, dynamic> item = alarmApp[i.toString()];

      children.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(
              "${item["hours"].toString()}:${item["minutes"].toString().padLeft(2, '0')}",
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(width: 16),
            Text(item["state"] & AlarmWidget.every == AlarmWidget.weekdays
                ? "Weekdays"
                : item["state"] & AlarmWidget.every == AlarmWidget.weekends
                    ? "Weekends"
                    : item["state"] & AlarmWidget.every == AlarmWidget.every
                        ? "Everyday"
                        : item["state"] & AlarmWidget.every == 0
                            ? "Only Once"
                            : "Custom Range")
          ]),
          OutlinedButton(
              onPressed: () {
                if (mounted) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AlarmEdit(
                                alarmId: i,
                              ))).then((_) => {
                        if (mounted) {setState(() {})}
                      });
                }
              },
              child: Icon(Icons.edit_outlined))
        ],
      ));
    }

    if (children.length < 4) {
      children.add(OutlinedButton(
          onPressed: () {
            newAlarm();
          },
          child: Icon(Icons.add)));
    }

    return children;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: getChildren(),
    );
  }
}
