import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sysproxy/controller.dart';
import 'theme.dart';
import 'ui/home.dart';

void main() {
  runApp(const ProviderScope(child: CrocellApp()));
}

class CrocellApp extends ConsumerWidget {
  const CrocellApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the desktop proxy settings in step with the connection.
    ref.watch(systemProxyControllerProvider);

    return MaterialApp(
      title: 'Crocell',
      debugShowCheckedModeBanner: false,
      theme: crocellTheme(Brightness.light),
      darkTheme: crocellTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
