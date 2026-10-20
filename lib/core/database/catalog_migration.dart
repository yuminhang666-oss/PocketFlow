import 'package:drift/drift.dart';
import '../domain/catalog_upgrade.dart';
import '../domain/ledger_models.dart' as model;
import '../domain/ledger_entry.dart';
import 'app_database.dart' show AppDatabase;

/// Explicitly authorized schema-upgrade scope; caller holds the upgrade
/// transaction. This updates only category metadata, never ledger fields.
Future<void> applyCatalogUpgrade(AppDatabase db) async {
  final rows = await db.customSelect('SELECT * FROM categories').get();
  final current = [
    for (final r in rows)
      model.Category(
        id: r.read<String>('id'),
        name: r.read<String>('name'),
        sortOrder: r.read<int>('sort_order'),
        isArchived: r.read<int>('is_archived') == 1,
        parentId: r.data['parent_id'] as String?,
        kind: r.data['category_kind'] == null
            ? null
            : EntryKind.values.byName(r.read<String>('category_kind')),
      ),
  ];
  final preview = previewCatalogUpgrade(current, catalogVersion: 0),
      ids = current.map((c) => c.id).toSet();
  for (final c in preview.categories.where(
    (c) => preview.changed.contains(c.id),
  )) {
    if (ids.contains(c.id)) {
      await db.customUpdate(
        'UPDATE categories SET name=?,sort_order=?,is_archived=? WHERE id=?',
        variables: [
          Variable.withString(c.name),
          Variable.withInt(c.sortOrder),
          Variable.withInt(c.isArchived ? 1 : 0),
          Variable.withString(c.id),
        ],
        updates: {db.categories},
      );
    } else {
      await db.customInsert(
        'INSERT INTO categories(id,name,sort_order,is_archived,category_kind,parent_id) VALUES (?,?,?,?,?,?)',
        variables: [
          Variable.withString(c.id),
          Variable.withString(c.name),
          Variable.withInt(c.sortOrder),
          Variable.withInt(c.isArchived ? 1 : 0),
          Variable<String>(c.kind?.name),
          Variable<String>(c.parentId),
        ],
        updates: {db.categories},
      );
    }
  }
}
