import 'package:crocell/data/core_api.dart';
import 'package:crocell/host.dart';
import 'package:crocell/l10n.dart';
import 'package:crocell/platform/autostart.dart';
import 'package:crocell/quit.dart';
import 'package:crocell/tray/tray.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart' show pumpApp, unmount, RecordingProxy, RecordingNotifications;
import 'support/fake_core.dart';

class RecordingTray implements TrayPlatform {
  TrayLook? look;
  String? tooltip;
  List<TrayEntry> menu = [];
  var updates = 0;
  var destroyed = false;

  @override
  Future<void> show(TrayLook look, String tooltip, List<TrayEntry> menu) async {
    this.look = look;
    this.tooltip = tooltip;
    this.menu = menu;
    updates++;
  }

  @override
  Future<void> destroy() async => destroyed = true;

  void tap(String label) => menu.firstWhere((e) => e.label == label).onTap!();
  List<String?> get labels => [for (final e in menu) e.label];
}

class NoActions implements TrayActions {
  @override
  void connect() {}
  @override
  void connectTo(FavoriteNode node) {}
  @override
  void disconnect() {}
  @override
  void open() {}
  @override
  void quit() {}
  @override
  void refreshAll() {}
}

FavoriteNode fav(String id) => FavoriteNode(subscriptionId: 'sub1', nodeId: id, name: 'Node $id');

void main() {
  test('the icon is red unless connected, dimmed while changing', () {
    expect(trayLook(null), TrayLook.off);
    expect(trayLook(Status(state: ConnectionState.CONNECTION_STATE_DISCONNECTED)), TrayLook.off);
    expect(trayLook(Status(state: ConnectionState.CONNECTION_STATE_FAILED)), TrayLook.off);
    expect(trayLook(Status(state: ConnectionState.CONNECTION_STATE_CONNECTING)), TrayLook.busy);
    expect(trayLook(Status(state: ConnectionState.CONNECTION_STATE_DISCONNECTING)), TrayLook.busy);
    expect(trayLook(Status(state: ConnectionState.CONNECTION_STATE_CONNECTED)), TrayLook.on);
  });

  test('the menu shows three favourites, not counting the current node', () {
    final labels = trayMenu(
      Status(
        state: ConnectionState.CONNECTION_STATE_CONNECTED,
        subscriptionId: 'sub1',
        nodeId: 'b',
        nodeName: 'Node b',
        favorites: [fav('a'), fav('b'), fav('c'), fav('d')],
      ),
      NoActions(),
    ).map((e) => e.label).toList();
    expect(labels.where((l) => l?.startsWith('Node') ?? false), ['Node a', 'Node c', 'Node d']);
    expect(labels.first, 'Crocell: Node b');
  });

  test('Kill Switch has the internet cut off: the menu offers the way out', () {
    final menu = trayMenu(Status(state: ConnectionState.CONNECTION_STATE_FAILED, killSwitchBlocking: true), NoActions());
    expect(menu.first.label, 'Crocell: Интернет заблокирован');
    expect(menu.map((e) => e.label), contains('Отключить'));
    expect(menu.map((e) => e.label), isNot(contains('Подключить')));
  });

  test('no service: only opening the app and leaving', () {
    final menu = trayMenu(null, NoActions());
    expect(menu.where((e) => e.onTap != null).map((e) => e.label),
        [tr('Открыть Crocell', 'Open Crocell'), tr('Выйти совсем', 'Quit completely')]);
  });

  testWidgets('the tray follows the status and redraws only on a change', (tester) async {
    final tray = RecordingTray();
    final core = await pumpApp(tester, FakeCore(subs: [sampleSubscription()]), overrides: [
      hostProvider.overrideWithValue(const Host(HostKind.windows)),
      trayPlatformProvider.overrideWithValue(tray),
    ]);
    expect(tray.look, TrayLook.off);

    tray.tap('Подключить');
    await tester.pumpAndSettle();
    expect(core.calls, contains('connect'));
    expect(tray.look, TrayLook.on);

    final before = tray.updates;
    core.push(core.current.deepCopy()..checking = true);
    await tester.pumpAndSettle();
    expect(tray.updates, before, reason: 'same look, same menu');

    core.push(core.current.deepCopy()..favorites.add(fav('n2')));
    await tester.pumpAndSettle();
    tray.tap('Node n2');
    await tester.pumpAndSettle();
    expect(core.calls, contains('connect n2'));
    await unmount(tester);
  });

  testWidgets('a favourite that failed to refresh is named in a notification', (tester) async {
    final tray = RecordingTray();
    final alerts = RecordingNotifications();
    final core = FakeCore(subs: [sampleSubscription()])
      ..refreshFailures = [RefreshFailure(subscriptionId: 'sub1', title: 'WISELESS', error: 'HTTP 502')];
    await pumpApp(tester, core, notifications: alerts, overrides: [
      hostProvider.overrideWithValue(const Host(HostKind.macos)),
      trayPlatformProvider.overrideWithValue(tray),
    ]);
    tray.tap('Обновить все подписки');
    await tester.pumpAndSettle();
    expect(core.calls, contains('refresh all'));
    expect(alerts.shown, contains('Не все подписки обновились'));
    await unmount(tester);
  });

  testWidgets('quit: the service stops, the proxy goes back, the icon goes, the app closes', (tester) async {
    final tray = RecordingTray();
    final proxy = RecordingProxy();
    var exited = 0;
    final core = await pumpApp(tester, FakeCore(), proxy: proxy, overrides: [
      hostProvider.overrideWithValue(const Host(HostKind.windows)),
      trayPlatformProvider.overrideWithValue(tray),
      appExitProvider.overrideWithValue(() => exited++),
    ]);
    proxy.log.clear();
    tray.tap('Выйти совсем');
    await tester.pumpAndSettle();
    expect(core.calls, contains('shutdown'));
    expect(proxy.log, contains('restore'));
    expect(tray.destroyed, isTrue);
    expect(exited, 1);
    await tester.pump(const Duration(seconds: 3)); // the fallback timer
    await unmount(tester);
  });

  testWidgets('the service quitting closes the app, whoever asked', (tester) async {
    var exited = 0;
    final core = await pumpApp(tester, FakeCore(), overrides: [appExitProvider.overrideWithValue(() => exited++)]);
    expect(exited, 0);
    core.push(core.current.deepCopy()..quitting = true);
    await tester.pumpAndSettle();
    expect(exited, 1);
    await unmount(tester);
  });

  group('autostart', () {
    late List<List<String>> calls;
    late String? stored;
    Future<String> reg(String exe, List<String> args) async {
      calls.add(args);
      if (args.first == 'query') {
        if (stored == null) throw Exception('not found');
        return 'HKEY_CURRENT_USER\\...\\Run\r\n    Crocell    REG_SZ    $stored\r\n';
      }
      stored = args.first == 'add' ? args[args.indexOf('/d') + 1] : null;
      return '';
    }

    Autostart make([String exe = r'C:\Program Files\Crocell\crocell.exe']) => Autostart(run: reg, executable: exe);

    setUp(() {
      calls = [];
      stored = null;
      SharedPreferences.setMockInitialValues({});
    });

    test('on by itself the first time, hidden', () async {
      await make().applyOnStart();
      expect(stored, r'"C:\Program Files\Crocell\crocell.exe" --hidden');
      expect(await make().isEnabled(), isTrue);
    });

    test('turned off stays off', () async {
      await make().applyOnStart();
      await make().setEnabled(false);
      expect(stored, isNull);
      await make().applyOnStart();
      expect(stored, isNull);
    });

    test('follows the app when it moves, only if on', () async {
      await make().applyOnStart();
      await make(r'D:\Crocell\crocell.exe').applyOnStart();
      expect(stored, r'"D:\Crocell\crocell.exe" --hidden');
      calls.clear();
      await make(r'D:\Crocell\crocell.exe').applyOnStart();
      expect(calls.where((c) => c.first == 'add'), isEmpty, reason: 'nothing to change');
    });
  });

  testWidgets('settings: the switch is there on Windows and not elsewhere', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester, FakeCore(), overrides: [
      hostProvider.overrideWithValue(const Host(HostKind.windows)),
      trayPlatformProvider.overrideWithValue(RecordingTray()),
      autostartProvider.overrideWithValue(Autostart(run: (_, _) async => '', executable: 'crocell.exe')),
    ]);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Запускать вместе с Windows'), findsOneWidget);
    await unmount(tester);
  });
}
