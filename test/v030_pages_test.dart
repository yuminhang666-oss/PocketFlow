import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/core/database/app_database.dart' show AppDatabase;
import 'package:pocketflow/features/feedback/data/feedback_service.dart';
import 'package:pocketflow/features/feedback/presentation/feedback_page.dart';
import 'package:pocketflow/features/planning/presentation/planning_pages_v3.dart';
import 'package:pocketflow/features/reports/presentation/reports_page.dart';

// Layout receives a fixed contract snapshot. Real Drift I/O, migration and
// transaction failures are exercised separately in planning_storage_test.dart.
class _LayoutPlans implements PlanningPort {
  _LayoutPlans(this.data, this.plans);
  final LedgerMonthData data;
  final PlanningData plans;
  @override
  Stream<PlanningData> watchPlans() => Stream.value(plans);
  @override
  Stream<LedgerRangeData> watchRange(String start, String end) => Stream.value(
    LedgerRangeData(
      start: start,
      end: end,
      entries: data.entries.where(
        (e) =>
            e.localDate.compareTo(start) >= 0 &&
            e.localDate.compareTo(end) <= 0,
      ),
      categories: data.categories,
      revision: 'synthetic-layout',
    ),
  );
  @override
  Future<List<RecoveryPoint>> recoveryPoints() async => const [
    RecoveryPoint(
      id: 'synthetic-recovery',
      createdAtUtcMs: 1793404800000,
      entries: 30,
      encodingVersion: 3,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedBackup implements BackupStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Drafts implements FeedbackDraftStore {
  final values = <String, FeedbackDraft>{};
  @override
  Future<List<FeedbackDraft>> readDrafts() async => values.values.toList();
  @override
  Future<void> saveDraft(FeedbackDraft draft) async {
    values[draft.id] = draft;
  }
}

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 31, 12);
}

class _Feedback implements FeedbackMailPort {
  bool available = true;
  bool fail = false;
  final sent = <FeedbackDraft>[];
  @override
  Future<bool> openComposer(FeedbackDraft draft) async {
    sent.add(draft);
    if (fail) {
      throw const PocketFlowException(PocketFlowErrorCode.feedbackUnavailable);
    }
    return available;
  }
}

Future<void> _settle(WidgetTester tester) async {
  // Drift's asyncMap transaction can start after the first rendered stream
  // event. Alternate real I/O and fake frames instead of starving native SQL
  // while pumpAndSettle repeatedly advances only the widget-test clock.
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 2),
  );
}

void main() {
  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final spec in [
      for (final size in [
        const Size(320, 568),
        const Size(360, 640),
        const Size(390, 844),
        const Size(412, 915),
      ])
        for (final scale in [1.0, 1.3, 2.0])
          if (size.width != 320 || scale != 1.3) (size, scale),
    ]) {
      final size = spec.$1, scale = spec.$2;
      testWidgets(
        'planning, reports and feedback at $size $theme scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final clock = _Clock();
          final month = CalendarMonth(2026, 10);
          final data = LedgerMonthData(
            month: month,
            budget: MonthlyBudget(
              month: month,
              amount: const Money.fromFen(10000),
              updatedAtUtcMs: 100,
            ),
            entries: [
              for (final income in [false, true])
                LedgerEntry(
                  id: income ? 'synthetic-i' : 'synthetic-e',
                  amount: const Money.fromFen(12345678),
                  localDate: '2026-10-30',
                  categoryId: income ? 'income_work' : 'food',
                  kind: income ? EntryKind.income : EntryKind.expense,
                  note:
                      'SYNTHETIC long report note for wrapping on small screens',
                  occurredAtUtcMs: 100,
                  createdAtUtcMs: 100,
                  updatedAtUtcMs: 100,
                ),
            ],
            categories: generalRecommendedCategories(),
            categoryBudgets: [
              CategoryBudget(
                month: month,
                categoryId: 'food',
                amount: const Money.fromFen(12000),
              ),
            ],
          );
          final plans = _LayoutPlans(
            data,
            PlanningData(
              rules: [RecurringRule(id: 'synthetic-rule', createdAtUtcMs: 100)],
              versions: [
                RecurringVersion(
                  id: 'synthetic-version',
                  ruleId: 'synthetic-rule',
                  effectiveMonth: month,
                  startMonth: month,
                  kind: EntryKind.expense,
                  categoryId: 'food',
                  amount: const Money.fromFen(3500),
                  day: 31,
                  note: 'SYNTHETIC monthly task with a long note',
                ),
              ],
            ),
          );
          try {
            for (final page in <Widget>[
              CategoryBudgetsPage(
                data: data,
                port: plans,
                today: clock.now(),
                onTotalBudget: () {},
              ),
              RecurringPlansPage(
                port: plans,
                categories: data.categories,
                clock: clock,
              ),
              RecurringRuleEditor(
                port: plans,
                categories: data.categories,
                clock: clock,
              ),
              RecoveryPointsPage(port: plans, backup: _UnusedBackup()),
              ReminderSettingsPage(port: plans),
              ReportsPage(port: plans, clock: clock),
              FeedbackPage(port: _Feedback(), store: _Drafts()),
            ]) {
              debugPrint('SYNTHETIC layout ${page.runtimeType}');
              await tester.pumpWidget(
                PocketFlowApp(themeMode: theme, home: page),
              );
              await _settle(tester);
              expect(
                tester.takeException(),
                isNull,
                reason: '${page.runtimeType}',
              );
              for (var step = 0; step < 3; step++) {
                final scroll = find.byType(Scrollable).hitTestable();
                if (scroll.evaluate().isNotEmpty) {
                  await tester.drag(scroll.last, const Offset(0, -350));
                  await _settle(tester);
                  expect(
                    tester.takeException(),
                    isNull,
                    reason: '${page.runtimeType} after scrolling',
                  );
                }
              }
              await tester.pumpWidget(const SizedBox.shrink());
              await _settle(tester);
            }
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );
    }
  }

  testWidgets(
    'email preview cancels safely; missing client retains draft; opening is never reported as sent',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory()),
          port = _Feedback()..available = false;
      final store = DriftFeedbackDraftStore(db);
      Future<void> tap(String text) async {
        if (find.text(text).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text(text),
            180,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
        }
        final target = find.text(text).last;
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await _settle(tester);
      }

      try {
        await tester.pumpWidget(
          PocketFlowApp(
            home: FeedbackPage(port: port, store: store),
          ),
        );
        await _settle(tester);
        await tester.enterText(
          find.byType(TextField).first,
          'SYNTHETIC email feedback long enough',
        );
        await tap('预览反馈邮件');
        expect(port.sent, isEmpty);
        expect(find.textContaining(feedbackEmailRecipient), findsWidgets);
        await tap('取消');
        expect(port.sent, isEmpty);
        await tap('预览反馈邮件');
        await tap('打开邮件客户端');
        expect(port.sent.length, 1);
        expect(find.textContaining('未找到可用的邮件客户端'), findsOneWidget);
        expect(
          (await tester.runAsync(store.readDrafts))!.single.status,
          FeedbackStatus.draft,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await _settle(tester);
        await tester.pumpWidget(
          PocketFlowApp(
            home: FeedbackPage(port: port, store: store),
          ),
        );
        await _settle(tester);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          contains('SYNTHETIC email'),
        );
        port.available = true;
        await tap('预览反馈邮件');
        await tap('打开邮件客户端');
        expect(find.textContaining('App无法确认是否发送或送达'), findsOneWidget);
        expect(find.textContaining('已提交 · 回执'), findsNothing);
        expect(
          (await tester.runAsync(store.readDrafts))!.single.status,
          FeedbackStatus.mailOpened,
        );
        await tap('写一条新反馈');
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          isEmpty,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(db.close);
      }
    },
  );
}
