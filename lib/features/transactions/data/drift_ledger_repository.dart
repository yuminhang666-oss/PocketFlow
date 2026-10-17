import 'package:drift/drift.dart';

import '../../../contracts/contracts.dart';
import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/database/ledger_reader.dart';
import '../../../core/database/ledger_validation.dart';
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
  Future<LedgerEntry> createExpense(EntryDraft draft) => _guard(() async {
    final now = _clock.now();
    _validateDraft(draft, now);
    return database.transaction(() async {
      await _requireCategory(draft.categoryId);
      final entry = LedgerEntry(
        id: _newId(),
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
      return entry;
    });
  });

  @override
  Future<LedgerEntry> updateExpense(String id, EntryDraft draft) => _guard(
    () async {
      final now = _clock.now();
      _validateDraft(draft, now);
      return database.transaction(() async {
        final row = await database
            .customSelect(
              "SELECT * FROM ledger_entries WHERE id = ? AND kind = 'expense'",
              variables: [Variable.withString(id)],
            )
            .getSingleOrNull();
        if (row == null) {
          throw const PocketFlowException(PocketFlowErrorCode.notFound);
        }
        final old = decodeEntryRow(row);
        await _requireCategory(
          draft.categoryId,
          allowArchived: old.categoryId == draft.categoryId,
        );
        final nowMs = now.millisecondsSinceEpoch;
        final updated = nowMs < old.updatedAtUtcMs ? old.updatedAtUtcMs : nowMs;
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
        return entry;
      });
    },
  );

  @override
  Future<void> deleteEntry(String id) => _guard(() async {
    final changed = await database.customUpdate(
      'DELETE FROM ledger_entries WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {database.ledgerEntries},
      updateKind: UpdateKind.delete,
    );
    if (changed != 1) {
      throw const PocketFlowException(PocketFlowErrorCode.notFound);
    }
  });

  Future<void> _requireCategory(String id, {bool allowArchived = false}) async {
    final row = await database
        .customSelect(
          'SELECT is_archived FROM categories WHERE id = ?',
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
  }

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
