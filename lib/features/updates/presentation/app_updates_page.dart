import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../application/app_update_controller.dart';
import '../../../contracts/app_update_port.dart';
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
        ).showSnackBar(SnackBar(content: Text(tr(context, "暂时无法完成，请稍后重试"))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final installed = controller.installed;
      final update = controller.update;
      final downloading = controller.phase == AppUpdatePhase.downloading;
      final ready = controller.phase == AppUpdatePhase.ready;
      final busy =
          controller.phase == AppUpdatePhase.checking ||
          downloading ||
          controller.installing;
      final status = switch (controller.phase) {
        AppUpdatePhase.idle => tr(context, "点击下方按钮检查新版本"),
        AppUpdatePhase.checking => tr(context, "正在检查新版本…"),
        AppUpdatePhase.current => tr(context, "已经是最新版本"),
        AppUpdatePhase.available => tr(context, "发现新版本 {0}", [
          update?.versionName ?? '',
        ]),
        AppUpdatePhase.unavailable => tr(context, "暂时无法检查更新，记账仍可正常使用"),
        AppUpdatePhase.downloading => tr(context, "正在下载更新…"),
        AppUpdatePhase.ready => tr(context, "安装包已下载并通过校验"),
      };
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, "版本更新"))),
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
                            ? tr(context, "正在读取当前版本")
                            : tr(context, "当前版本 {0} · 测试版", [
                                installed.versionName,
                              ]),
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
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: LinearProgressIndicator(
                                    value: downloading && update != null
                                        ? (controller.downloaded / update.bytes)
                                              .clamp(0, 1)
                                        : null,
                                  ),
                                ),
                              Text(
                                status,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (controller.failure != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  tr(
                                    context,
                                    _failureText(controller.failure!),
                                  ),
                                ),
                              ],
                              if (controller.installNotice != null) ...[
                                const SizedBox(height: 8),
                                Text(tr(context, controller.installNotice!)),
                              ],
                              if (update != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  tr(context, "安装包 {0} MB", [
                                    (update.bytes / 1048576).toStringAsFixed(1),
                                  ]),
                                ),
                                const SizedBox(height: 12),
                                for (final note in update.notes)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text('• ${tr(context, note)}'),
                                  ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => _action(
                                          context,
                                          ready
                                              ? controller.install
                                              : controller.download,
                                        ),
                                  icon: const Icon(Icons.download_rounded),
                                  label: Text(
                                    downloading
                                        ? tr(context, "正在下载 {0}%", [
                                            (controller.downloaded /
                                                    update.bytes *
                                                    100)
                                                .clamp(0, 100)
                                                .toStringAsFixed(0),
                                          ])
                                        : ready
                                        ? tr(context, "安装更新")
                                        : tr(context, "下载并更新"),
                                  ),
                                ),
                                if (downloading)
                                  TextButton(
                                    onPressed: () =>
                                        _action(context, controller.cancel),
                                    child: Text(tr(context, "取消下载")),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  tr(
                                    context,
                                    "应用内下载并校验后，由系统确认安装。首次需允许安装应用；覆盖更新保留账本。",
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: busy ? null : controller.check,
                                child: Text(
                                  controller.phase == AppUpdatePhase.checking
                                      ? tr(context, "检查中…")
                                      : tr(context, "检查更新"),
                                ),
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
                                  child: Text(tr(context, "打开下载页")),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 12),
                      Text(
                        tr(context, "仅在你点击检查更新时联网，不上传账单。"),
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

String _failureText(UpdateFailure failure) => switch (failure) {
  UpdateFailure.network => '无法连接更新服务，请检查网络或切换 Wi-Fi / 移动网络后重试。',
  UpdateFailure.timeout => '连接超时，请稍后重试或切换网络。',
  UpdateFailure.rateLimited => '更新服务请求过多，请稍后重试。',
  UpdateFailure.invalidMetadata => '更新信息校验失败，请稍后重试。',
  UpdateFailure.incompatibleSignature => '新版签名与当前安装不一致，无法覆盖更新。',
  UpdateFailure.installedInfo => '无法读取本机版本，请重试。',
  UpdateFailure.download => '安装包下载失败，请检查网络与可用空间后重试。',
  UpdateFailure.integrity => '安装包校验未通过，已停止安装，请重新下载。',
  UpdateFailure.cancelled => '已取消下载。',
  UpdateFailure.installer => '无法打开系统安装界面，请检查安装权限后重试。',
};
