import '../core/domain/app_update.dart';
export '../core/domain/app_update.dart';

abstract interface class AppUpdatePort {
  Future<InstalledApp> installedApp();
  Future<void> openDownload(Uri url);
}

abstract interface class AppReleaseSource {
  Future<AppUpdate?> latestFor(InstalledApp installed);
}
