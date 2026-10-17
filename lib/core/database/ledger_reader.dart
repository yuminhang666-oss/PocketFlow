import 'package:drift/drift.dart';

import '../../contracts/contracts.dart';
import 'app_database.dart' show AppDatabase;
import 'ledger_validation.dart';

/// One SELECT means one SQLite read snapshot, including the empty-month case.
/// Filter comments are replaced only by constant clauses below, never by input.
const ledgerSnapshotQuery = '''
SELECT 'category' AS record_type, id, name, sort_order, is_archived,
       NULL AS month, NULL AS amount_fen, NULL AS occurred_local,
       NULL AS occurred_at_utc_ms, NULL AS category_id, NULL AS note,
       NULL AS created_at_utc_ms, NULL AS updated_at_utc_ms, NULL AS kind
FROM categories
UNION ALL
SELECT 'budget', NULL, NULL, NULL, NULL, month, amount_fen,
       NULL, NULL, NULL, NULL, NULL, updated_at_utc_ms, NULL
FROM monthly_budgets /* BUDGET_FILTER */
UNION ALL
SELECT 'entry', id, NULL, NULL, NULL, NULL, amount_fen, occurred_local,
       occurred_at_utc_ms, category_id, note, created_at_utc_ms, updated_at_utc_ms, kind
FROM ledger_entries /* ENTRY_FILTER */
''';

class LedgerReader {
  LedgerReader(this.database);
  final AppDatabase database;

  Selectable<QueryRow> _query([CalendarMonth? month]) {
    final sql = ledgerSnapshotQuery
        .replaceAll('/* BUDGET_FILTER */', month != null ? 'WHERE month = ?' : '')
        .replaceAll('/* ENTRY_FILTER */', month != null
            ? 'WHERE occurred_local >= ? AND occurred_local <= ?' : '');
    return database.customSelect(
      sql,
      variables: month != null ? [
        Variable.withString(month.key),
        Variable.withString('${month.key}-01'),
        Variable.withString('${month.key}-${month.days}'),
      ] : const [],
      readsFrom: {
        database.categories,
        database.monthlyBudgets,
        database.ledgerEntries,
      },
    );
  }

  Stream<LedgerMonthData> watchMonth(CalendarMonth month) =>
      _query(month).watch().map((rows) {
        final contents = _decode(rows);
        return LedgerMonthData(
          month: month,
          budget: contents.budgets.isEmpty ? null : contents.budgets.single,
          entries: contents.entries,
          categories: contents.categories,
        );
      }).handleError((Object error, StackTrace stack) {
        Error.throwWithStackTrace(storageException(error), stack);
      });

  Future<BackupDocument> readAll(int exportedAtUtcMs) async {
    final contents = _decode(await _query().get());
    return BackupDocument(
      exportedAtUtcMs: exportedAtUtcMs,
      budgets: contents.budgets,
      categories: contents.categories,
      entries: contents.entries,
    );
  }

  ({
    List<MonthlyBudget> budgets,
    List<Category> categories,
    List<LedgerEntry> entries,
  }) _decode(List<QueryRow> rows) {
    try {
      final budgets = <MonthlyBudget>[];
      final categories = <Category>[];
      final entries = <LedgerEntry>[];
      for (final row in rows) {
        switch (row.read<String>('record_type')) {
          case 'category':
            final archived = readStoredInt(row, 'is_archived');
            if (archived != 0 && archived != 1) {
              throw ArgumentError('Invalid archived flag');
            }
            final category = Category(
              id: row.read<String>('id'),
              name: row.read<String>('name'),
              sortOrder: readStoredInt(row, 'sort_order'),
              isArchived: archived == 1,
            );
            validateCategory(category);
            categories.add(category);
          case 'budget':
            final budget = MonthlyBudget(
              month: CalendarMonth.parse(row.read<String>('month')),
              amount: Money.fromFen(readStoredInt(row, 'amount_fen')),
              updatedAtUtcMs: readStoredInt(row, 'updated_at_utc_ms'),
            );
            validateBudget(budget);
            budgets.add(budget);
          case 'entry':
            entries.add(decodeEntryRow(row));
          default:
            throw ArgumentError('Invalid snapshot row');
        }
      }
      final categoryIds = categories.map((category) => category.id).toSet();
      if (entries.any((entry) => !categoryIds.contains(entry.categoryId))) {
        throw ArgumentError('Missing entry category');
      }
      budgets.sort((a, b) => a.month.compareTo(b.month));
      categories.sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.id.compareTo(b.id);
      });
      entries.sort((a, b) {
        final time = b.occurredAtUtcMs.compareTo(a.occurredAtUtcMs);
        return time != 0 ? time : a.id.compareTo(b.id);
      });
      return (budgets: budgets, categories: categories, entries: entries);
    } catch (error) {
      throw PocketFlowException(PocketFlowErrorCode.dataCorrupted, cause: error);
    }
  }
}

LedgerEntry decodeEntryRow(QueryRow row) {
  try {
    final kind = switch (row.read<String>('kind')) {
      'expense' => EntryKind.expense,
      'income' => EntryKind.income,
      _ => throw ArgumentError('Invalid entry kind'),
    };
    final entry = LedgerEntry(
      id: row.read<String>('id'),
      amount: Money.fromFen(readStoredInt(row, 'amount_fen')),
      localDate: row.read<String>('occurred_local'),
      categoryId: row.read<String>('category_id'),
      kind: kind,
      note: row.read<String>('note'),
      occurredAtUtcMs: readStoredInt(row, 'occurred_at_utc_ms'),
      createdAtUtcMs: readStoredInt(row, 'created_at_utc_ms'),
      updatedAtUtcMs: readStoredInt(row, 'updated_at_utc_ms'),
    );
    validateEntry(entry);
    return entry;
  } catch (error) {
    throw PocketFlowException(PocketFlowErrorCode.dataCorrupted, cause: error);
  }
}

/// Drift can coerce numeric SQL responses when mapping int. Inspect raw values
/// first so corrupt REAL/text financial fields are never silently truncated.
int readStoredInt(QueryRow row, String column) {
  final value = row.data[column];
  if (value is! int) {
    throw const PocketFlowException(PocketFlowErrorCode.dataCorrupted);
  }
  return value;
}
