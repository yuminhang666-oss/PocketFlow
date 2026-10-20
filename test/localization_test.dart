import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/app/composition/pocketflow_root.dart';
import 'package:pocketflow/app/pocketflow_app.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/core/database/app_database.dart' show AppDatabase;
import 'package:pocketflow/features/backup/domain/json_backup_codec.dart';
import 'package:pocketflow/features/settings/presentation/settings_page.dart';
import 'package:pocketflow/features/settings/presentation/about_pocketflow_page.dart';
import 'package:pocketflow/features/transactions/data/drift_ledger_repository.dart';
import 'package:pocketflow/features/transactions/data/drift_backup_store.dart';
import 'package:pocketflow/l10n/app_strings.dart';
import 'package:pocketflow/l10n/message_keys.dart';
import 'package:pocketflow/l10n/message_catalogs.dart';
import 'package:pocketflow/core/domain/category_catalog.dart';
import 'package:pocketflow/features/home/presentation/home_page.dart';
import 'package:pocketflow/features/entry_editor/presentation/quick_entry_page.dart';
import 'package:pocketflow/features/statistics/presentation/statistics_page.dart';
import 'package:pocketflow/app/routing/pocketflow_shell.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 20, 12);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all packaged language resources have matching keys and placeholders',
    () async {
      final sets = <Set<String>>[];
      for (final language in ['zh_Hans', 'zh_Hant', 'en']) {
        final map =
            jsonDecode(
                  await rootBundle.loadString('lib/l10n/app_$language.arb'),
                )
                as Map<String, dynamic>;
        sets.add(map.keys.where((key) => !key.startsWith('@')).toSet());
        expect(messageCatalogs[language], {
          for (final key in sets.last) key: map[key],
        });
        final strings = AppStrings(language, map);
        for (final entry in messageKeys.entries) {
          final value = map[entry.value] as String;
          final expected = RegExp(
            r'\{(\d+)\}',
          ).allMatches(entry.key).map((m) => m[1]).toSet();
          final actual = RegExp(
            r'\{p(\d+)\}',
          ).allMatches(value).map((m) => m[1]).toSet();
          expect(actual, expected, reason: entry.key);
          if (language == 'en') {
            expect(
              RegExp(r'[\u3400-\u9fff]').hasMatch(value),
              isFalse,
              reason: entry.key,
            );
          }
        }
        expect(strings.text('{0} {1}', ['{p1}', '备注']), '{p1} 备注');
      }
      expect(sets[0], sets[1]);
      expect(sets[0], sets[2]);
    },
  );
  test(
    'locale survives repository reopen, JSON restore and older missing fields',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = DriftLedgerRepository(db, clock: _Clock());
      final store = DriftBackupStore(db, clock: _Clock());
      await repository.saveBudget(
        CalendarMonth(2026, 10),
        const Money.fromFen(123456),
      );
      final before = await store.readAll();
      for (final language in ['en', 'zh_Hant', 'zh_Hans']) {
        await repository.savePreferences(
          locale: language,
          surfaceStyle: 'glass',
        );
        final data = await DriftLedgerRepository(
          db,
          clock: _Clock(),
        ).watchMonth(CalendarMonth(2026, 10)).first;
        expect(data.profile.locale, language);
        expect(data.profile.surfaceStyle, 'glass');
        final backup = const JsonBackupCodec().decode(
          const JsonBackupCodec().encode(await store.readAll()),
        );
        await store.replaceAll(backup);
        final after = await store.readAll();
        expect(after.profile.locale, language);
        expect(after.budgets.single.amount, before.budgets.single.amount);
        expect(
          after.categories
              .map((c) => (c.id, c.name, c.parentId, c.kind, c.isArchived))
              .toList(),
          before.categories
              .map((c) => (c.id, c.name, c.parentId, c.kind, c.isArchived))
              .toList(),
        );
      }
      expect(
        PersonalProfile.fromJson(PersonalProfile().toJson()).locale,
        'zh_Hans',
      );
      expect(() => PersonalProfile(locale: 'fr'), throwsFormatException);
    },
  );
  for (final language in ['en', 'zh_Hant']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$language home, navigation, editor and statistics at 320px scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final month = CalendarMonth(2026, 10),
              categories = recommendedCategories();
          final data = LedgerMonthData(
            month: month,
            budget: MonthlyBudget(
              month: month,
              amount: const Money.fromFen(160000),
              updatedAtUtcMs: 0,
            ),
            entries: [],
            categories: categories,
          );
          final budget = BudgetSnapshot(
            month: month,
            period: MonthPeriod.current,
            budget: const Money.fromFen(160000),
            spent: const Money.fromFen(0),
            remaining: const Money.fromFen(160000),
            remainingDays: 12,
            dailyAllowance: const Money.fromFen(13333),
          );
          await tester.pumpWidget(
            PocketFlowApp(
              language: language,
              glass: true,
              home: PocketFlowShell(
                home: HomePage(month: month, state: AsyncData((data, budget))),
                statistics: StatisticsPage(
                  month: month,
                  state: AsyncData(data),
                  clock: _Clock(),
                ),
                settings: const SizedBox(),
                ledger: const SizedBox(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            PocketFlowApp(
              language: language,
              home: QuickEntryPage(
                categories: categories,
                clock: _Clock(),
                onSave: (_) async => throw StateError('not used'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      '$language settings and history fit narrow screens with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          PocketFlowApp(
            language: language,
            glass: true,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: SettingsPage(
                  language: language,
                  onLanguageChanged: (_) {},
                  onGlassSelected: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final title = language == 'en' ? 'Language' : '語言';
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.text('English'), findsWidgets);
        expect(find.text('繁體中文'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          PocketFlowApp(
            language: language,
            home: const ReleaseHistoryPage(installedVersion: '0.3.1'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(language == 'en' ? 'Version history' : '更新記錄'),
          findsOneWidget,
        );
      },
    );
  }
  testWidgets(
    'language switches the running app and persists without rewriting user content',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repository = DriftLedgerRepository(db, clock: _Clock());
      await tester.runAsync(
        () => repository.watchMonth(CalendarMonth(2026, 10)).first,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ledgerRepositoryProvider.overrideWithValue(repository),
            clockProvider.overrideWithValue(_Clock()),
          ],
          child: const PocketFlowRoot(),
        ),
      );
      await tester.pumpAndSettle();
      final data = await tester.runAsync(
        () => repository.watchMonth(CalendarMonth(2026, 10)).first,
      );
      final category = data!.categories.first;
      String? builtin, custom;
      await tester.runAsync(() => repository.savePreferences(locale: 'en'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 80));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
      }
      expect(find.text('Overview'), findsOneWidget);
      final context = tester.element(find.text('Overview'));
      builtin = localizedCategoryLabel(context, category.id, category.name);
      custom = localizedCategoryLabel(context, 'custom-test', category.name);
      expect(builtin, isNot(category.name));
      expect(custom, category.name);
      expect(localizedCategoryLabel(context, category.id, '自定义 早餐'), '自定义 早餐');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
    },
  );
}
