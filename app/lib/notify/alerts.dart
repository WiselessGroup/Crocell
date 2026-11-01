import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/state.dart';
import '../ui/format.dart';

/// Where alerts go. System notifications in the app, a list in tests.
abstract interface class Notifications {
  Future<void> show(String title, String body);
}

class SystemNotifications implements Notifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool?>? _ready;

  Future<bool?> _init() => _ready ??= _plugin.initialize(
        settings: const InitializationSettings(
          linux: LinuxInitializationSettings(defaultActionName: 'Открыть Crocell'),
          macOS: DarwinInitializationSettings(),
          windows: WindowsInitializationSettings(
            appName: 'Crocell',
            appUserModelId: 'net.wiseless.crocell',
            guid: '6f3d2a8e-9b41-4c7e-8a55-2f1c0d7e4b93',
          ),
        ),
      );

  @override
  Future<void> show(String title, String body) async {
    if (!(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) return;
    try {
      await _init();
      // One id: a new alert replaces the previous one instead of piling up.
      await _plugin.show(id: 1, title: title, body: body);
    } catch (_) {
      // No notification daemon (bare WM, CI): the in-app warning still shows.
    }
  }
}

final notificationsProvider = Provider<Notifications>((ref) => SystemNotifications());

/// What went wrong, in words, or null when nothing worth interrupting for.
/// Pure, so the rules are testable without a notification server.
({String title, String body})? alertFor(Status? prev, Status? next, {String nodeName = ''}) {
  final node = nodeName.isEmpty ? 'Нода' : 'Нода «$nodeName»';

  if (next == null) {
    // The service vanished. Only news if a VPN was supposed to be running.
    if (prev != null && prev.isConnected) {
      return (title: 'Служба Crocell остановилась', body: 'VPN мог отключиться. Откройте Crocell, чтобы проверить.');
    }
    return null;
  }

  if (next.isFailed && (prev == null || !prev.isFailed)) {
    return (
      title: 'Не удалось подключиться',
      body: next.error.isNotEmpty ? next.error : 'Попробуйте выбрать другую ноду.',
    );
  }

  if (!next.isConnected || !next.hasLiveCheck()) return null;
  final wasBroken = prev != null && prev.isConnected && prev.hasLiveCheck() && prev.liveCheck.error.isNotEmpty;
  final isBroken = next.liveCheck.error.isNotEmpty;
  final sameNode = prev != null && prev.nodeId == next.nodeId;

  if (isBroken && !wasBroken) {
    return (title: 'VPN подключён, но интернет не идёт', body: '$node не отвечает. Выберите другую в списке.');
  }
  if (!isBroken && wasBroken && sameNode) {
    return (title: 'Интернет через VPN снова работает', body: 'Выход: ${exitPlace(next.liveCheck)}.');
  }
  return null;
}

/// Watches the connection and raises a system notification when it breaks.
/// Watch it once from the root widget.
final connectionAlertsProvider = Provider<void>((ref) {
  Status? last;
  var reachable = true;

  void consider(Status? next) {
    final subs = ref.read(subscriptionsProvider).value ?? const <Subscription>[];
    final name = next == null ? '' : (findNode(subs, next.subscriptionId, next.nodeId)?.node.name ?? '');
    final alert = alertFor(last, next, nodeName: displayName(name));
    if (alert != null) ref.read(notificationsProvider).show(alert.title, alert.body);
    last = next;
  }

  ref.listen(statusProvider, (_, next) {
    switch (next) {
      case AsyncData(:final value):
        reachable = true;
        consider(value);
      case AsyncError():
        if (reachable) consider(null); // say it once, not on every retry
        reachable = false;
      default:
    }
  });
});
