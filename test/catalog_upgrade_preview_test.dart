import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/core/domain/category_catalog.dart';
import 'package:pocketflow/core/domain/catalog_upgrade.dart';
import 'package:pocketflow/core/domain/ledger_models.dart';
import 'package:pocketflow/core/domain/ledger_entry.dart';

void main() {
  test(
    'custom incompatible root is retained without injecting wrong-kind children',
    () {
      final preview = previewCatalogUpgrade([
        Category(
          id: 'food',
          name: '自定义收入',
          sortOrder: 999,
          kind: EntryKind.income,
        ),
      ], catalogVersion: 0);
      expect(
        preview.categories.firstWhere((c) => c.id == 'food').name,
        '自定义收入',
      );
      expect(preview.categories.where((c) => c.parentId == 'food'), isEmpty);
    },
  );
  test(
    'pure preview archives only complete untouched historical branches and retains IDs',
    () {
      final old = recommendedCategories();
      expect(old.length, 87);
      final preview = previewCatalogUpgrade(old, catalogVersion: 0);
      for (final id in [
        'income_tutoring',
        'income_tutoring_english',
        'income_tutoring_math',
      ]) {
        final c = preview.categories.firstWhere((c) => c.id == id);
        expect(c.isArchived, isTrue);
        expect(c.name, old.firstWhere((c) => c.id == id).name);
      }
      expect(
        old.every((c) => preview.categories.any((v) => v.id == c.id)),
        isTrue,
      );
      expect(
        preview.categories.any(
          (c) => c.parentId == 'income_labor' && c.name == '家教',
        ),
        isTrue,
      );
      expect(
        old.every((c) => !c.isArchived),
        isTrue,
      ); // original objects untouched
    },
  );
  test('renamed child or custom descendant preserves entire branch', () {
    for (final custom in [false, true]) {
      final old = recommendedCategories()
          .map(
            (c) => c.id == 'income_tutoring_math' && !custom
                ? Category(
                    id: c.id,
                    name: '自定义课程',
                    sortOrder: c.sortOrder,
                    kind: c.kind,
                    parentId: c.parentId,
                  )
                : c,
          )
          .toList();
      if (custom) {
        old.add(
          Category(
            id: 'custom-child',
            name: '自定义',
            sortOrder: 999,
            kind: old.firstWhere((c) => c.id == 'income_tutoring').kind,
            parentId: 'income_tutoring',
          ),
        );
      }
      final preview = previewCatalogUpgrade(old, catalogVersion: 0);
      expect(preview.preservedBranches, contains('income_tutoring'));
      expect(
        preview.categories
            .where(
              (c) =>
                  c.id == 'income_tutoring' || c.parentId == 'income_tutoring',
            )
            .every((c) => !c.isArchived),
        isTrue,
      );
    }
  });
  test('custom name/order/archive survives; v1 preview is idempotent', () {
    final old = recommendedCategories()
        .map(
          (c) => c.id == 'food'
              ? Category(
                  id: c.id,
                  name: '我的餐饮',
                  sortOrder: 999,
                  isArchived: true,
                  kind: c.kind,
                )
              : c,
        )
        .toList();
    final first = previewCatalogUpgrade(old, catalogVersion: 0);
    final food = first.categories.firstWhere((c) => c.id == 'food');
    expect(food.name, '我的餐饮');
    expect(food.sortOrder, 999);
    expect(food.isArchived, isTrue);
    final second = previewCatalogUpgrade(first.categories, catalogVersion: 1);
    expect(second.changed, isEmpty);
    expect(second.categories, first.categories);
  });
}
