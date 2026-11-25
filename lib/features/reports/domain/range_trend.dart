import '../../../contracts/contracts.dart';
import '../../statistics/domain/report_arithmetic.dart';

enum RangeTrendScale { day, week, month }

typedef RangeTrendBucket = ({
  String start,
  String end,
  Money expense,
  Money income,
});

RangeTrendScale rangeTrendScale(int days) => switch (days) {
  <= 31 => RangeTrendScale.day,
  <= 120 => RangeTrendScale.week,
  _ => RangeTrendScale.month,
};

/// Align buckets to Monday or the first of the month, clipping the displayed
/// bounds to the selected interval. The input includes zero-activity days.
List<RangeTrendBucket> groupRangeTrend(
  List<DailyTotals> days,
  RangeTrendScale scale,
) {
  final buckets = <String, List<DailyTotals>>{};
  for (final day in days) {
    final date = parseCalendarDay(day.localDate);
    final bucket = switch (scale) {
      RangeTrendScale.day => date,
      RangeTrendScale.week => date.subtract(Duration(days: date.weekday - 1)),
      RangeTrendScale.month => DateTime.utc(date.year, date.month),
    };
    (buckets[calendarDayKey(bucket)] ??= []).add(day);
  }

  return [
    for (final bucket in buckets.values)
      (
        start: bucket.first.localDate,
        end: bucket.last.localDate,
        expense: Money.fromFen(sumReportFen(bucket.map((d) => d.expense.fen))),
        income: Money.fromFen(sumReportFen(bucket.map((d) => d.income.fen))),
      ),
  ];
}
