import '../core/domain/calendar_month.dart';
import '../core/domain/ledger_entry.dart';
import '../core/domain/ledger_models.dart';
import '../core/domain/money.dart';
import '../core/domain/personal_profile.dart';

abstract interface class LedgerRepository {
  Stream<LedgerMonthData> watchMonth(CalendarMonth month);
  Future<MonthlyBudget> saveBudget(CalendarMonth month, Money budget);
  Future<LedgerEntry> createExpense(EntryDraft draft);
  Future<LedgerEntry> updateExpense(String id, EntryDraft draft);
  Future<LedgerEntry> createIncome(EntryDraft draft);
  Future<LedgerEntry> updateIncome(String id, EntryDraft draft);
  Future<void> saveCategory(Category category);
  Future<void> reorderCategories(List<String> ids);
  Future<void> addRecommendedCategories();
  Future<void> savePreferences({String? theme, bool? feedback});
  Future<void> saveGoal(SavingsGoal goal);
  Future<void> deleteGoal(String id);
  Future<void> saveTemplate(EntryTemplate template);
  Future<void> deleteTemplate(String id);
  Future<void> markZeroExpenseDay(String localDate, bool value);
  Future<void> deleteEntry(String id);
}
