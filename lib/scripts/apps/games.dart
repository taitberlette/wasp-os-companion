import 'package:waspos/scripts/apps.dart';
import 'package:waspos/scripts/device.dart';
import 'package:waspos/scripts/storage.dart';

class GamesApp extends WatchApp {
  @override
  String name = "Games";

  @override
  Future<Map<String, dynamic>> sync() async {
    Map<String, dynamic> data = {};

    if (Device.appInstalled("SnakeGameApp")) {
      data["snake"] = {
        "highscore":
            await Device.message("${Device.appPath("SnakeGameApp")}.highscore")
                .then((value) => int.parse(value.text ?? "1"))
      };

      int storedHighscore = Storage.prefs.getInt("snakeGameHighscore") ?? 1;

      if (storedHighscore > data["snake"]["highscore"]) {
        data["snake"]["highscore"] = storedHighscore;
        Storage.prefs.setInt("snakeGameHighscore", storedHighscore);

        Device.message(
            "${Device.appPath("SnakeGameApp")}.highscore = $storedHighscore");
      } else {
        Storage.prefs.setInt("snakeGameHighscore", data["snake"]["highscore"]);
      }
    }

    return data;
  }

  @override
  bool visible() {
    return false;
  }

  @override
  bool active() {
    return true;
  }
}
