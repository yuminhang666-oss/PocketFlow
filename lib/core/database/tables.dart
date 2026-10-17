import 'package:drift/drift.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
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
  List<String> get customConstraints => ["CHECK (typeof(amount_fen) = 'integer')"];
}

class LedgerEntries extends Table {
  TextColumn get id => text()();
  IntColumn get amountFen => integer().check(
      amountFen.isBiggerThanValue(0) &
      amountFen.isSmallerOrEqualValue(99999999999))();
  TextColumn get kind => text().check(kind.isIn(['expense', 'income']))();
  TextColumn get occurredLocal => text().withLength(min: 10, max: 10)();
  IntColumn get occurredAtUtcMs => integer()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get note => text().withLength(max: 500).withDefault(const Constant(''))();
  IntColumn get createdAtUtcMs => integer()();
  IntColumn get updatedAtUtcMs => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ["CHECK (typeof(amount_fen) = 'integer')"];
}
