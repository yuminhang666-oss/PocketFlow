import 'package:flutter/material.dart';

import '../../../../core/domain/ledger_models.dart';
import '../../../../shared/widgets/entry_tile.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({super.key, required this.categories,
    required this.selectedId, required this.onSelected, this.enabled = true});

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
    final columns = constraints.maxWidth < 310 || largeText ? 2 : 4;
    final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final category in categories)
        SizedBox(width: width, child: Semantics(
          selected: selectedId == category.id,
          child: OutlinedButton(
            onPressed: enabled ? () => onSelected(category.id) : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 64),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              backgroundColor: selectedId == category.id
                  ? Theme.of(context).colorScheme.primaryContainer : null,
              side: BorderSide(color: selectedId == category.id
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(selectedId == category.id ? Icons.check_circle_outline_rounded
                  : categoryIcon(category.id), size: 22),
              const SizedBox(height: 6), Text(category.name, textAlign: TextAlign.center),
            ]),
          ),
        )),
    ]);
  });
}
