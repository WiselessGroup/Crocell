// Renders the README screenshots with real fonts, in Russian and English, from
// fake data. Not part of the test suite. Run from app/:
//
//   flutter test tool/readme_screenshots.dart --update-goldens
//
// OUT=<dir> writes elsewhere; ONLY=<part of a name> renders just those.
import 'dart:io';

import 'package:crocell/data/core_api.dart';
import 'package:crocell/data/state.dart';
import 'package:crocell/host.dart';
import 'package:crocell/l10n.dart';
import 'package:crocell/main.dart';
import 'package:crocell/notify/alerts.dart';
import 'package:crocell/sysproxy/controller.dart';
import 'package:crocell/theme.dart';
import 'package:crocell/ui/customize_dialog.dart';
import 'package:crocell/ui/settings_screen.dart';
import 'package:crocell/update/how_to_update.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as ts;

import '../test/app_test.dart' show RecordingProxy, RecordingNotifications;
import '../test/support/fake_core.dart';

const _nodes = [
  ('n1', 'Нидерланды', 'Netherlands', 'Reality', 'NL', 'AMS', 48),
  ('n2', 'Германия', 'Germany', 'XHTTP', 'DE', 'FRA', 61),
  ('n3', 'Финляндия', 'Finland', 'Hysteria2', 'FI', 'HEL', 39),
  ('n4', 'Швейцария', 'Switzerland', 'Reality', 'CH', 'ZRH', 72),
  ('n5', 'Франция', 'France', 'gRPC', 'FR', 'CDG', 66),
  ('n6', 'Великобритания', 'United Kingdom', 'Vision', 'GB', 'LHR', 84),
  ('n7', 'Польша', 'Poland', 'XHTTP', 'PL', 'WAW', 55),
];

Subscription _subscription() => Subscription(
      id: 'sub1',
      title: 'WISELESS',
      urlMasked: 'https://sub.example.net/…c03d1c',
      totalBytes: Int64(200 << 30),
      downloadBytes: Int64(37 << 30),
      uploadBytes: Int64(3 << 30),
      nodes: [
        for (final (id, ru, en, kind, country, colo, ms) in _nodes)
          Node(
            id: id,
            name: '${tr(ru, en)} · $kind',
            type: kind == 'Hysteria2' ? 'hysteria2' : 'vless',
            network: kind == 'XHTTP' ? 'xhttp' : (kind == 'gRPC' ? 'grpc' : (kind == 'Hysteria2' ? '' : 'tcp')),
            server: '$id.example.net',
            port: 443,
            lastProbe: ProbeResult(nodeId: id, exitCountry: country, exitColo: colo, latencyMs: ms, exitIp: '203.0.113.7'),
          ),
      ],
    );

Status _connected() => Status(
      state: ConnectionState.CONNECTION_STATE_CONNECTED,
      subscriptionId: 'sub1',
      nodeId: 'n3',
      tunnelMode: TunnelMode.TUNNEL_MODE_TUN,
      mixedPort: 7890,
      coreVersion: 'dev',
      connectedSince: ts.Timestamp.fromDateTime(DateTime.now().subtract(const Duration(minutes: 42, seconds: 17))),
      traffic: Traffic(upBytes: Int64(48 << 20), downBytes: Int64(1300 << 20), upRate: Int64(42 << 10), downRate: Int64(2400 << 10)),
      liveCheck: ProbeResult(nodeId: 'n3', exitCountry: 'FI', exitColo: 'HEL', exitIp: '203.0.113.7', latencyMs: 39),
    );

List<RouteRule> _rules() {
  RouteRule direct(RuleKind k, String v) => RouteRule(kind: k, value: v, action: RouteAction.ROUTE_ACTION_DIRECT);
  return [
    for (final h in ['talk.wiseless.net', 'hub.wiseless.net', 'myip.com']) direct(RuleKind.RULE_KIND_DOMAIN, h),
    for (final z in ['ru', 'xn--p1ai', 'su', 'by', 'kz', 'yandex.ru', 'vk.com', 'ozon.ru', 'wildberries.ru', 'avito.ru',
      'gosuslugi.ru', 'sberbank.ru', 'mail.ru', 'ok.ru', 'dzen.ru', 'rutube.ru', 'hh.ru', 'auto.ru', 'lenta.ru', 'rbc.ru',
      'ria.ru', 'kp.ru', 'tatar', 'moscow', 'xn--80adxhks', 'kinopoisk.ru', 'tinkoff.ru', 'xn--90ais', 'xn--80ao21a'])
      direct(RuleKind.RULE_KIND_DOMAIN_SUFFIX, z),
    direct(RuleKind.RULE_KIND_GEOIP, 'ru'),
    for (final g in ['category-ru', 'category-gov-ru', 'ru-available-only-inside', 'yandex', 'vk', 'mailru-group'])
      direct(RuleKind.RULE_KIND_GEOSITE, g),
    direct(RuleKind.RULE_KIND_PROCESS_NAME, 'chrome'),
    direct(RuleKind.RULE_KIND_IP_CIDR, '10.8.0.0/16'),
    RouteRule(kind: RuleKind.RULE_KIND_GEOSITE, value: 'category-ads-all', action: RouteAction.ROUTE_ACTION_BLOCK),
  ];
}

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

Future<void> _settle(WidgetTester tester) async {
  for (var k = 0; k < 2; k++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

enum _Screen { home, rules, customize }

void main() {
  final out = Platform.environment['OUT'] ?? '${Directory.current.parent.path}/assets/screenshots';
  final only = Platform.environment['ONLY'] ?? '';
  // bin/cache/artifacts/engine/<platform>/flutter_tester → bin/cache/artifacts.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent.path;

  final cases = <(String, Lang, Size, Brightness, _Screen, HostKind)>[
    ('home-dark', Lang.ru, const Size(1280, 800), Brightness.dark, _Screen.home, HostKind.android),
    ('home-dark-en', Lang.en, const Size(1280, 800), Brightness.dark, _Screen.home, HostKind.android),
    ('rules-dark', Lang.ru, const Size(1280, 1100), Brightness.dark, _Screen.rules, HostKind.android),
    ('rules-dark-en', Lang.en, const Size(1280, 1100), Brightness.dark, _Screen.rules, HostKind.android),
    ('customize-dark', Lang.ru, const Size(420, 860), Brightness.dark, _Screen.customize, HostKind.android),
    ('customize-dark-en', Lang.en, const Size(420, 860), Brightness.dark, _Screen.customize, HostKind.android),
    ('home-light-check', Lang.ru, const Size(1280, 800), Brightness.light, _Screen.home, HostKind.android),
    ('customize-mac-check', Lang.ru, const Size(1000, 800), Brightness.light, _Screen.customize, HostKind.macos),
  ];

  for (final (name, language, size, brightness, screen, hostKind) in cases) {
    if (!name.contains(only)) continue;
    // The rest are for checking by eye: only with OUT, never into the README's.
    if (Platform.environment['OUT'] == null && !name.startsWith('home-dark') && !name.startsWith('rules-dark')) continue;
    testWidgets(name, (tester) async {
      lang = language;
      final fonts = '$artifacts/material_fonts';
      await _font('Roboto', ['$fonts/Roboto-Regular.ttf', '$fonts/Roboto-Medium.ttf', '$fonts/Roboto-Bold.ttf']);
      await _font('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (c) async => null);

      final core = FakeCore(subs: [_subscription()], status: _connected());
      core.settings.tunnelMode = TunnelMode.TUNNEL_MODE_TUN;
      core.settings.rules.addAll(_rules());
      final updated = ts.Timestamp.fromDateTime(DateTime.now().subtract(const Duration(hours: 2)));
      core.geo = GeoInfo(geositeUpdated: updated, geoipUpdated: updated, geoipCategories: ['ru'], geositeCategories: ['category-ru']);

      final overrides = [
        hostProvider.overrideWithValue(Host(hostKind)),
        coreApiProvider.overrideWithValue(core),
        systemProxyProvider.overrideWithValue(RecordingProxy()),
        notificationsProvider.overrideWithValue(RecordingNotifications()),
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: RepaintBoundary(
          child: screen == _Screen.rules
              ? MaterialApp(debugShowCheckedModeBanner: false, theme: crocellTheme(brightness), home: const SettingsScreen())
              : const CrocellApp(),
        ),
      ));
      await _settle(tester);
      if (screen == _Screen.customize) {
        showCustomize(rootNavigatorKey.currentContext!);
        await tester.pumpAndSettle();
        await _settle(tester);
      }
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('$out/$name.png'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
