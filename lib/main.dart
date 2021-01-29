import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_test/flutter_test.dart';

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

  // Bluetooth variables
  FlutterBlue flutterBlue = FlutterBlue.instance;
  final String uartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  final String uartRXUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  final String uartTXUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
  String watch;
  BluetoothService uartService;
  BluetoothCharacteristic uartRX;
  BluetoothCharacteristic uartTX;
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
      case "watchDisconnected":
        if ((connectingState == 2 ||
            connectingState == 3 ||
            connectingState == 4)) {
          setState(() {
            connectingState = 0;
            watch = null;
          });
        }
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
    if (watch == null || (connectingState != 3 && connectingState != 4)) {
      return;
    }

    methodChannel.invokeMethod("disconnectFromBluetooth");

    watch = null;

    setState(() {
      connectingState = 0;
    });
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

    flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (connectingState != 1) {
          continue;
        }
        if (r.device.name == "P8" ||
            r.device.name == "PineTime" ||
            r.device.name == "K9") {
          methodChannel.invokeMethod("connectToBluetooth",
              <String, dynamic>{"address": r.device.id.id});
          setState(() {
            connectingState = 2;
            watch = r.device.name;
          });
          flutterBlue.stopScan();
        }
      }
    });

    await flutterBlue.startScan(timeout: Duration(seconds: 4));

    flutterBlue.stopScan();

    if (connectingState == 1) {
      setState(() {
        connectingState = 0;
      });
    }
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
              : _appPath("ChronoApp", 0);

      clockFaceId = _appPath("ClockApp", 0) != ""
          ? 1
          : _appPath("FibonacciClockApp", 0) != ""
              ? 2
              : 3;
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    RichText(
                      text: TextSpan(
                          text: 'wasp-os ',
                          style: TextStyle(fontSize: 24, color: Colors.black),
                          children: <TextSpan>[
                            TextSpan(
                              text: 'companion',
                              style: TextStyle(
                                  fontSize: 24, color: Colors.black45),
                            ),
                          ]),
                    ),
                  ],
                ),
                SizedBox(height: 25),
                _locationPermissionStatus != PermissionStatus.granted
                    ? Column(
                        children: [
                          SizedBox(height: 25),
                          Text(
                            "Sorry, we need location permissions in order to connect to a wasp-os device.",
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                          SizedBox(height: 25),
                        ],
                      )
                    : connectingState == 4
                        ? Column(
                            children: [
                              _appPath("AlarmApp") != ""
                                  ? SizedBox(
                                      width: double.infinity,
                                      child: Column(
                                        children: [
                                          Divider(height: 16),
                                          SizedBox(height: 15),
                                          Text("Alarm",
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black)),
                                          SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text("Enabled:",
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.black)),
                                              Checkbox(
                                                  value: alarmAppEnabled,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      alarmAppEnabled = value;
                                                    });

                                                    _sendString(
                                                        "${_appPath("AlarmApp")}.active.state = ${value ? "True" : "False"}");

                                                    _sendString(
                                                        "${_appPath("AlarmApp")}._set_current_alarm()");

                                                    _sendString(
                                                        "wasp.system.app._draw()");
                                                  }),
                                            ],
                                          ),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text("Time:    ",
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black)),
                                                OutlinedButton(
                                                    child: Text(alarmAppTime),
                                                    onPressed: () async {
                                                      final TimeOfDay time =
                                                          await showTimePicker(
                                                        context: context,
                                                        initialTime:
                                                            TimeOfDay.now(),
                                                      );
                                                      if (time != null)
                                                        setState(() {
                                                          alarmAppHours =
                                                              time.hour;
                                                          alarmAppMinutes =
                                                              time.minute;
                                                          alarmAppTime = time
                                                              .format(context);
                                                        });

                                                      _sendString(
                                                          "${_appPath("AlarmApp")}.hours.value = $alarmAppHours");

                                                      _sendString(
                                                          "${_appPath("AlarmApp")}.minutes.value = $alarmAppMinutes");

                                                      _sendString(
                                                          "${_appPath("AlarmApp")}._set_current_alarm()");

                                                      _sendString(
                                                          "wasp.system.app._draw()");
                                                    })
                                              ]),
                                        ],
                                      ),
                                    )
                                  : (Container()),
                              clockPath != ""
                                  ? SizedBox(
                                      width: double.infinity,
                                      child: Column(
                                        children: [
                                          Divider(height: 16),
                                          SizedBox(height: 15),
                                          Text("Clock",
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black)),
                                          SizedBox(height: 20),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text("Clock Face:",
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black)),
                                                DropdownButton(
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.black),
                                                  value: clockFaceId,
                                                  items: [
                                                    DropdownMenuItem(
                                                      child:
                                                          Text("Digital Clock"),
                                                      value: 1,
                                                    ),
                                                    DropdownMenuItem(
                                                      child: Text(
                                                          "Fibonacci Clock"),
                                                      value: 2,
                                                    ),
                                                    DropdownMenuItem(
                                                      child: Text(
                                                          "Analogue Clock"),
                                                      value: 3,
                                                    )
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      clockFaceId = value;
                                                      if (value == 1) {
                                                        _sendString(
                                                            "from apps.clock import ClockApp");
                                                        _sendString(
                                                            "$clockPath = ClockApp()");
                                                      } else if (value == 2) {
                                                        _sendString(
                                                            "from apps.fibonacci_clock import FibonacciClockApp");
                                                        _sendString(
                                                            "$clockPath = FibonacciClockApp()");
                                                      } else if (value == 3) {
                                                        _sendString(
                                                            "from apps.chrono import ChronoApp");
                                                        _sendString(
                                                            "$clockPath = ChronoApp()");
                                                      }
                                                      _sendString(
                                                          "wasp.system.switch($clockPath)");
                                                    });
                                                  },
                                                  hint: Text(
                                                      "Select a clock face."),
                                                ),
                                              ]),
                                        ],
                                      ),
                                    )
                                  : (Container()),
                              _appPath("StepCounterApp") != ""
                                  ? SizedBox(
                                      width: double.infinity,
                                      child: Column(
                                        children: [
                                          Divider(height: 16),
                                          SizedBox(height: 15),
                                          Text("Steps",
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black)),
                                          SizedBox(height: 20),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text("Steps:",
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black)),
                                                Text("$steps",
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black))
                                              ]),
                                          SizedBox(height: 20),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text("Steps History:",
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black)),
                                              ]),
                                          SizedBox(height: 10),
                                          SizedBox(
                                            height: 125,
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              shrinkWrap: true,
                                              itemCount: stepsHistoryMap
                                                          .keys.length !=
                                                      null
                                                  ? stepsHistoryMap.keys.length
                                                  : 0,
                                              itemBuilder: (context, index) {
                                                return ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(
                                                    '${stepsHistoryMap.keys.elementAt(index) != null ? stepsHistoryMap.keys.elementAt(index).toString() : ""} ',
                                                    style: new TextStyle(
                                                        fontSize: 14),
                                                  ),
                                                  trailing: Text(
                                                    '${stepsHistoryMap.values.elementAt(index) != null ? stepsHistoryMap.values.elementAt(index).toString() : ""} ',
                                                    style: new TextStyle(
                                                        fontSize: 14),
                                                  ),
                                                  dense: true,
                                                );
                                              },
                                            ),
                                          ),
                                          SizedBox(height: 20),
                                        ],
                                      ),
                                    )
                                  : (Container()),
                              SizedBox(
                                width: double.infinity,
                                child: Column(
                                  children: [
                                    Divider(height: 16),
                                    SizedBox(height: 15),
                                    Text("Settings",
                                        style: TextStyle(
                                            fontSize: 16, color: Colors.black)),
                                    SizedBox(height: 20),
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Brightness:",
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black)),
                                          Slider(
                                            value: brightnessSlider,
                                            min: 1,
                                            max: 3,
                                            divisions: 2,
                                            label: brightnessSlider
                                                .round()
                                                .toString(),
                                            onChanged: (value) {
                                              if (value == brightnessSlider) {
                                                return;
                                              }

                                              setState(() {
                                                brightnessSlider = value;
                                              });
                                              _sendString(
                                                  "wasp.system.brightness = ${value.round()}");

                                              _sendString(
                                                  "wasp.system.app._draw()");
                                            },
                                          ),
                                        ]),
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Notification Level:",
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black)),
                                          Slider(
                                            value: notifySlider,
                                            min: 1,
                                            max: 3,
                                            divisions: 2,
                                            label:
                                                notifySlider.round().toString(),
                                            onChanged: (value) {
                                              if (value == notifySlider) {
                                                return;
                                              }

                                              setState(() {
                                                notifySlider = value;
                                              });
                                              _sendString(
                                                  "wasp.system.notify_level = ${value.round()}");

                                              _sendString(
                                                  "wasp.system.app._draw()");
                                            },
                                          )
                                        ]),
                                  ],
                                ),
                              ),
                              Column(children: [
                                Divider(height: 16),
                                SizedBox(height: 15),
                                Column(
                                  children: [
                                    showConsole == true
                                        ? (Column(children: [
                                            Text("UART Console",
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.black)),
                                            SizedBox(height: 20),
                                            SizedBox(
                                                height: 250,
                                                child: SingleChildScrollView(
                                                    controller:
                                                        uartScrollController,
                                                    scrollDirection:
                                                        Axis.vertical,
                                                    child:
                                                        new Text(uartContent))),
                                            TextField(
                                              decoration: InputDecoration(
                                                hintText: 'wasp.system.run()',
                                              ),
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black),
                                              autocorrect: false,
                                              onSubmitted: (String content) {
                                                _sendString(content + "");
                                              },
                                            ),
                                            SizedBox(height: 15),
                                          ]))
                                        : Container(),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          showConsole = !showConsole;
                                        });
                                      },
                                      child: Text(
                                          "${showConsole == true ? "Hide" : "Show"} UART Console"),
                                    ),
                                    SizedBox(height: 15),
                                  ],
                                ),
                              ])
                            ],
                          )
                        : (Column(
                            children: [
                              SizedBox(height: 25),
                              Text(
                                connectingState == 0
                                    ? "Connect a wasp-os device to view data."
                                    : connectingState == 1
                                        ? "Searching for wasp-os devices..."
                                        : connectingState == 2
                                            ? "Connecting to ${watch == null ? "unknown wasp-os device" : watch}..."
                                            : "Syncing ${watch == null ? "unknown wasp-os device" : watch}...",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black),
                              ),
                              SizedBox(height: 25),
                            ],
                          )),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => {
          connectingState == 3 || connectingState == 4
              ? _disconnect()
              : _connect()
        },
        tooltip: connectingState == 3 || connectingState == 4
            ? 'Disconnect'
            : 'Connect',
        child: Icon(connectingState == 3 || connectingState == 4
            ? Icons.close
            : connectingState == 2 || connectingState == 1
                ? Icons.more_horiz
                : Icons.sync),
        focusElevation: 30,
      ),
    );
  }
}
