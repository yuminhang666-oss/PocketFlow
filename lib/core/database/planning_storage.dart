import 'dart:convert';
import 'package:drift/drift.dart';
import '../../contracts/contracts.dart';
import 'app_database.dart' show AppDatabase;

/// Caller holds the same read/write transaction as the ledger snapshot.
Future<PlanningData> readPlanning(AppDatabase db) async {
  try {
    final budgets = await db.select(db.planBudgets).get();
    final rules = await db.select(db.planRules).get();
    final versions = await db.select(db.planVersions).get();
    final decodedVersions = <RecurringVersion>[];
    for (final row in versions) {
      final value = RecurringVersion.fromJson(
        jsonDecode(row.payload) as Map<String, dynamic>,
      );
      if (value.id != row.id ||
          value.ruleId != row.ruleId ||
          value.categoryId != row.categoryId ||
          value.effectiveMonth.key != row.effectiveMonth) {
        throw const FormatException('规则存储版本不一致');
      }
      decodedVersions.add(value);
    }
    final occurrences = await db.select(db.planOccurrences).get();
    final settings = {
      for (final s in await db.select(db.planSettings).get())
        s.key: jsonDecode(s.payload),
    };
    return PlanningData(
      categoryBudgets: [
        for (final b in budgets)
          CategoryBudget(
            month: CalendarMonth.parse(b.month),
            categoryId: b.categoryId,
            amount: Money.fromFen(b.amountFen),
          ),
      ],
      rules: [
        for (final r in rules)
          RecurringRule(id: r.id, createdAtUtcMs: r.createdAtUtcMs),
      ],
      versions: decodedVersions,
      occurrences: [
        for (final o in occurrences)
          RecurringOccurrence(
            ruleId: o.ruleId,
            period: CalendarMonth.parse(o.periodKey),
            versionId: o.versionId,
            status: OccurrenceStatus.values.byName(o.status),
            entryId: o.entryId,
            actualLocalDate: o.entryId == null
                ? null
                : settings['actualDate:${o.ruleId}:${o.periodKey}'] as String?,
          ),
      ],
      settings: settings['settings'] == null
          ? const ReminderSettings()
          : ReminderSettings.fromJson(
              settings['settings'] as Map<String, dynamic>,
            ),
      catalogVersion: settings['catalog'] as int? ?? 0,
    );
  } catch (e) {
    throw PocketFlowException(PocketFlowErrorCode.dataCorrupted, cause: e);
  }
}

// User explicitly authorized v3 financial replacement after preview/confirmation.
// Operational device states and feedback rows are never touched by this helper.
Future<void> clearPlanning(AppDatabase db) async {
  await db.delete(db.planOccurrences).go();
  await db.delete(db.planVersions).go();
  await db.delete(db.planRules).go();
  await db.delete(db.planBudgets).go();
  await db.delete(db.planSettings).go();
}

Future<void> writePlanning(AppDatabase db, PlanningData data) async {
  await clearPlanning(db);
  for (final r in data.rules) {
    await db.customInsert(
      'INSERT INTO plan_rules(id,created_at_utc_ms) VALUES (?,?)',
      variables: [
        Variable.withString(r.id),
        Variable.withInt(r.createdAtUtcMs),
      ],
      updates: {db.planRules},
    );
  }
  for (final v in data.versions) {
    await db.customInsert(
      'INSERT INTO plan_versions(id,rule_id,category_id,effective_month,payload) VALUES (?,?,?,?,?)',
      variables: [
        Variable.withString(v.id),
        Variable.withString(v.ruleId),
        Variable.withString(v.categoryId),
        Variable.withString(v.effectiveMonth.key),
        Variable.withString(jsonEncode(v.toJson())),
      ],
      updates: {db.planVersions},
    );
  }
  for (final b in data.categoryBudgets) {
    await db.customInsert(
      'INSERT INTO plan_budgets(month,category_id,amount_fen) VALUES (?,?,?)',
      variables: [
        Variable.withString(b.month.key),
        Variable.withString(b.categoryId),
        Variable.withInt(b.amount.fen),
      ],
      updates: {db.planBudgets},
    );
  }
  for (final o in data.occurrences) {
    await db.customInsert(
      'INSERT INTO plan_occurrences(rule_id,period_key,version_id,status,entry_id) VALUES (?,?,?,?,?)',
      variables: [
        Variable.withString(o.ruleId),
        Variable.withString(o.period.key),
        Variable.withString(o.versionId),
        Variable.withString(o.status.name),
        Variable<String>(o.entryId),
      ],
      updates: {db.planOccurrences},
    );
    if (o.actualLocalDate != null) {
      await db.customInsert(
        'INSERT INTO plan_settings(key,payload) VALUES (?,?)',
        variables: [
          Variable.withString('actualDate:${o.key}'),
          Variable.withString(jsonEncode(o.actualLocalDate)),
        ],
        updates: {db.planSettings},
      );
    }
  }
  await db.customInsert(
    "INSERT INTO plan_settings(key,payload) VALUES ('settings',?)",
    variables: [Variable.withString(jsonEncode(data.settings.toJson()))],
    updates: {db.planSettings},
  );
  await db.customInsert(
    "INSERT INTO plan_settings(key,payload) VALUES ('catalog',?)",
    variables: [Variable.withString(jsonEncode(data.catalogVersion))],
    updates: {db.planSettings},
  );
}
