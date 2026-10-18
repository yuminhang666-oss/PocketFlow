import '../../../contracts/contracts.dart';
import '../../../core/domain/category_catalog.dart';
import 'report_arithmetic.dart';

final class DefaultLedgerQueryService implements LedgerQueryService {
  const DefaultLedgerQueryService();
  @override
  LedgerView filter(
    LedgerMonthData data,
    LedgerFilter filter, {
    required String asOfLocalDate,
  }) {
    parseCalendarDay(asOfLocalDate);
    final names = {for (final c in data.categories) c.id: c};
    final needle = filter.query.trim().toLowerCase();
    final selected =
        data.entries.where((e) {
          final c = names[e.categoryId];
          final text =
              '${e.note} ${c == null ? e.categoryId : categoryPath(c, data.categories)}'
                  .toLowerCase();
          return e.localDate.compareTo(asOfLocalDate) <= 0 &&
              (needle.isEmpty || text.contains(needle)) &&
              (filter.kind == null || e.kind == filter.kind) &&
              (filter.categoryId == null ||
                  e.categoryId == filter.categoryId ||
                  c?.parentId == filter.categoryId) &&
              (filter.fromDate == null ||
                  e.localDate.compareTo(filter.fromDate!) >= 0) &&
              (filter.toDate == null ||
                  e.localDate.compareTo(filter.toDate!) <= 0) &&
              (filter.minFen == null || e.amount.fen >= filter.minFen!) &&
              (filter.maxFen == null || e.amount.fen <= filter.maxFen!);
        }).toList()..sort((a, b) {
          final date = b.localDate.compareTo(a.localDate);
          if (date != 0) return date;
          final t = b.occurredAtUtcMs.compareTo(a.occurredAtUtcMs);
          return t != 0 ? t : a.id.compareTo(b.id);
        });
    var expense = BigInt.zero, income = BigInt.zero;
    final sums = <String, (BigInt, BigInt, int)>{};
    for (final e in selected) {
      final old = sums[e.localDate] ?? (BigInt.zero, BigInt.zero, 0);
      final amount = BigInt.from(e.amount.fen);
      if (e.kind == EntryKind.expense) {
        expense += amount;
        sums[e.localDate] = (old.$1 + amount, old.$2, old.$3 + 1);
      } else {
        income += amount;
        sums[e.localDate] = (old.$1, old.$2 + amount, old.$3 + 1);
      }
    }
    return LedgerView(
      entries: selected,
      expense: Money.fromFen(checkedReportInt(expense)),
      income: Money.fromFen(checkedReportInt(income)),
      days: {
        for (final d in sums.entries)
          d.key: DayTotals(
            expense: Money.fromFen(checkedReportInt(d.value.$1)),
            income: Money.fromFen(checkedReportInt(d.value.$2)),
            count: d.value.$3,
          ),
      },
    );
  }
}
