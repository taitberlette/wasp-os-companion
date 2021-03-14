import 'package:flutter/material.dart';

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({
    Key key,
    @required this.sendString,
    @required this.appPath,
    @required this.brightness,
    @required this.notify,
    this.onChanged,
  }) : super(key: key);

  final Function sendString;
  final Function appPath;
  final double brightness;
  final double notify;

  final Function onChanged;

  @override
  _SettingsWidgetState createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  double brightnessSlider;
  double notifySlider;

  @override
  void initState() {
    super.initState();
    brightnessSlider = widget.brightness;
    notifySlider = widget.notify;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Divider(height: 16),
          SizedBox(height: 15),
          Text("Settings", style: TextStyle(fontSize: 16, color: Colors.black)),
          SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Brightness:",
                style: TextStyle(fontSize: 14, color: Colors.black)),
            Slider(
              value: brightnessSlider,
              min: 1,
              max: 3,
              divisions: 2,
              label: brightnessSlider.round().toString(),
              onChanged: (value) {
                if (value == brightnessSlider) {
                  return;
                }
                setState(() {
                  brightnessSlider = value;
                  widget.onChanged(brightnessSlider, notifySlider);
                });
                widget.sendString("wasp.system.brightness = ${value.round()}");
                widget.sendString("wasp.system.app._draw()");
              },
            ),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Notification Level:",
                style: TextStyle(fontSize: 14, color: Colors.black)),
            Slider(
              value: notifySlider,
              min: 1,
              max: 3,
              divisions: 2,
              label: notifySlider.round().toString(),
              onChanged: (value) {
                if (value == notifySlider) {
                  return;
                }
                setState(() {
                  notifySlider = value;
                  widget.onChanged(brightnessSlider, notifySlider);
                });
                widget
                    .sendString("wasp.system.notify_level = ${value.round()}");
                widget.sendString("wasp.system.app._draw()");
              },
            )
          ]),
        ],
      ),
    );
  }
}
