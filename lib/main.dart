import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import './widgets/watch_apps/alarm_widget.dart';
import './widgets/watch_apps/clock_widget.dart';
import './widgets/watch_apps/steps_widget.dart';
import './widgets/watch_apps/settings_widget.dart';
import './widgets/watch_apps/uart_widget.dart';

import './widgets/header_widget.dart';
import './widgets/status_widget.dart';
import './widgets/location_widget.dart';

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
  int connectingState = 0;

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

  // Runs when the app is started
  @override
  void initState() {
    methodChannel =
        MethodChannel("io.github.taitberlette.wasp_os_companion/messages");
    methodChannel.setMethodCallHandler(_handleMethodChannel);

    methodChannel.invokeMethod("connectedToChannel");

    _checkPermissions();
    syncTimer =
        Timer.periodic(Duration(minutes: 1), (Timer t) => _updatePhoneSystem());

    super.initState();
  }

  // Runs when the app is closed
  @override
  void dispose() {
    _disconnect();
    syncTimer.cancel();
    super.dispose();
  }

  Future<void> _handleMethodChannel(MethodCall call) {
    switch (call.method) {
      case "watchConnected":
        setState(() {
          connectingState = 3;
          try {
            watch = call.arguments["data"];
          } catch (e) {
            watch = "unknown wasp-os watch";
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
            watch = "unknown wasp-os watch";
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

    _sendString("wasp.system.app._draw()");

    setState(() {
      connectingState = 4;
    });
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

    if (text.startsWith("Traceback")) {
      return;
    }

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
    if (watch == null || (connectingState != 3 && connectingState != 4)) {
      return;
    }

    methodChannel
        .invokeMethod("writeToBluetooth", <String, dynamic>{"data": text});
  }

  // This is the UI for the app
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Material(
        animationDuration: new Duration(seconds: 1),
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
                    : connectingState == 4
                        ? Column(
                            children: [
                              _appPath("AlarmApp") != ""
                                  ? AlarmWidget(
                                      sendString: _sendString,
                                      appPath: _appPath,
                                      enabled: alarmAppEnabled,
                                      hours: alarmAppHours,
                                      minutes: alarmAppMinutes,
                                      time: alarmAppTime,
                                      onChanged:
                                          (enabled, hours, minutes, time) => {
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
                        : (StatusWidget(state: connectingState, watch: watch)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => {connectingState != 0 ? _disconnect() : _connect()},
        tooltip: connectingState != 0 ? 'Disconnect' : 'Connect',
        child: Icon(connectingState != 0 ? Icons.close : Icons.sync),
        focusElevation: 30,
      ),
    );
  }
}
