import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import '../core/domain/ledger_models.dart';
import '../core/domain/category_catalog.dart';
import '../core/domain/catalog_upgrade.dart';
import 'message_keys.dart';
import 'message_catalogs.dart';

/// Local, packaged ARB resources. User-authored text never enters translation.
class AppStrings {
  AppStrings(this.language, this.messages);
  final String language;
  final Map<String, dynamic> messages;
  static const supportedLocales = [
    Locale('zh', 'CN'),
    Locale('zh', 'TW'),
    Locale('en', 'US'),
  ];
  static const delegate = _AppStringsDelegate();
  static Locale localeFor(String language) => switch (language) {
    'zh_Hant' => const Locale('zh', 'TW'),
    'en' => const Locale('en', 'US'),
    _ => const Locale('zh', 'CN'),
  };
  static String languageFor(Locale locale) => locale.languageCode == 'en'
      ? 'en'
      : locale.countryCode == 'TW' || locale.scriptCode == 'Hant'
      ? 'zh_Hant'
      : 'zh_Hans';
  String text(String source, [List<Object?> arguments = const []]) {
    final value = messages[messageKeys[source]] as String? ?? source;
    return value.replaceAllMapped(RegExp(r'\{p?(\d+)\}'), (match) {
      final index = int.parse(match[1]!);
      return index < arguments.length
          ? arguments[index]?.toString() ?? ''
          : match[0]!;
    });
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();
  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) {
    final language = AppStrings.languageFor(locale);
    return SynchronousFuture(AppStrings(language, messageCatalogs[language]!));
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

String tr(
  BuildContext context,
  String source, [
  List<Object?> arguments = const [],
]) {
  final strings = Localizations.of<AppStrings>(context, AppStrings);
  return (strings ?? AppStrings('zh_Hans', const {})).text(source, arguments);
}

final _builtinCategoryNames = _categoryNames();
Map<String, Set<String>> _categoryNames() {
  final names = <String, Set<String>>{};
  for (final category in [
    ...recommendedCategories(),
    ...generalRecommendedCategories(),
  ]) {
    names.putIfAbsent(category.id, () => {}).add(category.name);
  }
  for (final catalog in [
    recommendedCategories(),
    generalRecommendedCategories(),
  ]) {
    for (final category in catalog) {
      final parent = catalog
          .where((c) => c.id == category.parentId)
          .firstOrNull;
      if (parent != null) {
        names[category.id]!.add('${parent.name} · ${category.name}');
      }
    }
  }
  return names;
}

String localizedCategoryLabel(BuildContext context, String id, String name) =>
    (_builtinCategoryNames[id]?.contains(name) ?? false)
    ? name.split(' · ').map((part) => tr(context, part)).join(' · ')
    : name;
String localizedCategoryName(BuildContext context, Category category) =>
    localizedCategoryLabel(context, category.id, category.name);
String localizedCategoryById(
  BuildContext context,
  String id,
  List<Category> all,
) {
  final category = all.where((c) => c.id == id).firstOrNull;
  return category == null ? id : localizedCategoryName(context, category);
}

String localizedCategoryPath(
  BuildContext context,
  Category category,
  List<Category> all,
) {
  final parent = all.where((c) => c.id == category.parentId).firstOrNull;
  final name = localizedCategoryName(context, category);
  return parent == null
      ? name
      : '${localizedCategoryName(context, parent)} · $name';
}
