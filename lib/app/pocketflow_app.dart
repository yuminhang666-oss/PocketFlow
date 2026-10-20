import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../shared/widgets/status_panel.dart';
import 'theme/pocketflow_theme.dart';

/// The root composition supplies home. No mock repository is installed here.
class PocketFlowApp extends StatelessWidget {
  const PocketFlowApp({
    super.key,
    this.home,
    this.themeMode = ThemeMode.system,
    this.navigatorObservers = const [],
  });
  final Widget? home;
  final ThemeMode themeMode;
  final List<NavigatorObserver> navigatorObservers;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PocketFlow',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: PocketFlowTheme.light,
    darkTheme: PocketFlowTheme.dark,
    themeMode: themeMode,
    navigatorObservers: navigatorObservers,
    home:
        home ??
        const Scaffold(
          body: SafeArea(
            child: Center(child: StatusPanel(title: '正在准备账本', loading: true)),
          ),
        ),
  );
}
