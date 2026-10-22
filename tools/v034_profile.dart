// Measurement-only entrypoint. Never used by the preview Release APK.
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:pocketflow/main.dart' as app;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final frames = <Map<String, int>>[];
  SchedulerBinding.instance.addTimingsCallback((batch) {
    for (final frame in batch) {
      frames.add({
        'buildUs': frame.buildDuration.inMicroseconds,
        'rasterUs': frame.rasterDuration.inMicroseconds,
        'totalUs': frame.totalSpan.inMicroseconds,
      });
    }
  });
  developer.registerExtension('ext.pocketflow.qa.frames', (method, args) async {
    final result = jsonEncode({'frames': List.of(frames)});
    if (args['reset'] == 'true') frames.clear();
    return developer.ServiceExtensionResponse.result(result);
  });
  app.main();
}
