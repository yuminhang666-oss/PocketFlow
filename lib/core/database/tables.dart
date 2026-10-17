import 'package:drift/drift.dart';

// Drift generation requires literal SQL strings in customConstraints.
class Categories extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (length(id) BETWEEN 1 AND 64)',
        'CHECK (length(name) BETWEEN 1 AND 30)',
        "CHECK (typeof(sort_order) = 'integer')",
        "CHECK (typeof(is_archived) = 'integer' AND is_archived IN (0, 1))",
      ];
}

class MonthlyBudgets extends Table {
  TextColumn get month => text().withLength(min: 7, max: 7)();
  IntColumn get amountFen => integer().check(
      amountFen.isBiggerOrEqualValue(0) &
      amountFen.isSmallerOrEqualValue(99999999999))();
  IntColumn get updatedAtUtcMs => integer()();

  @override
  Set<Column> get primaryKey => {month};

  @override
  List<String> get customConstraints => [
        "CHECK (typeof(amount_fen) = 'integer')",
        "CHECK (length(month) = 7 AND month GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]' AND substr(month, 1, 4) BETWEEN '1900' AND '9999' AND substr(month, 6, 2) BETWEEN '01' AND '12')",
        "CHECK (typeof(updated_at_utc_ms) = 'integer' AND updated_at_utc_ms BETWEEN -8640000000000000 AND 8640000000000000)",
      ];
}

class LedgerEntries extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  IntColumn get amountFen => integer().check(
      amountFen.isBiggerThanValue(0) &
      amountFen.isSmallerOrEqualValue(99999999999))();
  TextColumn get kind => text().check(kind.isIn(['expense', 'income']))();
  TextColumn get occurredLocal => text().withLength(min: 10, max: 10)();
  IntColumn get occurredAtUtcMs => integer()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get note =>
      text().withLength(max: 500).withDefault(const Constant(''))();
  IntColumn get createdAtUtcMs => integer()();
  IntColumn get updatedAtUtcMs => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (length(id) BETWEEN 1 AND 64)',
        'CHECK (length(category_id) BETWEEN 1 AND 64)',
        'CHECK (length(note) <= 500)',
        "CHECK (typeof(amount_fen) = 'integer')",
        "CHECK (length(occurred_local) = 10 AND occurred_local GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND substr(occurred_local, 1, 4) BETWEEN '1900' AND '9999' AND substr(occurred_local, 6, 2) BETWEEN '01' AND '12' AND CAST(substr(occurred_local, 9, 2) AS INTEGER) BETWEEN 1 AND CASE WHEN substr(occurred_local, 6, 2) = '02' THEN 28 + (CAST(substr(occurred_local, 1, 4) AS INTEGER) % 4 = 0 AND (CAST(substr(occurred_local, 1, 4) AS INTEGER) % 100 != 0 OR CAST(substr(occurred_local, 1, 4) AS INTEGER) % 400 = 0)) WHEN substr(occurred_local, 6, 2) IN ('04', '06', '09', '11') THEN 30 ELSE 31 END)",
        "CHECK (typeof(occurred_at_utc_ms) = 'integer' AND occurred_at_utc_ms BETWEEN -8640000000000000 AND 8640000000000000)",
        "CHECK (typeof(created_at_utc_ms) = 'integer' AND created_at_utc_ms BETWEEN -8640000000000000 AND 8640000000000000)",
        "CHECK (typeof(updated_at_utc_ms) = 'integer' AND updated_at_utc_ms BETWEEN -8640000000000000 AND 8640000000000000)",
        'CHECK (updated_at_utc_ms >= created_at_utc_ms)',
      ];
}

/// Private recovery storage, deliberately excluded from public backup exports.
class RecoverySnapshots extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  IntColumn get createdAtUtcMs => integer()();
  TextColumn get payload => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (length(id) BETWEEN 1 AND 64)',
        "CHECK (typeof(created_at_utc_ms) = 'integer' AND created_at_utc_ms BETWEEN -8640000000000000 AND 8640000000000000)",
      ];
}
