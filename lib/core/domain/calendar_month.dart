final class CalendarMonth implements Comparable<CalendarMonth> {
  CalendarMonth(this.year, this.month) {
    if (year < 1900 || year > 9999 || month < 1 || month > 12) {
      throw ArgumentError('月份不在支持范围内');
    }
  }

  factory CalendarMonth.fromDate(DateTime date) =>
      CalendarMonth(date.year, date.month);

  factory CalendarMonth.parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(value)) {
      throw const FormatException('月份应为 YYYY-MM');
    }
    return CalendarMonth(int.parse(value.substring(0, 4)),
        int.parse(value.substring(5, 7)));
  }

  final int year;
  final int month;

  int get days => DateTime.utc(year, month + 1, 0).day;
  String get key => '$year-${month.toString().padLeft(2, '0')}';
  DateTime get firstDay => DateTime.utc(year, month);
  DateTime get nextMonthStart => DateTime.utc(year, month + 1);

  @override
  int compareTo(CalendarMonth other) =>
      (year * 12 + month).compareTo(other.year * 12 + other.month);

  @override
  bool operator ==(Object other) =>
      other is CalendarMonth && year == other.year && month == other.month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// UTC is only a timezone-independent container for calendar components here.
/// It does not represent the actual instant of a purchase.
DateTime calendarDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

String calendarDayKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime parseCalendarDay(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('日期应为 YYYY-MM-DD');
  }
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  final parsed = DateTime.utc(year, month, day);
  if (year < 1900 || year > 9999 || calendarDayKey(parsed) != value) {
    throw const FormatException('日期无效');
  }
  return parsed;
}
