import 'package:path_provider/path_provider.dart';

import 'dart:io';

// parse a wasp-os application ring
List<String> parseRing(String text) {
  text = text.replaceAll(RegExp(r'(<|>|object at |\[|\])'), "");

  List<String> ringApps = text.split(", ");
  for (int i = 0; i < ringApps.length; i++) {
    ringApps[i] = ringApps[i].split(" ")[0].trim();
  }
  return ringApps;
}

// get a file in the temporary directory
Future<File> getFile(String file) async {
  final directory = await getTemporaryDirectory();
  File data = new File("${directory.path}/$file");
  if (!data.existsSync()) {
    data.createSync();
  }
  return data;
}
