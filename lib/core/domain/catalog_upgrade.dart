import 'category_catalog.dart';
import 'ledger_models.dart';
import 'ledger_entry.dart';

/// Pure preview only. No database access or automatic startup mutation here.
List<Category> generalRecommendedCategories() {
  const groups = <String, List<String>>{
    'food': ['餐饮', '正餐', '食堂', '外卖', '零食水果', '聚餐'],
    'drinks': ['饮品', '咖啡', '茶饮', '瓶装饮料'],
    'transport': ['交通', '公交地铁', '网约车', '骑行', '长途车票'],
    'shopping': ['购物', '日用品', '衣鞋', '个护', '数码配件'],
    'living': ['居住生活', '房租', '水电燃气', '洗衣', '维修'],
    'study': ['学习成长', '书籍资料', '文具', '打印', '课程培训', '考试报名', '课程项目'],
    'digital': ['数字服务', '软件订阅', 'AI工具', '网盘', '开发服务'],
    'health': ['医疗健康', '药品', '门诊', '体检'],
    'telecom': ['通讯', '话费流量', '宽带'],
    'work': ['工作支出', '工作材料', '打印资料', '工具设备'],
    'fun': ['娱乐', '电影', '游戏', '影音会员'],
    'sports': ['运动', '场地', '健身', '装备'],
    'social': ['人情往来', '礼物', '红包', '聚会活动'],
    'travel': ['旅行', '住宿', '景点', '旅行活动'],
    'other': ['其他'],
    'income_family': ['生活费', '家庭支持'],
    'income_work': ['工资薪酬', '工资', '实习工资', '奖金津贴'],
    'income_labor': ['兼职劳务', '家教', '兼职', '项目劳务'],
    'income_scholarship': ['奖助学金', '奖学金', '助学金', '竞赛奖励'],
    'income_gift': ['红包礼金'],
    'income_interest': ['利息收益'],
    'income_other': ['其他收入', '校内岗位'],
  };
  // Reuse exact semantic child IDs where possible; new children get stable IDs.
  final old = recommendedCategories();
  final result = <Category>[];
  var order = 0;
  for (final group in groups.entries) {
    final kind = group.key.startsWith('income_')
        ? EntryKind.income
        : EntryKind.expense;
    result.add(
      Category(
        id: group.key,
        name: group.value.first,
        sortOrder: order++,
        kind: kind,
      ),
    );
    for (var i = 1; i < group.value.length; i++) {
      final name = group.value[i];
      final id =
          old
              .where((c) => c.parentId == group.key && c.name == name)
              .firstOrNull
              ?.id ??
          '${group.key}_general_$i';
      result.add(
        Category(
          id: id,
          name: name,
          sortOrder: order++,
          kind: kind,
          parentId: group.key,
        ),
      );
    }
  }
  return result;
}

final class CatalogUpgradePreview {
  CatalogUpgradePreview({
    required Iterable<Category> categories,
    required Iterable<String> changed,
    required Iterable<String> preservedBranches,
  }) : categories = List.unmodifiable(categories),
       changed = List.unmodifiable(changed),
       preservedBranches = List.unmodifiable(preservedBranches);
  final List<Category> categories;
  final List<String> changed, preservedBranches;
}

CatalogUpgradePreview previewCatalogUpgrade(
  List<Category> existing, {
  required int catalogVersion,
}) {
  validateCategoryGraph(existing);
  if (catalogVersion >= 1) {
    return CatalogUpgradePreview(
      categories: existing,
      changed: const [],
      preservedBranches: const [],
    );
  }
  final legacy = recommendedCategories();
  final byId = {for (final c in existing) c.id: c};
  final changes = <String>{}, preserved = <String>[];
  bool same(Category a, Category b) =>
      a.id == b.id &&
      a.name == b.name &&
      a.sortOrder == b.sortOrder &&
      a.kind == b.kind &&
      a.parentId == b.parentId &&
      a.isArchived == b.isArchived;
  for (final root in ['research', 'tutoring', 'income_tutoring']) {
    final baseline = legacy
        .where((c) => c.id == root || c.parentId == root)
        .toList();
    final actual = existing
        .where((c) => c.id == root || c.parentId == root)
        .toList();
    if (actual.isEmpty) continue;
    if (actual.length != baseline.length ||
        baseline.any((c) => byId[c.id] == null || !same(c, byId[c.id]!))) {
      preserved.add(root);
      continue;
    }
    for (final c in baseline) {
      byId[c.id] = Category(
        id: c.id,
        name: c.name,
        sortOrder: c.sortOrder,
        isArchived: true,
        kind: c.kind,
        parentId: c.parentId,
      );
      changes.add(c.id);
    }
  }
  for (final c in generalRecommendedCategories()) {
    final current = byId[c.id];
    if (c.parentId != null) {
      final parent = byId[c.parentId];
      if (parent == null ||
          parent.parentId != null ||
          parent.kind != null && parent.kind != c.kind) {
        if (!preserved.contains(c.parentId)) preserved.add(c.parentId!);
        continue;
      }
    }
    final original = legacy.where((v) => v.id == c.id).firstOrNull;
    if (current == null || (original != null && same(current, original))) {
      byId[c.id] = c;
      if (current == null || !same(current, c)) changes.add(c.id);
    }
  }
  validateCategoryGraph(byId.values);
  return CatalogUpgradePreview(
    categories: byId.values,
    changed: changes,
    preservedBranches: preserved,
  );
}
