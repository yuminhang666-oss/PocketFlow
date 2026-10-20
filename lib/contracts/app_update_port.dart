import '../core/domain/app_update.dart';
export '../core/domain/app_update.dart';

abstract interface class AppUpdatePort {
  Future<InstalledApp> installedApp();
  Future<void> openDownload(Uri url);
}

abstract interface class AppReleaseSource {
  Future<AppUpdate?> latestFor(InstalledApp installed);
}

/// Optional native capability; no finance or storage permissions are exposed.
abstract interface class AppPackageUpdatePort {
  Future<void> downloadUpdate(AppUpdate update);
  Future<int> downloadedBytes();
  Future<void> cancelDownload();

  /// False means Android's per-app install permission settings were opened.
  /// True means the installer opened, not that installation succeeded.
  Future<bool> installUpdate();
}
