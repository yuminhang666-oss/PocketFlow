import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.themeMode = ThemeMode.system,
    this.onThemeChanged,
    this.feedback = true,
    this.onFeedbackChanged,
    this.onBudget,
    this.onHistory,
    this.onCalendar,
    this.onGoals,
    this.onCategories,
    this.onTemplates,
    this.onExport,
    this.onBackup,
    this.onRestore,
    this.onAbout,
    this.onUpdates,
    this.updateVersion,
  });
  final ThemeMode themeMode;
  final bool feedback;
  final String? updateVersion;
  final VoidCallback? onUpdates;
  final ValueChanged<ThemeMode>? onThemeChanged;
  final ValueChanged<bool>? onFeedbackChanged;
  final VoidCallback? onBudget,
      onHistory,
      onCalendar,
      onGoals,
      onCategories,
      onTemplates,
      onExport,
      onBackup,
      onRestore,
      onAbout;
  String _themeName(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };
  Future<void> _theme(BuildContext context) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('选择主题', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final mode in ThemeMode.values)
                ListTile(
                  title: Text(_themeName(mode)),
                  trailing: mode == themeMode
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(sheet, mode),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onThemeChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('我的')),
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
                  _group(context, '我的账本', [
                    _item(
                      '预算设置',
                      Icons.account_balance_wallet_outlined,
                      onBudget,
                    ),
                    _item('历史账单', Icons.receipt_long_outlined, onHistory),
                    _item('记账日历', Icons.calendar_month_outlined, onCalendar),
                    _item('我的小目标', Icons.savings_outlined, onGoals),
                    _item('分类管理', Icons.category_outlined, onCategories),
                    _item('常用模板', Icons.bookmarks_outlined, onTemplates),
                  ]),
                  _group(context, '使用偏好', [
                    ListTile(
                      leading: const Icon(Icons.contrast_rounded),
                      title: const Text('主题'),
                      subtitle: Text(_themeName(themeMode)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onThemeChanged == null
                          ? null
                          : () => _theme(context),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration_outlined),
                      title: const Text('记账反馈'),
                      subtitle: const Text('保存后轻触反馈'),
                      value: feedback,
                      onChanged: onFeedbackChanged,
                    ),
                  ]),
                  _group(context, '数据管理', [
                    _item('导出月报', Icons.ios_share_rounded, onExport),
                    _item('备份数据', Icons.save_outlined, onBackup),
                    _item('恢复备份', Icons.restore_rounded, onRestore),
                  ]),
                  _group(context, '关于', [
                    ListTile(
                      leading: const Icon(Icons.system_update_outlined),
                      title: const Text('检查更新'),
                      subtitle: updateVersion == null
                          ? null
                          : Text('发现新版本 $updateVersion'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: onUpdates,
                    ),
                    _item('关于 PocketFlow', Icons.info_outline_rounded, onAbout),
                  ]),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '无需账号，数据保存在手机本地。\n只有你主动选择时，才会导出或分享文件。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
  Widget _group(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Material(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(children: children),
            ),
          ],
        ),
      );
  Widget _item(String title, IconData icon, VoidCallback? action) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    enabled: action != null,
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: action,
  );
}
