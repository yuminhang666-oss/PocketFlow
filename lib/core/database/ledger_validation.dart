import '../../contracts/contracts.dart';

/// Shared by persisted-row mapping, repository writes, and restore validation.
/// This validates existing values; it never repairs or normalizes stored money.
void validateTimestamp(int value) {
  if (value < -8640000000000000 || value > 8640000000000000) {
    throw ArgumentError('Timestamp is outside the Dart DateTime range');
  }
}

void validateCategory(Category category) {
  if (category.id.isEmpty ||
      category.id.length > 64 ||
      category.name.isEmpty ||
      category.name.length > 30) {
    throw ArgumentError('Invalid category');
  }
}

void validateBudget(MonthlyBudget budget) {
  CalendarMonth.parse(budget.month.key);
  if (budget.amount.fen < 0 || budget.amount.fen > Money.maxInputFen) {
    throw ArgumentError('Invalid budget amount');
  }
  validateTimestamp(budget.updatedAtUtcMs);
}

void validateEntry(LedgerEntry entry) {
  if (entry.id.isEmpty ||
      entry.id.length > 64 ||
      entry.categoryId.isEmpty ||
      entry.categoryId.length > 64 ||
      entry.note.length > 500) {
    throw ArgumentError('Invalid entry fields');
  }
  parseCalendarDay(entry.localDate);
  if (entry.amount.fen <= 0 || entry.amount.fen > Money.maxInputFen) {
    throw ArgumentError('Invalid entry amount');
  }
  validateTimestamp(entry.occurredAtUtcMs);
  validateTimestamp(entry.createdAtUtcMs);
  validateTimestamp(entry.updatedAtUtcMs);
  if (entry.updatedAtUtcMs < entry.createdAtUtcMs) {
    throw ArgumentError('Invalid audit timestamps');
  }
}

void validateBackup(BackupDocument document) {
  validateTimestamp(document.exportedAtUtcMs);
  final categories = <String>{};
  final months = <String>{};
  final entries = <String>{};
  for (final category in document.categories) {
    validateCategory(category);
    if (!categories.add(category.id)) {
      throw ArgumentError('Duplicate category');
    }
  }
  for (final budget in document.budgets) {
    validateBudget(budget);
    if (!months.add(budget.month.key)) {
      throw ArgumentError('Duplicate budget month');
    }
  }
  for (final entry in document.entries) {
    validateEntry(entry);
    if (!entries.add(entry.id) || !categories.contains(entry.categoryId)) {
      throw ArgumentError('Duplicate entry or missing category');
    }
  }
}

PocketFlowException storageException(Object error) =>
    error is PocketFlowException
    ? error
    : PocketFlowException(PocketFlowErrorCode.storageFailure, cause: error);
