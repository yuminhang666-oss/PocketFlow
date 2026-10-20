import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/frosted_glass.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.themeMode = ThemeMode.system,
    this.glass = false,
    this.language = 'zh_Hans',
    this.onLanguageChanged,
    this.onGlassSelected,
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
    this.onPlans,
    this.onReports,
    this.onRecoveryPoints,
    this.onReminders,
    this.onFeedback,
    this.lastExportUtcMs,
  });
  final ThemeMode themeMode;
  final bool glass;
  final String language;
  final ValueChanged<String>? onLanguageChanged;
  static const languages = {
    'zh_Hans': '简体中文',
    'zh_Hant': '繁體中文',
    'en': 'English',
  };
  final VoidCallback? onGlassSelected;
  final bool feedback;
  final String? updateVersion;
  final VoidCallback? onUpdates;
  final VoidCallback? onPlans,
      onReports,
      onRecoveryPoints,
      onReminders,
      onFeedback;
  final int? lastExportUtcMs;
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
  String _themeName(BuildContext context, ThemeMode mode) => switch (mode) {
    ThemeMode.system => tr(context, "跟随系统"),
    ThemeMode.light => tr(context, "浅色"),
    ThemeMode.dark => tr(context, "深色"),
  };
  Future<void> _theme(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(sheet, "选择主题"),
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final mode in ThemeMode.values)
                ListTile(
                  title: Text(_themeName(sheet, mode)),
                  trailing: !glass && mode == themeMode
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(sheet, mode.name),
                ),
              ListTile(
                leading: const Icon(Icons.blur_on_rounded),
                title: Text(tr(sheet, "毛玻璃（浅色）")),
                subtitle: Text(tr(sheet, "通透卡片与柔和层次，独立浅色主题")),
                trailing: glass ? const Icon(Icons.check_rounded) : null,
                onTap: onGlassSelected == null
                    ? null
                    : () => Navigator.pop(sheet, 'glass'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == 'glass') {
      onGlassSelected?.call();
    } else if (selected != null) {
      onThemeChanged?.call(ThemeMode.values.byName(selected));
    }
  }

  Future<void> _language(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(sheet, "选择语言"),
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final item in languages.entries)
              ListTile(
                title: Text(item.value),
                trailing: item.key == language
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(sheet, item.key),
              ),
          ],
        ),
      ),
    );
    if (selected != null) onLanguageChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, "我的"))),
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
                  _group(context, tr(context, "我的账本"), [
                    _item(
                      tr(context, "预算设置"),
                      Icons.account_balance_wallet_outlined,
                      onBudget,
                    ),
                    _item(
                      tr(context, "历史账单"),
                      Icons.receipt_long_outlined,
                      onHistory,
                    ),
                    _item(
                      tr(context, "记账日历"),
                      Icons.calendar_month_outlined,
                      onCalendar,
                    ),
                    _item(
                      tr(context, "我的小目标"),
                      Icons.savings_outlined,
                      onGoals,
                    ),
                    _item(
                      tr(context, "分类管理"),
                      Icons.category_outlined,
                      onCategories,
                    ),
                    _item(
                      tr(context, "常用模板"),
                      Icons.bookmarks_outlined,
                      onTemplates,
                    ),
                    _item(
                      tr(context, "周期账单与收入"),
                      Icons.event_repeat_outlined,
                      onPlans,
                    ),
                    _item(
                      tr(context, "周报与月报"),
                      Icons.summarize_outlined,
                      onReports,
                    ),
                    _item(
                      tr(context, "提醒设置与最近分类"),
                      Icons.notifications_none_outlined,
                      onReminders,
                    ),
                  ]),
                  _group(context, tr(context, "使用偏好"), [
                    ListTile(
                      leading: const Icon(Icons.language_rounded),
                      title: Text(tr(context, "语言")),
                      subtitle: Text(
                        languages[language] ?? languages['zh_Hans']!,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onLanguageChanged == null
                          ? null
                          : () => _language(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.contrast_rounded),
                      title: Text(tr(context, "主题")),
                      subtitle: Text(
                        glass
                            ? tr(context, "毛玻璃（浅色）")
                            : _themeName(context, themeMode),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onThemeChanged == null
                          ? null
                          : () => _theme(context),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration_outlined),
                      title: Text(tr(context, "记账反馈")),
                      subtitle: Text(tr(context, "保存后轻触反馈")),
                      value: feedback,
                      onChanged: onFeedbackChanged,
                    ),
                  ]),
                  _group(context, tr(context, "数据管理"), [
                    _item(
                      tr(context, "导出月报"),
                      Icons.ios_share_rounded,
                      onExport,
                    ),
                    _item(tr(context, "备份数据"), Icons.save_outlined, onBackup),
                    _item(
                      tr(context, "恢复备份"),
                      Icons.restore_rounded,
                      onRestore,
                    ),
                    _item(
                      tr(context, "本地恢复点"),
                      Icons.history_outlined,
                      onRecoveryPoints,
                    ),
                    ListTile(
                      title: Text(
                        lastExportUtcMs == null
                            ? tr(context, "尚未成功导出外部备份")
                            : tr(context, "上次成功导出：{0}", [
                                DateTime.fromMillisecondsSinceEpoch(
                                  lastExportUtcMs!,
                                ),
                              ]),
                      ),
                      subtitle: Text(
                        lastExportUtcMs == null ||
                                DateTime.now().millisecondsSinceEpoch -
                                        lastExportUtcMs! >
                                    const Duration(days: 30).inMilliseconds
                            ? tr(context, "建议保存一份外部JSON备份，本地恢复点不能替代它。")
                            : tr(context, "请妥善保管外部JSON备份。"),
                      ),
                    ),
                  ]),
                  _group(context, tr(context, "关于"), [
                    ListTile(
                      leading: const Icon(Icons.system_update_outlined),
                      title: Text(tr(context, "检查更新")),
                      subtitle: updateVersion == null
                          ? null
                          : Text(tr(context, "发现新版本 {0}", [updateVersion])),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: onUpdates,
                    ),
                    _item(
                      tr(context, "关于 PocketFlow"),
                      Icons.info_outline_rounded,
                      onAbout,
                    ),
                    _item(
                      tr(context, "建议与 Bug 反馈"),
                      Icons.feedback_outlined,
                      onFeedback,
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      tr(context, "无需账号，数据保存在手机本地。\n只有你主动选择时，才会导出或分享文件。"),
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
            FrostedSurface(radius: 18, child: Column(children: children)),
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
