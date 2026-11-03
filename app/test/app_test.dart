import 'dart:async';

import 'package:crocell/brand/appearance.dart';
import 'package:crocell/data/core_api.dart';
import 'package:crocell/data/state.dart';
import 'package:crocell/host.dart';
import 'package:crocell/main.dart';
import 'package:crocell/notify/alerts.dart';
import 'package:crocell/sysproxy/controller.dart';
import 'package:crocell/sysproxy/sysproxy.dart';
import 'package:crocell/widgets/connect_button.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_core.dart';

/// Notifications that land in a list instead of on the desktop.
class RecordingNotifications implements Notifications {
  final shown = <String>[];
  @override
  Future<void> show(String title, String body, {String? payload}) async => shown.add(title);
  final tapped = StreamController<String>.broadcast();
  @override
  Stream<String> get taps => tapped.stream;
}

/// A system proxy that records instead of touching the desktop.
class RecordingProxy extends SystemProxy {
  RecordingProxy() : super(stateFile: '/nonexistent/crocell-test-sysproxy.json');
  final log = <String>[];
  @override
  bool get isSupported => true;
  @override
  Future<void> enable(int port) async => log.add('enable $port');
  @override
  Future<void> restore() async => log.add('restore');
}

Future<FakeCore> pumpApp(
  WidgetTester tester,
  FakeCore core, {
  Size size = const Size(420, 860),
  RecordingProxy? proxy,
  RecordingNotifications? notifications,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      coreApiProvider.overrideWithValue(core),
      systemProxyProvider.overrideWithValue(proxy ?? RecordingProxy()),
      notificationsProvider.overrideWithValue(notifications ?? RecordingNotifications()),
      ...overrides,
    ],
    child: const CrocellApp(),
  ));
  await tester.pumpAndSettle();
  return core;
}

/// The status stream retries on a timer; unmount and let it drain.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

Status connectedTo(String node) => Status(
      state: ConnectionState.CONNECTION_STATE_CONNECTED,
      subscriptionId: 'sub1',
      nodeId: node,
      tunnelMode: TunnelMode.TUNNEL_MODE_SYSTEM_PROXY,
      mixedPort: 7890,
    );

void main() {
  testWidgets('no daemon: explains how to install the service', (tester) async {
    await pumpApp(tester, FakeCore(unavailable: true));
    expect(find.text('Служба Crocell не запущена'), findsOneWidget);
    expect(find.text('sudo crocelld install'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('no subscription: the big button adds one, then the first node is picked', (tester) async {
    final core = await pumpApp(tester, FakeCore());
    expect(find.text('Нет подписки'), findsOneWidget);

    await tester.tap(find.byType(ConnectButton));
    await tester.pumpAndSettle();
    expect(find.text('Добавить подписку'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'not a link');
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('https://'), findsWidgets, reason: 'inline error explains the format');
    expect(core.calls, isEmpty);

    await tester.enterText(find.byType(TextField), 'https://ftn.example.net/sub/token');
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();

    expect(core.calls, ['add https://ftn.example.net/sub/token', 'select n1']);
    expect(find.text('autoWISELESS-1'), findsOneWidget);
    expect(find.text('Не подключено'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('connected: shows state and speed, the button disconnects', (tester) async {
    final status = connectedTo('n1')..traffic = Traffic();
    final core = await pumpApp(tester, FakeCore(subs: [sampleSubscription()], status: status));

    expect(find.text('Подключено'), findsOneWidget);
    expect(find.byIcon(Icons.south_rounded), findsOneWidget);

    await tester.tap(find.byType(ConnectButton));
    await tester.pumpAndSettle();
    expect(core.calls, ['disconnect']);
    expect(find.text('Не подключено'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('wide window: nodes beside the button, probe and switch', (tester) async {
    final core = await pumpApp(
      tester,
      FakeCore(subs: [sampleSubscription()], status: connectedTo('n1')),
      size: const Size(1200, 800),
    );

    expect(find.text('nlWISELESS'), findsOneWidget, reason: 'list visible without navigation');

    await tester.tap(find.text('Проверить'));
    await tester.pumpAndSettle();
    expect(find.text('Выход: Германия, Франкфурт · 145 мс'), findsWidgets);
    expect(find.text('Не отвечает'), findsOneWidget);

    await tester.tap(find.text('nlWISELESS'));
    await tester.pumpAndSettle();
    expect(core.calls.last, 'select n2');
    await unmount(tester);
  });

  testWidgets('mode picker switches to the whole system', (tester) async {
    final core = await pumpApp(tester, FakeCore(subs: [sampleSubscription()], status: connectedTo('n1')));
    await tester.tap(find.text('Туннель'));
    await tester.pumpAndSettle();
    expect(core.calls.last, startsWith('settings TUNNEL_MODE_TUN'));

    await tester.tap(find.byTooltip('Чем отличаются режимы'));
    await tester.pumpAndSettle();
    expect(find.textContaining('игры, Telegram'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('system proxy follows the connection', (tester) async {
    final proxy = RecordingProxy();
    final core = await pumpApp(tester, FakeCore(subs: [sampleSubscription()], status: connectedTo('n1')), proxy: proxy);
    expect(proxy.log.last, 'enable 7890');

    await tester.tap(find.byType(ConnectButton));
    await tester.pumpAndSettle();
    expect(core.calls, ['disconnect']);
    expect(proxy.log.last, 'restore');
    await unmount(tester);
  });

  testWidgets('settings: a running program goes direct, sites go through the VPN', (tester) async {
    final core = await pumpApp(tester, FakeCore(subs: [sampleSubscription()]), size: const Size(1200, 900));
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Пока пусто'), findsOneWidget);

    await tester.tap(find.text('Напрямую  0'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Добавить в «Напрямую»'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Программа'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('steam'));
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();
    expect(core.calls.last, 'settings TUNNEL_MODE_SYSTEM_PROXY steam=ROUTE_ACTION_DIRECT');

    await tester.tap(find.text('Через VPN  0'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Добавить в «Через VPN»'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Сайты, адреса или наборы'), '*.wiseless.net\ngeosite:ru-blocked');
    await tester.pumpAndSettle();
    expect(find.text('Поддомены'), findsOneWidget, reason: 'live preview names the kind');
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();
    expect(core.calls.last, endsWith('*.wiseless.net=ROUTE_ACTION_PROXY,ru-blocked=ROUTE_ACTION_PROXY'));
    expect(find.text('geosite:ru-blocked'), findsOneWidget);

    await tester.tap(find.text('Напрямую  1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Убрать steam'));
    await tester.pumpAndSettle();
    expect(core.calls.last, isNot(contains('steam')));
    await unmount(tester);
  });

  testWidgets('a long pasted list folds, searches, and moves a rule between lists', (tester) async {
    final core = FakeCore(subs: [sampleSubscription()]);
    core.settings.rules.addAll([
      for (var i = 0; i < 40; i++)
        RouteRule(kind: RuleKind.RULE_KIND_DOMAIN_SUFFIX, value: 'site$i.ru', action: RouteAction.ROUTE_ACTION_DIRECT),
      RouteRule(kind: RuleKind.RULE_KIND_GEOSITE, value: 'category-ru', action: RouteAction.ROUTE_ACTION_DIRECT),
    ]);
    await pumpApp(tester, core, size: const Size(1200, 1400));
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();

    expect(find.text('Напрямую  41'), findsOneWidget, reason: 'opens on the list that has rules');
    expect(find.text('Сайты · 40'), findsOneWidget);
    expect(find.text('Ещё 16'), findsOneWidget);
    await tester.tap(find.text('Ещё 16'));
    await tester.pumpAndSettle();
    expect(find.text('+.site39.ru'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Найти в «Напрямую»'), 'site3');
    await tester.pumpAndSettle();
    expect(find.text('Сайты · 11'), findsOneWidget);
    expect(find.text('Наборы · 1'), findsNothing);

    await tester.tap(find.text('+.site30.ru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перенести в «Через VPN»'));
    await tester.pumpAndSettle();
    expect(core.settings.rules.firstWhere((r) => r.value == 'site30.ru').action, RouteAction.ROUTE_ACTION_PROXY);
    expect(find.text('Через VPN  1'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('logs: the core log and the app version, ready to copy', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    await pumpApp(tester, FakeCore(subs: [sampleSubscription()]), size: const Size(1000, 2000));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Логи'));
    await tester.tap(find.text('Логи'));
    await tester.pumpAndSettle();
    expect(find.textContaining('connected to "nlWISELESS"'), findsOneWidget);

    await tester.tap(find.text('Скопировать'));
    await tester.pumpAndSettle();
    expect(copied, contains('Crocell dev'));
    expect(copied, contains('--- core ---'));
    expect(find.text('Скопировано'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('hide unavailable: failed nodes go, the one in use stays', (tester) async {
    final sub = sampleSubscription();
    sub.nodes[1].lastProbe = ProbeResult(nodeId: 'n2', error: 'probe: timeout');
    sub.nodes[2].lastProbe = ProbeResult(nodeId: 'n3', error: 'probe: timeout');
    final core = FakeCore(subs: [sub], status: Status(
      state: ConnectionState.CONNECTION_STATE_FAILED, subscriptionId: 'sub1', nodeId: 'n3', error: 'boom'));
    await pumpApp(tester, core, size: const Size(1200, 900));

    expect(find.text('Скрыть недоступные · 1'), findsOneWidget, reason: 'the selected node is not counted');
    expect(find.text('nlWISELESS'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('nlWISELESS'), findsNothing);
    expect(find.text('autoWISELESS-2 (HYSTERIA)'), findsWidgets, reason: 'the node in use stays');
    expect(find.text('autoWISELESS-1'), findsOneWidget, reason: 'unchecked nodes stay');
    await unmount(tester);
  });

  testWidgets('phone: proxy or tunnel, and in proxy mode the address for the apps', (tester) async {
    final core = FakeCore(subs: [sampleSubscription()]);
    await pumpApp(tester, core, overrides: [hostProvider.overrideWithValue(const Host(HostKind.android))]);
    expect(find.text('Туннель'), findsOneWidget);
    expect(find.textContaining('127.0.0.1:7890'), findsOneWidget, reason: 'proxy mode says where to point apps');

    await tester.tap(find.byTooltip('Чем отличаются режимы'));
    await tester.pumpAndSettle();
    expect(find.textContaining('VPN не включается'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Туннель'));
    await tester.pumpAndSettle();
    expect(core.calls.last, startsWith('settings TUNNEL_MODE_TUN'));
    expect(find.textContaining('127.0.0.1:7890'), findsNothing);
    await unmount(tester);
  });

  testWidgets('customize: a choice on Android, nothing to choose on Linux', (tester) async {
    await pumpApp(tester, FakeCore(subs: [sampleSubscription()]), size: const Size(1000, 2000), overrides: [
      hostProvider.overrideWithValue(const Host(HostKind.android)),
    ]);
    final button = tester.element(find.byType(ConnectButton));
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Оформление'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Белый'));
    await tester.pumpAndSettle();
    expect(ProviderScope.containerOf(button).read(appearanceProvider).art, AppArt.glyphWhite);
    expect(find.text('Фон иконки'), findsOneWidget);
    await unmount(tester);

    await pumpApp(tester, FakeCore(subs: [sampleSubscription()]), size: const Size(1000, 2000), overrides: [
      hostProvider.overrideWithValue(const Host(HostKind.appImage)),
    ]);
    expect(tester.widget<ConnectButton>(find.byType(ConnectButton)).art, AppArt.crocell);
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Оформление'), findsNothing);
    await unmount(tester);
  });

  testWidgets('narrow window: the add button sits in the top bar next to update and settings', (tester) async {
    await pumpApp(tester, FakeCore(), size: const Size(320, 640));
    await tester.tap(find.byIcon(Icons.add_link_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('add: a sub:// link from Shadowrocket goes to the core', (tester) async {
    final core = await pumpApp(tester, FakeCore());
    await tester.tap(find.byType(ConnectButton));
    await tester.pumpAndSettle();
    const link = 'sub://aHR0cHM6Ly9zdWIuZXhhbXBsZS5uZXQvcw#tail';
    await tester.enterText(find.byType(TextField), link);
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();
    expect(core.calls.first, 'add $link');
    await unmount(tester);
  });

  testWidgets('add: a WireGuard config can be pasted as text', (tester) async {
    final core = await pumpApp(tester, FakeCore());
    await tester.tap(find.byType(ConnectButton));
    await tester.pumpAndSettle();
    const conf = '[Interface]\nPrivateKey = a\nJc = 4\n[Peer]\nPublicKey = b\nEndpoint = awg.example.net:51820';
    await tester.enterText(find.byType(TextField), conf);
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();
    expect(core.calls.first, 'add $conf');
    await unmount(tester);
  });

  testWidgets('many subscriptions: search by claimed country, fold one away', (tester) async {
    await pumpApp(
      tester,
      FakeCore(subs: [sampleSubscription(), bigSubscription()], status: connectedTo('n1')),
      size: const Size(1200, 800),
    );

    expect(find.text('150 нод'), findsOneWidget);
    expect(find.text('Provider 0 | Швейцария'), findsOneWidget, reason: 'leading flag stripped from the name');
    expect(find.byTooltip('Швейцария, по названию ноды'), findsWidgets, reason: 'claimed country shown before any probe');

    await tester.enterText(find.widgetWithText(TextField, 'Найти ноду или страну'), 'финляндия');
    await tester.pumpAndSettle();
    expect(find.text('38 из 150'), findsOneWidget);
    expect(find.text('WISELESS'), findsNothing, reason: 'subscriptions without matches hide');

    await tester.enterText(find.widgetWithText(TextField, 'Найти ноду или страну'), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Ничего не нашлось'), findsOneWidget);

    await tester.tap(find.byTooltip('Очистить'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Свернуть').last);
    await tester.pumpAndSettle();
    expect(find.text('Provider 0 | Швейцария'), findsNothing);
    expect(find.byTooltip('Развернуть'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a connection that stops working warns on screen and by notification', (tester) async {
    final alerts = RecordingNotifications();
    final core = await pumpApp(
      tester,
      FakeCore(subs: [sampleSubscription()], status: connectedTo('n1')),
      notifications: alerts,
    );

    core.push(connectedTo('n1')..liveCheck = ProbeResult(nodeId: 'n1', exitCountry: 'DE', exitColo: 'FRA', exitIp: '1.2.3.4'));
    await tester.pumpAndSettle();
    expect(find.text('Выход: Германия, Франкфурт'), findsOneWidget);
    expect(alerts.shown, isEmpty);

    core.push(connectedTo('n1')..liveCheck = ProbeResult(nodeId: 'n1', error: 'probe: timeout'));
    await tester.pumpAndSettle();
    expect(find.text('Подключено, но не работает'), findsOneWidget);
    expect(alerts.shown, ['VPN подключён, но интернет не идёт']);

    core.push(connectedTo('n1')..liveCheck = ProbeResult(nodeId: 'n1', exitCountry: 'DE', exitColo: 'FRA', exitIp: '1.2.3.4'));
    await tester.pumpAndSettle();
    expect(alerts.shown.last, 'Интернет через VPN снова работает');
    await unmount(tester);
  });

  testWidgets('settings fit a phone-width window, advanced section open', (tester) async {
    final core = FakeCore(subs: [sampleSubscription()]);
    core.settings.rules.addAll([
      RouteRule(kind: RuleKind.RULE_KIND_GEOSITE, value: 'ru-available-only-inside', action: RouteAction.ROUTE_ACTION_DIRECT),
      RouteRule(kind: RuleKind.RULE_KIND_PROCESS_PATH, value: '/home/someone/.local/share/Steam/ubuntu12_32/steam', action: RouteAction.ROUTE_ACTION_DIRECT),
    ]);
    await pumpApp(tester, core, size: const Size(360, 1600));
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Дополнительно'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дополнительно'));
    await tester.pumpAndSettle();
    expect(find.text('DNS-серверы'), findsOneWidget);

    // Phone width: the tab shows the name over the count.
    await tester.ensureVisible(find.text('Блокировать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Блокировать'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Добавить в «Блокировать»'));
    await tester.pumpAndSettle();
    for (final tab in ['Программа', 'Набор', 'Сайт или IP']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }
    await unmount(tester);
  });

  testWidgets('a refused geo link is explained next to the save button', (tester) async {
    final core = FakeCore(subs: [sampleSubscription()])
      ..refuseSettings = 'geosite.dat: по ссылке не база, а что-то другое, скорее всего веб-страница.';
    await pumpApp(tester, core, size: const Size(1000, 1800));
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дополнительно'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Источник geosite.dat'), 'https://example.com/page');
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('скорее всего веб-страница'), findsOneWidget);
    expect(core.settings.geo.geositeSource, isEmpty, reason: 'nothing saved');

    // Typing again clears the old complaint.
    await tester.enterText(find.widgetWithText(TextField, 'Источник geosite.dat'), 'https://example.com/geosite.dat');
    await tester.pump();
    expect(find.textContaining('скорее всего веб-страница'), findsNothing);
    await unmount(tester);
  });
}
