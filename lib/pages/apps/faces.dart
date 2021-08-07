import 'package:flutter/material.dart';
import 'package:waspos/scripts/device.dart';

// widget to change the watch face with previews

class FacesWidget extends StatefulWidget {
  const FacesWidget({
    Key key,
  }) : super(key: key);

  @override
  _FacesWidgetState createState() => _FacesWidgetState();
}

class _FacesWidgetState extends State<FacesWidget> {
  PageController facesController;

  // all the faces on the watch
  Map<String, Map<String, String>> faces = {
    "Default Clock": {"file": "clock", "class": "Clock"},
    "Analogue Clock": {"file": "chrono", "class": "Chrono"},
    "Dual Clock": {"file": "dual_clock", "class": "DualClock"},
    "Fibonacci Clock": {"file": "fibonacci_clock", "class": "FibonacciClock"},
    "Word Clock": {"file": "word_clock", "class": "WordClock"},
  };

  @override
  void initState() {
    super.initState();

    int currentFace = 0;

    String clockAppName = Device.device.state.quickRing[0] ?? "ClockApp";

    switch (clockAppName) {
      case "ChronoApp":
        currentFace = 1;
        break;
      case "DualClockApp":
        currentFace = 2;
        break;
      case "FibonacciClockApp":
        currentFace = 3;
        break;
      case "WordClockApp":
        currentFace = 4;
        break;
    }

    facesController =
        PageController(viewportFraction: 0.5, initialPage: currentFace);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 128,
        width: double.infinity,
        child: PageView.builder(
            itemCount: faces.length,
            controller: facesController,
            physics: BouncingScrollPhysics(),
            onPageChanged: (int index) {
              Map<String, String> item = faces.values.toList()[index];
              Device.message(
                  "wasp.system.register('apps.${item["file"]}.${item["class"]}App', True, True, True)");
              Device.message("wasp.system.switch(wasp.system.quick_ring[0])");
            },
            itemBuilder: (BuildContext context, int index) {
              return Container(
                width: double.infinity,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/apps/${faces.values.toList()[index % faces.length]["class"]}.png',
                      height: 75,
                      width: 75,
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      child: Text(faces.keys.toList()[index % faces.length]),
                    )
                  ],
                ),
              );
            }));
  }
}
