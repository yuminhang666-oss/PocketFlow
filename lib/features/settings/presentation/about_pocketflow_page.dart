import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../domain/release_history.dart';

class AboutPocketFlowPage extends StatelessWidget {
  const AboutPocketFlowPage({super.key, required this.installedVersion});

  final String installedVersion;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, "关于 PocketFlow"))),
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
                  const SizedBox(height: 16),
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'PocketFlow',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, "{0} · 个人测试版", [installedVersion]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr(
                      context,
                      "离线管理生活费，记录日常收支，安排预算，回顾每一笔花费。\nMarkdown用于分析，JSON用于完整备份。",
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: Text(tr(context, "更新记录")),
                    subtitle: Text(tr(context, "查看各版本新增功能与问题修复")),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => ReleaseHistoryPage(
                          installedVersion: installedVersion,
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(tr(context, "开源许可")),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'PocketFlow',
                      applicationVersion: installedVersion,
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
}

class ReleaseHistoryPage extends StatelessWidget {
  const ReleaseHistoryPage({super.key, required this.installedVersion});

  final String installedVersion;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, "更新记录"))),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr(context, "按版本查看新增功能与问题修复，离线可用。")),
                  const SizedBox(height: 16),
                  for (final release in pocketFlowVersionHistory)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        key: PageStorageKey('release-${release.version}'),
                        initiallyExpanded: release.version == installedVersion,
                        title: Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              release.version,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (release.version == installedVersion)
                              Text(
                                tr(context, "当前版本"),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          release.publishedOn == null
                              ? tr(context, release.title)
                              : '${release.publishedOn} · ${tr(context, release.title)}',
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _changes(
                                  context,
                                  tr(context, "新增功能"),
                                  release.additions,
                                ),
                                _changes(
                                  context,
                                  tr(context, "问题修复"),
                                  release.fixes,
                                ),
                                _changes(
                                  context,
                                  tr(context, "说明"),
                                  release.notes,
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _changes(BuildContext context, String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• ${tr(context, item)}'),
            ),
        ],
      ),
    );
  }
}
