import '../core/domain/calendar_month.dart';
import '../core/domain/ledger_entry.dart';
import '../core/domain/ledger_models.dart';
import '../core/domain/money.dart';

abstract interface class LedgerRepository {
  Stream<LedgerMonthData> watchMonth(CalendarMonth month);
  Future<MonthlyBudget> saveBudget(CalendarMonth month, Money budget);
  Future<LedgerEntry> createExpense(EntryDraft draft);
  Future<LedgerEntry> updateExpense(String id, EntryDraft draft);
  Future<void> deleteEntry(String id);
}
