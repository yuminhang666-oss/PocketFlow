import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../shared/widgets/status_panel.dart';
import 'theme/pocketflow_theme.dart';
import 'theme/frosted_glass.dart';

/// The root composition supplies home. No mock repository is installed here.
class PocketFlowApp extends StatelessWidget {
  const PocketFlowApp({
    super.key,
    this.home,
    this.themeMode = ThemeMode.system,
    this.glass = false,
    this.language = 'zh_Hans',
    this.navigatorObservers = const [],
  });
  final Widget? home;
  final ThemeMode themeMode;
  final bool glass;
  final String language;
  final List<NavigatorObserver> navigatorObservers;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PocketFlow',
    debugShowCheckedModeBanner: false,
    locale: AppStrings.localeFor(language),
    supportedLocales: AppStrings.supportedLocales,
    localizationsDelegates: const [
      AppStrings.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    theme: glass
        ? PocketFlowTheme.glass(Brightness.light)
        : PocketFlowTheme.light,
    darkTheme: glass
        ? PocketFlowTheme.glass(Brightness.dark)
        : PocketFlowTheme.dark,
    builder: (context, child) =>
        glass ? FrostedBackdrop(child: child!) : child!,
    themeMode: glass ? ThemeMode.light : themeMode,
    navigatorObservers: navigatorObservers,
    home:
        home ??
        Scaffold(
          body: SafeArea(
            child: Center(
              child: StatusPanel(title: tr(context, "正在准备账本"), loading: true),
            ),
          ),
        ),
  );
}
