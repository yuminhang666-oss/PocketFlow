import 'dart:convert';

import '../../../contracts/contracts.dart';
import '../../../core/database/ledger_validation.dart';

/// PRIVATE database encoding, not the public JSON backup format owned by C.
/// Positional rows preserve all v1 fields without depending on a file codec.
class RecoveryCodec {
  const RecoveryCodec();

  String encode(BackupDocument document) => jsonEncode({
    'recoveryVersion': 1,
    'exportedAtUtcMs': document.exportedAtUtcMs,
    'categories': [
      for (final c in document.categories)
        [c.id, c.name, c.sortOrder, c.isArchived],
    ],
    'budgets': [
      for (final b in document.budgets)
        [b.month.key, b.amount.fen, b.updatedAtUtcMs],
    ],
    'entries': [
      for (final e in document.entries)
        [
          e.id,
          e.amount.fen,
          e.localDate,
          e.categoryId,
          e.kind.name,
          e.note,
          e.occurredAtUtcMs,
          e.createdAtUtcMs,
          e.updatedAtUtcMs,
        ],
    ],
  });

  BackupDocument decode(String payload) {
    final root = jsonDecode(payload) as Map<String, dynamic>;
    if (root['recoveryVersion'] is! int || root['recoveryVersion'] != 1) {
      throw const FormatException('Unknown private recovery version');
    }
    final document = BackupDocument(
      exportedAtUtcMs: root['exportedAtUtcMs'] as int,
      categories: [
        for (final value in root['categories'] as List<dynamic>)
          _category(value as List<dynamic>),
      ],
      budgets: [
        for (final value in root['budgets'] as List<dynamic>)
          _budget(value as List<dynamic>),
      ],
      entries: [
        for (final value in root['entries'] as List<dynamic>)
          _entry(value as List<dynamic>),
      ],
    );
    validateBackup(document);
    return document;
  }

  Category _category(List<dynamic> row) {
    if (row.length != 4) throw const FormatException('Invalid category row');
    return Category(
      id: row[0] as String,
      name: row[1] as String,
      sortOrder: row[2] as int,
      isArchived: row[3] as bool,
    );
  }

  MonthlyBudget _budget(List<dynamic> row) {
    if (row.length != 3) throw const FormatException('Invalid budget row');
    return MonthlyBudget(
      month: CalendarMonth.parse(row[0] as String),
      amount: Money.fromFen(row[1] as int),
      updatedAtUtcMs: row[2] as int,
    );
  }

  LedgerEntry _entry(List<dynamic> row) {
    if (row.length != 9) throw const FormatException('Invalid entry row');
    final kind = switch (row[4]) {
      'expense' => EntryKind.expense,
      'income' => EntryKind.income,
      _ => throw const FormatException('Invalid entry kind'),
    };
    return LedgerEntry(
      id: row[0] as String,
      amount: Money.fromFen(row[1] as int),
      localDate: row[2] as String,
      categoryId: row[3] as String,
      kind: kind,
      note: row[5] as String,
      occurredAtUtcMs: row[6] as int,
      createdAtUtcMs: row[7] as int,
      updatedAtUtcMs: row[8] as int,
    );
  }
}
