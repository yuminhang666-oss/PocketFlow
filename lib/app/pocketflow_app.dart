import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class PocketFlowApp extends StatelessWidget {
  const PocketFlowApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PocketFlow',
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E6B58)),
          scaffoldBackgroundColor: const Color(0xFFF5F6F2),
        ),
        home: const _HomeFoundation(),
      );
}

/// Phase-one empty state. Real budget/database actions arrive in the MVP.
class _HomeFoundation extends StatelessWidget {
  const _HomeFoundation();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('PocketFlow')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('把生活费，安排得刚刚好',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF153E35),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('每日可支配', style: TextStyle(color: Colors.white70)),
                          SizedBox(height: 16),
                          Text('待设置预算',
                              style: TextStyle(fontSize: 28, color: Colors.white)),
                          SizedBox(height: 12),
                          Text('设置本月生活费后，查看每天的参考额度',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('最近消费', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    const Text('还没有消费记录'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
