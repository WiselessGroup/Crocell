import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/core_api.dart';
import 'data/state.dart';
import 'host.dart';
import 'sysproxy/controller.dart';
import 'tray/tray.dart';

/// Ends the process. Overridden in tests.
final appExitProvider = Provider<void Function()>((ref) => () => exit(0));

/// How long to wait for the service to confirm before closing anyway.
const _quitPatience = Duration(seconds: 2);

/// "Quit completely" from the tray: the service stops and says so in the
/// status, and [quitOnRequestProvider] closes the app. The setting and the last
/// connection stay as they are, so the next start carries on from there.
Future<void> quitCompletely(Ref ref) async {
  try {
    await ref.read(coreApiProvider).shutdown();
  } on CoreError catch (e) {
    debugPrint('quit: $e'); // no service to stop, the app still closes
    await _leave(ref);
    return;
  }
  Timer(_quitPatience, () => _leave(ref));
}

var _leaving = false;

Future<void> _leave(Ref ref) async {
  if (_leaving) return;
  _leaving = true;
  // The port is about to die, and the browser must not be left pointing at it.
  await ref.read(systemProxyProvider).restore().catchError((Object e) => debugPrint('quit: $e'));
  if (trayShownOn(ref.read(hostProvider))) {
    await ref.read(trayPlatformProvider).destroy().catchError((Object e) => debugPrint('quit: $e'));
  }
  ref.read(appExitProvider)();
  _leaving = false; // only matters in tests, where exit is a stub
}

/// Closes the app when the service announces it is quitting, whoever asked:
/// the tray here, or the GNOME menu with the window open.
final quitOnRequestProvider = Provider<void>((ref) {
  ref.listen(statusProvider, (_, next) {
    if (next.value?.quitting ?? false) unawaited(_leave(ref));
  });
});
