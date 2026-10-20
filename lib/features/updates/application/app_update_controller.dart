import 'package:flutter/foundation.dart';

import '../../../contracts/app_update_port.dart';

enum AppUpdatePhase { idle, checking, current, available, unavailable }

class AppUpdateController extends ChangeNotifier {
  AppUpdateController({required this.platform, required this.source});
  final AppUpdatePort platform;
  final AppReleaseSource source;
  InstalledApp? installed;
  AppUpdate? update;
  AppUpdatePhase phase = AppUpdatePhase.idle;
  bool _disposed = false;
  bool _initialized = false;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      installed = await platform.installedApp();
      _changed();
    } catch (_) {
      phase = AppUpdatePhase.unavailable;
      _changed();
    }
  }

  Future<void> check() async {
    if (phase == AppUpdatePhase.checking || _disposed || installed == null) {
      return;
    }
    phase = AppUpdatePhase.checking;
    update = null;
    _changed();
    try {
      final found = await source
          .latestFor(installed!)
          .timeout(const Duration(seconds: 20));
      if (_disposed) return;
      update = found;
      phase = found == null ? AppUpdatePhase.current : AppUpdatePhase.available;
    } catch (_) {
      if (!_disposed) {
        update = null;
        phase = AppUpdatePhase.unavailable;
      }
    }
    _changed();
  }

  Future<void> download() async {
    if (phase == AppUpdatePhase.available && update != null) {
      await platform.openDownload(update!.downloadUrl);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
