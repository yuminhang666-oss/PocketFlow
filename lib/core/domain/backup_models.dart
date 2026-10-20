import 'ledger_entry.dart';
import 'ledger_models.dart';
import 'personal_profile.dart';
import 'planning_models.dart';

final class BackupDocument {
  BackupDocument({
    required this.exportedAtUtcMs,
    required Iterable<MonthlyBudget> budgets,
    required Iterable<Category> categories,
    required Iterable<LedgerEntry> entries,
    PersonalProfile? profile,
    PlanningData? plans,
    this.sourceFormatVersion = 3,
  }) : budgets = List.unmodifiable(budgets),
       categories = List.unmodifiable(categories),
       entries = List.unmodifiable(entries),
       profile = profile ?? PersonalProfile(),
       plans = plans ?? PlanningData();
  static const appId = 'pocketflow';
  static const formatVersion = 3;
  static const currency = 'CNY';
  final int exportedAtUtcMs;
  final List<MonthlyBudget> budgets;
  final List<Category> categories;
  final List<LedgerEntry> entries;
  final PersonalProfile profile;
  final PlanningData plans;
  final int sourceFormatVersion;
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
