import 'dart:convert';

import '../../../contracts/contracts.dart';
import '../../../core/domain/category_catalog.dart';

/// Read external backup v1/v2 and write v2. No database writes or type coercion.
final class JsonBackupCodec implements BackupCodec {
  const JsonBackupCodec();

  @override
  BackupDocument decode(String content) {
    try {
      final root = _object(jsonDecode(content));
      if (_string(root, 'appId') != BackupDocument.appId ||
          _string(root, 'currency') != BackupDocument.currency) {
        throw const FormatException('Wrong application or currency');
      }
      final version = _integer(root, 'formatVersion');
      if (version < 1 || version > BackupDocument.formatVersion) {
        throw const PocketFlowException(
          PocketFlowErrorCode.unsupportedBackupVersion,
        );
      }
      final document = BackupDocument(
        exportedAtUtcMs: _timestamp(root, 'exportedAtUtcMs'),
        profile: version == 1
            ? PersonalProfile()
            : PersonalProfile.fromJson(_object(root['profile'])),
        categories: _array(root, 'categories').map((value) {
          final row = _object(value);
          final archived = row['isArchived'];
          if (archived is! bool) throw const FormatException('Invalid boolean');
          return Category(
            id: _string(row, 'id'),
            name: _string(row, 'name'),
            sortOrder: _integer(row, 'sortOrder'),
            isArchived: archived,
            kind: version == 1 || row['kind'] == null
                ? null
                : EntryKind.values.byName(_string(row, 'kind')),
            parentId: version == 1 ? null : row['parentId'] as String?,
          );
        }),
        budgets: _array(root, 'budgets').map((value) {
          final row = _object(value);
          return MonthlyBudget(
            month: CalendarMonth.parse(_string(row, 'month')),
            amount: Money.fromFen(_integer(row, 'amountFen')),
            updatedAtUtcMs: _timestamp(row, 'updatedAtUtcMs'),
          );
        }),
        entries: _array(root, 'entries').map((value) {
          final row = _object(value);
          final kind = switch (_string(row, 'kind')) {
            'expense' => EntryKind.expense,
            'income' => EntryKind.income,
            _ => throw const FormatException('Unknown entry kind'),
          };
          return LedgerEntry(
            id: _string(row, 'id'),
            amount: Money.fromFen(_integer(row, 'amountFen')),
            localDate: _string(row, 'localDate'),
            categoryId: _string(row, 'categoryId'),
            kind: kind,
            note: _string(row, 'note'),
            occurredAtUtcMs: _timestamp(row, 'occurredAtUtcMs'),
            createdAtUtcMs: _timestamp(row, 'createdAtUtcMs'),
            updatedAtUtcMs: _timestamp(row, 'updatedAtUtcMs'),
          );
        }),
      );
      _validate(document);
      return document;
    } on PocketFlowException {
      rethrow;
    } catch (_) {
      // Do not retain parser excerpts containing a financial note in diagnostics.
      throw const PocketFlowException(PocketFlowErrorCode.invalidBackup);
    }
  }

  @override
  String encode(BackupDocument document) {
    try {
      _validate(document);
      return '${const JsonEncoder.withIndent('  ').convert({
        'appId': BackupDocument.appId,
        'formatVersion': BackupDocument.formatVersion,
        'exportedAtUtcMs': document.exportedAtUtcMs,
        'currency': BackupDocument.currency,
        'profile': document.profile.toJson(),
        'budgets': [
          for (final b in document.budgets) {'month': b.month.key, 'amountFen': b.amount.fen, 'updatedAtUtcMs': b.updatedAtUtcMs},
        ],
        'categories': [
          for (final c in document.categories) {'id': c.id, 'name': c.name, 'sortOrder': c.sortOrder, 'isArchived': c.isArchived, 'kind': c.kind?.name, 'parentId': c.parentId},
        ],
        'entries': [
          for (final e in document.entries) {'id': e.id, 'amountFen': e.amount.fen, 'kind': e.kind.name, 'localDate': e.localDate, 'occurredAtUtcMs': e.occurredAtUtcMs, 'categoryId': e.categoryId, 'note': e.note, 'createdAtUtcMs': e.createdAtUtcMs, 'updatedAtUtcMs': e.updatedAtUtcMs},
        ],
      })}\n';
    } catch (_) {
      throw const PocketFlowException(PocketFlowErrorCode.invalidBackup);
    }
  }

  Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected object');
    }
    return value;
  }

  List<dynamic> _array(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! List<dynamic>) throw const FormatException('Expected array');
    return value;
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) throw const FormatException('Expected string');
    return value;
  }

  int _integer(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! int) throw const FormatException('Expected integer');
    return value;
  }

  int _timestamp(Map<String, dynamic> row, String key) {
    final value = _integer(row, key);
    _checkTimestamp(value);
    return value;
  }

  void _checkTimestamp(int value) {
    if (value < -8640000000000000 || value > 8640000000000000) {
      throw const FormatException('Invalid timestamp');
    }
  }

  void _validate(BackupDocument document) {
    _checkTimestamp(document.exportedAtUtcMs);
    final categories = <String>{};
    final entries = <String>{};
    final months = <String>{};
    for (final c in document.categories) {
      if (!categories.add(c.id) ||
          c.id.isEmpty ||
          c.id.length > 64 ||
          c.name.trim().isEmpty ||
          c.name.length > 30) {
        throw const FormatException('Invalid or duplicate category');
      }
    }
    for (final b in document.budgets) {
      if (!months.add(b.month.key) ||
          b.amount.fen < 0 ||
          b.amount.fen > Money.maxInputFen) {
        throw const FormatException('Invalid or duplicate budget');
      }
      _checkTimestamp(b.updatedAtUtcMs);
    }
    validateCategoryGraph(document.categories);
    validateCategoryAssignments(
      categories: document.categories,
      entries: document.entries,
      templates: document.profile.templates,
    );
    for (final t in document.profile.templates) {
      if (!categories.contains(t.categoryId)) {
        throw const FormatException('Missing template category');
      }
    }
    for (final e in document.entries) {
      if (!entries.add(e.id) ||
          !categories.contains(e.categoryId) ||
          e.id.isEmpty ||
          e.id.length > 64 ||
          e.amount.fen <= 0 ||
          e.amount.fen > Money.maxInputFen ||
          e.note.length > 500 ||
          e.updatedAtUtcMs < e.createdAtUtcMs) {
        throw const FormatException('Invalid entry or relation');
      }
      _checkTimestamp(e.occurredAtUtcMs);
      _checkTimestamp(e.createdAtUtcMs);
      _checkTimestamp(e.updatedAtUtcMs);
    }
  }
}
