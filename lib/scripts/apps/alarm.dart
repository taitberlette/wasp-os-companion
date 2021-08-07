import 'package:flutter/material.dart';
import 'package:waspos/pages/apps/alarm.dart';
import 'package:waspos/scripts/apps.dart';
import 'package:waspos/scripts/device.dart';

class AlarmApp extends WatchApp {
  @override
  String name = "Alarm";

  @override
  Widget widget = AlarmWidget();

  @override
  Future<Map<String, dynamic>> sync() async {
    Map<String, dynamic> data = {};

    data["number"] =
        await Device.message("${Device.appPath("AlarmApp")}.num_alarms")
            .then((SendResponse value) => int.parse(value.text ?? "0"));

    for (int i = 0; i < 4; i++) {
      data[i.toString()] = {
        "hours":
            await Device.message("${Device.appPath("AlarmApp")}.alarms[$i][0]")
                .then((SendResponse value) => int.parse(value.text ?? "0")),
        "minutes":
            await Device.message("${Device.appPath("AlarmApp")}.alarms[$i][1]")
                .then((SendResponse value) => int.parse(value.text ?? "0")),
        "state":
            await Device.message("${Device.appPath("AlarmApp")}.alarms[$i][2]")
                .then((SendResponse value) => int.parse(value.text ?? "0")),
      };
    }

    return data;
  }

  @override
  Future<void> update() async {
    Map<String, dynamic> alarmApp = Device.device.state.apps["Alarm"];

    Device.message(
        "${Device.appPath("AlarmApp")}.num_alarms = ${alarmApp["number"]}");

    Device.message("wasp.system.app._draw()");

    for (int i = 0; i < 4; i++) {
      Device.message(
          "${Device.appPath("AlarmApp")}.alarms[$i][0] = ${alarmApp[i.toString()]["hours"]}");
      Device.message(
          "${Device.appPath("AlarmApp")}.alarms[$i][1] = ${alarmApp[i.toString()]["minutes"]}");
      Device.message(
          "${Device.appPath("AlarmApp")}.alarms[$i][2] = ${alarmApp[i.toString()]["state"]}");
    }

    Device.message("wasp.system.app._draw()");
  }

  @override
  bool visible() {
    return active();
  }

  @override
  bool active() {
    return Device.appInstalled("AlarmApp");
  }
}
