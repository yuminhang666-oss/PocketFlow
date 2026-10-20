import 'package:drift/drift.dart';

// Drift generation requires literal SQL strings in customConstraints.
class Categories extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get categoryKind => text().nullable()();
  TextColumn get parentId => text().nullable()();

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

class PersonalState extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class PlanBudgets extends Table {
  TextColumn get month => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get amountFen => integer()();
  @override
  Set<Column> get primaryKey => {month, categoryId};
  @override
  List<String> get customConstraints => [
    "CHECK (length(month)=7 AND substr(month,6,2) BETWEEN '01' AND '12')",
    "CHECK (typeof(amount_fen)='integer' AND amount_fen BETWEEN 0 AND 99999999999)",
  ];
}

class PlanRules extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  IntColumn get createdAtUtcMs => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class PlanVersions extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get ruleId => text().references(PlanRules, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get effectiveMonth => text()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {ruleId, effectiveMonth},
  ];
  @override
  List<String> get customConstraints => [
    "CHECK (json_valid(payload))",
    r"CHECK (json_type(payload,'$.amountFen')='integer' AND json_extract(payload,'$.amountFen') BETWEEN 1 AND 99999999999)",
    r"CHECK (json_type(payload,'$.day')='integer' AND json_extract(payload,'$.day') BETWEEN 1 AND 31)",
  ];
}

class PlanOccurrences extends Table {
  TextColumn get ruleId => text().references(PlanRules, #id)();
  TextColumn get periodKey => text()();
  TextColumn get versionId => text().references(PlanVersions, #id)();
  TextColumn get status => text()();
  TextColumn get entryId =>
      text().nullable().unique().references(LedgerEntries, #id)();
  @override
  Set<Column> get primaryKey => {ruleId, periodKey};
  @override
  List<String> get customConstraints => [
    "CHECK ((status='settled' AND entry_id IS NOT NULL) OR (status='skipped' AND entry_id IS NULL))",
  ];
}

class PlanSettings extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {key};
  @override
  List<String> get customConstraints => ["CHECK(json_valid(payload))"];
}

/// Operational state and feedback are deliberately outside financial restore.
class DeviceStates extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {key};
  @override
  List<String> get customConstraints => ["CHECK(json_valid(payload))"];
}

class FeedbackDraftRows extends Table {
  TextColumn get id => text()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => ["CHECK(json_valid(payload))"];
}

class MonthlyBudgets extends Table {
  TextColumn get month => text().withLength(min: 7, max: 7)();
  late final IntColumn amountFen = integer().check(
    amountFen.isBiggerOrEqualValue(0) &
        amountFen.isSmallerOrEqualValue(99999999999),
  )();
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
  late final IntColumn amountFen = integer().check(
    amountFen.isBiggerThanValue(0) &
        amountFen.isSmallerOrEqualValue(99999999999),
  )();
  late final TextColumn kind = text().check(kind.isIn(['expense', 'income']))();
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
