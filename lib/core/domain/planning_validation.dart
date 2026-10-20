import 'backup_models.dart';
import 'ledger_entry.dart';

void validateFinancialPlans(BackupDocument document) {
  final categories = {for (final c in document.categories) c.id: c};
  for (final b in document.plans.categoryBudgets) {
    final c = categories[b.categoryId];
    if (c == null || c.parentId != null || c.kind == EntryKind.income) {
      throw const FormatException('分类预算必须引用支出根类');
    }
  }
  for (final v in document.plans.versions) {
    final c = categories[v.categoryId];
    if (c == null || !c.accepts(v.kind)) {
      throw const FormatException('规则分类类型不相容');
    }
  }
  final entries = {for (final e in document.entries) e.id: e};
  for (final o in document.plans.occurrences) {
    if (o.entryId == null) continue;
    final e = entries[o.entryId];
    final v = document.plans.versionFor(o.ruleId, o.period)!;
    if (e == null ||
        e.kind != v.kind ||
        e.categoryId != v.categoryId ||
        e.localDate != v.dueDate(o.period)) {
      throw const FormatException('周期处理期与账目关联不一致');
    }
  }
}
