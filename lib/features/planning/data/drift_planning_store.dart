import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../contracts/contracts.dart';
import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/database/ledger_reader.dart';
import '../../../core/database/planning_storage.dart';
import '../../../core/domain/category_catalog.dart';
import '../../transactions/data/drift_ledger_repository.dart';
import '../../transactions/data/drift_backup_store.dart';
import '../../transactions/data/recovery_codec.dart';
import '../../reminders/domain/budget_notice_policy.dart';
import '../../reports/domain/range_report_service.dart';

class DriftPlanningStore implements PlanningPort {
  DriftPlanningStore(this.db, {this.clock = const SystemClock()});
  final AppDatabase db;
  final Clock clock;
  LedgerReader get reader => LedgerReader(db);
  Future<T> _tx<T>(Future<T> Function() action) async {
    try {
      return await db.transaction(action);
    } catch (e) {
      if (e is PocketFlowException) rethrow;
      throw PocketFlowException(PocketFlowErrorCode.storageFailure, cause: e);
    }
  }

  @override
  Stream<PlanningData> watchPlans() => db
      .customSelect(
        'SELECT key,payload FROM plan_settings',
        readsFrom: {
          db.planSettings,
          db.planRules,
          db.planVersions,
          db.planOccurrences,
          db.planBudgets,
        },
      )
      .watch()
      .asyncMap((_) => _tx(() => readPlanning(db)));
  @override
  Stream<LedgerRangeData> watchRange(String start, String end) =>
      reader.watchRange(start, end);
  @override
  Future<void> clearBudget(CalendarMonth month) => _tx(() async {
    await db.customUpdate(
      'DELETE FROM monthly_budgets WHERE month=?',
      variables: [Variable.withString(month.key)],
      updates: {db.monthlyBudgets},
    );
  });
  @override
  Future<void> saveCategoryBudget(CategoryBudget budget) => _tx(() async {
    final all = await reader.readAll(clock.now().millisecondsSinceEpoch);
    final c = all.categories
        .where((c) => c.id == budget.categoryId)
        .firstOrNull;
    if (c == null ||
        c.parentId != null ||
        c.kind == EntryKind.income ||
        c.isArchived) {
      throw const PocketFlowException(PocketFlowErrorCode.invalidCategory);
    }
    await db.customInsert(
      'INSERT INTO plan_budgets(month,category_id,amount_fen) VALUES (?,?,?) ON CONFLICT(month,category_id) DO UPDATE SET amount_fen=excluded.amount_fen',
      variables: [
        Variable.withString(budget.month.key),
        Variable.withString(c.id),
        Variable.withInt(budget.amount.fen),
      ],
      updates: {db.planBudgets},
    );
  });
  @override
  Future<void> clearCategoryBudget(CalendarMonth month, String categoryId) =>
      _tx(() async {
        await db.customUpdate(
          'DELETE FROM plan_budgets WHERE month=? AND category_id=?',
          variables: [
            Variable.withString(month.key),
            Variable.withString(categoryId),
          ],
          updates: {db.planBudgets},
        );
      });
  @override
  Future<void> copyCategoryBudgets(CalendarMonth from, CalendarMonth to) => _tx(
    () async {
      final all = await reader.readAll(clock.now().millisecondsSinceEpoch);
      for (final b in all.plans.categoryBudgets.where((b) => b.month == from)) {
        final c = all.categories.where((c) => c.id == b.categoryId).firstOrNull;
        if (c != null &&
            !c.isArchived &&
            c.parentId == null &&
            c.kind != EntryKind.income) {
          await saveCategoryBudget(
            CategoryBudget(month: to, categoryId: c.id, amount: b.amount),
          );
        }
      }
    },
  );
  @override
  Future<void> saveRuleVersion(RecurringVersion v) => _tx(() async {
    final all = await reader.readAll(clock.now().millisecondsSinceEpoch),
        p = all.plans;
    final existing = p.versions.where((x) => x.id == v.id).firstOrNull;
    if (existing != null) {
      if (jsonEncode(existing.toJson()) == jsonEncode(v.toJson())) return;
      throw const PocketFlowException(PocketFlowErrorCode.conflict);
    }
    if (v.effectiveMonth.compareTo(CalendarMonth.fromDate(clock.now())) < 0 ||
        p.occurrences.any(
          (o) =>
              o.ruleId == v.ruleId && o.period.compareTo(v.effectiveMonth) >= 0,
        ) ||
        p.versions.any(
          (x) => x.ruleId == v.ruleId && x.effectiveMonth == v.effectiveMonth,
        )) {
      throw const PocketFlowException(PocketFlowErrorCode.conflict);
    }
    final c = all.categories.where((c) => c.id == v.categoryId).firstOrNull;
    if (c == null ||
        (!v.archived &&
            v.enabled &&
            !categoryAvailable(c, all.categories, v.kind)) ||
        !c.accepts(v.kind)) {
      throw const PocketFlowException(PocketFlowErrorCode.invalidCategory);
    }
    await db.customInsert(
      'INSERT OR IGNORE INTO plan_rules(id,created_at_utc_ms) VALUES (?,?)',
      variables: [
        Variable.withString(v.ruleId),
        Variable.withInt(clock.now().millisecondsSinceEpoch),
      ],
      updates: {db.planRules},
    );
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
  });
  Future<RecurringVersion> _pending(PendingOccurrence o) async {
    final p = await readPlanning(db),
        v = p.versionFor(o.version.ruleId, o.period);
    if (v == null || v.id != o.version.id || !v.applies(o.period)) {
      throw const PocketFlowException(PocketFlowErrorCode.conflict);
    }
    return v;
  }

  @override
  Future<LedgerEntry> confirm(
    PendingOccurrence o, {
    required Money actualAmount,
  }) => _tx(() async {
    final v = await _pending(o), p = await readPlanning(db);
    final done = p.occurrences
        .where((x) => x.ruleId == v.ruleId && x.period == o.period)
        .firstOrNull;
    if (done != null) {
      if (done.status == OccurrenceStatus.settled) {
        final all = await reader.readAll(clock.now().millisecondsSinceEpoch);
        return all.entries.firstWhere((e) => e.id == done.entryId);
      }
      throw const PocketFlowException(PocketFlowErrorCode.conflict);
    }
    final date = v.dueDate(o.period);
    if (date.compareTo(calendarDayKey(clock.now())) > 0) {
      throw const PocketFlowException(PocketFlowErrorCode.invalidDate);
    }
    final day = parseCalendarDay(date),
        repo = DriftLedgerRepository(db, clock: clock);
    final draft = EntryDraft(
      amount: actualAmount,
      localDate: date,
      occurredAtUtcMs: DateTime(
        day.year,
        day.month,
        day.day,
        12,
      ).millisecondsSinceEpoch,
      categoryId: v.categoryId,
      note: v.note,
    );
    final entry = v.kind == EntryKind.income
        ? await repo.createIncome(draft)
        : await repo.createExpense(draft);
    await _insertOccurrence(v, o.period, OccurrenceStatus.settled, entry.id);
    return entry;
  });
  Future<void> _insertOccurrence(
    RecurringVersion v,
    CalendarMonth period,
    OccurrenceStatus status,
    String? entryId,
  ) => db
      .customInsert(
        'INSERT INTO plan_occurrences(rule_id,period_key,version_id,status,entry_id) VALUES (?,?,?,?,?)',
        variables: [
          Variable.withString(v.ruleId),
          Variable.withString(period.key),
          Variable.withString(v.id),
          Variable.withString(status.name),
          Variable<String>(entryId),
        ],
        updates: {db.planOccurrences},
      )
      .then((_) {});
  @override
  Future<void> skip(PendingOccurrence o) => _tx(() async {
    final v = await _pending(o), p = await readPlanning(db);
    final existing = p.occurrences
        .where((x) => x.ruleId == v.ruleId && x.period == o.period)
        .firstOrNull;
    if (existing != null) {
      if (existing.status == OccurrenceStatus.skipped) return;
      throw const PocketFlowException(PocketFlowErrorCode.conflict);
    }
    await _insertOccurrence(v, o.period, OccurrenceStatus.skipped, null);
  });
  @override
  Future<void> reopen(String ruleId, CalendarMonth period) => _tx(() async {
    final changed = await db.customUpdate(
      "DELETE FROM plan_occurrences WHERE rule_id=? AND period_key=? AND status='skipped' AND entry_id IS NULL",
      variables: [Variable.withString(ruleId), Variable.withString(period.key)],
      updates: {db.planOccurrences},
    );
    if (changed != 1) {
      throw const PocketFlowException(PocketFlowErrorCode.conflict);
    }
  });
  @override
  Future<void> undoCreate(LedgerEntry expected) => _tx(() async {
    final changed = await db.customUpdate(
      'DELETE FROM ledger_entries WHERE id=? AND created_at_utc_ms=? AND updated_at_utc_ms=? AND NOT EXISTS (SELECT 1 FROM plan_occurrences WHERE entry_id=ledger_entries.id)',
      variables: [
        Variable.withString(expected.id),
        Variable.withInt(expected.createdAtUtcMs),
        Variable.withInt(expected.updatedAtUtcMs),
      ],
      updates: {db.ledgerEntries},
    );
    if (changed != 1) {
      throw const PocketFlowException(PocketFlowErrorCode.conflict);
    }
  });
  @override
  Future<void> clearRecentCategory(EntryKind kind) => _tx(() async {
    final all = await reader.readAll(clock.now().millisecondsSinceEpoch);
    final profile = all.profile.copyWith(
      clearExpenseCategory: kind == EntryKind.expense,
      clearIncomeCategory: kind == EntryKind.income,
    );
    await db.customInsert(
      "INSERT INTO personal_state(key,value_json) VALUES ('profile',?) ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json",
      variables: [Variable.withString(jsonEncode(profile.toJson()))],
      updates: {db.personalState},
    );
  });
  @override
  Future<void> saveReminderSettings(ReminderSettings settings) => _tx(() async {
    await db.customInsert(
      "INSERT INTO plan_settings(key,payload) VALUES ('settings',?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload",
      variables: [Variable.withString(jsonEncode(settings.toJson()))],
      updates: {db.planSettings},
    );
  });
  Future<Map<String, dynamic>> _state(String key) async {
    final r = await db
        .customSelect(
          'SELECT payload FROM device_states WHERE key=?',
          variables: [Variable.withString(key)],
        )
        .getSingleOrNull();
    return r == null
        ? <String, dynamic>{}
        : jsonDecode(r.read<String>('payload')) as Map<String, dynamic>;
  }

  Future<void> _saveState(String key, Map<String, dynamic> value) => db
      .customInsert(
        'INSERT INTO device_states(key,payload) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload',
        variables: [
          Variable.withString(key),
          Variable.withString(jsonEncode(value)),
        ],
        updates: {db.deviceStates},
      )
      .then((_) {});
  @override
  Future<bool> reserveBudgetNotice(CalendarMonth month) => _tx(() async {
    final now = clock.now(),
        all = await reader.readAll(now.millisecondsSinceEpoch),
        p = all.plans;
    if (!p.settings.budget) return false;
    final budget = all.budgets
        .where((b) => b.month == month)
        .firstOrNull
        ?.amount;
    final spent = all.entries
        .where(
          (e) =>
              e.kind == EntryKind.expense &&
              CalendarMonth.fromDate(e.date) == month &&
              e.localDate.compareTo(calendarDayKey(now)) <= 0,
        )
        .fold<int>(0, (a, b) => a + b.amount.fen);
    const policy = BudgetNoticePolicy();
    if (policy.qualify(
          month: month,
          now: now,
          budget: budget,
          spentFen: spent,
        ) ==
        null) {
      return false;
    }
    final key = 'budget:${month.key}',
        state = await _state(key),
        count = state['count'] as int? ?? 0;
    if (!policy.canReserve(
      now: now,
      budgetFen: budget!.fen,
      spentFen: spent,
      count: count,
      lastDate: state['lastDate'] as String?,
      lastUtcMs: state['lastUtcMs'] as int?,
      lastSpentFen: state['spent'] as int? ?? 0,
      muted: state['muted'] as bool? ?? false,
    )) {
      return false;
    }
    await _saveState(key, {
      'count': count + 1,
      'lastDate': calendarDayKey(now),
      'lastUtcMs': now.millisecondsSinceEpoch,
      'spent': spent,
      'policyVersion': BudgetNoticePolicy.version,
      'muted': false,
    });
    return true;
  });
  @override
  Future<void> muteBudgetMonth(CalendarMonth month) => _tx(() async {
    final key = 'budget:${month.key}', state = await _state(key);
    state['muted'] = true;
    await _saveState(key, state);
  });
  @override
  Future<bool> reserveReport(String start, String end) => _tx(() async {
    final p = await readPlanning(db),
        eligible = const RangeReportService().latestWeeklyRange(clock.now());
    if (!p.settings.weekly ||
        eligible == null ||
        eligible.$1 != start ||
        eligible.$2 != end) {
      return false;
    }
    final key = 'weekly:$start:$end';
    if ((await _state(key))['shown'] == true) return false;
    if ((await reader.readRange(start, end)).entries.isEmpty) return false;
    await _saveState(key, {
      'shown': true,
      'atUtcMs': clock.now().millisecondsSinceEpoch,
    });
    return true;
  });
  @override
  Future<List<RecoveryPoint>> recoveryPoints() => _tx(() async {
    final rows =
        await (db.select(db.recoverySnapshots)..orderBy([
              (t) => OrderingTerm.desc(t.createdAtUtcMs),
              (t) => OrderingTerm.desc(t.id),
            ]))
            .get();
    return [for (final r in rows) _point(r.id, r.createdAtUtcMs, r.payload)];
  });
  RecoveryPoint _point(String id, int at, String payload) {
    try {
      final raw = jsonDecode(payload) as Map<String, dynamic>,
          doc = const RecoveryCodec().decode(payload);
      return RecoveryPoint(
        id: id,
        createdAtUtcMs: at,
        entries: doc.entries.length,
        encodingVersion: raw['recoveryVersion'] as int,
      );
    } catch (_) {
      return RecoveryPoint(id: id, createdAtUtcMs: at, corrupted: true);
    }
  }

  @override
  Future<BackupDocument> readRecoveryPoint(String id) =>
      DriftBackupStore(db, clock: clock).readRecovery(id);
  @override
  Future<void> deleteRecoveryPoints(List<String> ids) => _tx(() async {
    for (final id in ids) {
      await db.customUpdate(
        'DELETE FROM recovery_snapshots WHERE id=?',
        variables: [Variable.withString(id)],
        updates: {db.recoverySnapshots},
      );
    }
  });
  @override
  Future<int?> lastExportUtcMs() async =>
      (await _state('last-export'))['atUtcMs'] as int?;
  @override
  Future<void> recordSuccessfulExport() => _tx(
    () => _saveState('last-export', {
      'atUtcMs': clock.now().millisecondsSinceEpoch,
    }),
  );
}
