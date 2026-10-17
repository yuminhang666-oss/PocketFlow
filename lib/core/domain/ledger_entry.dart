import 'calendar_month.dart';
import 'money.dart';

enum EntryKind { expense, income }

final class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.amount,
    required String localDate,
    required this.categoryId,
    required this.occurredAtUtcMs,
    required this.createdAtUtcMs,
    required this.updatedAtUtcMs,
    this.kind = EntryKind.expense,
    this.note = '',
  }) : date = parseCalendarDay(localDate) {
    if (id.isEmpty || categoryId.isEmpty) {
      throw ArgumentError('记录与分类必须有 ID');
    }
    if (amount.fen <= 0 || amount.fen > Money.maxInputFen) {
      throw ArgumentError('记录金额必须大于零且在允许范围内');
    }
    if (note.length > 500) throw ArgumentError('备注不能超过 500 个字符');
    if (id.length > 64 || categoryId.length > 64) {
      throw ArgumentError('ID 不能超过 64 个字符');
    }
    if (updatedAtUtcMs < createdAtUtcMs) {
      throw ArgumentError('修改时间不能早于创建时间');
    }
  }

  final String id;
  final Money amount;
  final DateTime date;
  final String categoryId;
  final EntryKind kind;
  final String note;
  final int occurredAtUtcMs;
  final int createdAtUtcMs;
  final int updatedAtUtcMs;
  String get localDate => calendarDayKey(date);
}
