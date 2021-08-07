import 'package:flutter/material.dart';
import 'package:waspos/scripts/main.dart';

import 'connect.dart';

// material app root

class App extends StatefulWidget {
  const App({
    Key key,
  }) : super(key: key);

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {

  // runs when the app is opened
  @override
  void initState() {
    super.initState();
    start();
  }

  // runs when the app is closed
  @override
  void dispose() {
    super.dispose();
    stop();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Connect(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
