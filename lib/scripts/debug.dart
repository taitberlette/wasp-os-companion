import 'dart:async';

// simple debugging (uart) logic
class Debug {
  // uart data
  static String uart = ">>> ";

  // uart stream
  static StreamController<String> uartStreamController =
      StreamController<String>.broadcast();
  static Stream<String> uartStream = uartStreamController.stream;

  // called from native code when new uart data is available
  static uartData(String text) {
    Debug.uart += text;
    uartStreamController.sink.add(text);
  }

  // clear the uart data
  static clear() {
    Debug.uart = "";
    uartStreamController.sink.add("");
  }

  // dispose
  static stop() {
    uartStreamController.close();
  }
}
