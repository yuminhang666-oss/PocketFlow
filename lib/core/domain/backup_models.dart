import 'ledger_entry.dart';
import 'ledger_models.dart';
import 'personal_profile.dart';

final class BackupDocument {
  BackupDocument({
    required this.exportedAtUtcMs,
    required Iterable<MonthlyBudget> budgets,
    required Iterable<Category> categories,
    required Iterable<LedgerEntry> entries,
    PersonalProfile? profile,
  }) : budgets = List.unmodifiable(budgets),
       categories = List.unmodifiable(categories),
       entries = List.unmodifiable(entries),
       profile = profile ?? PersonalProfile();
  static const appId = 'pocketflow';
  static const formatVersion = 2;
  static const currency = 'CNY';
  final int exportedAtUtcMs;
  final List<MonthlyBudget> budgets;
  final List<Category> categories;
  final List<LedgerEntry> entries;
  final PersonalProfile profile;
}

final class RestoreResult {
  const RestoreResult({
    required this.entryCount,
    required this.budgetCount,
    required this.categoryCount,
    required this.recoveryBackupId,
  });
  final int entryCount;
  final int budgetCount;
  final int categoryCount;

  /// Opaque local recovery reference; never upload automatically.
  final String recoveryBackupId;
}
