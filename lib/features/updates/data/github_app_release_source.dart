import 'dart:convert';
import 'dart:io';

import '../../../contracts/app_update_port.dart';

typedef UpdateTextLoader = Future<String> Function(Uri url);

class GithubAppReleaseSource implements AppReleaseSource {
  GithubAppReleaseSource({UpdateTextLoader? load})
    : _load = load ?? _downloadText;
  final UpdateTextLoader _load;
  static final releasesPage = Uri.parse(
    'https://github.com/yuminhang666-oss/PocketFlow/releases',
  );
  static final _feed = Uri.parse(
    'https://api.github.com/repos/yuminhang666-oss/PocketFlow/releases?per_page=20',
  );
  static const _repositoryPrefix =
      'https://github.com/yuminhang666-oss/PocketFlow/releases/';

  @override
  Future<AppUpdate?> latestFor(InstalledApp installed) async {
    try {
      final releases = jsonDecode(await _load(_feed)) as List<dynamic>;
      AppUpdate? newest;
      for (final item in releases) {
        final release = item as Map<String, dynamic>;
        if (release['draft'] == true) continue;
        final tag = release['tag_name'] as String;
        final version = RegExp(
          r'^(?:mvp-)?v(\d+\.\d+\.\d+)(?:-debug)?$',
        ).firstMatch(tag)?.group(1);
        if (version == null ||
            _compareVersions(version, installed.versionName) <= 0) {
          continue;
        }
        final assets = (release['assets'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final manifest = assets
            .where((a) => a['name'] == 'PocketFlow-update.json')
            .firstOrNull;
        if (manifest == null) throw const UpdateUnavailable();
        final data =
            jsonDecode(await _load(_assetUrl(manifest, tag)))
                as Map<String, dynamic>;
        if (data['schemaVersion'] != 1 ||
            data['applicationId'] != installed.applicationId ||
            data['versionName'] != version ||
            data['versionCode'] is! int ||
            data['versionCode'] <= 0 ||
            data['apkSizeBytes'] is! int ||
            data['apkSizeBytes'] <= 0 ||
            data['apkSizeBytes'] > 2147483648 ||
            data['apkSha256'] is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['apkSha256'])) {
          throw const UpdateUnavailable();
        }
        if (data['certificateSha256'] != installed.certificateSha256) continue;
        if (data['versionCode'] <= installed.versionCode) continue;
        final apkName = 'PocketFlow-$version-debug.apk';
        if (data['apkName'] != apkName) throw const UpdateUnavailable();
        final apk = assets.where((a) => a['name'] == apkName).firstOrNull;
        if (apk == null ||
            apk['size'] != data['apkSizeBytes'] ||
            apk['digest'] != 'sha256:${data['apkSha256']}') {
          throw const UpdateUnavailable();
        }
        final notes = (data['releaseNotes'] as List<dynamic>).cast<String>();
        if (notes.length > 30 || notes.any((n) => n.length > 500)) {
          throw const UpdateUnavailable();
        }
        final update = AppUpdate(
          versionName: version,
          versionCode: data['versionCode'],
          bytes: data['apkSizeBytes'],
          sha256: data['apkSha256'],
          downloadUrl: _assetUrl(apk, tag),
          releaseUrl: Uri.parse(
            '${_repositoryPrefix}tag/${Uri.encodeComponent(tag)}',
          ),
          notes: notes,
        );
        if (newest == null || update.versionCode > newest.versionCode) {
          newest = update;
        }
      }
      return newest;
    } catch (_) {
      throw const UpdateUnavailable();
    }
  }

  static Uri _assetUrl(Map<String, dynamic> asset, String tag) {
    final name = asset['name'] as String;
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name)) {
      throw const UpdateUnavailable();
    }
    final expected =
        '${_repositoryPrefix}download/${Uri.encodeComponent(tag)}/$name';
    if (asset['browser_download_url'] != expected) {
      throw const UpdateUnavailable();
    }
    return Uri.parse(expected);
  }

  static int _compareVersions(String a, String b) {
    final left = a.split('.').map(int.parse).toList();
    final right = b.split('.').map(int.parse).toList();
    if (left.length != 3 || right.length != 3) throw const UpdateUnavailable();
    for (var i = 0; i < 3; i++) {
      final result = left[i].compareTo(right[i]);
      if (result != 0) return result;
    }
    return 0;
  }

  static Future<String> _downloadText(Uri url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      return await (() async {
        final request = await client.getUrl(url);
        request.headers.set(HttpHeaders.userAgentHeader, 'PocketFlow-Updater');
        request.headers.set(
          HttpHeaders.acceptHeader,
          'application/vnd.github+json',
        );
        final response = await request.close();
        if (response.statusCode != 200) throw const UpdateUnavailable();
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > 1048576) {
            throw const UpdateUnavailable();
          }
          bytes.addAll(chunk);
        }
        return utf8.decode(bytes);
      })().timeout(const Duration(seconds: 12));
    } finally {
      client.close(force: true);
    }
  }
}
