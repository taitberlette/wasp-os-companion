import 'package:flutter/material.dart';

class StepsWidget extends StatefulWidget {
  const StepsWidget({
    Key key,
    @required this.sendString,
    @required this.appPath,
    @required this.steps,
    @required this.history,
    this.onChanged,
  }) : super(key: key);

  final Function sendString;
  final Function appPath;
  final int steps;
  final Map<String, dynamic> history;

  final Function onChanged;

  @override
  _StepsWidgetState createState() => _StepsWidgetState();
}

class _StepsWidgetState extends State<StepsWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Divider(height: 16),
          SizedBox(height: 15),
          Text("Steps", style: TextStyle(fontSize: 16, color: Colors.black)),
          SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Steps:", style: TextStyle(fontSize: 14, color: Colors.black)),
            Text("${widget.steps}",
                style: TextStyle(fontSize: 14, color: Colors.black))
          ]),
          SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Steps History:",
                style: TextStyle(fontSize: 14, color: Colors.black)),
          ]),
          SizedBox(height: 10),
          SizedBox(
            height: 125,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: widget.history.keys.length != null
                  ? widget.history.keys.length
                  : 0,
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${widget.history.keys.elementAt(index) != null ? widget.history.keys.elementAt(index).toString() : ""} ',
                    style: new TextStyle(fontSize: 14),
                  ),
                  trailing: Text(
                    '${widget.history.values.elementAt(index) != null ? widget.history.values.elementAt(index).toString() : ""} ',
                    style: new TextStyle(fontSize: 14),
                  ),
                  dense: true,
                );
              },
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
