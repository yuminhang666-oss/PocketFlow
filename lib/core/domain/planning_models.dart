import 'calendar_month.dart';
import 'ledger_entry.dart';
import 'money.dart';

void validatePlanId(String id) {
  if (id.trim().isEmpty || id.length > 64) {
    throw const FormatException('计划ID无效');
  }
}

void validatePlanAmount(int fen, {bool zero = false}) {
  if (fen < (zero ? 0 : 1) || fen > Money.maxInputFen) {
    throw const FormatException('计划金额无效');
  }
}

final class CategoryBudget {
  CategoryBudget({
    required this.month,
    required this.categoryId,
    required this.amount,
  }) {
    validatePlanId(categoryId);
    validatePlanAmount(amount.fen, zero: true);
  }
  final CalendarMonth month;
  final String categoryId;
  final Money amount;
  Map<String, Object?> toJson() => {
    'month': month.key,
    'categoryId': categoryId,
    'amountFen': amount.fen,
  };
  factory CategoryBudget.fromJson(Map<String, dynamic> j) => CategoryBudget(
    month: CalendarMonth.parse(j['month'] as String),
    categoryId: j['categoryId'] as String,
    amount: Money.fromFen(j['amountFen'] as int),
  );
}

final class RecurringRule {
  RecurringRule({required this.id, required this.createdAtUtcMs}) {
    validatePlanId(id);
    if (createdAtUtcMs.abs() > 8640000000000000) {
      throw const FormatException('规则时间无效');
    }
  }
  final String id;
  final int createdAtUtcMs;
  Map<String, Object?> toJson() => {'id': id, 'createdAtUtcMs': createdAtUtcMs};
  factory RecurringRule.fromJson(Map<String, dynamic> j) => RecurringRule(
    id: j['id'] as String,
    createdAtUtcMs: j['createdAtUtcMs'] as int,
  );
}

/// Every field needed to derive an occurrence is immutable and versioned.
final class RecurringVersion {
  RecurringVersion({
    required this.id,
    required this.ruleId,
    required this.effectiveMonth,
    required this.startMonth,
    this.endMonth,
    required this.kind,
    required this.categoryId,
    required this.amount,
    required this.day,
    this.leadDays = 7,
    this.note = '',
    this.enabled = true,
    this.archived = false,
  }) {
    validatePlanId(id);
    validatePlanId(ruleId);
    validatePlanId(categoryId);
    validatePlanAmount(amount.fen);
    if (day < 1 ||
        day > 31 ||
        leadDays < 0 ||
        leadDays > 31 ||
        note.length > 500 ||
        (endMonth != null && endMonth!.compareTo(startMonth) < 0)) {
      throw const FormatException('周期规则字段无效');
    }
  }
  final String id, ruleId, categoryId, note;
  final CalendarMonth effectiveMonth, startMonth;
  final CalendarMonth? endMonth;
  final EntryKind kind;
  final Money amount;
  final int day, leadDays;
  final bool enabled, archived;
  String dueDate(CalendarMonth month) => calendarDayKey(
    DateTime.utc(month.year, month.month, day > month.days ? month.days : day),
  );
  bool applies(CalendarMonth month) =>
      enabled &&
      !archived &&
      month.compareTo(startMonth) >= 0 &&
      (endMonth == null || month.compareTo(endMonth!) <= 0);
  Map<String, Object?> toJson() => {
    'id': id,
    'ruleId': ruleId,
    'effectiveMonth': effectiveMonth.key,
    'startMonth': startMonth.key,
    'endMonth': endMonth?.key,
    'kind': kind.name,
    'categoryId': categoryId,
    'amountFen': amount.fen,
    'day': day,
    'leadDays': leadDays,
    'note': note,
    'enabled': enabled,
    'archived': archived,
  };
  factory RecurringVersion.fromJson(Map<String, dynamic> j) => RecurringVersion(
    id: j['id'] as String,
    ruleId: j['ruleId'] as String,
    effectiveMonth: CalendarMonth.parse(j['effectiveMonth'] as String),
    startMonth: CalendarMonth.parse(j['startMonth'] as String),
    endMonth: j['endMonth'] == null
        ? null
        : CalendarMonth.parse(j['endMonth'] as String),
    kind: EntryKind.values.byName(j['kind'] as String),
    categoryId: j['categoryId'] as String,
    amount: Money.fromFen(j['amountFen'] as int),
    day: j['day'] as int,
    leadDays: j['leadDays'] as int,
    note: j['note'] as String,
    enabled: j['enabled'] as bool,
    archived: j['archived'] as bool,
  );
}

enum OccurrenceStatus { settled, skipped }

final class RecurringOccurrence {
  RecurringOccurrence({
    required this.ruleId,
    required this.period,
    required this.versionId,
    required this.status,
    this.entryId,
  }) {
    validatePlanId(ruleId);
    validatePlanId(versionId);
    if ((status == OccurrenceStatus.settled) != (entryId != null)) {
      throw const FormatException('周期处理关联无效');
    }
    if (entryId != null) validatePlanId(entryId!);
  }
  final String ruleId, versionId;
  final CalendarMonth period;
  final OccurrenceStatus status;
  final String? entryId;
  String get key => '$ruleId:${period.key}';
  Map<String, Object?> toJson() => {
    'ruleId': ruleId,
    'periodKey': period.key,
    'versionId': versionId,
    'status': status.name,
    'entryId': entryId,
  };
  factory RecurringOccurrence.fromJson(Map<String, dynamic> j) =>
      RecurringOccurrence(
        ruleId: j['ruleId'] as String,
        period: CalendarMonth.parse(j['periodKey'] as String),
        versionId: j['versionId'] as String,
        status: OccurrenceStatus.values.byName(j['status'] as String),
        entryId: j['entryId'] as String?,
      );
}

final class ReminderSettings {
  const ReminderSettings({this.budget = true, this.weekly = true});
  final bool budget, weekly;
  Map<String, Object?> toJson() => {'budget': budget, 'weekly': weekly};
  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
    budget: j['budget'] as bool,
    weekly: j['weekly'] as bool,
  );
}

final class PlanningData {
  PlanningData({
    Iterable<CategoryBudget> categoryBudgets = const [],
    Iterable<RecurringRule> rules = const [],
    Iterable<RecurringVersion> versions = const [],
    Iterable<RecurringOccurrence> occurrences = const [],
    this.settings = const ReminderSettings(),
    this.catalogVersion = 0,
  }) : categoryBudgets = List.unmodifiable(categoryBudgets),
       rules = List.unmodifiable(rules),
       versions = List.unmodifiable(versions),
       occurrences = List.unmodifiable(occurrences) {
    if (catalogVersion < 0 || catalogVersion > 1) {
      throw const FormatException('分类目录版本无效');
    }
    final ruleIds = this.rules.map((r) => r.id).toSet();
    final versionIds = this.versions.map((r) => r.id).toSet();
    if (ruleIds.length != this.rules.length ||
        versionIds.length != this.versions.length ||
        this.categoryBudgets
                .map((b) => '${b.month.key}:${b.categoryId}')
                .toSet()
                .length !=
            this.categoryBudgets.length ||
        this.versions
                .map((v) => '${v.ruleId}:${v.effectiveMonth.key}')
                .toSet()
                .length !=
            this.versions.length ||
        this.occurrences.map((o) => o.key).toSet().length !=
            this.occurrences.length ||
        this.versions.any((v) => !ruleIds.contains(v.ruleId)) ||
        ruleIds.any((id) => !this.versions.any((v) => v.ruleId == id))) {
      throw const FormatException('计划ID或版本关系无效');
    }
    final entryIds = <String>{};
    for (final o in this.occurrences) {
      final v = versionFor(o.ruleId, o.period);
      if (v == null ||
          v.id != o.versionId ||
          !v.applies(o.period) ||
          (o.entryId != null && !entryIds.add(o.entryId!))) {
        throw const FormatException('周期期关系无效');
      }
    }
  }
  final List<CategoryBudget> categoryBudgets;
  final List<RecurringRule> rules;
  final List<RecurringVersion> versions;
  final List<RecurringOccurrence> occurrences;
  final ReminderSettings settings;
  final int catalogVersion;
  RecurringVersion? versionFor(String id, CalendarMonth month) {
    final candidates =
        versions
            .where(
              (v) => v.ruleId == id && v.effectiveMonth.compareTo(month) <= 0,
            )
            .toList()
          ..sort((a, b) => b.effectiveMonth.compareTo(a.effectiveMonth));
    return candidates.firstOrNull;
  }

  PlanningData copyWith({
    Iterable<CategoryBudget>? categoryBudgets,
    Iterable<RecurringRule>? rules,
    Iterable<RecurringVersion>? versions,
    Iterable<RecurringOccurrence>? occurrences,
    ReminderSettings? settings,
    int? catalogVersion,
  }) => PlanningData(
    categoryBudgets: categoryBudgets ?? this.categoryBudgets,
    rules: rules ?? this.rules,
    versions: versions ?? this.versions,
    occurrences: occurrences ?? this.occurrences,
    settings: settings ?? this.settings,
    catalogVersion: catalogVersion ?? this.catalogVersion,
  );
  Map<String, Object?> toJson() => {
    'categoryBudgets': categoryBudgets.map((v) => v.toJson()).toList(),
    'rules': rules.map((v) => v.toJson()).toList(),
    'versions': versions.map((v) => v.toJson()).toList(),
    'occurrences': occurrences.map((v) => v.toJson()).toList(),
    'reminderSettings': settings.toJson(),
    'catalogVersion': catalogVersion,
  };
  factory PlanningData.fromJson(Map<String, dynamic> j) => PlanningData(
    categoryBudgets: (j['categoryBudgets'] as List).map(
      (x) => CategoryBudget.fromJson(x as Map<String, dynamic>),
    ),
    rules: (j['rules'] as List).map(
      (x) => RecurringRule.fromJson(x as Map<String, dynamic>),
    ),
    versions: (j['versions'] as List).map(
      (x) => RecurringVersion.fromJson(x as Map<String, dynamic>),
    ),
    occurrences: (j['occurrences'] as List).map(
      (x) => RecurringOccurrence.fromJson(x as Map<String, dynamic>),
    ),
    settings: ReminderSettings.fromJson(
      j['reminderSettings'] as Map<String, dynamic>,
    ),
    catalogVersion: j['catalogVersion'] as int,
  );
}

final class PendingOccurrence {
  const PendingOccurrence(this.version, this.period);
  final RecurringVersion version;
  final CalendarMonth period;
  String get dueDate => version.dueDate(period);
}

final class RecoveryPoint {
  const RecoveryPoint({
    required this.id,
    required this.createdAtUtcMs,
    this.entries,
    this.encodingVersion,
    this.corrupted = false,
  });
  final String id;
  final int createdAtUtcMs;
  final int? entries, encodingVersion;
  final bool corrupted;
}
