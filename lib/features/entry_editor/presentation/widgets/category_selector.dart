import 'package:pocketflow/l10n/app_strings.dart';
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
  final all =
      categories
          .where(
            (c) =>
                categoryAvailable(c, categories, kind) &&
                (kind == EntryKind.expense ||
                    c.kind == EntryKind.income ||
                    c.id == selectedId),
          )
          .toList()
        ..sort((a, b) {
          final order = a.sortOrder.compareTo(b.sortOrder);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: SizedBox(
          height:
              (MediaQuery.sizeOf(sheet).height -
                  MediaQuery.viewInsetsOf(sheet).bottom -
                  MediaQuery.paddingOf(sheet).vertical) *
              .82,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              kind == EntryKind.expense
                                  ? tr(context, "选择支出分类")
                                  : tr(context, "选择收入分类"),
                              style: Theme.of(sheet).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: tr(context, "关闭"),
                            onPressed: () => Navigator.pop(sheet),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: tr(context, "搜索分类或细分类"),
                        ),
                        onChanged: (v) => setSheet(() => query = v.trim()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (selectedId != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          tr(context, "已选：{0}", [
                            localizedCategoryById(
                              context,
                              selectedId,
                              categories,
                            ),
                          ]),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (query.isNotEmpty &&
                              !all.any(
                                (c) => localizedCategoryPath(
                                  context,
                                  c,
                                  categories,
                                ).toLowerCase().contains(query.toLowerCase()),
                              ))
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(tr(context, "没有匹配的分类，请尝试其他关键词")),
                            ),
                          for (final root in all.where(
                            (c) => c.parentId == null,
                          )) ...[
                            if (query.isEmpty ||
                                localizedCategoryName(
                                  context,
                                  root,
                                ).toLowerCase().contains(query.toLowerCase()) ||
                                all.any(
                                  (c) =>
                                      c.parentId == root.id &&
                                      localizedCategoryName(context, c)
                                          .toLowerCase()
                                          .contains(query.toLowerCase()),
                                )) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 16,
                                  bottom: 8,
                                ),
                                child: Text(
                                  localizedCategoryName(context, root),
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
                                        localizedCategoryName(context, root)
                                            .toLowerCase()
                                            .contains(query.toLowerCase()) ||
                                        localizedCategoryName(context, c)
                                            .toLowerCase()
                                            .contains(query.toLowerCase()))
                                      ChoiceChip(
                                        selectedColor: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                        checkmarkColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        side: BorderSide(
                                          color: c.id == selectedId
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.outlineVariant,
                                        ),
                                        selected: c.id == selectedId,
                                        label: Text(
                                          c.id == root.id
                                              ? tr(context, "{0}（未细分）", [
                                                  localizedCategoryName(
                                                    context,
                                                    c,
                                                  ),
                                                ])
                                              : localizedCategoryName(
                                                  context,
                                                  c,
                                                ),
                                        ),
                                        avatar: Icon(
                                          categoryIcon(c.id, categories),
                                          color: identityColor(
                                            context,
                                            c.id,
                                            categories,
                                          ),
                                          size: 18,
                                        ),
                                        onSelected: (_) =>
                                            Navigator.pop(sheet, c.id),
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
            ],
          ),
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
    // Catalog order is stable; saving or selecting never reorders shortcuts.
    final roots = all
        .where((c) => c.parentId == null)
        .take(MediaQuery.sizeOf(context).height < 700 ? 4 : 8)
        .toList();
    final rootId = selected?.parentId ?? selected?.id;
    final children = all.where((c) => c.parentId == rootId).toList();
    final large = MediaQuery.textScalerOf(context).scale(14) > 19;
    final medium = MediaQuery.textScalerOf(context).scale(14) > 16.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selected == null
                    ? tr(context, '请选择分类')
                    : tr(context, '已选：{0}', [
                        localizedCategoryPath(context, selected, categories),
                      ]),
                key: const ValueKey('selected-category-path'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Flexible(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                key: const ValueKey('all-categories'),
                icon: const Icon(Icons.apps, size: 18),
                label: Text(
                  tr(context, "全部 {0} 个分类", [
                    all.where((c) => c.parentId == null).length,
                  ]),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
        ),
        const SizedBox(height: 0),
        if (children.isNotEmpty)
          SizedBox(
            height: large ? 70 : 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in children)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      showCheckmark: true,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                        color: c.id == selectedId
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                      avatar: Icon(
                        categoryIcon(c.id, categories),
                        size: 18,
                        color: identityColor(context, c.id, categories),
                      ),
                      selected: c.id == selectedId,
                      label: Text(localizedCategoryName(context, c)),
                      onSelected: enabled ? (_) => onSelected(c.id) : null,
                    ),
                  ),
              ],
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          key: ValueKey('category-grid-${kind.name}'),
          itemCount: roots.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: large
                ? 2
                : medium
                ? 3
                : 4,
            mainAxisExtent: large
                ? 130
                : medium
                ? 96
                : 48,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            final c = roots[index], active = c.id == rootId;
            return Semantics(
              selected: active,
              button: true,
              enabled: enabled,
              excludeSemantics: true,
              onTap: enabled ? () => onSelected(c.id) : null,
              label: tr(context, "{0}{1}", [
                localizedCategoryName(context, c),
                active ? tr(context, "，已选") : '',
              ]),
              child: OutlinedButton(
                onPressed: enabled ? () => onSelected(c.id) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(2),
                  backgroundColor: active
                      ? Theme.of(context).colorScheme.primaryContainer
                      : categoryColor(c.id, categories).withValues(alpha: .08),
                  side: BorderSide(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: active ? 1.5 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          categoryIcon(c.id, categories),
                          size: 22,
                          color: identityColor(context, c.id, categories),
                        ),
                        const SizedBox(height: 2),
                        Flexible(
                          child: Text(
                            localizedCategoryName(context, c),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
      ],
    );
  }
}
