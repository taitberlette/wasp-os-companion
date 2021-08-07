import 'dart:async';

import 'package:flutter/services.dart';
import 'package:waspos/scripts/debug.dart';
import 'package:waspos/scripts/device.dart';
import 'package:waspos/scripts/storage.dart';

Timer syncTimer;
MethodChannel methodChannel;

// init
void start() {
  syncTimer = Timer.periodic(Duration(minutes: 10), sync);

  methodChannel =
      MethodChannel("io.github.taitberlette.wasp_os_companion/messages");

  methodChannel.setMethodCallHandler(channel);

  Device.start();
  Storage.start();
}

// sync
void sync(Timer timer) {
  Device.sync();
}

// handle messages from the native code
Future<void> channel(MethodCall call) {
  switch (call.method) {
    case "watchConnecting":
      Device.connecting(call.arguments["data"]);
      break;
    case "watchConnected":
      Device.connected(call.arguments["main"], call.arguments["extra"]);
      break;
    case "watchDisconnected":
      Device.disconnected();
      break;
    case "watchUart":
      Debug.uartData(call.arguments["data"]);
      break;
    case "watchCommand":
      break;
    case "watchResponse":
      Device.response(call.arguments["main"], call.arguments["extra"]);
      break;
    case "askNotifications":
      break;
  }

  return null;
}

// dispose
void stop() {
  Device.stop();
  Debug.stop();

  syncTimer.cancel();
}
