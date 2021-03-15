import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
  Color currentColor = Colors.blue;

  Color light(Color color, double amount) {
    HSLColor hsl = HSLColor.fromColor(color);
    HSLColor hslLight =
        hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));

    return hslLight.toColor();
  }

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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Theme:", style: TextStyle(fontSize: 14, color: Colors.black)),
            OutlinedButton(
                child: Text("Change"),
                onPressed: () async {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                          title: Text(
                            "SELECT COLOUR",
                            style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 10,
                                letterSpacing: 1.25),
                          ),
                          titlePadding: const EdgeInsets.all(20.0),
                          contentPadding:
                              const EdgeInsets.only(left: 20, right: 20),
                          actions: <Widget>[
                            FlatButton(
                              child: const Text('RESET'),
                              onPressed: () {
                                Navigator.of(context).pop();

                                widget.sendString(
                                    "wasp.system.set_theme(b'\\x7b\\xef\\x7b\\xef\\x7b\\xef\\xe7\\x3c\\x7b\\xef\\xff\\xff\\xbd\\xb6\\x39\\xff\\xff\\x00\\xdd\\xd0\\x00\\x0f')");

                                widget.sendString("wasp.system.app._draw()");
                              },
                            ),
                            FlatButton(
                              child: const Text('CANCEL'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            FlatButton(
                              child: const Text(
                                'OK',
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();

                                Color currentColorLight =
                                    light(currentColor, 0.3);

                                int r = currentColor.red & 0xFF;
                                int g = currentColor.green & 0xFF;
                                int b = currentColor.blue & 0xFF;

                                int rLight = currentColorLight.red & 0xFF;
                                int gLight = currentColorLight.green & 0xFF;
                                int bLight = currentColorLight.blue & 0xFF;

                                int rgb = ((r &
                                            int.parse("11111000", radix: 2)) <<
                                        8) |
                                    ((g & int.parse("11111100", radix: 2)) <<
                                        3) |
                                    (b >> 3);

                                int rgbLight = ((rLight &
                                            int.parse("11111000", radix: 2)) <<
                                        8) |
                                    ((gLight &
                                            int.parse("11111100", radix: 2)) <<
                                        3) |
                                    (bLight >> 3);

                                String hexString =
                                    rgb.toRadixString(16).padLeft(4, '0');

                                String hexStringLight =
                                    rgbLight.toRadixString(16).padLeft(4, '0');

                                String hexTop = hexString.substring(0, 2);
                                String hexBottom = hexString.substring(2, 4);

                                String hexTopLight =
                                    hexStringLight.substring(0, 2);
                                String hexBottomLight =
                                    hexStringLight.substring(2, 4);
                                widget.sendString(
                                    "wasp.system.set_theme(b'\\x$hexTop\\x$hexBottom\\x$hexTop\\x$hexBottom\\x$hexTop\\x$hexBottom\\x$hexTopLight\\x$hexBottomLight\\x$hexTop\\x$hexBottom\\x$hexTopLight\\x$hexBottomLight\\x$hexTopLight\\x$hexBottomLight\\x$hexTop\\x$hexBottom\\x$hexTop\\x$hexBottom\\x$hexTopLight\\x$hexBottomLight\\x$hexTop\\x$hexBottom')");

                                widget.sendString("wasp.system.app._draw()");
                              },
                            ),
                          ],
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: currentColor,
                              onColorChanged: (Color color) =>
                                  setState(() => currentColor = color),
                              colorPickerWidth: 300.0,
                              pickerAreaHeightPercent: 0.7,
                              enableAlpha: false,
                              displayThumbColor: false,
                              showLabel: false,
                              paletteType: PaletteType.hsv,
                              pickerAreaBorderRadius: const BorderRadius.only(
                                topLeft: const Radius.circular(5.0),
                                topRight: const Radius.circular(5.0),
                              ),
                            ),
                          ));
                    },
                  );
                })
          ]),
        ],
      ),
    );
  }
}
