import 'dart:async';
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
      return await _fromFeed(installed);
    } on UpdateUnavailable catch (failure) {
      // An invalid manifest must not bypass the release metadata checks.
      if (failure.reason != UpdateFailure.network &&
          failure.reason != UpdateFailure.timeout &&
          failure.reason != UpdateFailure.rateLimited) {
        rethrow;
      }
      return _fromLatest(installed, failure);
    }
  }

  Future<AppUpdate?> _fromFeed(InstalledApp installed) async {
    try {
      final feed = jsonDecode(await _load(_feed));
      if (feed is! List) throw const UpdateUnavailable();
      AppUpdate? newest;
      var invalid = false;
      for (final item in feed) {
        try {
          final release = item as Map<String, dynamic>;
          if (release['draft'] == true) continue;
          final tag = release['tag_name'] as String;
          final version = RegExp(
            r'^(?:mvp-)?v(\d+\.\d+\.\d+)(?:-(?:debug|release))?$',
          ).firstMatch(tag)?.group(1);
          if (version == null ||
              _compareVersions(version, installed.versionName) <= 0) {
            continue;
          }
          final assets = (release['assets'] as List)
              .cast<Map<String, dynamic>>();
          AppUpdate? candidate;
          var manifestSeen = false, usable = false;
          for (final manifestName in [
            'PocketFlow-update-v2.json',
            'PocketFlow-update.json',
          ]) {
            final asset = assets
                .where((a) => a['name'] == manifestName)
                .firstOrNull;
            if (asset == null) continue;
            manifestSeen = true;
            try {
              final data =
                  jsonDecode(await _load(_assetUrl(asset, tag)))
                      as Map<String, dynamic>;
              final v2 = manifestName == 'PocketFlow-update-v2.json';
              if (data['schemaVersion'] != (v2 ? 2 : 1) ||
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
              final kind = v2 ? data['buildKind'] : 'debug';
              if (kind != 'debug' && kind != 'release') {
                throw const UpdateUnavailable();
              }
              final name = 'PocketFlow-$version-$kind.apk';
              if (data[v2 ? 'assetName' : 'apkName'] != name) {
                throw const UpdateUnavailable();
              }
              final apk = assets.where((a) => a['name'] == name).firstOrNull;
              if (apk == null ||
                  apk['size'] != data['apkSizeBytes'] ||
                  apk['digest'] != 'sha256:${data['apkSha256']}') {
                throw const UpdateUnavailable();
              }
              final notes = (data['releaseNotes'] as List).cast<String>();
              if (notes.length > 30 || notes.any((n) => n.length > 500)) {
                throw const UpdateUnavailable();
              }
              usable = true;
              if (data['certificateSha256'] != installed.certificateSha256 ||
                  data['versionCode'] <= installed.versionCode) {
                continue;
              }
              candidate = AppUpdate(
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
              break;
            } on UpdateUnavailable catch (e) {
              if (e.reason != UpdateFailure.invalidMetadata) rethrow;
              /* v2 may fall back to the independently valid v1. */
            } catch (_) {
              /* Malformed v2 may fall back to the independently valid v1. */
            }
          }
          if (!manifestSeen || !usable) invalid = true;
          if (candidate != null &&
              (newest == null || candidate.versionCode > newest.versionCode)) {
            newest = candidate;
          }
        } on UpdateUnavailable catch (e) {
          if (e.reason != UpdateFailure.invalidMetadata) rethrow;
          invalid = true;
        } catch (_) {
          invalid = true;
        }
      }
      if (newest == null && invalid) throw const UpdateUnavailable();
      return newest;
    } on UpdateUnavailable {
      rethrow;
    } on TimeoutException {
      throw const UpdateUnavailable(UpdateFailure.timeout);
    } on SocketException {
      throw const UpdateUnavailable(UpdateFailure.network);
    } on HandshakeException {
      throw const UpdateUnavailable(UpdateFailure.network);
    } catch (_) {
      throw const UpdateUnavailable();
    }
  }

  Future<AppUpdate?> _fromLatest(
    InstalledApp installed,
    UpdateUnavailable original,
  ) async {
    for (final schema in [2, 1]) {
      try {
        final name = schema == 2
            ? 'PocketFlow-update-v2.json'
            : 'PocketFlow-update.json';
        final data =
            jsonDecode(
                  await _load(
                    Uri.parse('${_repositoryPrefix}latest/download/$name'),
                  ),
                )
                as Map<String, dynamic>;
        final version = data['versionName'];
        final kind = schema == 2 ? data['buildKind'] : 'debug';
        if (data['schemaVersion'] != schema ||
            data['applicationId'] != installed.applicationId ||
            version is! String ||
            !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
            (kind != 'release' && kind != 'debug') ||
            data[schema == 2 ? 'assetName' : 'apkName'] !=
                'PocketFlow-$version-$kind.apk' ||
            data['versionCode'] is! int ||
            data['versionCode'] <= 0 ||
            data['apkSizeBytes'] is! int ||
            data['apkSizeBytes'] <= 0 ||
            data['apkSizeBytes'] > 2147483648 ||
            data['apkSha256'] is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['apkSha256']) ||
            data['releaseNotes'] is! List ||
            (data['releaseNotes'] as List).length > 30 ||
            (data['releaseNotes'] as List).any(
              (n) => n is! String || n.length > 500,
            )) {
          throw const UpdateUnavailable();
        }
        if (data['certificateSha256'] != installed.certificateSha256) {
          throw const UpdateUnavailable(UpdateFailure.incompatibleSignature);
        }
        if (_compareVersions(version, installed.versionName) <= 0 ||
            data['versionCode'] <= installed.versionCode) {
          return null;
        }
        // latest/download resolves the actual tag, including historical tag forms.
        // Native download verifies bytes, SHA-256, package, version and signer.
        return AppUpdate(
          versionName: version,
          versionCode: data['versionCode'],
          bytes: data['apkSizeBytes'],
          sha256: data['apkSha256'],
          downloadUrl: Uri.parse(
            '${_repositoryPrefix}latest/download/PocketFlow-$version-$kind.apk',
          ),
          releaseUrl: releasesPage,
          notes: (data['releaseNotes'] as List).cast<String>(),
        );
      } on UpdateUnavailable catch (e) {
        if (e.reason == UpdateFailure.incompatibleSignature) rethrow;
        if (schema == 1 && e.reason == UpdateFailure.invalidMetadata) rethrow;
      } catch (_) {
        // Try the legacy manifest on the same official release only.
      }
    }
    throw original;
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
        if (response.statusCode == 403 || response.statusCode == 429) {
          throw const UpdateUnavailable(UpdateFailure.rateLimited);
        }
        if (response.statusCode != 200) {
          throw const UpdateUnavailable(UpdateFailure.network);
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > 1048576) {
            throw const UpdateUnavailable();
          }
          bytes.addAll(chunk);
        }
        return utf8.decode(bytes);
      })().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const UpdateUnavailable(UpdateFailure.timeout);
    } on SocketException {
      throw const UpdateUnavailable(UpdateFailure.network);
    } on HandshakeException {
      throw const UpdateUnavailable(UpdateFailure.network);
    } finally {
      client.close(force: true);
    }
  }
}
