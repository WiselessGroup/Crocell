import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notify/alerts.dart';
import 'sysproxy/controller.dart';
import 'theme.dart';
import 'ui/home.dart';
import 'update/how_to_update.dart';

void main() {
  runApp(const ProviderScope(child: CrocellApp()));
}

class CrocellApp extends ConsumerWidget {
  const CrocellApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the desktop proxy settings in step with the connection.
    ref.watch(systemProxyControllerProvider);
    // System notifications when the connection fails or stops working.
    ref.watch(connectionAlertsProvider);
    // A click on "new version" opens how to update.
    ref.watch(updatePromptProvider);

    return MaterialApp(
      title: 'Crocell',
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: crocellTheme(Brightness.light),
      darkTheme: crocellTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
