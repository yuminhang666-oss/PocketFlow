import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../contracts/app_update_port.dart';

enum AppUpdatePhase {
  idle,
  checking,
  current,
  available,
  unavailable,
  downloading,
  ready,
}

class AppUpdateController extends ChangeNotifier {
  AppUpdateController({required this.platform, required this.source});
  final AppUpdatePort platform;
  final AppReleaseSource source;
  InstalledApp? installed;
  AppUpdate? update;
  AppUpdatePhase phase = AppUpdatePhase.idle;
  bool _disposed = false;
  bool _initialized = false;
  UpdateFailure? failure;
  int downloaded = 0;
  String? installNotice;
  bool installing = false;
  Timer? _progress;
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
      _initialized = false;
      failure = UpdateFailure.installedInfo;
      phase = AppUpdatePhase.unavailable;
      _changed();
    }
  }

  Future<void> check() async {
    if (phase == AppUpdatePhase.checking ||
        phase == AppUpdatePhase.downloading ||
        installing ||
        _disposed) {
      return;
    }
    if (installed == null) await initialize();
    if (_disposed || installed == null) return;
    phase = AppUpdatePhase.checking;
    update = null;
    failure = null;
    installNotice = null;
    _changed();
    try {
      final found = await source
          .latestFor(installed!)
          .timeout(const Duration(seconds: 45));
      if (_disposed) return;
      update = found;
      phase = found == null ? AppUpdatePhase.current : AppUpdatePhase.available;
    } catch (e) {
      if (!_disposed) {
        update = null;
        phase = AppUpdatePhase.unavailable;
        failure = e is UpdateUnavailable
            ? e.reason
            : e is TimeoutException
            ? UpdateFailure.timeout
            : UpdateFailure.network;
      }
    }
    _changed();
  }

  Future<void> download() async {
    if (phase == AppUpdatePhase.available && update != null) {
      final native = platform is AppPackageUpdatePort
          ? platform as AppPackageUpdatePort
          : null;
      if (native == null) {
        await platform.openDownload(update!.downloadUrl);
        return;
      }
      phase = AppUpdatePhase.downloading;
      failure = null;
      downloaded = 0;
      installNotice = null;
      _changed();
      var polling = false;
      _progress = Timer.periodic(const Duration(milliseconds: 400), (_) async {
        if (polling || _disposed) return;
        polling = true;
        try {
          final bytes = await native.downloadedBytes();
          if (!_disposed && phase == AppUpdatePhase.downloading) {
            downloaded = bytes;
            _changed();
          }
        } catch (_) {
          /* A transient progress read does not fail the transfer. */
        } finally {
          polling = false;
        }
      });
      try {
        await native.downloadUpdate(update!);
        if (_disposed) return;
        downloaded = update!.bytes;
        phase = AppUpdatePhase.ready;
        await install();
      } catch (e) {
        if (_disposed) return;
        failure = e is UpdateUnavailable ? e.reason : UpdateFailure.download;
        if (failure == UpdateFailure.cancelled) failure = null;
        phase = AppUpdatePhase.available;
      } finally {
        _progress?.cancel();
        _changed();
      }
    }
  }

  Future<void> cancel() async {
    final native = platform is AppPackageUpdatePort
        ? platform as AppPackageUpdatePort
        : null;
    if (phase == AppUpdatePhase.downloading && native != null) {
      await native.cancelDownload();
    }
  }

  Future<void> install() async {
    final native = platform is AppPackageUpdatePort
        ? platform as AppPackageUpdatePort
        : null;
    if (phase != AppUpdatePhase.ready || installing || native == null) {
      return;
    }
    installing = true;
    failure = null;
    _changed();
    try {
      final opened = await native.installUpdate();
      if (_disposed) return;
      installNotice = opened
          ? '已打开系统安装界面，请确认更新；取消后可再次点击安装。'
          : '请允许 PocketFlow 安装应用，返回后点击“安装更新”。';
    } catch (e) {
      if (!_disposed) {
        failure = e is UpdateUnavailable ? e.reason : UpdateFailure.installer;
        if (failure == UpdateFailure.integrity) {
          phase = AppUpdatePhase.available;
        }
      }
    } finally {
      installing = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _progress?.cancel();
    if (phase == AppUpdatePhase.downloading &&
        platform is AppPackageUpdatePort) {
      unawaited(
        (platform as AppPackageUpdatePort).cancelDownload().catchError(
          (Object _) {},
        ),
      );
    }
    super.dispose();
  }
}
