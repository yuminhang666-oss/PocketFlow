import '../../../contracts/contracts.dart';
import 'report_arithmetic.dart';

/// Derived values, not a second shared report or persisted budget model.
extension MonthlyReportInsights on MonthlyReport {
  int get expenseCount =>
      entries.where((e) => e.kind == EntryKind.expense).length;
  int get incomeCount =>
      entries.where((e) => e.kind == EntryKind.income).length;

  /// Calendar days including zero-spend days; rounded half up to the nearest fen.
  Money get averageDailyExpense {
    final days = BigInt.from(asOf.day);
    return Money.fromFen(
      checkedReportInt(
        (BigInt.from(totalExpense.fen) + days ~/ BigInt.two) ~/ days,
      ),
    );
  }

  Money get highestDailyExpense => Money.fromFen(
    daily.fold<int>(
      0,
      (peak, day) => day.amount.fen > peak ? day.amount.fen : peak,
    ),
  );

  List<DailyExpense> get highestExpenseDays {
    final peak = highestDailyExpense.fen;
    return List.unmodifiable(
      peak == 0
          ? <DailyExpense>[]
          : daily.where((day) => day.amount.fen == peak),
    );
  }

  String? get budgetUsagePercent =>
      reportPercent(totalExpense.fen, budget?.fen);

  String? categoryPercent(CategoryExpense category) =>
      reportPercent(category.amount.fen, totalExpense.fen);
}
