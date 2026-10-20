import 'contracts.dart';

abstract interface class PlanningPort {
  Stream<PlanningData> watchPlans();
  Stream<LedgerRangeData> watchRange(String start, String end);
  Future<void> clearBudget(CalendarMonth month);
  Future<void> saveCategoryBudget(CategoryBudget budget);
  Future<void> clearCategoryBudget(CalendarMonth month, String categoryId);
  Future<void> copyCategoryBudgets(CalendarMonth from, CalendarMonth to);
  Future<void> saveRuleVersion(RecurringVersion version);
  Future<LedgerEntry> confirm(
    PendingOccurrence occurrence, {
    required Money actualAmount,
  });
  Future<void> skip(PendingOccurrence occurrence);
  Future<void> reopen(String ruleId, CalendarMonth period);
  Future<void> undoCreate(LedgerEntry expected);
  Future<void> clearRecentCategory(EntryKind kind);
  Future<void> saveReminderSettings(ReminderSettings settings);
  Future<bool> reserveBudgetNotice(CalendarMonth month);
  Future<void> muteBudgetMonth(CalendarMonth month);
  Future<bool> reserveReport(String start, String end);
  Future<List<RecoveryPoint>> recoveryPoints();
  Future<BackupDocument> readRecoveryPoint(String id);
  Future<void> deleteRecoveryPoints(List<String> ids);
  Future<int?> lastExportUtcMs();
  Future<void> recordSuccessfulExport();
}

abstract interface class FeedbackPort {
  bool get configured;
  Future<FeedbackReceipt> submit(FeedbackDraft draft);
}

abstract interface class FeedbackDraftStore {
  Future<List<FeedbackDraft>> readDrafts();
  Future<void> saveDraft(FeedbackDraft draft);
}

/// Opens a user-controlled email composer. True means only that it opened;
/// this port cannot confirm sending, delivery or receipt.
abstract interface class FeedbackMailPort {
  Future<bool> openComposer(FeedbackDraft draft);
}
