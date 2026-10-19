import 'package:flutter/material.dart';
import '../../../shared/widgets/completed_modal.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/entry_tile.dart';
import '../../../shared/widgets/presentation_errors.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({
    super.key,
    required this.categories,
    required this.onSave,
    required this.onRecommended,
    required this.onReorder,
  });
  final List<Category> categories;
  final Future<void> Function(Category) onSave;
  final Future<void> Function() onRecommended;
  final Future<void> Function(List<String>) onReorder;
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  EntryKind _kind = EntryKind.expense;
  bool _archived = false, _busy = false;
  String? _error;
  bool _matches(Category c) => _kind == EntryKind.income
      ? c.kind == EntryKind.income
      : c.kind != EntryKind.income;
  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = presentationError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Category? initial]) async {
    final name = TextEditingController(text: initial?.name ?? '');
    String? parentId = initial?.parentId;
    String? error;
    var saving = false;
    final roots = widget.categories
        .where((c) => c.parentId == null && !c.isArchived && _matches(c))
        .toList();
    await showCompletedDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialog) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(initial == null ? '新增分类' : '编辑分类'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    enabled: !saving,
                    maxLength: 30,
                    decoration: const InputDecoration(labelText: '分类名称'),
                  ),
                  if (initial == null)
                    DropdownButtonFormField<String>(
                      initialValue: '',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '放在哪一组'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('新建一级分类'),
                        ),
                        for (final c in roots)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => parentId = v == '' ? null : v,
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(dialog).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialog),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        try {
                          final title = name.text.trim();
                          if (title.isEmpty) {
                            throw const FormatException('请输入分类名称');
                          }
                          final category = Category(
                            id:
                                initial?.id ??
                                'custom-${DateTime.now().microsecondsSinceEpoch}',
                            name: title,
                            sortOrder:
                                initial?.sortOrder ??
                                (widget.categories.isEmpty
                                    ? 0
                                    : widget.categories
                                              .map((c) => c.sortOrder)
                                              .reduce((a, b) => a > b ? a : b) +
                                          10),
                            isArchived: initial?.isArchived ?? false,
                            kind: initial == null ? _kind : initial.kind,
                            parentId: initial == null
                                ? parentId
                                : initial.parentId,
                          );
                          setDialog(() => saving = true);
                          await widget.onSave(category);
                          if (dialog.mounted) Navigator.pop(dialog);
                        } catch (e) {
                          if (dialog.mounted) {
                            setDialog(() {
                              saving = false;
                              error = e is FormatException
                                  ? e.message
                                  : presentationError(e);
                            });
                          }
                        }
                      },
                child: Text(saving ? '保存中…' : '保存分类'),
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roots =
        widget.categories
            .where(
              (c) =>
                  c.parentId == null &&
                  _matches(c) &&
                  (_archived || !c.isArchived),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    Widget tile(Category c, {bool root = false, int? index}) => ListTile(
      leading: Icon(
        categoryIcon(c.id, widget.categories),
        color: categoryColor(c.id, widget.categories),
      ),
      title: Text(c.name),
      subtitle: c.isArchived ? const Text('已归档，历史账单仍保留') : null,
      onTap: _busy ? null : () => _edit(c),
      trailing: PopupMenuButton<String>(
        enabled: !_busy,
        onSelected: (value) {
          if (value == 'edit') {
            _edit(c);
            return;
          }
          if (value == 'archive') {
            _action(
              () => widget.onSave(
                Category(
                  id: c.id,
                  name: c.name,
                  sortOrder: c.sortOrder,
                  isArchived: !c.isArchived,
                  kind: c.kind,
                  parentId: c.parentId,
                ),
              ),
            );
            return;
          }
          if (root && index != null) {
            final next = List<Category>.of(roots),
                other = value == 'up' ? index - 1 : index + 1;
            if (other < 0 || other >= next.length) return;
            next[index] = roots[other];
            next[other] = c;
            _action(() => widget.onReorder(next.map((c) => c.id).toList()));
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('修改名称')),
          PopupMenuItem(
            value: 'archive',
            child: Text(c.isArchived ? '恢复显示' : '归档分类'),
          ),
          if (root && index != null && index > 0)
            const PopupMenuItem(value: 'up', child: Text('向上移动')),
          if (root && index != null && index < roots.length - 1)
            const PopupMenuItem(value: 'down', child: Text('向下移动')),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        actions: [
          IconButton(
            tooltip: '新增分类',
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<EntryKind>(
              segments: const [
                ButtonSegment(value: EntryKind.expense, label: Text('支出分类')),
                ButtonSegment(value: EntryKind.income, label: Text('收入分类')),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 8),
            const Text('一级分类下可以展开细分类。归档会隐藏新增入口，保留历史记录。'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示已归档分类'),
              value: _archived,
              onChanged: (v) => setState(() => _archived = v),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: scheme.error)),
            if (_busy) const LinearProgressIndicator(),
            for (var i = 0; i < roots.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                child: ExpansionTile(
                  key: ValueKey(roots[i].id),
                  title: Text(roots[i].name),
                  leading: Icon(
                    categoryIcon(roots[i].id, widget.categories),
                    color: categoryColor(roots[i].id, widget.categories),
                  ),
                  children: [
                    tile(roots[i], root: true, index: i),
                    for (final c in widget.categories.where(
                      (c) =>
                          c.parentId == roots[i].id &&
                          (_archived || !c.isArchived),
                    ))
                      tile(c),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _action(widget.onRecommended),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('补全推荐分类'),
            ),
            const SizedBox(height: 6),
            Text(
              '只添加缺少的分类，不覆盖你修改的名称和归档状态。',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
