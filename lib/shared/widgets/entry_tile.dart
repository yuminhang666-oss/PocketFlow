import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../core/domain/ledger_entry.dart';
import '../../core/domain/ledger_models.dart';
import 'amount_text.dart';

String categoryRoot(String id, List<Category> all) {
  final c = all.where((c) => c.id == id).firstOrNull;
  if (c?.parentId != null) return c!.parentId!;
  const roots = [
    'income_scholarship',
    'income_tutoring',
    'income_interest',
    'income_family',
    'income_campus',
    'income_work',
    'income_gift',
    'income_other',
    'transport',
    'shopping',
    'research',
    'tutoring',
    'telecom',
    'living',
    'digital',
    'sports',
    'social',
    'travel',
    'health',
    'drinks',
    'study',
    'food',
    'fun',
    'other',
  ];
  return roots.where((r) => id == r || id.startsWith('${r}_')).firstOrNull ??
      id;
}

IconData categoryIcon(String id, [List<Category> categories = const []]) =>
    switch (categoryRoot(id, categories)) {
      'food' => Icons.restaurant_rounded,
      'drinks' => Icons.local_cafe_rounded,
      'shopping' => Icons.shopping_bag_outlined,
      'transport' => Icons.directions_transit_rounded,
      'study' => Icons.menu_book_rounded,
      'research' => Icons.science_outlined,
      'digital' => Icons.computer_rounded,
      'living' => Icons.home_work_outlined,
      'telecom' => Icons.phone_android_rounded,
      'tutoring' => Icons.school_outlined,
      'sports' => Icons.sports_basketball_outlined,
      'social' => Icons.card_giftcard_rounded,
      'travel' => Icons.luggage_outlined,
      'fun' => Icons.sports_esports_outlined,
      'health' => Icons.health_and_safety_outlined,
      'income_family' => Icons.account_balance_wallet_outlined,
      'work' => Icons.work_outline_rounded,
      'income_labor' => Icons.payments_outlined,
      'income_tutoring' => Icons.school_outlined,
      'income_scholarship' => Icons.workspace_premium_outlined,
      'income_campus' => Icons.apartment_rounded,
      'income_work' => Icons.work_outline_rounded,
      'income_gift' => Icons.redeem_outlined,
      'income_interest' => Icons.savings_outlined,
      _ => Icons.more_horiz_rounded,
    };
Color categoryColor(String id, [List<Category> categories = const []]) {
  final root = categoryRoot(id, categories);
  const known = {
    'food': 0,
    'drinks': 1,
    'shopping': 2,
    'transport': 3,
    'study': 4,
    'research': 5,
    'digital': 6,
    'living': 7,
    'telecom': 8,
    'tutoring': 9,
    'sports': 10,
    'fun': 11,
    'health': 12,
    'social': 13,
    'travel': 14,
    'other': 15,
    'income_family': 2,
    'income_tutoring': 4,
    'income_scholarship': 9,
    'income_campus': 3,
    'income_work': 6,
    'income_gift': 13,
    'income_interest': 8,
    'income_other': 15,
  };
  const palette = [
    Color(0xFFBF5700),
    Color(0xFF86621E),
    Color(0xFF7048E8),
    Color(0xFF1971C2),
    Color(0xFF3E63DD),
    Color(0xFF8E4EC6),
    Color(0xFF0C8599),
    Color(0xFF806342),
    Color(0xFF5372A8),
    Color(0xFF7659A4),
    Color(0xFF357E75),
    Color(0xFFD6336C),
    Color(0xFFB42335),
    Color(0xFFAA4D79),
    Color(0xFF397DA9),
    Color(0xFF60646C),
  ];
  final hash = root.codeUnits.fold<int>(0, (v, c) => (v * 31 + c) & 0x7fffffff);
  return palette[known[root] ?? hash % palette.length];
}

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
    final c = categories.where((c) => c.id == entry.categoryId).firstOrNull;
    final name = c == null
        ? tr(context, "未识别分类")
        : localizedCategoryPath(context, c, categories);
    final color = categoryColor(entry.categoryId, categories);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final narrow = MediaQuery.textScalerOf(context).scale(14) > 20;
    final amount = AmountText(
      entry.amount,
      prefix: entry.kind == EntryKind.expense ? '−¥' : '+¥',
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: entry.kind == EntryKind.income
            ? scheme.primary
            : scheme.onSurface,
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: dark ? 0.24 : 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                categoryIcon(entry.categoryId, categories),
                color: dark ? Color.lerp(color, Colors.white, .4) : color,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.note.isEmpty
                        ? (c == null
                              ? tr(context, "未识别分类")
                              : localizedCategoryName(context, c))
                        : entry.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (narrow) ...[const SizedBox(height: 6), amount],
                ],
              ),
            ),
            if (!narrow) ...[const SizedBox(width: 8), Flexible(child: amount)],
          ],
        ),
      ),
    );
  }
}
