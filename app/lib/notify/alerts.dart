import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/state.dart';
import '../l10n.dart';
import '../logs.dart';
import '../ui/format.dart';

/// Where alerts go. System notifications in the app, a list in tests.
abstract interface class Notifications {
  /// A [payload] makes the notification clickable: [taps] reports it.
  Future<void> show(String title, String body, {String? payload});

  /// Payloads of notifications the person clicked, also the one that
  /// launched the app.
  Stream<String> get taps;
}

class SystemNotifications implements Notifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  Future<bool?>? _ready;

  static bool get supported => Platform.isLinux || Platform.isMacOS || Platform.isWindows || Platform.isAndroid;

  Future<bool?> _init() => _ready ??= () async {
        final ok = await _plugin.initialize(
          settings: InitializationSettings(
            android: const AndroidInitializationSettings('ic_notification'),
            linux: LinuxInitializationSettings(defaultActionName: tr('Открыть Crocell', 'Open Crocell')),
            macOS: const DarwinInitializationSettings(),
            windows: const WindowsInitializationSettings(
              appName: 'Crocell',
              appUserModelId: 'net.wiseless.crocell',
              guid: '6f3d2a8e-9b41-4c7e-8a55-2f1c0d7e4b93',
            ),
          ),
          onDidReceiveNotificationResponse: (r) => _tapped(r.payload),
        );
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) _tapped(launch!.notificationResponse?.payload);
        // Android 13+ shows nothing until the person allows it.
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        return ok;
      }();

  void _tapped(String? payload) {
    if (payload == null || payload.isEmpty) return;
    presentWindow();
    _taps.add(payload);
  }

  /// Starts listening for clicks, including the click that launched the app.
  Future<void> start() async {
    if (!supported) return;
    try {
      await _init();
    } catch (_) {}
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> show(String title, String body, {String? payload}) async {
    if (!supported) return;
    try {
      await _init();
      await _plugin.show(
        // One id per kind: a new alert replaces the previous one instead
        // of piling up, and an update notice does not wipe out an alert.
        id: payload == null ? 1 : 2,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails('alerts', tr('Состояние VPN', 'VPN status'),
              channelDescription: tr('Сбои подключения и новые версии Crocell', 'Connection failures and new Crocell versions')),
        ),
      );
    } catch (_) {
      // No notification daemon (bare WM, CI): the in-app warning still shows.
    }
  }
}

const _window = MethodChannel('crocell/window');

/// Brings the Crocell window to the front, as a notification click should.
Future<void> presentWindow() async {
  try {
    await _window.invokeMethod<void>('present');
  } catch (_) {
    // Not implemented here (Android opens the activity by itself).
  }
}

final notificationsProvider = Provider<Notifications>((ref) {
  final n = SystemNotifications();
  n.start();
  return n;
});

/// What went wrong, in words, or null when nothing worth interrupting for.
/// Pure, so the rules are testable without a notification server.
({String title, String body})? alertFor(Status? prev, Status? next, {String nodeName = ''}) {
  final node = nodeName.isEmpty ? tr('Нода', 'The node') : tr('Нода «$nodeName»', 'Node "$nodeName"');

  if (next == null) {
    // The service vanished. Only news if a VPN was supposed to be running.
    if (prev != null && prev.isConnected) {
      return (
        title: tr('Служба Crocell остановилась', 'Crocell service stopped'),
        body: tr('VPN мог отключиться. Откройте Crocell, чтобы проверить.', 'The VPN may have disconnected. Open Crocell to check.'),
      );
    }
    return null;
  }

  if (next.isFailed && (prev == null || !prev.isFailed)) {
    return (
      title: tr('Не удалось подключиться', "Couldn't connect"),
      body: next.error.isNotEmpty ? next.error : tr('Попробуйте выбрать другую ноду.', 'Try picking another node.'),
    );
  }

  if (!next.isConnected || !next.hasLiveCheck()) return null;
  final wasBroken = prev != null && prev.isConnected && prev.hasLiveCheck() && prev.liveCheck.error.isNotEmpty;
  final isBroken = next.liveCheck.error.isNotEmpty;
  final sameNode = prev != null && prev.nodeId == next.nodeId;

  if (isBroken && !wasBroken) {
    return (
      title: tr('VPN подключён, но интернет не идёт', "VPN is connected, but there's no internet"),
      body: tr('$node не отвечает. Выберите другую в списке.', '$node is not responding. Pick another one from the list.'),
    );
  }
  if (!isBroken && wasBroken && sameNode) {
    return (
      title: tr('Интернет через VPN снова работает', 'Internet through VPN works again'),
      body: tr('Выход: ${exitPlace(next.liveCheck)}.', 'Exit: ${exitPlace(next.liveCheck)}.'),
    );
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
    if (alert != null) {
      appLog('${alert.title}: ${alert.body}');
      ref.read(notificationsProvider).show(alert.title, alert.body);
    }
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
