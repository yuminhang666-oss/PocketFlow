import 'package:flutter/services.dart';

import '../../../contracts/app_update_port.dart';

class AndroidAppUpdatePort implements AppUpdatePort {
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
    );
  }

  @override
  Future<void> openDownload(Uri url) =>
      _channel.invokeMethod('openDownload', {'url': url.toString()});
}
