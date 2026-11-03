import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart' as native;

import '../data/core_api.dart' hide Process;
import '../data/state.dart';
import '../host.dart';
import '../l10n.dart';
import '../notify/alerts.dart';
import '../platform/autostart.dart';
import '../quit.dart';

/// Red is everything but connected, service down included. See ADR-0001.
enum TrayLook { off, on, busy }

TrayLook trayLook(Status? status) {
  if (status == null || status.quitting) return TrayLook.off;
  if (status.isConnected) return TrayLook.on;
  return status.isBusy ? TrayLook.busy : TrayLook.off;
}

/// A menu line. No label means a separator, no action means it can't be picked.
class TrayEntry {
  const TrayEntry(this.label, [this.onTap]);
  const TrayEntry.separator()
      : label = null,
        onTap = null;
  final String? label;
  final void Function()? onTap;
}

/// How many favourites the menu shows, besides the current node.
const trayFavorites = 3;

String trayTitle(Status? status) {
  if (status?.killSwitchBlocking ?? false) return tr('Интернет заблокирован', 'Internet blocked');
  final node = status?.nodeName ?? '';
  return switch (status?.state) {
    null => tr('Служба не запущена', 'Service not running'),
    ConnectionState.CONNECTION_STATE_CONNECTED => node.isEmpty ? tr('Подключено', 'Connected') : node,
    ConnectionState.CONNECTION_STATE_CONNECTING => tr('Подключаюсь…', 'Connecting…'),
    ConnectionState.CONNECTION_STATE_DISCONNECTING => tr('Отключаюсь…', 'Disconnecting…'),
    ConnectionState.CONNECTION_STATE_FAILED => tr('Не удалось подключиться', 'Could not connect'),
    _ => tr('Не подключено', 'Not connected'),
  };
}

/// The same menu as in GNOME Quick Settings. [status] is null while the service
/// does not answer: then only opening and leaving make sense.
List<TrayEntry> trayMenu(Status? status, TrayActions actions) {
  final others = (status?.favorites ?? const <FavoriteNode>[])
      .where((f) => f.subscriptionId != status!.subscriptionId || f.nodeId != status.nodeId)
      .take(trayFavorites);
  return [
    TrayEntry('Crocell: ${trayTitle(status)}'),
    if (status != null) ...[
      // With Kill Switch up this is the way back to the internet.
      if (status.isConnected || status.killSwitchBlocking)
        TrayEntry(tr('Отключить', 'Disconnect'), actions.disconnect)
      else
        TrayEntry(tr('Подключить', 'Connect'), status.isBusy ? null : actions.connect),
      if (others.isNotEmpty) const TrayEntry.separator(),
      for (final f in others) TrayEntry(f.name, () => actions.connectTo(f)),
      const TrayEntry.separator(),
      TrayEntry(tr('Обновить все подписки', 'Refresh all subscriptions'), actions.refreshAll),
    ],
    TrayEntry(tr('Открыть Crocell', 'Open Crocell'), actions.open),
    const TrayEntry.separator(),
    TrayEntry(tr('Выйти совсем', 'Quit completely'), actions.quit),
  ];
}

abstract interface class TrayActions {
  void connect();
  void disconnect();
  void connectTo(FavoriteNode node);
  void refreshAll();
  void open();
  void quit();
}

/// The icon itself. Tests record instead.
abstract interface class TrayPlatform {
  Future<void> show(TrayLook look, String tooltip, List<TrayEntry> menu);
  Future<void> destroy();
}

final trayPlatformProvider = Provider<TrayPlatform>((ref) => NativeTray(ref.watch(hostProvider)));

const _window = MethodChannel('crocell/window');

/// From here on closing the window hides it, and the app stays in the tray.
Future<void> _hideOnClose() => _window.invokeMethod<void>('setHideOnClose', true);

class _Actions implements TrayActions {
  _Actions(this._ref);
  final Ref _ref;

  // A failure shows in the status and comes as a notification anyway.
  void _quietly(Future<Object?> Function() f) => unawaited(f().catchError((Object e) {
        debugPrint('tray: $e');
        return null;
      }));

  @override
  void connect() => _quietly(() => _ref.read(connectionProvider).connect());
  @override
  void disconnect() => _quietly(() => _ref.read(connectionProvider).disconnect());
  @override
  void connectTo(FavoriteNode f) =>
      _quietly(() => _ref.read(connectionProvider).connect(subscriptionId: f.subscriptionId, nodeId: f.nodeId));
  @override
  void open() => unawaited(presentWindow());
  @override
  void quit() => unawaited(quitCompletely(_ref));
  @override
  void refreshAll() => _quietly(() async {
        final result = await _ref.read(subscriptionsProvider.notifier).refreshAll();
        if (result.failed.isNotEmpty) {
          await _ref.read(notificationsProvider).show(
                tr('Не все подписки обновились', 'Some subscriptions did not refresh'),
                result.failed.map((f) => f.title).join(', '),
              );
        }
        return null;
      });
}

/// Windows and macOS only: GNOME has the extension, and the rest of Linux has
/// nothing yet.
bool trayShownOn(Host host) => host.kind == HostKind.windows || host.kind == HostKind.macos;

/// Keeps the tray icon and its menu in step with the service.
/// Watch it once from the root widget.
final trayControllerProvider = Provider<void>((ref) {
  if (!trayShownOn(ref.watch(hostProvider))) return;
  final tray = ref.watch(trayPlatformProvider);
  final actions = _Actions(ref);

  var shown = '';
  void update() {
    final s = ref.read(statusProvider);
    final status = s is AsyncError ? null : s.value;
    final look = trayLook(status);
    final title = 'Crocell: ${trayTitle(status)}';
    final menu = trayMenu(status, actions);
    // The status comes every second while connected, mostly with new speeds.
    final signature = [look.name, title, for (final e in menu) '${e.label}${e.onTap != null}'].join('\n');
    if (signature == shown) return;
    shown = signature;
    unawaited(tray.show(look, title, menu).catchError((Object e) => debugPrint('tray: $e')));
  }

  update();
  ref.listen(statusProvider, (_, _) => update());

  // After the first update: without an icon a hidden window would be lost.
  unawaited(_hideOnClose().catchError((Object e) => debugPrint('tray: $e')));
  if (kReleaseMode) {
    unawaited(ref.read(autostartProvider)?.applyOnStart().catchError((Object e) => debugPrint('autostart: $e')));
  }
});

/// The real icon, through the tray_manager plugin.
class NativeTray with native.TrayListener, WidgetsBindingObserver implements TrayPlatform {
  NativeTray(this._host) {
    native.trayManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
  }

  final Host _host;
  var _entries = <String, TrayEntry>{};
  TrayLook? _look;

  bool get _isMac => _host.kind == HostKind.macos;

  @override
  Future<void> show(TrayLook look, String tooltip, List<TrayEntry> menu) async {
    if (look != _look) {
      _look = look;
      await _applyIcon(look);
    }
    await native.trayManager.setToolTip(tooltip);
    final entries = <String, TrayEntry>{};
    final items = <native.MenuItem>[];
    for (final (i, e) in menu.indexed) {
      if (e.label == null) {
        items.add(native.MenuItem.separator());
      } else {
        entries['$i'] = e;
        items.add(native.MenuItem(key: '$i', label: e.label, disabled: e.onTap == null));
      }
    }
    _entries = entries;
    await native.trayManager.setContextMenu(native.Menu(items: items));
  }

  Future<void> _applyIcon(TrayLook look) async {
    if (_isMac) {
      // A template picks up the menu bar's colour by itself.
      await native.trayManager.setIcon(
        switch (look) {
          TrayLook.on => 'assets/tray/tray_mac.png',
          TrayLook.busy => 'assets/tray/tray_mac_dim.png',
          TrayLook.off => 'assets/tray/tray_mac_red.png',
        },
        isTemplate: look != TrayLook.off,
      );
      return;
    }
    final shade = await _windowsTaskbarIsLight() ? 'black' : 'white';
    await native.trayManager.setIcon(switch (look) {
      TrayLook.on => 'assets/tray/tray_$shade.ico',
      TrayLook.busy => 'assets/tray/tray_${shade}_dim.ico',
      TrayLook.off => 'assets/tray/tray_red.ico',
    });
  }

  /// The taskbar has its own light or dark setting, apart from the apps'.
  Future<bool> _windowsTaskbarIsLight() async {
    try {
      final r = await Process.run('reg', [
        'query', r'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', '/v', 'SystemUsesLightTheme',
      ]);
      return RegExp(r'0x1\b').hasMatch('${r.stdout}');
    } on ProcessException {
      return false; // dark is the default since Windows 10
    }
  }

  /// Windows announces a theme change here, and the icon follows the taskbar.
  @override
  void didChangePlatformBrightness() {
    final look = _look;
    if (!_isMac && look != null) unawaited(_applyIcon(look).catchError((Object e) => debugPrint('tray: $e')));
  }

  // On a Mac every click opens the menu, as everywhere in the menu bar. On
  // Windows the left button opens the window and the right one the menu.
  @override
  void onTrayIconMouseDown() {
    if (_isMac) {
      unawaited(native.trayManager.popUpContextMenu());
    } else {
      unawaited(presentWindow());
    }
  }

  @override
  void onTrayIconRightMouseUp() => unawaited(native.trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(native.MenuItem menuItem) => _entries[menuItem.key]?.onTap?.call();

  @override
  Future<void> destroy() => native.trayManager.destroy();
}
