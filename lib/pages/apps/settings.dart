import 'package:flutter/material.dart';
import 'package:waspos/pages/theme.dart';
import 'package:waspos/scripts/device.dart';

// widget to modify the settings

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({
    Key key,
  }) : super(key: key);

  @override
  _SettingsWidgetState createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  // array of units
  List<String> possibleUnits = ["Metric", "Imperial"];

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
    return Container(
      child: Column(
        children: [
          Container(
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                Text("Brightness"),
                Slider(
                    min: 0,
                    max: 2,
                    divisions: 2,
                    value: Device.device.state.brightnessLevel,
                    onChanged: (double value) {
                      if (mounted) {
                        setState(() {
                          Device.device.state.brightnessLevel = value;
                          Device.message(
                              "wasp.system.brightness = ${value.toInt() + 1}");
                          Device.message("wasp.system.app._draw()");
                        });
                      }
                    }),
              ])),
          Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Notification"),
                Slider(
                    min: 0,
                    max: 2,
                    divisions: 2,
                    value: Device.device.state.notificationLevel,
                    onChanged: (double value) {
                      if (mounted) {
                        setState(() {
                          Device.device.state.notificationLevel = value;
                          Device.message(
                              "wasp.system.notify_level = ${value.toInt() + 1}");
                          Device.message("wasp.system.app._draw()");
                        });
                      }
                    })
              ],
            ),
          ),
          Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Units"),
                OutlinedButton(
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          Device.device.state.units = possibleUnits[
                              (possibleUnits
                                          .indexOf(Device.device.state.units) +
                                      1) %
                                  possibleUnits.length];
                          Device.message(
                              "wasp.system.units = '${Device.device.state.units}'");
                          Device.message("wasp.system.app._draw()");
                        });
                      }
                    },
                    child: Container(
                      child: Text(Device.device.state.units),
                    ))
              ],
            ),
          ),
          Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Theme"),
                OutlinedButton(
                    onPressed: () {
                      if (mounted) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ThemeSelect()));
                      }
                    },
                    child: Container(
                      child: Text("Change"),
                    ))
              ],
            ),
          )
        ],
      ),
    );
  }
}
