import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/core/domain/backup_models.dart';
import 'package:pocketflow/core/domain/calendar_month.dart';
import 'package:pocketflow/core/domain/ledger_entry.dart';
import 'package:pocketflow/core/domain/ledger_models.dart';
import 'package:pocketflow/core/domain/money.dart';

LedgerEntry entry({
  String date = '2026-10-17',
  int amount = 1,
  String note = '',
  int created = 100,
  int updated = 100,
}) => LedgerEntry(
  id: 'test-entry',
  amount: Money.fromFen(amount),
  localDate: date,
  categoryId: 'food',
  occurredAtUtcMs: 100,
  createdAtUtcMs: created,
  updatedAtUtcMs: updated,
  note: note,
);

void main() {
  test('calendar rejects normalized invalid dates and unsupported years', () {
    for (final value in [
      '2026-04-31',
      '2026-00-01',
      '2026-01-00',
      '2026-2-01',
      '1899-12-31',
      '10000-01-01',
    ]) {
      expect(
        () => parseCalendarDay(value),
        throwsFormatException,
        reason: value,
      );
    }
    expect(calendarDayKey(parseCalendarDay('2000-02-29')), '2000-02-29');
    expect(calendarDayKey(parseCalendarDay('9999-12-31')), '9999-12-31');
  });

  test('calendar handles century leap rules and December rollover', () {
    expect(CalendarMonth(1900, 2).days, 28);
    expect(CalendarMonth(2000, 2).days, 29);
    expect(CalendarMonth(2100, 2).days, 28);
    expect(CalendarMonth(2026, 12).nextMonthStart, DateTime.utc(2027));
    expect(CalendarMonth(9999, 12).days, 31);
    expect(CalendarMonth.parse('2026-01').key, '2026-01');
    expect(() => CalendarMonth(1899, 12), throwsArgumentError);
    expect(() => CalendarMonth(2026, 13), throwsArgumentError);
  });

  test('local calendar components survive UTC container conversion', () {
    final local = DateTime(2026, 10, 17, 23, 59);
    expect(calendarDay(local), DateTime.utc(2026, 10, 17));
    expect(calendarDayKey(local), '2026-10-17');
  });

  test(
    'entry accepts boundaries and rejects invalid money and audit order',
    () {
      expect(entry(amount: Money.maxInputFen).amount.fen, Money.maxInputFen);
      for (final amount in [-1, 0, Money.maxInputFen + 1]) {
        expect(() => entry(amount: amount), throwsArgumentError);
      }
      expect(() => entry(created: 101, updated: 100), throwsArgumentError);
      expect(entry(note: List.filled(500, '中').join()).note.length, 500);
      expect(
        () => entry(note: List.filled(501, '中').join()),
        throwsArgumentError,
      );
      expect(entry(note: '午饭 | 换行\n<>&\\').note, '午饭 | 换行\n<>&\\');
    },
  );

  test('month snapshot copies collections and forbids later mutation', () {
    final entries = [entry()];
    final categories = [Category(id: 'food', name: '餐饮', sortOrder: 0)];
    final snapshot = LedgerMonthData(
      month: CalendarMonth(2026, 10),
      budget: null,
      entries: entries,
      categories: categories,
    );
    entries.clear();
    categories.clear();
    expect(snapshot.entries, hasLength(1));
    expect(snapshot.categories, hasLength(1));
    expect(() => snapshot.entries.clear(), throwsUnsupportedError);
    expect(() => snapshot.categories.clear(), throwsUnsupportedError);
  });

  test('month snapshot rejects mismatched budget or entry months', () {
    expect(
      () => LedgerMonthData(
        month: CalendarMonth(2026, 10),
        budget: MonthlyBudget(
          month: CalendarMonth(2026, 9),
          amount: const Money.fromFen(0),
          updatedAtUtcMs: 100,
        ),
        entries: const [],
        categories: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => LedgerMonthData(
        month: CalendarMonth(2026, 10),
        budget: null,
        entries: [entry(date: '2026-09-30')],
        categories: const [],
      ),
      throwsArgumentError,
    );
  });

  test('backup data is isolated from callers and preserves income', () {
    final entries = [
      LedgerEntry(
        id: 'income-test',
        amount: const Money.fromFen(100),
        localDate: '2026-10-17',
        categoryId: 'food',
        occurredAtUtcMs: 100,
        createdAtUtcMs: 100,
        updatedAtUtcMs: 100,
        kind: EntryKind.income,
      ),
    ];
    final document = BackupDocument(
      exportedAtUtcMs: 100,
      budgets: const [],
      categories: const [],
      entries: entries,
    );
    entries.clear();
    expect(document.entries.single.kind, EntryKind.income);
    expect(() => document.entries.clear(), throwsUnsupportedError);
    expect(() => document.budgets.clear(), throwsUnsupportedError);
    expect(() => document.categories.clear(), throwsUnsupportedError);
  });
}
