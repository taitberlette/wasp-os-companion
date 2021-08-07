import 'package:flutter/material.dart';
import 'package:waspos/pages/apps/steps.dart';
import 'package:waspos/scripts/apps.dart';
import 'package:waspos/scripts/device.dart';

class StepsApp extends WatchApp {
  @override
  String name = "Steps";

  @override
  Widget widget = StepsWidget();

  @override
  Future<Map<String, dynamic>> sync() async {
    Map<String, dynamic> data = {};

    for (int i = 0; i < 7; i++) {
      DateTime date = DateTime.now().subtract(Duration(days: i));

      List<int> bytes = await Device.downloadFile(
          'logs/${date.year}/${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}.steps');

      if (bytes == null) {
        bytes = [];
      }

      data[i.toString()] = {"data": bytes, "time": date};
    }

    return data;
  }

  @override
  bool visible() {
    return active();
  }

  @override
  bool active() {
    return Device.appInstalled("StepCounterApp");
  }
}
