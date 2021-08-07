import 'package:shared_preferences/shared_preferences.dart';

// a simple shared preferences interface
class Storage {
  static SharedPreferences prefs;

  static start() async {
    prefs = await SharedPreferences.getInstance();
  }
}
