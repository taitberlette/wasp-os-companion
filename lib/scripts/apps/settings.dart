import 'package:flutter/material.dart';
import 'package:waspos/pages/apps/settings.dart';
import 'package:waspos/scripts/apps.dart';

class SettingsApp extends WatchApp {
  @override
  String name = "Settings";

  @override
  Widget widget = SettingsWidget();

  @override
  bool visible() {
    return true;
  }

  @override
  bool active() {
    return true;
  }
}
