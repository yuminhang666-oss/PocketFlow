import '../../../contracts/contracts.dart';
import 'report_arithmetic.dart';

/// C-owned presentation projection. Amounts remain integer fen until painting.
final class DailyChartPoint {
  const DailyChartPoint({required this.day, required this.expense,
    required this.remaining, required this.referenceRemaining});
  final int day;
  /// Null after cutoff, rather than a misleading zero-spend actual observation.
  final Money? expense;
  final Money? remaining;
  final Money? referenceRemaining;
}

List<DailyChartPoint> monthlyChartData(MonthlyReport report) {
  final daily = {for (final d in report.daily) d.date.day: d.amount};
  var spent = BigInt.zero;
  final budget = report.budget;
  final days = BigInt.from(report.month.days);
  return List.unmodifiable([
    for (var day = 1; day <= report.month.days; day++)
      (() {
        final expense = day <= report.asOf.day ? daily[day] : null;
        if (expense != null) spent += BigInt.from(expense.fen);
        return DailyChartPoint(
          day: day,
          expense: expense,
          remaining: expense == null || budget == null ? null :
              Money.fromFen(checkedReportInt(BigInt.from(budget.fen) - spent)),
          referenceRemaining: budget == null ? null : Money.fromFen(
              checkedReportInt(BigInt.from(budget.fen) -
                  BigInt.from(budget.fen) * BigInt.from(day) ~/ days)),
        );
      })(),
  ]);
}
