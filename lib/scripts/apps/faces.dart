import 'package:flutter/material.dart';
import 'package:waspos/pages/apps/faces.dart';
import 'package:waspos/scripts/apps.dart';

class FacesApp extends WatchApp {
  @override
  String name = "Faces";

  @override
  Widget widget = FacesWidget();

  @override
  bool visible() {
    return true;
  }

  @override
  bool active() {
    return true;
  }
}
