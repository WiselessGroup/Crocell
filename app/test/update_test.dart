import 'package:crocell/data/core_api.dart';
import 'package:crocell/host.dart';
import 'package:crocell/notify/alerts.dart';
import 'package:crocell/update/how_to_update.dart';
import 'package:crocell/update/releases.dart';
import 'package:crocell/widgets/connect_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show RecordingNotifications, pumpApp, unmount;
import 'support/fake_core.dart';

class FakeFeed implements ReleaseFeed {
  FakeFeed(this.version);
  String version;
  var asked = 0;
  @override
  Future<String> latestVersion() async {
    asked++;
    return version;
  }
}

void main() {
  test('versions compare as numbers, and dev builds never update', () {
    expect(isNewer('0.10.0', '0.9.3'), isTrue);
    expect(isNewer('v0.4.0', '0.4.0'), isFalse);
    expect(isNewer('0.3.9', '0.4.0'), isFalse);
    expect(isNewer('0.5.0', 'dev'), isFalse);
    expect(isNewer('garbage', '0.4.0'), isFalse);
  });

  test('a newer release is announced once, and GitHub is not asked on every connect', () async {
    final feed = FakeFeed('0.5.0');
    final alerts = RecordingNotifications();
    final c = ProviderContainer(overrides: [
      releaseFeedProvider.overrideWithValue(feed),
      currentVersionProvider.overrideWithValue('0.4.0'),
      notificationsProvider.overrideWithValue(alerts),
    ]);
    addTearDown(c.dispose);

    await c.read(availableUpdateProvider.notifier).check();
    await c.read(availableUpdateProvider.notifier).check();
    expect(c.read(availableUpdateProvider), '0.5.0');
    expect(alerts.shown, ['Вышла Crocell 0.5.0']);
    expect(feed.asked, 1);
  });

  test('a dev build does not ask at all', () async {
    final feed = FakeFeed('0.5.0');
    final c = ProviderContainer(overrides: [
      releaseFeedProvider.overrideWithValue(feed),
      currentVersionProvider.overrideWithValue('dev'),
      notificationsProvider.overrideWithValue(RecordingNotifications()),
    ]);
    addTearDown(c.dispose);
    await c.read(availableUpdateProvider.notifier).check();
    expect(feed.asked, 0);
  });

  test('the service counts as outdated when it is older or too old to say', () {
    expect(serviceOutdated('0.3.0', '0.4.0'), isTrue);
    expect(serviceOutdated('', '0.4.0'), isTrue);
    expect(serviceOutdated('0.4.0', '0.4.0'), isFalse);
    expect(serviceOutdated('', 'dev'), isFalse);
  });

  for (final (os, env, asset) in [
    ('linux', {'APPIMAGE': '/home/me/AppImages/crocell.appimage'}, 'Crocell-x86_64.AppImage'),
    ('windows', <String, String>{}, 'Crocell-x86_64-Setup.exe'),
    ('macos', <String, String>{}, 'Crocell-arm64.dmg'),
    ('android', <String, String>{}, 'Crocell.apk'),
  ]) {
    testWidgets('connect finds an update, the click explains it for $os', (tester) async {
      final alerts = RecordingNotifications();
      await pumpApp(tester, FakeCore(subs: [sampleSubscription()]), notifications: alerts, overrides: [
        releaseFeedProvider.overrideWithValue(FakeFeed('0.5.0')),
        currentVersionProvider.overrideWithValue('0.4.0'),
        hostProvider.overrideWithValue(Host.detect(os: os, env: env)),
      ]);

      await tester.tap(find.byType(ConnectButton));
      await tester.pumpAndSettle();
      expect(alerts.shown, contains('Вышла Crocell 0.5.0'));
      expect(find.byTooltip('Вышла Crocell 0.5.0'), findsOneWidget);

      alerts.tapped.add(UpdateNotifier.tapPayload);
      await tester.pumpAndSettle();
      expect(find.text('Как обновить Crocell'), findsOneWidget);
      expect(find.text('Вышла версия 0.5.0, у вас 0.4.0.'), findsOneWidget);
      expect(find.text('Скачать $asset'), findsOneWidget);

      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.text('Как обновить Crocell'), findsNothing);
      await unmount(tester);
    });
  }

  testWidgets('an old service after an app update asks to be reinstalled', (tester) async {
    final core = FakeCore(
      subs: [sampleSubscription()],
      status: Status(state: ConnectionState.CONNECTION_STATE_DISCONNECTED, coreVersion: '0.3.0'),
    );
    await pumpApp(tester, core, overrides: [
      currentVersionProvider.overrideWithValue('0.4.0'),
      hostProvider.overrideWithValue(Host.detect(os: 'linux', env: {'APPIMAGE': '/a/crocell.appimage'})),
    ]);
    expect(find.text('Обновите службу Crocell'), findsOneWidget);
    expect(find.text("sudo '/a/crocell.appimage' crocelld install"), findsOneWidget);

    core.push(core.current.deepCopy()..coreVersion = '0.4.0');
    await tester.pumpAndSettle();
    expect(find.text('Обновите службу Crocell'), findsNothing);
    await unmount(tester);
  });
}
