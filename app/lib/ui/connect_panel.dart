import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/state.dart';
import '../sysproxy/controller.dart';
import '../theme.dart';
import '../widgets/connect_button.dart';
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
          await ref.read(connectionProvider).connect();
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
      final buttonSize = (c.maxHeight * 0.36).clamp(160.0, 260.0);
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
                  ConnectButton(
                    connected: connected,
                    onPressed: onPressed,
                    size: buttonSize,
                    label: subs.isEmpty ? 'Добавить подписку' : null,
                  ),
                  const SizedBox(height: 20),
                  _StatusText(status: status, hasNodes: subs.isNotEmpty),
                  const SizedBox(height: 28),
                  if (subs.isEmpty)
                    _EmptyCard(onAdd: () => showAddSubscription(context))
                  else
                    _NodeCard(selected: selected, onTap: onOpenNodes),
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
      null => ('Связываюсь со службой…', null),
      _ when s.isConnected => ('Подключено', t.brandText),
      _ when s.isConnecting => ('Подключаюсь…', null),
      _ when s.isDisconnecting => ('Отключаюсь…', null),
      _ when s.isFailed => ('Не удалось подключиться', theme.colorScheme.error),
      _ => (hasNodes ? 'Не подключено' : 'Нет подписки', null),
    };

    Widget? detail;
    if (s != null && s.isConnected) {
      final since = s.hasConnectedSince() ? DateTime.now().difference(s.connectedSince.toDateTime()) : Duration.zero;
      final style = theme.textTheme.bodyMedium?.copyWith(
        color: t.muted,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      Widget arrow(IconData icon) =>
          Icon(icon, size: 15, color: t.muted);
      detail = Semantics(
        label: 'Подключено ${elapsed(since)}, загрузка ${speed(s.traffic.downRate.toInt())}, '
            'отдача ${speed(s.traffic.upRate.toInt())}',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(elapsed(since), style: style),
            const SizedBox(width: 14),
            arrow(Icons.south_rounded),
            Text(speed(s.traffic.downRate.toInt()), style: style),
            const SizedBox(width: 10),
            arrow(Icons.north_rounded),
            Text(speed(s.traffic.upRate.toInt()), style: style),
          ],
        ),
      );
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

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.selected, required this.onTap});

  final ({Subscription sub, Node node})? selected;
  final VoidCallback? onTap;

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
              CountryBadge(code: sel?.node.lastProbe.exitCountry ?? ''),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sel?.node.name ?? 'Нода не выбрана',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (sel != null)
                      QualityLine(probe: sel.node.hasLastProbe() ? sel.node.lastProbe : null)
                    else
                      Text('Выберите ноду из списка', style: theme.textTheme.bodySmall?.copyWith(color: t.muted)),
                  ],
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
              'Добавьте ссылку на подписку от вашего VPN-сервиса, и здесь появятся ноды.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Добавить подписку'),
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
    final t = context.tokens;
    final mode = settings.tunnelMode == TunnelMode.TUNNEL_MODE_TUN
        ? TunnelMode.TUNNEL_MODE_TUN
        : TunnelMode.TUNNEL_MODE_SYSTEM_PROXY;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<TunnelMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: TunnelMode.TUNNEL_MODE_SYSTEM_PROXY,
                icon: Icon(Icons.public_rounded),
                label: Text('Системный прокси'),
              ),
              ButtonSegment(
                value: TunnelMode.TUNNEL_MODE_TUN,
                icon: Icon(Icons.shield_outlined),
                label: Text('Вся система'),
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
        const SizedBox(height: 8),
        Text(
          mode == TunnelMode.TUNNEL_MODE_TUN
              ? 'Через VPN идут все программы, даже те, что не умеют прокси: игры, Telegram, терминал.'
              : 'Через VPN идут браузеры и программы, которые слушают системный прокси.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted),
        ),
      ],
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
              'Не получилось настроить системный прокси: $error',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
