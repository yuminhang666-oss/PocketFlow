import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.themeMode = ThemeMode.system,
    this.onThemeChanged, this.onBudget, this.onHistory, this.onExport,
    this.onBackup, this.onRestore, this.onAbout});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeChanged;
  final VoidCallback? onBudget;
  final VoidCallback? onHistory;
  final VoidCallback? onExport;
  final VoidCallback? onBackup;
  final VoidCallback? onRestore;
  final VoidCallback? onAbout;

  String _themeName(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '跟随系统', ThemeMode.light => '浅色', ThemeMode.dark => '深色',
  };

  Future<void> _theme(BuildContext context) async {
    final selected = await showModalBottomSheet<ThemeMode>(context: context, useSafeArea: true,
      builder: (context) => SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text('选择主题', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final mode in ThemeMode.values) ListTile(title: Text(_themeName(mode)),
              trailing: mode == themeMode ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(context, mode)),
          ]))));
    if (selected != null) onThemeChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: SafeArea(top: false, child: SingleChildScrollView(padding: const EdgeInsets.all(20),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(context, '生活费管理'),
          _item('预算设置', Icons.account_balance_wallet_outlined, onBudget),
          _item('历史账单', Icons.receipt_long_rounded, onHistory),
          const SizedBox(height: 24), _heading(context, '显示'),
          ListTile(leading: const Icon(Icons.contrast_rounded), title: const Text('主题'),
            subtitle: Text(_themeName(themeMode)), enabled: onThemeChanged != null,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onThemeChanged == null ? null : () => _theme(context)),
          const SizedBox(height: 24), _heading(context, '数据管理'),
          _item('导出月报', Icons.ios_share_rounded, onExport),
          _item('备份数据', Icons.save_outlined, onBackup),
          _item('恢复备份', Icons.restore_rounded, onRestore),
          const SizedBox(height: 24), _heading(context, '关于'),
          _item('关于 PocketFlow', Icons.info_outline_rounded, onAbout),
          const SizedBox(height: 24),
          const Text('无需账号，数据保存在手机本地。\n只有你主动选择时，才会导出或分享文件。'),
        ]),
      )),
    )),
  );

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge));

  Widget _item(String text, IconData icon, VoidCallback? action) => ListTile(
    leading: Icon(icon), title: Text(text), enabled: action != null,
    subtitle: action == null ? const Text('尚未开放') : null,
    trailing: const Icon(Icons.chevron_right_rounded), onTap: action);
}
