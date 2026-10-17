import 'package:flutter/material.dart';

/// Slots let C own the charts and the root composition own injected services.
class PocketFlowShell extends StatefulWidget {
  const PocketFlowShell({
    super.key,
    required this.home,
    required this.statistics,
    required this.settings,
  });
  final Widget home;
  final Widget statistics;
  final Widget settings;
  @override
  State<PocketFlowShell> createState() => _PocketFlowShellState();
}

class _PocketFlowShellState extends State<PocketFlowShell> {
  int _selected = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selected,
      children: [widget.home, widget.statistics, widget.settings],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selected,
      onDestinationSelected: (value) => setState(() => _selected = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: '首页',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: '统计',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: '设置',
        ),
      ],
    ),
  );
}
