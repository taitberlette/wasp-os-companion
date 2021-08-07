import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waspos/pages/connect.dart';
import 'package:waspos/pages/widgets/layout.dart';
import 'package:waspos/scripts/device.dart';

// widget to change the watch theme

class ThemeSelect extends StatefulWidget {
  const ThemeSelect({
    Key key,
  }) : super(key: key);

  @override
  _ThemeSelectState createState() => _ThemeSelectState();
}

class _ThemeSelectState extends State<ThemeSelect> {
  StreamSubscription<Device> deviceSubscription;

  // default wasp-os theme
  List<int> wasp = [
    0x3A3DFF,
    0xFFE300,
    0xDEBA84,
    0x00007B,
  ];

  @override
  void initState() {
    super.initState();

    deviceSubscription = Device.deviceStream.listen(data);
  }

  @override
  void dispose() {
    super.dispose();

    deviceSubscription.cancel();
  }

  void data(Device data) {
    if (data.connectState == 0 && !Device.device.updating && mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => Connect()));
    }
  }

  // format and send the theme to the watch
  void setTheme(int ui, int spot1, int spot2, int contrast) {
    ui = convertRgb(ui);
    spot1 = convertRgb(spot1);
    spot2 = convertRgb(spot2);
    contrast = convertRgb(contrast);

    Device.message(
        "wasp.system.set_theme(b'\\x7b\\xef\\x7b\\xef\\x7b\\xef\\xe7\\x3c\\x7b\\xef\\xff\\xff\\xbd\\xb6\\x${((ui & 0xFF00) >> 8).toRadixString(16).padLeft(2, '0')}\\x${(ui & 0xFF).toRadixString(16).padLeft(2, '0')}\\x${((spot1 & 0xFF00) >> 8).toRadixString(16).padLeft(2, '0')}\\x${(spot1 & 0xFF).toRadixString(16).padLeft(2, '0')}\\x${((spot2 & 0xFF00) >> 8).toRadixString(16).padLeft(2, '0')}\\x${(spot2 & 0xFF).toRadixString(16).padLeft(2, '0')}\\x${((contrast & 0xFF00) >> 8).toRadixString(16).padLeft(2, '0')}\\x${(contrast & 0xFF).toRadixString(16).padLeft(2, '0')}')");

    Device.message("wasp.system.app._draw()");
  }

  // convert rgb888 to rgb565
  int convertRgb(int input) {
    return (((input & 0xf80000) >> 8) +
            ((input & 0xfc00) >> 5) +
            ((input & 0xf8) >> 3)) &
        0xFFFF;
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      children: [
        Text(
          "Select a theme.",
          style: TextStyle(fontSize: 20),
        ),
        Container(
          height: 48,
        ),
        InkWell(
          onTap: () {
            setTheme(wasp[0], wasp[1], wasp[2], wasp[3]);
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(16),
            height: 72,
            width: double.infinity,
            decoration: BoxDecoration(
                color: Color(0xFF000000 | wasp[0]),
                borderRadius: BorderRadius.circular(5)),
            child: Center(
              child: Text(
                "Default Theme",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          child: GridView(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
            children: [
              ...Colors.primaries
                  .map((e) => Center(
                      child: InkWell(
                          onTap: () {
                            setTheme(
                                e.shade500.value,
                                Colors
                                    .primaries[
                                        (Colors.primaries.indexOf(e) + 6) %
                                            Colors.primaries.length]
                                    .shade500
                                    .value,
                                Colors
                                    .primaries[
                                        (Colors.primaries.indexOf(e) + 6) %
                                            Colors.primaries.length]
                                    .shade700
                                    .value,
                                e.shade900.value);
                          },
                          child: Container(
                            margin: EdgeInsets.all(8),
                            padding: EdgeInsets.all(8),
                            child: Container(
                              decoration: BoxDecoration(
                                  color: e.shade500,
                                  borderRadius: BorderRadius.circular(5)),
                            ),
                          ))))
                  .toList(),
            ],
          ),
        )
      ],
      fab: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: Icon(Icons.arrow_back),
        tooltip: "Back",
        focusElevation: 30,
      ),
    );
  }
}
