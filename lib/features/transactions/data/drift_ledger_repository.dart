import 'package:drift/drift.dart';
import 'dart:convert';

import '../../../contracts/contracts.dart';
import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/database/ledger_reader.dart';
import '../../../core/database/ledger_validation.dart';
import '../../../core/domain/category_catalog.dart';
import 'entry_id.dart';

class DriftLedgerRepository implements LedgerRepository {
  DriftLedgerRepository(
    this.database, {
    this._clock = const SystemClock(),
    String Function()? idGenerator,
  }) : _newId = idGenerator ?? newEntryId,
       _reader = LedgerReader(database);

  final AppDatabase database;
  final Clock _clock;
  final String Function() _newId;
  final LedgerReader _reader;

  @override
  Stream<LedgerMonthData> watchMonth(CalendarMonth month) =>
      _reader.watchMonth(month);

  @override
  Future<MonthlyBudget> saveBudget(CalendarMonth month, Money budget) =>
      _guard(() async {
        if (budget.fen < 0 || budget.fen > Money.maxInputFen) {
          throw const PocketFlowException(PocketFlowErrorCode.invalidAmount);
        }
        final now = _clock.now().millisecondsSinceEpoch;
        validateTimestamp(now);
        return database.transaction(() async {
          await database.customInsert(
            'INSERT INTO monthly_budgets(month, amount_fen, updated_at_utc_ms) '
            'VALUES (?, ?, ?) ON CONFLICT(month) DO UPDATE SET '
            'amount_fen = excluded.amount_fen, '
            'updated_at_utc_ms = MAX(monthly_budgets.updated_at_utc_ms, '
            'excluded.updated_at_utc_ms)',
            variables: [
              Variable.withString(month.key),
              Variable.withInt(budget.fen),
              Variable.withInt(now),
            ],
            updates: {database.monthlyBudgets},
          );
          final row = await database
              .customSelect(
                'SELECT * FROM monthly_budgets WHERE month = ?',
                variables: [Variable.withString(month.key)],
              )
              .getSingle();
          return MonthlyBudget(
            month: month,
            amount: Money.fromFen(readStoredInt(row, 'amount_fen')),
            updatedAtUtcMs: readStoredInt(row, 'updated_at_utc_ms'),
          );
        });
      });

  @override
  Future<LedgerEntry> createExpense(EntryDraft draft) =>
      _create(draft, EntryKind.expense);

  @override
  Future<LedgerEntry> createIncome(EntryDraft draft) =>
      _create(draft, EntryKind.income);

  Future<LedgerEntry> _create(EntryDraft draft, EntryKind kind) =>
      _guard(() async {
        final now = _clock.now();
        _validateDraft(draft, now);
        return database.transaction(() async {
          await _requireCategory(draft.categoryId, kind: kind);
          final entry = LedgerEntry(
            id: _newId(),
            kind: kind,
            amount: draft.amount,
            localDate: draft.localDate,
            categoryId: draft.categoryId,
            note: draft.note,
            occurredAtUtcMs: draft.occurredAtUtcMs,
            createdAtUtcMs: now.millisecondsSinceEpoch,
            updatedAtUtcMs: now.millisecondsSinceEpoch,
          );
          validateEntry(entry);
          await insertEntry(database, entry);
          final profile = await _readProfile();
          await _writeProfile(
            profile.copyWith(
              lastExpenseCategoryId: kind == EntryKind.expense
                  ? draft.categoryId
                  : null,
              lastIncomeCategoryId: kind == EntryKind.income
                  ? draft.categoryId
                  : null,
              zeroExpenseDays: kind == EntryKind.expense
                  ? profile.zeroExpenseDays.where((d) => d != draft.localDate)
                  : null,
            ),
          );
          return entry;
        });
      });

  @override
  Future<LedgerEntry> updateExpense(String id, EntryDraft draft) =>
      _update(id, draft, EntryKind.expense);

  @override
  Future<LedgerEntry> updateIncome(String id, EntryDraft draft) =>
      _update(id, draft, EntryKind.income);

  Future<LedgerEntry> _update(String id, EntryDraft draft, EntryKind kind) =>
      _guard(() async {
        final now = _clock.now();
        _validateDraft(draft, now);
        return database.transaction(() async {
          final row = await database
              .customSelect(
                'SELECT * FROM ledger_entries WHERE id = ? AND kind = ?',
                variables: [
                  Variable.withString(id),
                  Variable.withString(kind.name),
                ],
              )
              .getSingleOrNull();
          if (row == null) {
            throw const PocketFlowException(PocketFlowErrorCode.notFound);
          }
          final old = decodeEntryRow(row);
          await _requireCategory(
            draft.categoryId,
            kind: kind,
            allowArchived: old.categoryId == draft.categoryId,
          );
          final nowMs = now.millisecondsSinceEpoch;
          final updated = nowMs <= old.updatedAtUtcMs
              ? old.updatedAtUtcMs + 1
              : nowMs;
          final entry = LedgerEntry(
            id: old.id,
            amount: draft.amount,
            localDate: draft.localDate,
            categoryId: draft.categoryId,
            kind: old.kind,
            note: draft.note,
            occurredAtUtcMs: draft.occurredAtUtcMs,
            createdAtUtcMs: old.createdAtUtcMs,
            updatedAtUtcMs: updated,
          );
          validateEntry(entry);
          final linked = await database
              .customSelect(
                'SELECT entry_id FROM plan_occurrences WHERE entry_id=?',
                variables: [Variable.withString(id)],
              )
              .get();
          if (linked.isNotEmpty &&
              (entry.categoryId != old.categoryId ||
                  entry.localDate != old.localDate)) {
            throw const PocketFlowException(PocketFlowErrorCode.conflict);
          }
          final changed = await database.customUpdate(
            'UPDATE ledger_entries SET amount_fen = ?, occurred_local = ?, '
            'occurred_at_utc_ms = ?, category_id = ?, note = ?, '
            'updated_at_utc_ms = ? WHERE id = ?',
            variables: [
              Variable.withInt(entry.amount.fen),
              Variable.withString(entry.localDate),
              Variable.withInt(entry.occurredAtUtcMs),
              Variable.withString(entry.categoryId),
              Variable.withString(entry.note),
              Variable.withInt(entry.updatedAtUtcMs),
              Variable.withString(entry.id),
            ],
            updates: {database.ledgerEntries},
          );
          if (changed != 1) {
            throw const PocketFlowException(PocketFlowErrorCode.notFound);
          }
          if (kind == EntryKind.expense) {
            final profile = await _readProfile();
            await _writeProfile(
              profile.copyWith(
                zeroExpenseDays: profile.zeroExpenseDays.where(
                  (d) => d != draft.localDate,
                ),
              ),
            );
          }
          return entry;
        });
      });

  @override
  Future<void> deleteEntry(String id) => _guard(
    () => database.transaction(() async {
      await database.customUpdate(
        "UPDATE plan_occurrences SET status='skipped',entry_id=NULL WHERE entry_id=?",
        variables: [Variable.withString(id)],
        updates: {database.planOccurrences},
      );
      final changed = await database.customUpdate(
        'DELETE FROM ledger_entries WHERE id = ?',
        variables: [Variable.withString(id)],
        updates: {database.ledgerEntries},
        updateKind: UpdateKind.delete,
      );
      if (changed != 1) {
        throw const PocketFlowException(PocketFlowErrorCode.notFound);
      }
    }),
  );

  Future<void> _requireCategory(
    String id, {
    EntryKind? kind,
    bool allowArchived = false,
    int depth = 0,
  }) async {
    if (depth > 1) {
      throw const PocketFlowException(PocketFlowErrorCode.dataCorrupted);
    }
    final row = await database
        .customSelect(
          'SELECT is_archived, category_kind, parent_id FROM categories WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (row == null ||
        (!allowArchived && readStoredInt(row, 'is_archived') == 1)) {
      throw const PocketFlowException(PocketFlowErrorCode.invalidCategory);
    }
    if (readStoredInt(row, 'is_archived') != 0 &&
        readStoredInt(row, 'is_archived') != 1) {
      throw const PocketFlowException(PocketFlowErrorCode.dataCorrupted);
    }
    final storedKind = row.data['category_kind'];
    if (storedKind != null &&
        storedKind != 'expense' &&
        storedKind != 'income') {
      throw const PocketFlowException(PocketFlowErrorCode.dataCorrupted);
    }
    if (!allowArchived &&
        kind != null &&
        storedKind != null &&
        storedKind != kind.name) {
      throw const PocketFlowException(PocketFlowErrorCode.invalidCategory);
    }
    if (!allowArchived && row.data['parent_id'] != null) {
      await _requireCategory(
        row.read<String>('parent_id'),
        kind: kind,
        depth: depth + 1,
      );
    }
  }

  @override
  Future<void> addRecommendedCategories() => _guard(
    () => database.transaction(() async {
      await database.addDefaultCategories();
      await database.markCatalogSupplemented();
    }),
  );

  @override
  Future<void> saveCategory(Category category) => _guard(
    () => database.transaction(() async {
      validateCategory(category);
      final data = await _reader.readAll(_clock.now().millisecondsSinceEpoch);
      validateCategoryGraph([
        ...data.categories.where((c) => c.id != category.id),
        category,
      ]);
      final old = data.categories.where((c) => c.id == category.id).firstOrNull;
      if (old != null &&
          (old.kind != category.kind || old.parentId != category.parentId)) {
        throw const PocketFlowException(PocketFlowErrorCode.invalidCategory);
      }
      await database.customInsert(
        'INSERT INTO categories '
        '(id,name,sort_order,is_archived,category_kind,parent_id) VALUES (?,?,?,?,?,?) '
        'ON CONFLICT(id) DO UPDATE SET name=excluded.name, sort_order=excluded.sort_order, is_archived=excluded.is_archived',
        variables: [
          Variable.withString(category.id),
          Variable.withString(category.name),
          Variable.withInt(category.sortOrder),
          Variable.withInt(category.isArchived ? 1 : 0),
          Variable<String>(category.kind?.name),
          Variable<String>(category.parentId),
        ],
        updates: {database.categories},
      );
      if (category.parentId == null && category.colorValue != null) {
        await _writeProfile(
          data.profile.copyWith(
            categoryColors: {
              ...data.profile.categoryColors,
              category.id: category.colorValue!,
            },
          ),
        );
      }
    }),
  );

  Future<PersonalProfile> _readProfile() async {
    final row = await database
        .customSelect(
          "SELECT value_json FROM personal_state WHERE key='profile'",
        )
        .getSingleOrNull();
    return row == null
        ? PersonalProfile()
        : PersonalProfile.fromJson(
            jsonDecode(row.read<String>('value_json')) as Map<String, dynamic>,
          );
  }

  @override
  Future<void> reorderCategories(List<String> ids) => _guard(
    () => database.transaction(() async {
      if (ids.toSet().length != ids.length) {
        throw const PocketFlowException(PocketFlowErrorCode.invalidCategory);
      }
      for (var i = 0; i < ids.length; i++) {
        final changed = await database.customUpdate(
          'UPDATE categories SET sort_order=? WHERE id=?',
          variables: [Variable.withInt(i * 10), Variable.withString(ids[i])],
          updates: {database.categories},
        );
        if (changed != 1) {
          throw const PocketFlowException(PocketFlowErrorCode.notFound);
        }
      }
    }),
  );

  Future<void> _writeProfile(PersonalProfile profile) async {
    await database.customInsert(
      "INSERT INTO personal_state(key,value_json) VALUES ('profile',?) "
      'ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json',
      variables: [Variable.withString(jsonEncode(profile.toJson()))],
      updates: {database.personalState},
    );
  }

  Future<void> _changeProfile(
    PersonalProfile Function(PersonalProfile) change,
  ) => _guard(
    () => database.transaction(() async {
      await _writeProfile(change(await _readProfile()));
    }),
  );

  @override
  Future<void> savePreferences({
    String? theme,
    String? surfaceStyle,
    String? locale,
    bool? feedback,
  }) => _changeProfile(
    (p) => p.copyWith(
      theme: theme,
      surfaceStyle: surfaceStyle,
      locale: locale,
      feedback: feedback,
    ),
  );
  @override
  Future<void> saveGoal(SavingsGoal goal) => _changeProfile(
    (p) => p.copyWith(
      goals: p.goals.any((g) => g.id == goal.id)
          ? p.goals.map((g) => g.id == goal.id ? goal : g)
          : [...p.goals, goal],
    ),
  );
  @override
  Future<void> deleteGoal(String id) => _changeProfile(
    (p) => p.copyWith(goals: p.goals.where((g) => g.id != id)),
  );
  @override
  Future<void> saveTemplate(EntryTemplate template) => _guard(
    () => database.transaction(() async {
      await _requireCategory(template.categoryId, kind: template.kind);
      final p = await _readProfile();
      await _writeProfile(
        p.copyWith(
          templates: [
            ...p.templates.where((t) => t.id != template.id),
            template,
          ],
        ),
      );
    }),
  );
  @override
  Future<void> deleteTemplate(String id) => _changeProfile(
    (p) => p.copyWith(templates: p.templates.where((t) => t.id != id)),
  );
  @override
  Future<void> markZeroExpenseDay(String localDate, bool value) => _guard(
    () => database.transaction(() async {
      final date = parseCalendarDay(localDate);
      if (date.isAfter(calendarDay(_clock.now()))) {
        throw const PocketFlowException(PocketFlowErrorCode.invalidDate);
      }
      final count = await database
          .customSelect(
            "SELECT count(*) AS n FROM ledger_entries WHERE occurred_local=? AND kind='expense'",
            variables: [Variable.withString(localDate)],
          )
          .getSingle();
      if (value && count.read<int>('n') != 0) {
        throw const FormatException('当天已有支出，不能标为零消费');
      }
      final p = await _readProfile();
      await _writeProfile(
        p.copyWith(
          zeroExpenseDays: [
            ...p.zeroExpenseDays.where((d) => d != localDate),
            if (value) localDate,
          ],
        ),
      );
    }),
  );

  void _validateDraft(EntryDraft draft, DateTime now) {
    if (draft.amount.fen <= 0 || draft.amount.fen > Money.maxInputFen) {
      throw const PocketFlowException(PocketFlowErrorCode.invalidAmount);
    }
    try {
      parseCalendarDay(draft.localDate);
      CalendarMonth.fromDate(now);
      validateTimestamp(draft.occurredAtUtcMs);
      validateTimestamp(now.millisecondsSinceEpoch);
      if (draft.date.isAfter(calendarDay(now))) {
        throw ArgumentError('Future expense date');
      }
    } catch (error) {
      throw PocketFlowException(PocketFlowErrorCode.invalidDate, cause: error);
    }
    if (draft.categoryId.isEmpty || draft.categoryId.length > 64) {
      throw const PocketFlowException(PocketFlowErrorCode.invalidCategory);
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stack) {
      Error.throwWithStackTrace(storageException(error), stack);
    }
  }
}

/// Also used by restore, so the persisted field mapping has one implementation.
Future<void> insertEntry(AppDatabase database, LedgerEntry entry) async {
  await database.customInsert(
    'INSERT INTO ledger_entries(id, amount_fen, kind, occurred_local, '
    'occurred_at_utc_ms, category_id, note, created_at_utc_ms, updated_at_utc_ms) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    variables: [
      Variable.withString(entry.id),
      Variable.withInt(entry.amount.fen),
      Variable.withString(entry.kind.name),
      Variable.withString(entry.localDate),
      Variable.withInt(entry.occurredAtUtcMs),
      Variable.withString(entry.categoryId),
      Variable.withString(entry.note),
      Variable.withInt(entry.createdAtUtcMs),
      Variable.withInt(entry.updatedAtUtcMs),
    ],
    updates: {database.ledgerEntries},
  );
}
