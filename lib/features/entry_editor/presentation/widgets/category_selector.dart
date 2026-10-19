import 'package:flutter/material.dart';
import '../../../../core/domain/ledger_models.dart';
import '../../../../core/domain/ledger_entry.dart';
import '../../../../core/domain/category_catalog.dart';
import '../../../../shared/widgets/entry_tile.dart';

Future<String?> showCategoryPicker(
  BuildContext context,
  List<Category> categories,
  EntryKind kind,
  String? selectedId,
) {
  var query = '';
  final all = categories
      .where(
        (c) =>
            categoryAvailable(c, categories, kind) &&
            (kind == EntryKind.expense ||
                c.kind == EntryKind.income ||
                c.id == selectedId),
      )
      .toList();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) => SizedBox(
        height: MediaQuery.sizeOf(sheet).height * .82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      kind == EntryKind.expense ? '选择支出分类' : '选择收入分类',
                      style: Theme.of(sheet).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(sheet),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索分类或细分类',
                ),
                onChanged: (v) => setSheet(() => query = v.trim()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  for (final root in all.where((c) => c.parentId == null)) ...[
                    if (query.isEmpty ||
                        root.name.contains(query) ||
                        all.any(
                          (c) =>
                              c.parentId == root.id && c.name.contains(query),
                        )) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          root.name,
                          style: Theme.of(sheet).textTheme.titleMedium,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final c in [
                            root,
                            ...all.where((c) => c.parentId == root.id),
                          ])
                            if (query.isEmpty ||
                                root.name.contains(query) ||
                                c.name.contains(query))
                              ChoiceChip(
                                selected: c.id == selectedId,
                                label: Text(
                                  c.id == root.id ? '${c.name}（未细分）' : c.name,
                                ),
                                avatar: Icon(
                                  categoryIcon(c.id, categories),
                                  size: 18,
                                ),
                                onSelected: (_) => Navigator.pop(sheet, c.id),
                              ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.enabled = true,
    this.kind = EntryKind.expense,
  });
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final EntryKind kind;
  @override
  Widget build(BuildContext context) {
    final all = categories
        .where(
          (c) =>
              categoryAvailable(c, categories, kind) &&
              (kind == EntryKind.expense ||
                  c.kind == EntryKind.income ||
                  c.id == selectedId),
        )
        .toList();
    final selected = categories.where((c) => c.id == selectedId).firstOrNull;
    final common = <Category>[];
    if (selected != null) common.add(selected);
    for (final c in all.where((c) => c.parentId == null)) {
      if (common.length >= 3) break;
      if (!common.any((v) => v.id == c.id)) common.add(c);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final columns = MediaQuery.textScalerOf(context).scale(12) > 19 ? 2 : 4;
        final width = (box.maxWidth - (columns - 1) * 6) / columns;
        Widget item(
          String label,
          IconData icon,
          Color color,
          bool selected,
          VoidCallback? tap,
        ) => SizedBox(
          width: width,
          child: OutlinedButton(
            onPressed: tap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 56),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              backgroundColor: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              side: BorderSide(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_circle_outline : icon,
                  size: 19,
                  color: color,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in common)
              item(
                c.name,
                categoryIcon(c.id, categories),
                Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.primary
                    : categoryColor(c.id, categories),
                selectedId == c.id,
                enabled ? () => onSelected(c.id) : null,
              ),
            item(
              '更多分类',
              Icons.grid_view_rounded,
              Theme.of(context).colorScheme.primary,
              false,
              !enabled
                  ? null
                  : () async {
                      final id = await showCategoryPicker(
                        context,
                        categories,
                        kind,
                        selectedId,
                      );
                      if (id != null) onSelected(id);
                    },
            ),
          ],
        );
      },
    );
  }
}
