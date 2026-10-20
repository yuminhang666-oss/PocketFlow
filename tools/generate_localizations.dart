import 'dart:convert';
import 'dart:io';

/// Run from the project root after editing lib/l10n/*.arb.
void main() {
  final output = StringBuffer(
    '// Generated from the packaged ARB resources.\nconst messageCatalogs = <String, Map<String, String>>{\n',
  );
  final sourceKeys = <String, String>{};
  Set<String>? expected;
  String literal(Object? value) => jsonEncode(value).replaceAll(r'$', r'\$');
  for (final language in ['zh_Hans', 'zh_Hant', 'en']) {
    final map =
        jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
            as Map<String, dynamic>;
    final keys = map.keys.where((key) => !key.startsWith('@')).toSet();
    expected ??= keys;
    if (keys.length != expected.length || !keys.containsAll(expected)) {
      throw FormatException('Language keys differ: $language');
    }
    output.writeln('  "$language": {');
    for (final key in keys) {
      output.writeln('    ${literal(key)}: ${literal(map[key])},');
      if (language == 'zh_Hans') {
        final source = (map[key] as String).replaceAllMapped(
          RegExp(r'\{p(\d+)\}'),
          (m) => '{${m[1]}}',
        );
        sourceKeys[source] = key;
      }
    }
    output.writeln('  },');
  }
  output.writeln('};');
  File('lib/l10n/message_catalogs.dart').writeAsStringSync(output.toString());
  File('lib/l10n/message_keys.dart').writeAsStringSync(
    '// Generated from app_zh_Hans.arb. User-authored values stay unchanged.\nconst messageKeys = <String, String>{\n${sourceKeys.entries.map((e) => '  ${literal(e.key)}: ${literal(e.value)},').join('\n')}\n};\n',
  );
}
