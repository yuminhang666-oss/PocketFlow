import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/app_update_port.dart';
import 'package:pocketflow/features/updates/application/app_update_controller.dart';
import 'package:pocketflow/features/updates/data/github_app_release_source.dart';
import 'package:pocketflow/features/updates/presentation/app_updates_page.dart';

const installed = InstalledApp(
  versionName: '0.2.1',
  versionCode: 4,
  applicationId: 'cn.pocketflow',
  certificateSha256: 'certificate',
);
const digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const tag = 'mvp-v0.3.0-debug';
const prefix =
    'https://github.com/yuminhang666-oss/PocketFlow/releases/download/$tag/';

Map<String, dynamic> manifest() => {
  'schemaVersion': 1,
  'applicationId': 'cn.pocketflow',
  'versionName': '0.3.0',
  'versionCode': 5,
  'certificateSha256': 'certificate',
  'apkName': 'PocketFlow-0.3.0-debug.apk',
  'apkSha256': digest,
  'apkSizeBytes': 12345,
  'releaseNotes': ['分类预算', '周期账单'],
};
List<dynamic> feed() => [
  {
    'draft': false,
    'prerelease': true,
    'tag_name': tag,
    'assets': [
      {
        'name': 'PocketFlow-update.json',
        'browser_download_url': '${prefix}PocketFlow-update.json',
      },
      {
        'name': 'PocketFlow-0.3.0-debug.apk',
        'browser_download_url': '${prefix}PocketFlow-0.3.0-debug.apk',
        'size': 12345,
        'digest': 'sha256:$digest',
      },
    ],
  },
];
GithubAppReleaseSource source(
  Map<String, dynamic> document, [
  List<dynamic>? releases,
]) => GithubAppReleaseSource(
  load: (url) async =>
      jsonEncode(url.host == 'api.github.com' ? releases ?? feed() : document),
);
AppUpdate candidate() => AppUpdate(
  versionName: '0.3.0',
  versionCode: 5,
  bytes: 12345,
  sha256: digest,
  downloadUrl: Uri.parse('${prefix}PocketFlow-0.3.0-debug.apk'),
  releaseUrl: Uri.parse(
    'https://github.com/yuminhang666-oss/PocketFlow/releases/tag/$tag',
  ),
  notes: ['分类预算', '周期账单'],
);

class FakePlatform implements AppUpdatePort {
  Uri? opened;
  @override
  Future<InstalledApp> installedApp() async => installed;
  @override
  Future<void> openDownload(Uri uri) async {
    opened = uri;
  }
}

class FakeSource implements AppReleaseSource {
  int calls = 0;
  bool fail = false;
  AppUpdate? next = candidate();
  @override
  Future<AppUpdate?> latestFor(InstalledApp app) async {
    calls++;
    if (fail) throw const UpdateUnavailable();
    return next;
  }
}

void main() {
  test('v2 selects Release asset while retaining v1 compatibility', () async {
    final release = feed();
    release[0]['assets'].add({
      'name': 'PocketFlow-update-v2.json',
      'browser_download_url': '${prefix}PocketFlow-update-v2.json',
    });
    release[0]['assets'].add({
      'name': 'PocketFlow-0.3.0-release.apk',
      'browser_download_url': '${prefix}PocketFlow-0.3.0-release.apk',
      'size': 12345,
      'digest': 'sha256:$digest',
    });
    final v2 = {
      ...manifest(),
      'schemaVersion': 2,
      'buildKind': 'release',
      'assetName': 'PocketFlow-0.3.0-release.apk',
    }..remove('apkName');
    final remote = GithubAppReleaseSource(
      load: (uri) async => jsonEncode(
        uri.host == 'api.github.com'
            ? release
            : uri.path.endsWith('v2.json')
            ? v2
            : manifest(),
      ),
    );
    expect(
      (await remote.latestFor(installed))!.downloadUrl.path,
      endsWith('release.apk'),
    );
  });
  test(
    'invalid latest release does not hide an earlier valid update',
    () async {
      final invalid = {
        'draft': false,
        'prerelease': true,
        'tag_name': 'mvp-v0.4.0-debug',
        'assets': [],
      };
      expect(
        (await source(manifest(), [
          invalid,
          ...feed(),
        ]).latestFor(installed))!.versionCode,
        5,
      );
    },
  );
  test(
    'failed recheck clears stale candidate and prevents opening it',
    () async {
      final platform = FakePlatform(), remote = FakeSource();
      final controller = AppUpdateController(
        platform: platform,
        source: remote,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.check();
      remote.fail = true;
      await controller.check();
      expect(controller.update, isNull);
      await controller.download();
      expect(platform.opened, isNull);
    },
  );
  test('test-channel manifest offers a newer compatible APK', () async {
    final update = await source(manifest()).latestFor(installed);
    expect(update!.versionCode, 5);
    expect(
      update.downloadUrl.toString(),
      '${prefix}PocketFlow-0.3.0-debug.apk',
    );
  });
  test('older published releases need no update manifest', () async {
    final releases = feed();
    releases[0]['tag_name'] = 'mvp-v0.2.0-debug';
    releases[0]['assets'] = [];
    expect(await source(manifest(), releases).latestFor(installed), isNull);
  });
  test(
    'missing newer manifest cannot claim the installation is latest',
    () async {
      final releases = feed();
      releases[0]['assets'] = [];
      await expectLater(
        source(manifest(), releases).latestFor(installed),
        throwsA(isA<UpdateUnavailable>()),
      );
    },
  );
  test('APK metadata mismatch and off-repository links are rejected', () async {
    final changed = manifest()..['apkSizeBytes'] = 1;
    await expectLater(
      source(changed).latestFor(installed),
      throwsA(isA<UpdateUnavailable>()),
    );
    final releases = feed();
    releases[0]['assets'][0]['browser_download_url'] =
        'https://example.com/PocketFlow-update.json';
    await expectLater(
      source(manifest(), releases).latestFor(installed),
      throwsA(isA<UpdateUnavailable>()),
    );
  });
  test(
    'different application and invalid version metadata are rejected',
    () async {
      for (final changed in [
        manifest()..['applicationId'] = 'other.app',
        manifest()..['versionCode'] = 5.5,
        manifest()..['apkSha256'] = 'invalid',
        manifest()..['versionName'] = '0.9.0',
      ]) {
        await expectLater(
          source(changed).latestFor(installed),
          throwsA(isA<UpdateUnavailable>()),
        );
      }
    },
  );
  test('a different signing identity is never offered as an update', () async {
    expect(
      await source(
        manifest()..['certificateSha256'] = 'other',
      ).latestFor(installed),
      isNull,
    );
  });
  test('offline and malformed responses are reported as unavailable', () async {
    for (final load in [
      ((Uri _) async => throw Exception('offline')),
      ((Uri _) async => 'invalid JSON'),
    ]) {
      await expectLater(
        GithubAppReleaseSource(load: load).latestFor(installed),
        throwsA(isA<UpdateUnavailable>()),
      );
    }
  });
  test(
    'startup reads only local version information without network requests',
    () async {
      final remote = FakeSource();
      final controller = AppUpdateController(
        platform: FakePlatform(),
        source: remote,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(remote.calls, 0);
      expect(controller.phase, AppUpdatePhase.idle);
      expect(controller.installed!.versionCode, 4);
    },
  );
  test(
    'manual check offers a newer version and opens its verified URL',
    () async {
      final platform = FakePlatform(), remote = FakeSource();
      final controller = AppUpdateController(
        platform: platform,
        source: remote,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.check();
      expect(remote.calls, 1);
      expect(controller.phase, AppUpdatePhase.available);
      await controller.download();
      expect(platform.opened, candidate().downloadUrl);
    },
  );
  test('repeated taps do not start concurrent version requests', () async {
    final remote = FakeSource();
    final controller = AppUpdateController(
      platform: FakePlatform(),
      source: remote,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await Future.wait([controller.check(), controller.check()]);
    expect(remote.calls, 1);
  });
  test(
    'network failure never claims the installed version is latest',
    () async {
      final controller = AppUpdateController(
        platform: FakePlatform(),
        source: FakeSource()..fail = true,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.check();
      expect(controller.phase, AppUpdatePhase.unavailable);
      expect(controller.installed!.versionCode, 4);
      expect(controller.update, isNull);
    },
  );
  testWidgets(
    'update page remains scrollable with large text on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final platform = FakePlatform();
      final controller = AppUpdateController(
        platform: platform,
        source: FakeSource(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.check();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: AppUpdatesPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = find.text('下载并更新');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(platform.opened, candidate().downloadUrl);
      expect(tester.takeException(), isNull);
    },
  );
}
