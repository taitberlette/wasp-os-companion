import 'package:flutter/material.dart';

import 'header.dart';

// create a basic layout

class AppLayout extends StatefulWidget {
  const AppLayout({Key key, this.children, this.fab, this.refresh})
      : super(key: key);

  final List<Widget> children;
  final FloatingActionButton fab;
  final Function refresh;

  @override
  _AppLayoutState createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        scrollDirection: Axis.vertical,
        child: Container(
          padding: EdgeInsets.only(left: 24, right: 24, top: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        padding: EdgeInsets.only(top: 24, bottom: 48),
                        child: Header())
                  ]),
              ...this.widget.children,
              Container(
                height: 96,
              )
            ],
          ),
        ));

    return Scaffold(
      key: _scaffoldKey,
      body: Material(
          animationDuration: new Duration(seconds: 1),
          child: this.widget.refresh != null
              ? RefreshIndicator(
                  child: child,
                  onRefresh: this.widget.refresh,
                  displacement: 64,
                )
              : child),
      floatingActionButton: this.widget.fab,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
