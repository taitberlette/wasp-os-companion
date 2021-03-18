import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class DeviceWidget extends StatefulWidget {
  const DeviceWidget({
    Key key,
    @required this.sendString,
    @required this.appPath,
    @required this.name,
    @required this.address,
    @required this.batteryLevel,
    @required this.lastSync,
    this.onChanged,
  }) : super(key: key);

  final Function sendString;
  final Function appPath;
  final String name;
  final String address;
  final int batteryLevel;
  final DateTime lastSync;

  final Function onChanged;

  @override
  _DeviceWidgetState createState() => _DeviceWidgetState();
}

class _DeviceWidgetState extends State<DeviceWidget> {
  @override
  void initState() {
    super.initState();
  }

  void dfuFilePicker() async {
    FilePickerResult result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.extension == "zip") {
      widget.onChanged(0, result.files.single.path);
    }
  }

  void updateMenu() {
    SimpleDialog dialog = SimpleDialog(
      title: Text("Update " + widget.name),
      children: <Widget>[
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context);
            dfuFilePicker();
          },
          child: const Text('Update From Local File (.zip)'),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context);
            widget.onChanged(1, "");
          },
          child: const Text('Update From Latest GitHub Action'),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context);
            widget.onChanged(2, "");
          },
          child: const Text('Update From Latest GitHub Release'),
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }

  void menu() {
    SimpleDialog dialog = SimpleDialog(
      title: Text(widget.name),
      children: <Widget>[
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context);
            updateMenu();
          },
          child: const Text('Update'),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context);
            widget.sendString("import machine");
            widget.sendString("machine.reset()");
          },
          child: const Text('Reset'),
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          SizedBox(height: 10),
          Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white60,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 20,
                    offset: Offset(2, 2),
                  )
                ],
                borderRadius: BorderRadius.all(
                  Radius.circular(5),
                ),
              ),
              child: new InkWell(
                  onTap: () {
                    menu();
                  },
                  child: Column(
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/images/watches/${widget.name}.png',
                              height: 75,
                              width: 75,
                            ),
                            Padding(padding: EdgeInsets.only(left: 20)),
                            RichText(
                              text: TextSpan(
                                  text: widget.name,
                                  style: TextStyle(
                                      fontSize: 24, color: Colors.black),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text:
                                          '\nBattery: ${widget.batteryLevel.toString()}%\nLast Synced: ${widget.lastSync.hour}:${widget.lastSync.minute}',
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.black45),
                                    ),
                                  ]),
                            ),
                          ]),
                    ],
                  ))),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
