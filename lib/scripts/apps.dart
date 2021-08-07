import 'package:flutter/material.dart';
import 'package:waspos/scripts/apps/alarm.dart';
import 'package:waspos/scripts/apps/faces.dart';
import 'package:waspos/scripts/apps/device.dart';
import 'package:waspos/scripts/apps/settings.dart';
import 'package:waspos/scripts/apps/steps.dart';

import 'apps/games.dart';

// a definition for an app
class WatchApp {
  // details
  String name = "";
  Widget widget;
  bool showTitle = true;

  // is the app visible
  bool visible() {
    return false;
  }

  // is the app active (can it sync)
  bool active() {
    return false;
  }

  // custom sync logic for each app
  Future<Map<String, dynamic>> sync() async {
    return {};
  }

  // custom logic to update the watch for each app
  Future<void> update() {
    return null;
  }
}

// a class to manage apps
class WatchApps {
  static Map<String, WatchApp> apps = {
    // device will always be first
    "Device": DeviceApp(),

    // other apps in alphabetical order
    "Alarm": AlarmApp(),
    "Faces": FacesApp(),
    "Games": GamesApp(),
    "Steps": StepsApp(),

    // settings will always be last
    "Settings": SettingsApp(),
  };

  // get a list of all visible apps
  static List<Widget> getApps() {
    List<Widget> result = [];

    for (WatchApp app in WatchApps.apps.values) {
      if (!app.visible()) continue;

      result.add(Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: 16, bottom: 16, left: 8, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                app.showTitle
                    ? Container(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          app.name,
                          style: TextStyle(fontSize: 20),
                        ),
                      )
                    : Container(),
                app.widget,
              ],
            ),
          ),
          Divider()
        ],
      ));
    }

    return result;
  }
}
