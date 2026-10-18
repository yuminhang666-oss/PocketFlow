import 'package:flutter/material.dart';

import '../application/app_update_controller.dart';
import '../data/github_app_release_source.dart';

class AppUpdatesPage extends StatelessWidget {
  const AppUpdatesPage({super.key, required this.controller});
  final AppUpdateController controller;
  Future<void> _action(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法完成，请稍后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final installed = controller.installed;
      final update = controller.update;
      final busy = controller.phase == AppUpdatePhase.checking;
      final status = switch (controller.phase) {
        AppUpdatePhase.idle => '点击下方按钮检查新版本',
        AppUpdatePhase.checking => '正在检查新版本…',
        AppUpdatePhase.current => '已经是最新版本',
        AppUpdatePhase.available => '发现新版本 ${update?.versionName ?? ''}',
        AppUpdatePhase.unavailable => '暂时无法检查更新，记账仍可正常使用',
      };
      return Scaffold(
        appBar: AppBar(title: const Text('版本更新')),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.system_update_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'PocketFlow',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        installed == null
                            ? '正在读取当前版本'
                            : '当前版本 ${installed.versionName} · 测试版',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (busy)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 14),
                                  child: LinearProgressIndicator(),
                                ),
                              Text(
                                status,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (update != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '安装包 ${(update.bytes / 1048576).toStringAsFixed(1)} MB',
                                ),
                                const SizedBox(height: 12),
                                for (final note in update.notes)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text('• $note'),
                                  ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: () =>
                                      _action(context, controller.download),
                                  icon: const Icon(Icons.download_rounded),
                                  label: const Text('下载并更新'),
                                ),
                                const SizedBox(height: 8),
                                const Text('下载完成后打开安装包，选择更新即可保留账本。无需卸载旧版。'),
                              ],
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: busy || installed == null
                                    ? null
                                    : controller.check,
                                child: Text(busy ? '检查中…' : '检查更新'),
                              ),
                              if (controller.phase ==
                                  AppUpdatePhase.unavailable)
                                TextButton(
                                  onPressed: () => _action(
                                    context,
                                    () => controller.platform.openDownload(
                                      GithubAppReleaseSource.releasesPage,
                                    ),
                                  ),
                                  child: const Text('打开下载页'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 12),
                      Text(
                        '仅在你点击检查更新时联网，不上传账单。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
