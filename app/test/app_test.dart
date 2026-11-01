import 'package:crocell/data/core_api.dart';
import 'package:crocell/data/state.dart';
import 'package:crocell/main.dart';
import 'package:crocell/sysproxy/controller.dart';
import 'package:crocell/sysproxy/sysproxy.dart';
import 'package:crocell/widgets/connect_button.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_core.dart';

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
    await tester.tap(find.text('Вся система'));
    await tester.pumpAndSettle();
    expect(core.calls.last, startsWith('settings TUNNEL_MODE_TUN'));
    expect(find.textContaining('игры, Telegram'), findsOneWidget);
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

  testWidgets('settings: add a program that bypasses the VPN', (tester) async {
    final core = await pumpApp(tester, FakeCore(subs: [sampleSubscription()]));
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'steam');
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();
    expect(core.calls.last, 'settings TUNNEL_MODE_SYSTEM_PROXY steam=APP_MODE_BYPASS');
    expect(find.text('Напрямую'), findsOneWidget);
    await unmount(tester);
  });
}
