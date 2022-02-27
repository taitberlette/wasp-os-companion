import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:waspos/scripts/apps.dart';
import 'package:waspos/scripts/main.dart';
import 'package:waspos/scripts/util.dart';

// device interface class
class Device {
  // the current device
  static Device device;

  // device stream
  static StreamController<Device> deviceStreamController =
      StreamController<Device>.broadcast();
  static Stream<Device> deviceStream = deviceStreamController.stream;

  // device message stream
  static StreamController<SendResponse> messageStreamController =
      StreamController<SendResponse>.broadcast();
  static Stream<SendResponse> messageStream = messageStreamController.stream;

  String name;
  String uuid;
  int connectState;
  bool syncing;
  bool updating;
  bool askingNotifications;
  DeviceState state;
  DateTime syncTime;

  Device() {
    name = "";
    uuid = "";
    connectState = 0;
    syncing = false;
    updating = false;
    askingNotifications = false;
    state = DeviceState();
    syncTime = DateTime.now();
  }

  // create the device
  static start() {
    Device.device = Device();
  }

  // connect to the watch
  static connect() {
    // if (Device.device.connectState != 0) return;

    methodChannel.invokeMethod("startBackgroundService");

    Device.device.connectState = 1;

    deviceStreamController.sink.add(Device.device);

    methodChannel.invokeMethod("connectToBluetooth");
  }

  // called when the native code is connecting
  static connecting(String name) {
    // if (Device.device.connectState == 0) return;

    Device.device.name = name;
    Device.device.connectState = 2;

    deviceStreamController.sink.add(Device.device);
  }

  // called when the native code is connected
  static connected(String name, String uuid) {
    // if (Device.device.connectState == 3) return;

    Device.device.name = name;
    Device.device.uuid = uuid;
    Device.device.connectState = 3;

    deviceStreamController.sink.add(Device.device);

    Device.sync();
  }

  // disconnect from the watch
  static disconnect() {
    // if (Device.device.connectState == 0) return;

    Device.device.connectState = 0;

    deviceStreamController.sink.add(Device.device);

    methodChannel.invokeMethod("disconnectFromBluetooth");
  }

  // called when the native code is disconnected
  static disconnected() {
    // if (Device.device.connectState == 0) return;

    Device.device.connectState = 0;

    deviceStreamController.sink.add(Device.device);
  }

  // called when the native code gets a response
  static response(String text, String command) {
    text = text.trim();
    command = command.trim();

    if (text.startsWith("Traceback") || text.startsWith("MemoryError"))
      text = null;

    messageStreamController.sink.add(SendResponse(text, command));
  }

  // async function to send commands to the watch
  static Future<SendResponse> message(String command) async {
    // if (Device.device.connectState != 3) return null;

    command = command.trim();

    methodChannel
        .invokeMethod("writeToBluetooth", <String, dynamic>{"data": command});

    SendResponse response = await Device.messageStream
        .firstWhere((SendResponse element) => command == element.command);

    return response ?? SendResponse(null, null);
  }

  // sync the device
  static Future<void> sync() async {
    // if (Device.device.connectState != 3 ||
    //     Device.device.syncing ||
    //     Device.device.updating) return;

    Device.device.syncing = true;

    deviceStreamController.sink.add(Device.device);

    SendResponse brightness = await Device.message("wasp.system.brightness");
    Device.device.state.brightnessLevel =
        double.parse(brightness.text ?? "1.0") - 1;

    SendResponse notification =
        await Device.message("wasp.system.notify_level");
    Device.device.state.notificationLevel =
        double.parse(notification.text ?? "1.0") - 1;

    SendResponse units = await Device.message("wasp.system.units");
    Device.device.state.units =
        units.text != null ? units.text.replaceAll("'", "") : "Metric";

    SendResponse battery = await Device.message("watch.battery.level()");
    Device.device.state.batteryLevel = int.parse(battery.text ?? "0");

    SendResponse steps = await Device.message("watch.accel.steps");
    Device.device.state.steps = int.parse(steps.text ?? "0");

    SendResponse quickRing = await Device.message("wasp.system.quick_ring");
    Device.device.state.quickRing = parseRing(quickRing.text ?? "");

    SendResponse launcherRing =
        await Device.message("wasp.system.launcher_ring");
    Device.device.state.launcherRing = parseRing(launcherRing.text ?? "");

    for (WatchApp app in WatchApps.apps.values) {
      if (app.active()) Device.device.state.apps[app.name] = await app.sync();
    }

    Device.collectMemory();

    Device.device.syncing = false;

    Device.device.syncTime = DateTime.now();

    deviceStreamController.sink.add(Device.device);
  }

  // change the watch updating state
  static updateState(bool running) {
    Device.device.updating = running;

    deviceStreamController.sink.add(Device.device);
  }

  // get the path of an app on the watch
  static String appPath(String appName, [int ring]) {
    DeviceState state = Device.device.state;

    if (ring == null || ring == 0) {
      for (int i = 0; i < state.quickRing.length; i++) {
        if (state.quickRing[i] == appName) {
          return "wasp.system.quick_ring[$i]";
        }
      }
    }

    if (ring == null || ring == 1) {
      for (int i = 0; i < state.launcherRing.length; i++) {
        if (state.launcherRing[i] == appName) {
          return "wasp.system.launcher_ring[$i]";
        }
      }
    }

    return "";
  }

  // check if an app is installed on the watch
  static bool appInstalled(String appName, [int ring]) {
    return Device.appPath(appName, ring) != "";
  }

  // run gc.collect() on the watch
  static collectMemory() {
    Device.message("import gc");
    Device.message("gc.collect()");
    Device.message("del gc");
  }

  // upload a file to the file system
  static Future<void> uploadFile(String filename, List<int> bytes) async {
    if (bytes == null) {
      return;
    }

    Device.message('upload = open("$filename", "wb")');

    Device.message('upload.seek(0)');

    for (int i = 0; i < bytes.length; i += 24) {
      List<int> packet = bytes.sublist(i, min(i + 24, bytes.length));

      Device.message("upload.write(bytes(bytearray(${packet.toString()})))");

      if (i % (4 * 24) == 0) {
        Device.collectMemory();
      }
    }

    await Device.message("upload.close()");

    Device.message("del upload");

    Device.collectMemory();

    return null;
  }

  // download a file from the filesystem
  static Future<List<int>> downloadFile(String filename) async {
    List<int> bytes = [];

    Device.message('import os');

    SendResponse stats = await Device.message('os.stat("$filename")[6]');

    if (stats.text == null) {
      return null;
    }

    int fileSize = int.parse(stats.text) ?? 0;

    Device.message('download = open("$filename", "rb")');

    for (int i = 0; i < fileSize; i += 24) {
      SendResponse message = await Device.message('list(download.read(24))');

      if (message.text == null) return null;

      List<int> currentBytes = jsonDecode(message.text).cast<int>();

      bytes.addAll(currentBytes);

      if (i % (4 * 24) == 0) {
        Device.collectMemory();
      }
    }

    Device.message("del os");
    Device.message("del download");

    Device.collectMemory();

    return bytes;
  }

  // ask for watch notifications
  static askNotifications() {
    Device.device.askingNotifications = true;
  }

  // accept the notification request
  static acceptNotifications() {
    methodChannel.invokeMethod("acceptNotifications");
  }

  // dispose
  static stop() {
    Device.disconnect();
    deviceStreamController.close();
    messageStreamController.close();
  }
}

// device state (sync)
class DeviceState {
  double brightnessLevel = 0;
  double notificationLevel = 0;
  String units = "Metric";

  int batteryLevel = 0;

  int steps = 0;

  List<String> quickRing = [];
  List<String> launcherRing = [];

  Map<String, Map<String, dynamic>> apps = {};
}

// message response from native code
class SendResponse {
  String command = "";
  String text = "";

  SendResponse(String _text, String _command) {
    text = _text;
    command = _command;
  }
}
