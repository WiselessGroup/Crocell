import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../brand/appearance.dart';
import '../data/core_api.dart';
import '../data/state.dart';
import '../l10n.dart';
import '../sysproxy/controller.dart';
import '../host.dart';
import '../platform/android.dart';
import '../theme.dart';
import '../update/how_to_update.dart';
import '../widgets/connect_button.dart';
import '../widgets/elapsed_text.dart';
import 'add_subscription.dart';
import 'common.dart';
import 'format.dart';

/// The one job of the app: the button, what it is doing, and which node it
/// uses. Everything else is one level away.
class ConnectPanel extends ConsumerWidget {
  const ConnectPanel({super.key, this.onOpenNodes});

  /// Compact layout: opens the node list. Wide layout shows it alongside,
  /// so this is null there.
  final VoidCallback? onOpenNodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(statusProvider).value;
    final subs = ref.watch(subscriptionsProvider).value ?? const <Subscription>[];
    final selected = status == null ? null : findNode(subs, status.subscriptionId, status.nodeId);

    final connected = status?.isConnected ?? false;
    final busy = status?.isBusy ?? true;

    Future<void> toggle() async {
      try {
        if (connected) {
          await ref.read(connectionProvider).disconnect();
        } else {
          if (!await ensureVpnPermission()) {
            throw CoreError(tr('Без разрешения на VPN Crocell не подключится. Нажмите ещё раз и разрешите.', "Crocell can't connect without VPN permission. Press again and allow it."));
          }
          // Checked after connecting, so it goes through the VPN like
          // everything else and works where GitHub is blocked.
          try {
            await ref.read(connectionProvider).connect();
          } finally {
            checkForUpdate(ref);
          }
        }
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    final VoidCallback? onPressed = switch (status) {
      null => null,
      _ when busy => null,
      _ when subs.isEmpty => () => showAddSubscription(context),
      _ => toggle,
    };

    return LayoutBuilder(builder: (context, c) {
      // The figure is the point of the screen: as large as the height
      // allows while the status, node and mode still fit below it.
      final buttonSize = (c.maxHeight * 0.46).clamp(200.0, 360.0).clamp(0.0, c.maxWidth - 32);
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight - 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ServiceOutdatedBanner(),
                  ConnectButton(
                    art: ref.watch(appearanceProvider).art,
                    connected: connected,
                    onPressed: onPressed,
                    size: buttonSize,
                    label: subs.isEmpty ? tr('Добавить подписку', 'Add subscription') : null,
                  ),
                  const SizedBox(height: 20),
                  _StatusText(status: status, hasNodes: subs.isNotEmpty),
                  // The figure is the signature, but a figure alone does not
                  // say "press me". A plain button next to the state does.
                  if (subs.isNotEmpty && status != null) ...[
                    const SizedBox(height: 16),
                    _ActionButton(connected: connected, onPressed: onPressed),
                  ],
                  const SizedBox(height: 28),
                  if (subs.isEmpty)
                    _EmptyCard(onAdd: () => showAddSubscription(context))
                  else
                    _NodeCard(
                      selected: selected,
                      onTap: onOpenNodes,
                      auto: ref.watch(settingsProvider).value?.autoNode ?? false,
                    ),
                  const SizedBox(height: 16),
                  const _ModePicker(),
                  const _SystemProxyWarning(),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.status, required this.hasNodes});

  final Status? status;
  final bool hasNodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final s = status;

    final (title, color) = switch (s) {
      null => (tr('Связываюсь со службой…', 'Contacting the service…'), null),
      _ when s.isConnected && s.hasLiveCheck() && s.liveCheck.error.isNotEmpty =>
        (tr('Подключено, но не работает', 'Connected, but not working'), theme.colorScheme.error),
      _ when s.isConnected => (tr('Подключено', 'Connected'), t.brandText),
      _ when s.isConnecting => (tr('Подключаюсь…', 'Connecting…'), null),
      _ when s.isDisconnecting => (tr('Отключаюсь…', 'Disconnecting…'), null),
      _ when s.isFailed => (tr('Не удалось подключиться', "Couldn't connect"), theme.colorScheme.error),
      _ => (hasNodes ? tr('Не подключено', 'Not connected') : tr('Нет подписки', 'No subscription'), null),
    };

    Widget? detail;
    if (s != null && s.isConnected) {
      final since = s.hasConnectedSince() ? s.connectedSince.toDateTime() : DateTime.now();
      final style = theme.textTheme.bodyMedium?.copyWith(
        color: t.muted,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      Widget arrow(IconData icon) =>
          Icon(icon, size: 15, color: t.muted);
      detail = Semantics(
        // No time here: a screen reader would re-announce it every second.
        label: tr(
          'Загрузка ${speed(s.traffic.downRate.toInt())}, '
              'отдача ${speed(s.traffic.upRate.toInt())}',
          'Download ${speed(s.traffic.downRate.toInt())}, '
              'upload ${speed(s.traffic.upRate.toInt())}',
        ),
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElapsedText(since: since, style: style),
            const SizedBox(width: 14),
            arrow(Icons.south_rounded),
            Text(speed(s.traffic.downRate.toInt()), style: style),
            const SizedBox(width: 10),
            arrow(Icons.north_rounded),
            Text(speed(s.traffic.upRate.toInt()), style: style),
          ],
        ),
      );
      // What the live check found: where we exit, or that nothing gets out.
      final check = s.hasLiveCheck() ? s.liveCheck : null;
      final checkLine = switch (check) {
        _ when check == null && s.checking => tr('Проверяю, работает ли интернет…', 'Checking if the internet works…'),
        null => null,
        _ when check.error.isNotEmpty => tr('Интернет через VPN не идёт. Попробуйте другую ноду.', "The internet isn't getting through the VPN. Try another node."),
        _ => tr('Выход: ${exitPlace(check)}', 'Exit: ${exitPlace(check)}'),
      };
      if (checkLine != null) {
        final broken = check != null && check.error.isNotEmpty;
        detail = Column(children: [
          detail,
          const SizedBox(height: 4),
          Text(
            checkLine,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: broken ? theme.colorScheme.error : t.muted),
          ),
        ]);
      }
    } else if (s != null && s.isFailed && s.error.isNotEmpty) {
      detail = SelectableText(s.error, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: t.muted));
    } else if (s != null && s.isBusy) {
      detail = const SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2));
    }

    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: color)),
          if (detail != null) ...[const SizedBox(height: 6), detail],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.connected, required this.onPressed});

  final bool connected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const size = Size(200, 48);
    if (connected) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(minimumSize: size, foregroundColor: context.tokens.brandText),
        icon: const Icon(Icons.power_settings_new_rounded),
        label: Text(tr('Отключить', 'Disconnect')),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: size),
      icon: const Icon(Icons.power_settings_new_rounded),
      label: Text(tr('Подключить', 'Connect')),
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.selected, required this.onTap, this.auto = false});

  final ({Subscription sub, Node node})? selected;
  final VoidCallback? onTap;
  final bool auto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final sel = selected;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (sel != null) CountryBadge.forNode(sel.node) else const CountryBadge(code: ''),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sel == null ? tr('Нода не выбрана', 'No node selected') : displayName(sel.node.name),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (sel != null)
                      QualityLine(probe: sel.node.hasLastProbe() ? sel.node.lastProbe : null)
                    else
                      Text(tr('Выберите ноду из списка', 'Pick a node from the list'), style: theme.textTheme.bodySmall?.copyWith(color: t.muted)),
                  ],
                ),
              ),
              if (auto)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: tr('Crocell выбирает ноду сам', 'Crocell picks the node by itself'),
                    child: Icon(Icons.autorenew_rounded, size: 18, color: t.muted),
                  ),
                ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: t.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              tr('Добавьте ссылку на подписку от вашего VPN-сервиса, и здесь появятся ноды.', 'Add the subscription link from your VPN service, and nodes will show up here.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_link_rounded),
              label: Text(tr('Добавить подписку', 'Add subscription')),
            ),
          ],
        ),
      ),
    );
  }
}

/// System proxy vs whole system. Sits under the node because it is part of
/// "how do I connect", not a buried setting.
class _ModePicker extends ConsumerWidget {
  const _ModePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return const SizedBox.shrink();
    final phone = ref.watch(hostProvider).embeddedCore;
    final t = context.tokens;
    final mode = settings.tunnelMode == TunnelMode.TUNNEL_MODE_TUN
        ? TunnelMode.TUNNEL_MODE_TUN
        : TunnelMode.TUNNEL_MODE_SYSTEM_PROXY;

    final picker = Row(
      children: [
        Expanded(
          child: SegmentedButton<TunnelMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: TunnelMode.TUNNEL_MODE_SYSTEM_PROXY,
                icon: const Icon(Icons.public_rounded),
                label: Text(tr('Прокси', 'Proxy')),
              ),
              ButtonSegment(
                value: TunnelMode.TUNNEL_MODE_TUN,
                icon: const Icon(Icons.shield_outlined),
                label: Text(tr('Туннель', 'Tunnel')),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (v) async {
              try {
                await ref.read(settingsProvider.notifier).setMode(v.first);
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: tr('Чем отличаются режимы', 'How the modes differ'),
          icon: Icon(Icons.info_outline_rounded, color: t.muted),
          onPressed: () => showDialog<void>(context: context, builder: (_) => _ModesInfo(phone: phone)),
        ),
      ],
    );
    if (!phone || mode != TunnelMode.TUNNEL_MODE_SYSTEM_PROXY) return picker;

    // A phone has no system proxy to set: the address goes into the apps.
    final address = '127.0.0.1:${settings.mixedPort == 0 ? 7890 : settings.mixedPort}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        picker,
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Укажите в приложении прокси $address (HTTP или SOCKS5)',
                    'Set the proxy to $address (HTTP or SOCKS5) in the app'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted),
              ),
            ),
            IconButton(
              tooltip: tr('Скопировать адрес', 'Copy the address'),
              icon: Icon(Icons.copy_rounded, size: 18, color: t.muted),
              onPressed: () => Clipboard.setData(ClipboardData(text: address)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Written for people who don't know what a proxy is, and edited with the
/// humanizer skill so it reads like a person explaining, not a spec.
class _ModesInfo extends StatelessWidget {
  const _ModesInfo({required this.phone});

  /// On a phone "proxy" is a local proxy for the apps you set it in, not
  /// the system's proxy settings.
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    final body = theme.textTheme.bodyMedium;

    Widget mode(IconData icon, String title, String text) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(title, style: heading), const SizedBox(height: 4), Text(text, style: body)],
              ),
            ),
          ],
        );

    return AlertDialog(
      title: Text(tr('Прокси или туннель', 'Proxy or tunnel')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            mode(
              Icons.public_rounded,
              tr('Прокси', 'Proxy'),
              phone
                  ? tr(
                      'VPN не включается. Crocell держит прокси на 127.0.0.1:7890, и через ноду идут только те '
                          'приложения, где вы его указали: Telegram, браузер. Остальное идёт как обычно, '
                          'а системный VPN свободен для другого.',
                      'No VPN is turned on. Crocell runs a proxy on 127.0.0.1:7890, and only the apps you set it in '
                          'go through the node: Telegram, a browser. Everything else goes as usual, '
                          'and the system VPN stays free for something else.',
                    )
                  : tr(
                      'Crocell прописывает себя в системные настройки прокси, и браузер с большинством программ '
                          'идут через VPN. Некоторые программы эти настройки игнорируют, им VPN не достанется.',
                      'Crocell sets itself as the system proxy, so your browser and most programs '
                          'go through the VPN. Some programs ignore these settings and won\'t use the VPN.',
                    ),
            ),
            const SizedBox(height: 16),
            mode(
              Icons.shield_outlined,
              tr('Туннель', 'Tunnel'),
              tr(
                'Через VPN идёт весь трафик устройства: игры, Telegram, терминал. Пригодится, когда '
                    'программа не видит прокси или не даёт его настроить.',
                'All of the device\'s traffic goes through the VPN: games, Telegram, the terminal. Useful when '
                    'a program doesn\'t see the proxy or won\'t let you set it.',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              phone
                  ? tr('Если не знаете, что выбрать, оставьте туннель.', "If you're not sure which to pick, keep the tunnel.")
                  : tr('Если не знаете, что выбрать, начните с прокси.', "If you're not sure which to pick, start with proxy."),
              style: body?.copyWith(color: context.tokens.muted),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Понятно', 'Got it')))],
    );
  }
}

class _SystemProxyWarning extends ConsumerWidget {
  const _SystemProxyWarning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(systemProxyErrorProvider);
    if (error == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr('Не получилось настроить системный прокси: $error', "Couldn't set up the system proxy: $error"),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
