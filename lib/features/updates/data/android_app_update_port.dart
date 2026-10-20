import 'package:flutter/services.dart';

import '../../../contracts/app_update_port.dart';

class AndroidAppUpdatePort implements AppUpdatePort, AppPackageUpdatePort {
  const AndroidAppUpdatePort();
  static const _channel = MethodChannel('pocketflow/app_updates/v1');
  @override
  Future<InstalledApp> installedApp() async {
    final data = (await _channel.invokeMapMethod<String, dynamic>(
      'installedApp',
    ))!;
    return InstalledApp(
      versionName: data['versionName'] as String,
      versionCode: data['versionCode'] as int,
      certificateSha256: data['certificateSha256'] as String,
      applicationId: data['applicationId'] as String,
      androidApi: data['androidApi'] as int?,
    );
  }

  @override
  Future<void> openDownload(Uri url) =>
      _channel.invokeMethod('openDownload', {'url': url.toString()});

  @override
  Future<void> downloadUpdate(AppUpdate update) async {
    try {
      await _channel.invokeMethod('downloadUpdate', {
        'url': update.downloadUrl.toString(),
        'bytes': update.bytes,
        'sha256': update.sha256,
        'versionCode': update.versionCode,
        'versionName': update.versionName,
      });
    } on PlatformException catch (e) {
      throw UpdateUnavailable(switch (e.code) {
        'CANCELLED' => UpdateFailure.cancelled,
        'INTEGRITY' => UpdateFailure.integrity,
        'TIMEOUT' => UpdateFailure.timeout,
        _ => UpdateFailure.download,
      });
    }
  }

  @override
  Future<int> downloadedBytes() async =>
      await _channel.invokeMethod<int>('downloadedBytes') ?? 0;

  @override
  Future<void> cancelDownload() => _channel.invokeMethod('cancelDownload');

  @override
  Future<bool> installUpdate() async {
    try {
      return await _channel.invokeMethod<bool>('installUpdate') ?? false;
    } on PlatformException catch (e) {
      throw UpdateUnavailable(
        e.code == 'INTEGRITY'
            ? UpdateFailure.integrity
            : UpdateFailure.installer,
      );
    }
  }
}
