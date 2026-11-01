import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/state.dart';
import '../theme.dart';
import 'add_subscription.dart';
import 'common.dart';
import 'format.dart';

/// Subscriptions and their nodes. Picking a node switches to it right away
/// when connected, or makes it the one the big button will use.
class NodesView extends ConsumerWidget {
  const NodesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(subscriptionsProvider);
    final status = ref.watch(statusProvider).value;

    return switch (subs) {
      AsyncData(:final value) when value.isEmpty => _Empty(onAdd: () => showAddSubscription(context)),
      AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final sub in value) ...[
              _SubscriptionHeader(sub: sub),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (i, node) in sub.nodes.indexed) ...[
                      if (i > 0) const Divider(indent: 66),
                      _NodeRow(
                        sub: sub,
                        node: node,
                        selected: status?.subscriptionId == sub.id && status?.nodeId == node.id,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      AsyncError(:final error) => Center(
          child: Padding(padding: const EdgeInsets.all(24), child: Text('$error', textAlign: TextAlign.center)),
        ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _SubscriptionHeader extends ConsumerWidget {
  const _SubscriptionHeader({required this.sub});

  final Subscription sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final probing = ref.watch(probingProvider).contains(sub.id);
    final q = quota(sub);
    final notifier = ref.read(subscriptionsProvider.notifier);

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.title.isNotEmpty ? sub.title : sub.urlMasked,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    '${sub.nodes.length} ${_plural(sub.nodes.length, 'нода', 'ноды', 'нод')}',
                    ?q,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: probing ? null : () => run(() => notifier.probe(sub.id)),
            icon: probing
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.travel_explore_rounded, size: 18),
            label: Text(probing ? 'Проверяю…' : 'Проверить'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (v) async {
              switch (v) {
                case 'refresh':
                  await run(() => notifier.refresh(sub.id));
                case 'remove':
                  if (await _confirmRemove(context, sub)) await run(() => notifier.remove(sub.id));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'refresh', child: Text('Обновить подписку')),
              PopupMenuItem(value: 'remove', child: Text('Удалить подписку…')),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmRemove(BuildContext context, Subscription sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить «${sub.title.isNotEmpty ? sub.title : sub.urlMasked}»?'),
        content: const Text('Ноды из неё пропадут. Если VPN подключён через неё, он отключится. '
            'Вернуть можно, снова добавив ссылку.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _NodeRow extends ConsumerWidget {
  const _NodeRow({required this.sub, required this.node, required this.selected});

  final Subscription sub;
  final Node node;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final probe = node.hasLastProbe() ? node.lastProbe : null;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: selected
            ? null
            : () async {
                try {
                  await ref.read(connectionProvider).select(sub.id, node.id);
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CountryBadge(code: probe?.exitCountry ?? ''),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: selected ? FontWeight.w600 : null),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    QualityLine(probe: probe),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(nodeKind(node), style: theme.textTheme.labelSmall?.copyWith(color: t.muted)),
              SizedBox(
                width: 36,
                child: selected
                    ? Icon(Icons.check_rounded, color: t.brandText, semanticLabel: 'Выбрана')
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 40, color: context.tokens.muted),
            const SizedBox(height: 12),
            Text('Здесь будут ноды', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Добавьте подписку, и Crocell покажет все ноды из неё.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: context.tokens.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_link_rounded), label: const Text('Добавить подписку')),
          ],
        ),
      ),
    );
  }
}

String _plural(int n, String one, String few, String many) {
  final mod10 = n % 10, mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}
