import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'data/core_api.dart';
import 'data/state.dart';
import 'l10n.dart';
import 'platform/android.dart';

import 'notify/alerts.dart';
import 'sysproxy/controller.dart';
import 'theme.dart';
import 'ui/home.dart';
import 'update/how_to_update.dart';

Future<void> main() async {
  final overrides = <Override>[];
  if (Platform.isAndroid) {
    // The core runs inside the app here; the platform side knows its socket.
    WidgetsFlutterBinding.ensureInitialized();
    final socket = await androidCore.invokeMethod<String>('socketPath');
    overrides.add(coreEndpointProvider.overrideWithValue(CoreEndpoint.unix(socket!)));
  }
  runApp(ProviderScope(overrides: overrides, child: const CrocellApp()));
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
      locale: appLocale,
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeScreen(),
    );
  }
}
