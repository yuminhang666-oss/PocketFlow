import 'ledger_entry.dart';
import 'ledger_models.dart';
import 'personal_profile.dart';

/// Stable IDs preserve the eight original categories and their historical data.
List<Category> recommendedCategories() {
  const expense = <String, String>{
    'food': '餐饮',
    'drinks': '饮品',
    'shopping': '购物',
    'transport': '交通',
    'study': '学习',
    'fun': '娱乐',
    'health': '医疗健康',
    'other': '其他',
    'research': '科研与课程',
    'digital': '数字服务',
    'living': '居住生活',
    'telecom': '通讯',
    'tutoring': '家教成本',
    'sports': '运动',
    'social': '人情往来',
    'travel': '旅行出行',
  };
  const income = <String, String>{
    'income_family': '生活费',
    'income_tutoring': '家教收入',
    'income_scholarship': '奖助学金',
    'income_campus': '校内岗位',
    'income_work': '实习兼职',
    'income_gift': '红包礼金',
    'income_interest': '利息',
    'income_other': '其他收入',
  };
  const children = <String, Map<String, String>>{
    'food': {
      'canteen': '食堂',
      'takeaway': '外卖',
      'restaurant': '校外餐',
      'snack': '零食水果',
      'gathering': '聚餐',
    },
    'drinks': {'coffee': '咖啡', 'tea': '茶饮', 'bottled': '瓶装饮料'},
    'transport': {
      'transit': '公交地铁',
      'taxi': '网约车',
      'bike': '共享单车',
      'home': '返乡车票',
    },
    'shopping': {
      'daily': '日用品',
      'clothing': '衣鞋',
      'care': '个护',
      'electronics': '电子配件',
    },
    'study': {
      'books': '教材教辅',
      'stationery': '文具',
      'print': '打印装订',
      'exam': '考试报名',
    },
    'research': {
      'materials': '自费实验耗材',
      'project': '课程器件与制作',
      'contest': '竞赛报名',
      'papers': '学术资料',
    },
    'digital': {
      'ai': 'AI工具订阅',
      'software': '软件授权',
      'cloud': '网盘',
      'development': '开发与云服务',
    },
    'living': {
      'utilities': '宿舍水电',
      'laundry': '洗衣',
      'repair': '生活维修',
      'haircut': '理发',
    },
    'telecom': {'phone': '话费流量', 'broadband': '宽带'},
    'tutoring': {'print': '授课讲义打印', 'books': '教学资料', 'supplies': '教学用品'},
    'sports': {'court': '运动场地', 'fitness': '健身', 'equipment': '运动装备'},
    'fun': {'movie': '电影', 'game': '游戏', 'membership': '影音会员'},
    'health': {'medicine': '药品', 'clinic': '门诊', 'check': '体检'},
    'social': {'gift': '礼物', 'redpacket': '支出红包', 'club': '社团会费'},
    'travel': {'hotel': '住宿', 'attraction': '景点', 'activity': '旅行活动'},
    'income_tutoring': {'english': '英语家教', 'math': '数学理科家教'},
    'income_scholarship': {
      'scholarship': '奖学金',
      'grant': '助学金',
      'contest': '竞赛奖励',
    },
    'income_campus': {
      'assistant': '助教',
      'workstudy': '勤工助学',
      'project': '学校项目补贴',
    },
    'income_work': {
      'internship': '实习工资',
      'parttime': '校外兼职',
      'project': '项目劳务',
    },
  };
  final result = <Category>[];
  var order = 0;
  for (final group in [expense, income]) {
    final kind = identical(group, expense)
        ? EntryKind.expense
        : EntryKind.income;
    for (final root in group.entries) {
      result.add(
        Category(
          id: root.key,
          name: root.value,
          sortOrder: order++,
          kind: kind,
        ),
      );
      for (final child
          in (children[root.key] ?? const <String, String>{}).entries) {
        result.add(
          Category(
            id: '${root.key}_${child.key}',
            name: child.value,
            sortOrder: order++,
            kind: kind,
            parentId: root.key,
          ),
        );
      }
    }
  }
  return result;
}

void validateCategoryGraph(Iterable<Category> values) {
  final items = {for (final c in values) c.id: c};
  if (items.length != values.length) throw const FormatException('分类ID重复');
  for (final c in values) {
    if (c.parentId == null) continue;
    final parent = items[c.parentId];
    if (parent == null ||
        parent.id == c.id ||
        parent.parentId != null ||
        (parent.kind != null && parent.kind != c.kind)) {
      throw const FormatException('分类层级或收支类型无效');
    }
  }
}

bool categoryAvailable(Category c, List<Category> all, EntryKind kind) =>
    !c.isArchived &&
    c.accepts(kind) &&
    (c.parentId == null ||
        all.any((p) => p.id == c.parentId && !p.isArchived && p.accepts(kind)));

/// Historical archived categories remain valid. A null kind is a legacy
/// category accepting either entry kind; explicit kinds must always match.
void validateCategoryAssignments({
  required Iterable<Category> categories,
  required Iterable<LedgerEntry> entries,
  required Iterable<EntryTemplate> templates,
}) {
  final byId = {for (final c in categories) c.id: c};
  for (final entry in entries) {
    final category = byId[entry.categoryId];
    if (category == null || !category.accepts(entry.kind)) {
      throw const FormatException('账目分类缺失或收支类型不相容');
    }
  }
  for (final template in templates) {
    final category = byId[template.categoryId];
    if (category == null || !category.accepts(template.kind)) {
      throw const FormatException('模板分类缺失或收支类型不相容');
    }
  }
}

String categoryPath(Category c, List<Category> all) {
  final parent = all.where((p) => p.id == c.parentId).firstOrNull;
  return parent == null ? c.name : '${parent.name} · ${c.name}';
}
