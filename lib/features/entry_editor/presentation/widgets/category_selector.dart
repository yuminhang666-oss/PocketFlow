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
    final selected = categories.where((c) => c.id == selectedId).firstOrNull;
    final all =
        categories.where((c) => categoryAvailable(c, categories, kind)).toList()
          ..sort((a, b) {
            final order = a.sortOrder.compareTo(b.sortOrder);
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
    final roots = all.where((c) => c.parentId == null).toList();
    final rootId = selected?.parentId ?? selected?.id;
    final children = all.where((c) => c.parentId == rootId).toList();
    final large = MediaQuery.textScalerOf(context).scale(14) > 19;
    final medium = MediaQuery.textScalerOf(context).scale(14) > 16.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          selected == null
              ? '请选择分类'
              : '已选：${categoryPath(selected, categories)}',
          key: const ValueKey('selected-category-path'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: large
              ? 230
              : medium
              ? 198
              : 158,
          child: GridView.builder(
            key: ValueKey('category-grid-${kind.name}'),
            itemCount: roots.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: large
                  ? 2
                  : medium
                  ? 3
                  : 4,
              mainAxisExtent: large
                  ? 112
                  : medium
                  ? 96
                  : 76,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final c = roots[index], active = c.id == rootId;
              return Semantics(
                selected: active,
                button: true,
                label: '${c.name}${active ? '，已选' : ''}',
                child: OutlinedButton(
                  onPressed: enabled ? () => onSelected(c.id) : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    backgroundColor: active
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    side: BorderSide(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: active ? 2 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(categoryIcon(c.id, categories), size: 22),
                          const SizedBox(height: 4),
                          Text(
                            c.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                      if (active)
                        const Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(Icons.check_circle, size: 13),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (children.isNotEmpty)
          SizedBox(
            height: large ? 70 : 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in children)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(categoryIcon(c.id, categories), size: 18),
                      selected: c.id == selectedId,
                      label: Text(c.name),
                      onSelected: enabled ? (_) => onSelected(c.id) : null,
                    ),
                  ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.search, size: 18),
            label: const Text('搜索全部分类'),
            onPressed: !enabled
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
        ),
      ],
    );
  }
}
