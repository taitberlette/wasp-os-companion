import 'package:flutter/material.dart';

class UartWidget extends StatefulWidget {
  const UartWidget({
    Key key,
    @required this.sendString,
    @required this.appPath,
    @required this.show,
    @required this.content,
    @required this.scrollController,
    this.onChanged,
  }) : super(key: key);

  final Function sendString;
  final Function appPath;
  final bool show;
  final String content;
  final ScrollController scrollController;

  final Function onChanged;

  @override
  _UartWidgetState createState() => _UartWidgetState();
}

class _UartWidgetState extends State<UartWidget> {
  bool showConsole;
  String uartContent;
  ScrollController uartScrollController;

  @override
  void initState() {
    super.initState();
    showConsole = widget.show;
    uartContent = widget.content;
    uartScrollController = widget.scrollController;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Divider(height: 16),
      SizedBox(height: 15),
      Column(
        children: [
          showConsole == true
              ? (Column(children: [
                  Text("UART Console",
                      style: TextStyle(fontSize: 16, color: Colors.black)),
                  SizedBox(height: 20),
                  SizedBox(
                      height: 250,
                      child: SingleChildScrollView(
                          controller: uartScrollController,
                          scrollDirection: Axis.vertical,
                          child: new Text(widget.content))),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'wasp.system.run()',
                    ),
                    style: TextStyle(fontSize: 16, color: Colors.black),
                    autocorrect: false,
                    onSubmitted: (String content) {
                      widget.sendString(content + "");
                    },
                  ),
                  SizedBox(height: 15),
                ]))
              : Container(),
          OutlinedButton(
            onPressed: () {
              setState(() {
                showConsole = !showConsole;
                widget.onChanged(showConsole);
              });
            },
            child:
                Text("${showConsole == true ? "Hide" : "Show"} UART Console"),
          ),
          SizedBox(height: 15),
        ],
      ),
    ]);
  }
}
