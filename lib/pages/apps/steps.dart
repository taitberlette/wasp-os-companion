import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:waspos/scripts/device.dart';

// widget to view recent step data

class StepsWidget extends StatefulWidget {
  const StepsWidget({
    Key key,
  }) : super(key: key);

  @override
  _StepsWidgetState createState() => _StepsWidgetState();
}

class _StepsWidgetState extends State<StepsWidget> {

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
    Map<String, dynamic> steps = Device.device.state.apps["Steps"] ?? {};

    return Container(
      height: 256,
      width: double.infinity,
      child: PageView.builder(
          itemCount: steps.values.length,
          physics: BouncingScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            List<int> data = steps[index.toString()]["data"];
            DateTime date = steps[index.toString()]["time"];

            List<int> formatted = [];

            int totalCount = 0;

            for (int i = 0; i < data.length; i += 2) {
              int sectionCount = data[i] + (data[i + 1] << 8);
              totalCount += sectionCount;
              formatted.add(sectionCount);
            }

            return Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Date"),
                              Text(
                                  "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"),
                            ])),
                    Container(
                      width: double.infinity,
                      height: 128,
                      child: formatted.length == 0
                          ? Center(
                              child: Text("No data for this day"),
                            )
                          : charts.TimeSeriesChart([
                              charts.Series(
                                  id: 'Steps',
                                  data: formatted,
                                  domainFn: (data, dataIndex) {
                                    return date
                                        .add(Duration(minutes: dataIndex));
                                  },
                                  measureFn: (data, dataIndex) {
                                    return data;
                                  })
                            ], animate: true),
                    ),
                    Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Total Steps"),
                              Text(totalCount.toString()),
                            ])),
                  ],
                ));
          }),
    );
  }
}
