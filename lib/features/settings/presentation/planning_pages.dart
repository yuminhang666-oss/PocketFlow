import 'package:flutter/material.dart';
import '../../../shared/widgets/completed_modal.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/presentation_errors.dart';

Future<void> editSavingsGoal(
  BuildContext context,
  SavingsGoal? initial,
  Future<void> Function(SavingsGoal) save,
) async {
  final name = TextEditingController(text: initial?.name ?? '');
  final target = TextEditingController(text: initial?.target.decimal ?? '');
  final saved = TextEditingController(text: initial?.saved.decimal ?? '0.00');
  var busy = false;
  String? error;
  await showCompletedBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) => PopScope(
        canPop: !busy,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.viewInsetsOf(sheet).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                initial == null ? '新建小目标' : '编辑目标进度',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                enabled: !busy,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: '目标名称',
                  hintText: '例如：耳机基金',
                ),
              ),
              TextField(
                controller: target,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '目标金额（元）'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: saved,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '已登记金额（元）'),
              ),
              const SizedBox(height: 12),
              const Text('这里只登记你的目标进度，不会扣减生活费预算。'),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(sheet).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        try {
                          final goal = SavingsGoal(
                            id:
                                initial?.id ??
                                'goal-${DateTime.now().microsecondsSinceEpoch}',
                            name: name.text.trim(),
                            target: Money.parse(target.text),
                            saved: Money.parse(saved.text),
                          );
                          setSheet(() => busy = true);
                          await save(goal);
                          if (sheet.mounted) Navigator.pop(sheet);
                        } catch (e) {
                          if (sheet.mounted) {
                            setSheet(() {
                              busy = false;
                              error = e is FormatException
                                  ? e.message
                                  : presentationError(e);
                            });
                          }
                        }
                      },
                child: Text(busy ? '保存中…' : '保存目标'),
              ),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(sheet),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  name.dispose();
  target.dispose();
  saved.dispose();
}

Future<bool> confirmPlanningDelete(BuildContext context, String name) =>
    showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('删除$name？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((v) => v ?? false);

class GoalsPage extends StatelessWidget {
  const GoalsPage({
    super.key,
    required this.profile,
    required this.onSave,
    required this.onDelete,
  });
  final PersonalProfile profile;
  final Future<void> Function(SavingsGoal) onSave;
  final Future<void> Function(String) onDelete;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('我的小目标')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text('把想做的事变成看得见的进度。金额由你手动登记，与生活费预算独立。'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => editSavingsGoal(context, null, onSave),
              icon: const Icon(Icons.add),
              label: const Text('新建目标'),
            ),
            if (profile.goals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('还没有目标，可以从一个小计划开始。', textAlign: TextAlign.center),
              ),
            for (final goal in profile.goals)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            goal.saved.fen >= goal.target.fen
                                ? Icons.celebration_outlined
                                : Icons.savings_outlined,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              goal.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: (goal.saved.fen / goal.target.fen).clamp(
                          0.0,
                          1.0,
                        ),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          AmountText(goal.saved),
                          Text('/ 目标 ${goal.target.yuan}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        goal.saved.fen >= goal.target.fen
                            ? '已达到目标，记录这一刻。'
                            : '已登记 ${(goal.saved.fen / goal.target.fen * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () =>
                                editSavingsGoal(context, goal, onSave),
                            child: const Text('更新进度'),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (await confirmPlanningDelete(
                                context,
                                '这个目标',
                              )) {
                                try {
                                  await onDelete(goal.id);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(presentationError(e)),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            child: const Text('删除目标'),
                          ),
                        ],
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
}

class TemplatesPage extends StatelessWidget {
  const TemplatesPage({
    super.key,
    required this.profile,
    required this.categories,
    required this.onUse,
    required this.onDelete,
  });
  final PersonalProfile profile;
  final List<Category> categories;
  final ValueChanged<EntryTemplate> onUse;
  final Future<void> Function(String) onDelete;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('常用模板')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('在记账页填写金额和分类后，点右上角书签图标保存模板。使用时仍可确认金额、日期和备注。'),
          const SizedBox(height: 16),
          if (profile.templates.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('还没有模板')),
          for (final t in profile.templates)
            ListTile(
              leading: Icon(categoryIcon(t.categoryId, categories)),
              title: Text(t.name),
              subtitle: Text(
                '${t.kind == EntryKind.income ? '收入' : '支出'} · ${t.amount.yuan}',
              ),
              onTap: () => onUse(t),
              trailing: IconButton(
                tooltip: '删除模板',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirmPlanningDelete(context, '这个模板')) {
                    try {
                      await onDelete(t.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(presentationError(e))),
                        );
                      }
                    }
                  }
                },
              ),
            ),
        ],
      ),
    ),
  );
}
