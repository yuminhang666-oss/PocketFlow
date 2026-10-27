import 'calendar_month.dart';
import 'ledger_entry.dart';
import 'money.dart';
import 'personal_profile.dart';
import 'planning_models.dart';

final class Category {
  Category({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.isArchived = false,
    this.kind,
    this.parentId,
    this.colorValue,
  }) {
    if (id.isEmpty ||
        id.length > 64 ||
        name.trim().isEmpty ||
        name.length > 30 ||
        (colorValue != null &&
            (colorValue! < 0xFF000000 || colorValue! > 0xFFFFFFFF))) {
      throw ArgumentError('分类 ID 或名称无效');
    }
  }
  final String id;
  final String name;
  final int sortOrder;
  final bool isArchived;

  /// Null preserves legacy categories used by either kind of historical entry.
  final EntryKind? kind;
  final String? parentId;

  /// Optional identity color projected from the same profile snapshot.
  final int? colorValue;

  bool accepts(EntryKind value) => kind == null || kind == value;
}

final class MonthlyBudget {
  MonthlyBudget({
    required this.month,
    required this.amount,
    required this.updatedAtUtcMs,
  }) {
    if (amount.fen < 0 || amount.fen > Money.maxInputFen) {
      throw ArgumentError('预算金额无效');
    }
  }
  final CalendarMonth month;
  final Money amount;
  final int updatedAtUtcMs;
}

final class EntryDraft {
  EntryDraft({
    required this.amount,
    required String localDate,
    required this.occurredAtUtcMs,
    required this.categoryId,
    this.note = '',
  }) : date = parseCalendarDay(localDate) {
    if (amount.fen <= 0 || amount.fen > Money.maxInputFen) {
      throw ArgumentError('支出金额无效');
    }
    if (categoryId.isEmpty || categoryId.length > 64 || note.length > 500) {
      throw ArgumentError('分类或备注无效');
    }
  }
  final Money amount;
  final DateTime date;
  final int occurredAtUtcMs;
  final String categoryId;
  final String note;
  String get localDate => calendarDayKey(date);
}

final class LedgerMonthData {
  LedgerMonthData({
    required this.month,
    required this.budget,
    required Iterable<LedgerEntry> entries,
    required Iterable<Category> categories,
    PersonalProfile? profile,
    Iterable<CategoryBudget> categoryBudgets = const [],
  }) : entries = List.unmodifiable(entries),
       categories = List.unmodifiable(categories),
       profile = profile ?? PersonalProfile(),
       categoryBudgets = List.unmodifiable(categoryBudgets) {
    if (budget != null && budget!.month != month) {
      throw ArgumentError('预算月份与快照月份不同');
    }
    if (this.entries.any((e) => CalendarMonth.fromDate(e.date) != month)) {
      throw ArgumentError('月快照含其他月份的记录');
    }
  }
  final CalendarMonth month;
  final MonthlyBudget? budget;
  final List<LedgerEntry> entries;
  final List<Category> categories;
  final PersonalProfile profile;
  final List<CategoryBudget> categoryBudgets;
}
