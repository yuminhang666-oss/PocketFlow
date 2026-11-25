import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../../core/domain/ledger_entry.dart';
import '../../core/domain/ledger_models.dart';
import '../../core/domain/money.dart';
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
  final custom = categories.where((c) => c.id == root).firstOrNull?.colorValue;
  if (custom != null) return Color(custom);
  const known = {
    'food': 0,
    'drinks': 1,
    'transport': 2,
    'shopping': 3,
    'living': 4,
    'study': 5,
    'digital': 6,
    'health': 7,
    'telecom': 8,
    'work': 9,
    'fun': 10,
    'sports': 11,
    'social': 12,
    'travel': 13,
    'other': 14,
    'research': 5,
    'tutoring': 9,
    'income_family': 4,
    'income_work': 2,
    'income_labor': 9,
    'income_scholarship': 1,
    'income_gift': 12,
    'income_interest': 8,
    'income_other': 14,
    'income_tutoring': 9,
    'income_campus': 9,
  };
  const palette = categoryPalette;
  final hash = root.codeUnits.fold<int>(0, (v, c) => (v * 31 + c) & 0x7fffffff);
  return palette[known[root] ?? hash % palette.length];
}

const categoryPalette = [
  Color(0xFFE77A2C),
  Color(0xFFB98624),
  Color(0xFF327BCB),
  Color(0xFFC46891),
  Color(0xFF338574),
  Color(0xFF7A64BB),
  Color(0xFF61708A),
  Color(0xFFCC6171),
  Color(0xFF348C9D),
  Color(0xFF596DB0),
  Color(0xFF9A6AB3),
  Color(0xFF7C914B),
  Color(0xFFB5707E),
  Color(0xFF3B9094),
  Color(0xFF7E8793),
];

Color identityColor(
  BuildContext context,
  String id,
  List<Category> categories,
) {
  final color = categoryColor(id, categories);
  return Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(color, Colors.white, .28)!
      : color;
}

Color flowColor(BuildContext context, EntryKind kind, {Money? amount}) {
  if (amount?.fen == 0) return Theme.of(context).colorScheme.onSurfaceVariant;
  final color = kind == EntryKind.income
      ? const Color(0xFFD74747)
      : const Color(0xFF168454);
  return Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(color, Colors.white, .28)!
      : color;
}

class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.categories,
    this.onTap,
    this.compact = false,
  });
  final LedgerEntry entry;
  final List<Category> categories;
  final VoidCallback? onTap;
  final bool compact;
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
        color: flowColor(context, entry.kind, amount: entry.amount),
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 8 : 12,
          horizontal: 2,
        ),
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
                color: identityColor(context, entry.categoryId, categories),
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
                    maxLines: compact ? 1 : 2,
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
