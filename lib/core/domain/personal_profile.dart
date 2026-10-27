import 'calendar_month.dart';
import 'ledger_entry.dart';
import 'money.dart';

final class SavingsGoal {
  SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
  }) {
    if (id.isEmpty ||
        id.length > 64 ||
        name.trim().isEmpty ||
        name.length > 40 ||
        target.fen <= 0 ||
        target.fen > Money.maxInputFen ||
        saved.fen < 0 ||
        saved.fen > Money.maxInputFen) {
      throw const FormatException('目标名称或金额无效');
    }
  }
  final String id;
  final String name;
  final Money target;
  final Money saved;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'targetFen': target.fen,
    'savedFen': saved.fen,
  };
  factory SavingsGoal.fromJson(Map<String, dynamic> row) => SavingsGoal(
    id: row['id'] as String,
    name: row['name'] as String,
    target: Money.fromFen(row['targetFen'] as int),
    saved: Money.fromFen(row['savedFen'] as int),
  );
}

final class EntryTemplate {
  EntryTemplate({
    required this.id,
    required this.name,
    required this.kind,
    required this.amount,
    required this.categoryId,
    this.note = '',
  }) {
    if (id.isEmpty ||
        id.length > 64 ||
        name.trim().isEmpty ||
        name.length > 40 ||
        amount.fen <= 0 ||
        amount.fen > Money.maxInputFen ||
        categoryId.isEmpty ||
        categoryId.length > 64 ||
        note.length > 500) {
      throw const FormatException('模板内容无效');
    }
  }
  final String id;
  final String name;
  final EntryKind kind;
  final Money amount;
  final String categoryId;
  final String note;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'amountFen': amount.fen,
    'categoryId': categoryId,
    'note': note,
  };
  factory EntryTemplate.fromJson(Map<String, dynamic> row) => EntryTemplate(
    id: row['id'] as String,
    name: row['name'] as String,
    kind: EntryKind.values.byName(row['kind'] as String),
    amount: Money.fromFen(row['amountFen'] as int),
    categoryId: row['categoryId'] as String,
    note: row['note'] as String,
  );
}

/// Personal settings and planning data. Goals never change the ledger budget.
final class PersonalProfile {
  PersonalProfile({
    this.theme = 'system',
    this.surfaceStyle = 'classic',
    this.locale = 'zh_Hans',
    this.feedback = true,
    this.lastExpenseCategoryId,
    this.lastIncomeCategoryId,
    Iterable<SavingsGoal> goals = const [],
    Iterable<EntryTemplate> templates = const [],
    Iterable<String> zeroExpenseDays = const [],
    Map<String, int> categoryColors = const {},
  }) : goals = List.unmodifiable(goals),
       templates = List.unmodifiable(templates),
       zeroExpenseDays = List.unmodifiable(zeroExpenseDays),
       categoryColors = Map.unmodifiable(categoryColors) {
    if (categoryColors.entries.any(
      (e) =>
          e.key.isEmpty ||
          e.key.length > 64 ||
          e.value < 0xFF000000 ||
          e.value > 0xFFFFFFFF,
    )) {
      throw const FormatException('分类颜色无效');
    }
    if (!['system', 'light', 'dark'].contains(theme) ||
        !['classic', 'glass'].contains(surfaceStyle) ||
        !['zh_Hans', 'zh_Hant', 'en'].contains(locale) ||
        [
          lastExpenseCategoryId,
          lastIncomeCategoryId,
        ].any((id) => id != null && (id.isEmpty || id.length > 64)) ||
        this.goals.map((g) => g.id).toSet().length != this.goals.length ||
        this.templates.map((t) => t.id).toSet().length !=
            this.templates.length ||
        this.zeroExpenseDays.toSet().length != this.zeroExpenseDays.length) {
      throw const FormatException('个人设置无效');
    }
    for (final date in this.zeroExpenseDays) {
      parseCalendarDay(date);
    }
  }
  final String theme;
  final String surfaceStyle;
  final String locale;
  final bool feedback;
  final String? lastExpenseCategoryId;
  final String? lastIncomeCategoryId;
  final List<SavingsGoal> goals;
  final List<EntryTemplate> templates;
  final List<String> zeroExpenseDays;
  final Map<String, int> categoryColors;

  PersonalProfile copyWith({
    String? theme,
    String? surfaceStyle,
    String? locale,
    bool? feedback,
    String? lastExpenseCategoryId,
    String? lastIncomeCategoryId,
    bool clearExpenseCategory = false,
    bool clearIncomeCategory = false,
    Iterable<SavingsGoal>? goals,
    Iterable<EntryTemplate>? templates,
    Iterable<String>? zeroExpenseDays,
    Map<String, int>? categoryColors,
  }) => PersonalProfile(
    theme: theme ?? this.theme,
    surfaceStyle: surfaceStyle ?? this.surfaceStyle,
    locale: locale ?? this.locale,
    feedback: feedback ?? this.feedback,
    lastExpenseCategoryId: clearExpenseCategory
        ? null
        : lastExpenseCategoryId ?? this.lastExpenseCategoryId,
    lastIncomeCategoryId: clearIncomeCategory
        ? null
        : lastIncomeCategoryId ?? this.lastIncomeCategoryId,
    goals: goals ?? this.goals,
    templates: templates ?? this.templates,
    zeroExpenseDays: zeroExpenseDays ?? this.zeroExpenseDays,
    categoryColors: categoryColors ?? this.categoryColors,
  );

  Map<String, Object?> toJson() => {
    'theme': theme,
    if (surfaceStyle != 'classic') 'surfaceStyle': surfaceStyle,
    if (locale != 'zh_Hans') 'locale': locale,
    'feedback': feedback,
    'lastExpenseCategoryId': lastExpenseCategoryId,
    'lastIncomeCategoryId': lastIncomeCategoryId,
    'goals': goals.map((g) => g.toJson()).toList(),
    'templates': templates.map((t) => t.toJson()).toList(),
    'zeroExpenseDays': zeroExpenseDays,
    if (categoryColors.isNotEmpty) 'categoryColors': categoryColors,
  };
  factory PersonalProfile.fromJson(Map<String, dynamic> row) => PersonalProfile(
    theme: row['theme'] as String,
    surfaceStyle: row['surfaceStyle'] as String? ?? 'classic',
    locale: row['locale'] as String? ?? 'zh_Hans',
    feedback: row['feedback'] as bool,
    lastExpenseCategoryId: row['lastExpenseCategoryId'] as String?,
    lastIncomeCategoryId: row['lastIncomeCategoryId'] as String?,
    goals: (row['goals'] as List).map(
      (v) => SavingsGoal.fromJson(v as Map<String, dynamic>),
    ),
    templates: (row['templates'] as List).map(
      (v) => EntryTemplate.fromJson(v as Map<String, dynamic>),
    ),
    zeroExpenseDays: (row['zeroExpenseDays'] as List).cast<String>(),
    categoryColors: (row['categoryColors'] as Map<String, dynamic>? ?? {}).map(
      (id, value) => MapEntry(id, value as int),
    ),
  );
}
