import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_nordic_dfu/flutter_nordic_dfu.dart';
import 'package:http/http.dart';

import './widgets/device_widget.dart';
import './widgets/watch_apps/alarm_widget.dart';
import './widgets/watch_apps/clock_widget.dart';
import './widgets/watch_apps/steps_widget.dart';
import './widgets/watch_apps/settings_widget.dart';
import './widgets/watch_apps/uart_widget.dart';

import './widgets/header_widget.dart';
import './widgets/status_widget.dart';
import './widgets/location_widget.dart';
import './widgets/upload_widget.dart';

void main() async {
  // Run the application
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Setup the application
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wasp-os',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Home(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Home extends StatefulWidget {
  Home({Key key}) : super(key: key);

  // Create the application state
  @override
  _Home createState() => _Home();
}

class _Home extends State<Home> {
  // Scaffold key for floating action button, snackbars, etc
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  // Location permisions (needed for BLE)
  PermissionStatus _locationPermissionStatus;

  // Recent notifications (to help prevent multiple messages)
  Map<String, int> recentNotification = {};

  // Watch application rings
  List<String> quickRing = [];
  List<String> launcherRing = [];
  List<String> updatingQuickRing = [];
  List<String> updatingLauncherRing = [];

  // Command variables
  List<String> commandList = [];
  bool responseWaiting = false;
  bool haltCommands = false;
  String responseText = "";
  String actionText = "";
  String commandText = "";

  // Device variables
  String watch;
  String watchAddress;
  int connectingState = 0;
  int batteryLevel = 0;

  // Sync variables
  DateTime lastSync = DateTime.now();

  // Timer variables
  Timer syncTimer;

  // Watch settings app variables
  double brightnessSlider = 2;
  double notifySlider = 2;

  // Watch alarm app variales
  bool alarmAppEnabled = false;
  int alarmAppHours = 7;
  int alarmAppMinutes = 0;
  String alarmAppTime = "7:00 AM";

  // Watch clock app variables
  int clockFaceId = 1;
  String clockPath = "";

  // Watch steps app variables
  int steps = 0;

  // Watch snake game variables
  int snakeHighscore = 1;

  // File storage variables
  List<String> highscores = [];
  dynamic stepsHistory;
  Map<String, dynamic> stepsHistoryMap = new Map<String, dynamic>();

  // UART console variables
  String uartContent = ">>> ";
  bool showConsole = false;
  ScrollController uartScrollController = new ScrollController();

  // MethodChannel (talk to native code)
  MethodChannel methodChannel;

  //MemoryError
  bool memoryError = false;

  //DFU
  bool dfuRunning = false;
  int dfuProgress = 0;
  int uploadState = 0;

  // Runs when the app is started
  @override
  void initState() {
    methodChannel =
        MethodChannel("io.github.taitberlette.wasp_os_companion/messages");
    methodChannel.setMethodCallHandler(_handleMethodChannel);

    methodChannel.invokeMethod("connectedToChannel");

    _checkPermissions();
    syncTimer = Timer.periodic(
        Duration(minutes: 30), (Timer t) => _updatePhoneSystem());

    super.initState();
  }

  // Runs when the app is closed
  @override
  void dispose() {
    _disconnect();
    syncTimer.cancel();
    super.dispose();
  }

  Future<void> downloadWebBuild(String type) async {
    if (watch == null ||
        (connectingState != 3 && connectingState != 4) ||
        memoryError) {
      return;
    }
    try {
      setState(() {
        dfuRunning = true;
        dfuProgress = 0;
        uploadState = 1;
      });

      Response res = await get(Uri.https(
          'wasp-os-companion.glitch.me', 'api/$type/${watch.toLowerCase()}'));

      if (res.statusCode != 200) {
        throw "network error";
      }

      Map<String, dynamic> json = jsonDecode(res.body);

      String url = json["url"];

      if (url == "" || url == null) {
        throw "file not found";
      }

      HttpClient client = new HttpClient();
      dynamic fileReq = await client.getUrl(Uri.parse(url));
      dynamic fileRes = await fileReq.close();
      List<int> bytes = await consolidateHttpClientResponseBytes(fileRes);

      Archive archive;

      if (type == "actions") {
        archive = ZipDecoder().decodeBytes(bytes);
      } else {
        List<int> archiveBytes = GZipDecoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(archiveBytes);
      }

      dynamic micropython;

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          if (type == "actions"
              ? filename == "micropython.zip"
              : filename
                  .endsWith("build-${watch.toLowerCase()}/micropython.zip")) {
            micropython = file.content as List<int>;
          }
        }
      }
      if (micropython == null) {
        throw "micropython";
      }

      File micropythonZip = await _getFile("micropython.zip");
      micropythonZip.writeAsBytesSync(micropython);

      _sendString("import machine");
      _sendString("machine.enter_ota_dfu()");
      doDfu(watchAddress, micropythonZip.path);

      await Future.delayed(Duration(seconds: 3));
      _disconnect();
    } catch (e) {
      setState(() {
        dfuRunning = false;
        dfuProgress = 0;
      });
      final snackBar = SnackBar(
        duration: Duration(minutes: 10),
        behavior: SnackBarBehavior.fixed,
        action: SnackBarAction(
          label: "Retry",
          onPressed: () {
            downloadWebBuild(type);
          },
        ),
        content: Text('Watch update failed!'),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      print(e.toString());
    }
  }

  Future<void> doDfu(String deviceId, String file) async {
    setState(() {
      dfuRunning = true;
      dfuProgress = 0;
      uploadState = 0;
    });
    String top = deviceId.substring(0, 15);
    String value = deviceId.substring(15, 17);
    int number = int.parse(value, radix: 16);
    number++;
    number = number & 0xFF;
    value = number.toRadixString(16);
    value = value.toUpperCase();

    try {
      String s = await FlutterNordicDfu.startDfu(
        top + value,
        file,
        androidSpecialParameter:
            AndroidSpecialParameter(disableNotification: true),
        numberOfPackets: 20,
        progressListener:
            DefaultDfuProgressListenerAdapter(onProgressChangedHandle: (
          deviceAddress,
          percent,
          speed,
          avgSpeed,
          currentPart,
          partsTotal,
        ) {
          setState(() {
            dfuProgress = percent;
          });
        }),
      );
      setState(() {
        dfuRunning = false;
        dfuProgress = 0;
      });
      _connect();
    } catch (e) {
      setState(() {
        dfuRunning = false;
        dfuProgress = 0;
      });

      final snackBar = SnackBar(
        duration: Duration(minutes: 10),
        behavior: SnackBarBehavior.fixed,
        action: SnackBarAction(
          label: "Retry",
          onPressed: () {
            doDfu(deviceId, file);
          },
        ),
        content: Text('Watch update failed!'),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      print(e.toString());
    }
  }

  Future<void> _handleMethodChannel(MethodCall call) {
    switch (call.method) {
      case "watchConnected":
        setState(() {
          connectingState = 3;
          try {
            watch = call.arguments["main"];
            watchAddress = call.arguments["extra"];
          } catch (e) {
            watch = "PineTime";
          }
        });
        _updatePhoneSystem();
        break;
      case "watchConnecting":
        setState(() {
          connectingState = 2;
          try {
            watch = call.arguments["data"];
          } catch (e) {
            watch = "PineTime";
          }
        });
        break;
      case "watchDisconnected":
        setState(() {
          connectingState = 0;
          watch = null;
        });
        break;
      case "watchCommand":
        _handleCommand(call.arguments["data"]);
        break;
      case "watchResponse":
        _handleResponse(call.arguments["main"], call.arguments["extra"]);
        break;
      case "watchUart":
        setState(() {
          uartContent += call.arguments["data"];
          uartScrollController.animateTo(
              uartScrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 500),
              curve: Curves.ease);
        });
        break;
      case "askNotifications":
        Widget cancelButton = FlatButton(
          child: Text("No"),
          onPressed: () {
            Navigator.pop(context);
          },
        );
        Widget continueButton = FlatButton(
          child: Text("Yes"),
          onPressed: () {
            methodChannel.invokeMethod("acceptNotifications");
            Navigator.pop(context);
          },
        );
        AlertDialog alert = AlertDialog(
          title: Text("Enable watch notifications?"),
          content: Text(
              "If you would like your notifications to show on your watch you need to enable the notification listener."),
          actions: [
            cancelButton,
            continueButton,
          ],
        );
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return alert;
          },
        );

        break;
      default:
        break;
    }
    return null;
  }

  // This function checks to see if we have permission to access the local, which we need for BLE
  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      var permissionStatus = await PermissionHandler()
          .requestPermissions([PermissionGroup.location]);

      setState(() {
        _locationPermissionStatus = permissionStatus[PermissionGroup.location];
      });

      if (_locationPermissionStatus != PermissionStatus.granted) {
        return Future.error(Exception("Location permission not granted"));
      }
    }
  }

  // This function disconnects the watch, if it is connected
  void _disconnect() async {
    setState(() {
      connectingState = 0;
    });

    methodChannel.invokeMethod("disconnectFromBluetooth");

    watch = null;
  }

  // This function finds and connects a wasp-os watch, if none are connected
  void _connect() async {
    if (watch != null || connectingState != 0) {
      return;
    }

    methodChannel.invokeMethod("startBackgroundService");
    setState(() {
      connectingState = 1;
    });

    methodChannel.invokeMethod("connectToBluetooth");
  }

  // This function updates the time on the watch, and retrives the application ring
  void _updatePhoneSystem() async {
    if (watch == null || (connectingState != 3 && connectingState != 4)) {
      return;
    }
    File highscoreFile = await _getFile("highscores.txt");
    String highscoreString = await highscoreFile.readAsString();
    if (highscoreString == "") {
      highscoreString = "1";
    }
    highscores = highscoreString.split("|");
    snakeHighscore = int.parse(highscores[0]);

    File stepsFile = await _getFile("steps.json");
    String stepsString = await stepsFile.readAsString();
    if (stepsString == "") {
      stepsString = "{}";
    }

    stepsHistory = json.decode(stepsString);
    setState(() {
      stepsHistoryMap = stepsHistory as Map<String, dynamic>;
      Map stepsHistoryMapCache = new Map<String, dynamic>();
      for (int i = stepsHistory.keys.length - 1; i >= 0; i--) {
        stepsHistoryMapCache.putIfAbsent(stepsHistory.keys.elementAt(i),
            () => stepsHistory.values.elementAt(i));
      }
      stepsHistoryMap = stepsHistoryMapCache;
    });

    updatingLauncherRing = [];
    updatingQuickRing = [];
    commandList = [];
    responseWaiting = false;
    haltCommands = false;
    responseText = "";
    commandText = "";
    memoryError = false;

    DateTime now = new DateTime.now();
    _sendString(
        "watch.rtc.set_localtime((${now.year},${now.month},${now.day},${now.hour},${now.minute},${now.second}))");

    _sendString("wasp.system.quick_ring");

    _sendString("wasp.system.launcher_ring");
  }

  // This functions retrives variables from the apps on the watch
  void _updatePhoneApps() {
    setState(() {
      clockPath = _appPath("ClockApp", 0) != ""
          ? _appPath("ClockApp", 0)
          : _appPath("FibonacciClockApp", 0) != ""
              ? _appPath("FibonacciClockApp", 0)
              : _appPath("ChronoApp", 0) != ""
                  ? _appPath("ChronoApp", 0)
                  : _appPath("WordClockApp", 0);

      clockFaceId = _appPath("ClockApp", 0) != ""
          ? 1
          : _appPath("FibonacciClockApp", 0) != ""
              ? 2
              : _appPath("ChronoApp", 0) != ""
                  ? 3
                  : 4;
    });

    if (_appPath("AlarmApp") != "") {
      _sendString("${_appPath("AlarmApp")}.hours.value");
      _sendString("${_appPath("AlarmApp")}.minutes.value");
      _sendString("${_appPath("AlarmApp")}.active.state");
    }

    if (_appPath("SnakeGameApp") != "") {
      _sendString("${_appPath("SnakeGameApp")}.highscore");
    }

    _sendString("watch.accel.steps");

    _sendString("wasp.system.brightness");

    _sendString("wasp.system.notify_level");

    _sendString("watch.battery.level()");

    setState(() {
      connectingState = 4;
    });

    lastSync = DateTime.now();
  }

  // This function gets a file from our application directory
  Future<File> _getFile(String file) async {
    final directory = await getApplicationDocumentsDirectory();
    File data = new File("${directory.path}/$file");
    if (!data.existsSync()) {
      data.createSync();
    }
    return data;
  }

  // This function checks to see if an app is enabled on the watch
  String _appPath(String appPackage, [int ring]) {
    String path = "";
    if (ring != null) {
      if (ring == 0) {
        for (int i = 0; i < quickRing.length; i++) {
          if (quickRing[i] == appPackage) {
            path = "wasp.system.quick_ring[$i]";
          }
        }
      } else {
        for (int i = 0; i < launcherRing.length; i++) {
          if (launcherRing[i] == appPackage) {
            path = "wasp.system.launcher_ring[$i]";
          }
        }
      }
    } else {
      for (int i = 0; i < quickRing.length; i++) {
        if (quickRing[i] == appPackage) {
          path = "wasp.system.quick_ring[$i]";
        }
      }
      for (int i = 0; i < launcherRing.length; i++) {
        if (launcherRing[i] == appPackage) {
          path = "wasp.system.launcher_ring[$i]";
        }
      }
    }

    return path;
  }

  // This function parses an application ring
  void parseRing(String ring, int type) {
    ring = ring.replaceAll(RegExp(r'(<|>|object at |\[|\])'), "");

    List<String> ringApps = ring.split(", ");
    for (int i = 0; i < ringApps.length; i++) {
      ringApps[i] = ringApps[i].split(" ")[0].trim();
    }

    setState(() {
      if (type == 0) {
        updatingQuickRing = ringApps;
      } else if (type == 1) {
        updatingLauncherRing = ringApps;
      }
    });

    if (updatingLauncherRing.length >= 1 && updatingQuickRing.length >= 1) {
      quickRing = updatingQuickRing;
      launcherRing = updatingLauncherRing;
      _updatePhoneApps();
    }
  }

  void _handleCommand(String text) async {
    // Nothing yet...
  }

  // This functions parses a response from the watch
  void _handleResponse(String text, String command) async {
    command = command.trim();

    if (text.trim().startsWith("Traceback")) {
      return;
    }

    if (text.trim().startsWith("MemoryError")) {
      if (memoryError) {
        return;
      }
      final snackBar = SnackBar(
        duration: Duration(minutes: 10),
        behavior: SnackBarBehavior.fixed,
        content: Text('Your watch is running low on memory.'),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);

      memoryError = true;

      // Try again after 10 minutes (if the user disconnects and reconnects the watch it will also reset)
      new Future.delayed(
          const Duration(minutes: 10), () => {memoryError = false});

      return;
    }
    memoryError = false;

    if (command == "wasp.system.brightness") {
      setState(() {
        brightnessSlider = double.parse(text);
      });
    }
    if (command == "wasp.system.notify_level") {
      setState(() {
        notifySlider = double.parse(text);
      });
    }
    if (command == "wasp.system.quick_ring") {
      parseRing(text, 0);
    }
    if (command == "wasp.system.launcher_ring") {
      parseRing(text, 1);
    }
    if (command == "watch.battery.level()") {
      setState(() {
        batteryLevel = int.parse(text);
      });
    }
    if (command == "${_appPath("AlarmApp")}.hours.value") {
      setState(() {
        alarmAppHours = int.parse(text);
        String hourText =
            alarmAppHours > 12 ? "${alarmAppHours - 12}" : "$alarmAppHours";
        String minuteText =
            alarmAppMinutes > 9 ? "$alarmAppMinutes" : "${alarmAppMinutes}0";
        String amPm = alarmAppHours > 12 ? "PM" : "AM";
        alarmAppTime = "$hourText:$minuteText $amPm";
      });
    }
    if (command == "${_appPath("AlarmApp")}.minutes.value") {
      setState(() {
        alarmAppMinutes = int.parse(text);
        String hourText =
            alarmAppHours > 12 ? "${alarmAppHours - 12}" : "$alarmAppHours";
        String minuteText =
            alarmAppMinutes > 9 ? "$alarmAppMinutes" : "${alarmAppMinutes}0";
        String amPm = alarmAppHours > 12 ? "PM" : "AM";
        alarmAppTime = "$hourText:$minuteText $amPm";
      });
    }
    if (command == "${_appPath("AlarmApp")}.active.state") {
      setState(() {
        alarmAppEnabled = text.trim() == "True" ? true : false;
      });
    }
    if (command == "${_appPath("SnakeGameApp")}.highscore") {
      if (snakeHighscore < int.parse(text)) {
        setState(() {
          snakeHighscore = int.parse(text);
          highscores[0] = "$snakeHighscore";
        });

        File highscoreFile = await _getFile("highscores.txt");
        await highscoreFile.writeAsString(highscores.join("|"));
      } else {
        _sendString("${_appPath("SnakeGameApp")}.highscore = $snakeHighscore");
      }
    }
    if (command == "watch.accel.steps") {
      setState(() {
        steps = int.parse(text);
      });

      DateTime now = new DateTime.now();
      if (stepsHistory["${now.year}/${now.month}/${now.day}"] == null) {
        stepsHistory["${now.year}/${now.month}/${now.day}"] = steps;
      } else {
        if (stepsHistory["${now.year}/${now.month}/${now.day}"] < steps) {
          stepsHistory["${now.year}/${now.month}/${now.day}"] = steps;
        }
      }

      setState(() {
        stepsHistoryMap = stepsHistory as Map<String, dynamic>;
        Map stepsHistoryMapCache = new Map<String, dynamic>();
        for (int i = stepsHistory.keys.length - 1; i >= 0; i--) {
          stepsHistoryMapCache.putIfAbsent(stepsHistory.keys.elementAt(i),
              () => stepsHistory.values.elementAt(i));
        }
        stepsHistoryMap = stepsHistoryMapCache;
      });

      File stepsFile = await _getFile("steps.json");
      await stepsFile.writeAsString(json.encode(stepsHistory));
    }
  }

  // This function sends a string to the watch
  void _sendString(String text) {
    if (watch == null ||
        (connectingState != 3 && connectingState != 4) ||
        memoryError) {
      return;
    }

    methodChannel
        .invokeMethod("writeToBluetooth", <String, dynamic>{"data": text});
  }

  // The function starts a sync, and shows the refreshing circle for three seconds (about how long a sync takes).
  Future<void> _manualSync() async {
    if (watch == null ||
        (connectingState != 3 && connectingState != 4) ||
        memoryError) {
      return;
    }

    _updatePhoneSystem();

    await Future.delayed(Duration(seconds: 3));
  }

  // This is the UI for the app
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Material(
        animationDuration: new Duration(seconds: 1),
        child: RefreshIndicator(
          onRefresh: _manualSync,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: ClampingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.only(left: 25, right: 25, top: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 25),
                  HeaderWidget(),
                  SizedBox(height: 25),
                  _locationPermissionStatus != PermissionStatus.granted
                      ? LocationWidget()
                      : dfuRunning
                          ? UploadWidget(
                              progress: dfuProgress,
                              state: uploadState,
                            )
                          : connectingState == 4
                              ? Column(
                                  children: [
                                    DeviceWidget(
                                      sendString: _sendString,
                                      appPath: _appPath,
                                      name: watch,
                                      address: watchAddress,
                                      batteryLevel: batteryLevel,
                                      lastSync: lastSync,
                                      onChanged: (state, file) {
                                        if (watch == null ||
                                            (connectingState != 3 &&
                                                connectingState != 4) ||
                                            memoryError) {
                                          return;
                                        }
                                        if (state == 0) {
                                          doDfu(watchAddress, file);

                                          _sendString("import machine");
                                          _sendString(
                                              "machine.enter_ota_dfu()");
                                        } else {
                                          downloadWebBuild(state == 1
                                              ? "actions"
                                              : "release");
                                        }
                                      },
                                    ),
                                    _appPath("AlarmApp") != ""
                                        ? AlarmWidget(
                                            sendString: _sendString,
                                            appPath: _appPath,
                                            enabled: alarmAppEnabled,
                                            hours: alarmAppHours,
                                            minutes: alarmAppMinutes,
                                            time: alarmAppTime,
                                            onChanged: (enabled, hours, minutes,
                                                    time) =>
                                                {
                                              setState(() {
                                                alarmAppEnabled = enabled;
                                                alarmAppHours = hours;
                                                alarmAppMinutes = minutes;
                                                alarmAppTime = time;
                                              })
                                            },
                                          )
                                        : (Container()),
                                    clockPath != ""
                                        ? ClockWidget(
                                            sendString: _sendString,
                                            appPath: _appPath,
                                            faceId: clockFaceId,
                                            clockPath: clockPath,
                                            onChanged: (faceId) => {
                                                  setState(() {
                                                    clockFaceId = faceId;
                                                  })
                                                })
                                        : (Container()),
                                    _appPath("StepCounterApp") != ""
                                        ? StepsWidget(
                                            sendString: _sendString,
                                            appPath: _appPath,
                                            steps: steps,
                                            history: stepsHistoryMap)
                                        : (Container()),
                                    SettingsWidget(
                                      sendString: _sendString,
                                      appPath: _appPath,
                                      brightness: brightnessSlider,
                                      notify: notifySlider,
                                      onChanged: (brightness, notify) => {
                                        setState(() {
                                          brightnessSlider = brightness;
                                          notifySlider = notify;
                                        })
                                      },
                                    ),
                                    UartWidget(
                                      sendString: _sendString,
                                      appPath: _appPath,
                                      show: showConsole,
                                      content: uartContent,
                                      scrollController: uartScrollController,
                                      onChanged: (show) => {
                                        setState(() => {showConsole = show})
                                      },
                                    )
                                  ],
                                )
                              : (StatusWidget(
                                  state: connectingState, watch: watch)),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: dfuRunning != true
          ? FloatingActionButton(
              onPressed: () =>
                  {connectingState != 0 ? _disconnect() : _connect()},
              tooltip: connectingState != 0 ? 'Disconnect' : 'Connect',
              child: Icon(connectingState != 0 ? Icons.close : Icons.sync),
              focusElevation: 30,
            )
          : Container(),
    );
  }
}
