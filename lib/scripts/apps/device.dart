import 'package:flutter/material.dart';
import 'package:waspos/pages/apps/device.dart';
import 'package:waspos/scripts/apps.dart';

class DeviceApp extends WatchApp {
  @override
  String name = "Device";

  @override
  Widget widget = DeviceWidget();

  @override
  bool showTitle = false;

  @override
  bool visible() {
    return true;
  }

  @override
  bool active() {
    return true;
  }
}
