import 'package:flutter/material.dart';

import '../../core/domain/ledger_entry.dart';
import '../../core/domain/ledger_models.dart';
import 'amount_text.dart';

IconData categoryIcon(String id) => switch (id) {
  'food' => Icons.restaurant_rounded,
  'drinks' => Icons.local_cafe_rounded,
  'shopping' => Icons.shopping_bag_outlined,
  'transport' => Icons.directions_transit_rounded,
  'study' => Icons.menu_book_rounded,
  'fun' => Icons.sports_esports_outlined,
  'health' => Icons.health_and_safety_outlined,
  _ => Icons.more_horiz_rounded,
};

class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.categories,
    this.onTap,
  });
  final LedgerEntry entry;
  final List<Category> categories;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final matches = categories.where((c) => c.id == entry.categoryId);
    final category = matches.isEmpty ? '未识别分类' : matches.first.name;
    final title = entry.note.isEmpty ? category : entry.note;
    final amount = AmountText(
      entry.amount,
      prefix: entry.kind == EntryKind.expense ? '−¥' : '+¥',
      style: Theme.of(context).textTheme.titleMedium,
    );
    final narrow =
        MediaQuery.textScalerOf(context).scale(16) > 22 ||
        MediaQuery.sizeOf(context).width < 350;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                categoryIcon(entry.categoryId),
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$category · ${entry.localDate}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  if (narrow) ...[const SizedBox(height: 8), amount],
                ],
              ),
            ),
            if (!narrow) ...[
              const SizedBox(width: 12),
              Flexible(child: amount),
            ],
          ],
        ),
      ),
    );
  }
}
