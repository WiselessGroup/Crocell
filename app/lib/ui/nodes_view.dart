import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/state.dart';
import '../l10n.dart';
import '../theme.dart';
import 'add_subscription.dart';
import 'common.dart';
import 'format.dart';

/// Subscriptions and their nodes. Picking a node switches to it right away
/// when connected, or makes it the one the big button will use.
///
/// Built lazily with slivers: a single subscription can carry 150+ nodes.
/// A search field appears once there is enough to search through, and each
/// subscription folds away.
class NodesView extends ConsumerStatefulWidget {
  const NodesView({super.key});

  /// Below this many nodes in total a search field is clutter.
  static const searchThreshold = 12;

  @override
  ConsumerState<NodesView> createState() => _NodesViewState();
}

class _NodesViewState extends ConsumerState<NodesView> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(subscriptionsProvider);
    final status = ref.watch(statusProvider).value;
    final collapsed = ref.watch(collapsedProvider);
    final t = context.tokens;

    return switch (subs) {
      AsyncData(:final value) when value.isEmpty => _Empty(onAdd: () => showAddSubscription(context)),
      AsyncData(:final value) => () {
        final total = value.fold<int>(0, (n, s) => n + s.nodes.length);
        final query = _query.text;
        var anyMatch = false;

        final slivers = <Widget>[
          if (total > NodesView.searchThreshold)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: tr('Найти ноду или страну', 'Find a node or country'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: tr('Очистить', 'Clear'),
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_query.clear),
                          ),
                  ),
                ),
              ),
            ),
        ];

        for (final sub in value) {
          final nodes = [
            for (final n in sub.nodes)
              if (nodeMatches(n, query)) n,
          ];
          if (query.isNotEmpty && nodes.isEmpty) continue;
          anyMatch = true;
          // Searching unfolds everything: hidden matches help nobody.
          final folded = query.isEmpty && collapsed.contains(sub.id);

          slivers.add(
            SliverToBoxAdapter(
              child: _SubscriptionHeader(sub: sub, shown: nodes.length, folded: folded),
            ),
          );
          slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
          if (!folded) {
            slivers.add(
              DecoratedSliver(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.outline),
                ),
                sliver: SliverList.separated(
                  itemCount: nodes.length,
                  separatorBuilder: (_, _) => const Divider(indent: 66),
                  itemBuilder: (_, i) => _NodeRow(
                    sub: sub,
                    node: nodes[i],
                    selected: status?.subscriptionId == sub.id && status?.nodeId == nodes[i].id,
                  ),
                ),
              ),
            );
          }
          slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
        }

        if (!anyMatch) {
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  tr('Ничего не нашлось по «$query»', 'Nothing found for "$query"'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.muted),
                ),
              ),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverMainAxisGroup(slivers: slivers),
            ),
          ],
        );
      }(),
      AsyncError(:final error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$error', textAlign: TextAlign.center),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// Folded subscriptions. In memory: a fresh start shows everything.
final collapsedProvider = NotifierProvider<_CollapsedNotifier, Set<String>>(_CollapsedNotifier.new);

class _CollapsedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};
  void toggle(String id) => state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
}

class _SubscriptionHeader extends ConsumerWidget {
  const _SubscriptionHeader({required this.sub, required this.shown, required this.folded});

  final Subscription sub;

  /// Nodes left after the search filter.
  final int shown;
  final bool folded;

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

    final count = shown == sub.nodes.length
        ? tr(
            '${sub.nodes.length} ${_plural(sub.nodes.length, 'нода', 'ноды', 'нод')}',
            '${sub.nodes.length} ${sub.nodes.length == 1 ? 'node' : 'nodes'}',
          )
        : tr('$shown из ${sub.nodes.length}', '$shown of ${sub.nodes.length}');

    return Row(
      children: [
        IconButton(
          tooltip: folded ? tr('Развернуть', 'Expand') : tr('Свернуть', 'Collapse'),
          icon: AnimatedRotation(
            turns: folded ? -0.25 : 0,
            duration: const Duration(milliseconds: 150),
            child: const Icon(Icons.expand_more_rounded),
          ),
          onPressed: () => ref.read(collapsedProvider.notifier).toggle(sub.id),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sub.title.isNotEmpty ? sub.title : sub.urlMasked,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Text([count, ?q].join(' · '), style: theme.textTheme.bodySmall?.copyWith(color: t.muted)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: probing ? null : () => run(() => notifier.probe(sub.id)),
          icon: probing
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.travel_explore_rounded, size: 18),
          label: Text(probing ? tr('Проверяю…', 'Checking…') : tr('Проверить', 'Check')),
        ),
        PopupMenuButton<String>(
          tooltip: tr('Ещё', 'More'),
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (v) async {
            switch (v) {
              case 'refresh':
                await run(() => notifier.refresh(sub.id));
              case 'remove':
                if (await _confirmRemove(context, sub)) await run(() => notifier.remove(sub.id));
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'refresh', child: Text(tr('Обновить подписку', 'Refresh subscription'))),
            PopupMenuItem(value: 'remove', child: Text(tr('Удалить подписку…', 'Remove subscription…'))),
          ],
        ),
      ],
    );
  }

  Future<bool> _confirmRemove(BuildContext context, Subscription sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Удалить «${sub.title.isNotEmpty ? sub.title : sub.urlMasked}»?', 'Remove "${sub.title.isNotEmpty ? sub.title : sub.urlMasked}"?')),
        content: Text(
          tr(
            'Ноды из неё пропадут. Если VPN подключён через неё, он отключится. '
            'Вернуть можно, снова добавив ссылку.',
            'Its nodes will be gone. If the VPN is connected through it, it will disconnect. '
            'You can bring it back by adding the link again.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Отмена', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Удалить', 'Remove'))),
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
              CountryBadge.forNode(node),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName(node.name),
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
                child: selected ? Icon(Icons.check_rounded, color: t.brandText, semanticLabel: tr('Выбрана', 'Selected')) : null,
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
            Text(tr('Здесь будут ноды', 'Nodes will show up here'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              tr('Добавьте подписку, и Crocell покажет все ноды из неё.', 'Add a subscription, and Crocell will show all its nodes.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: context.tokens.muted),
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

String _plural(int n, String one, String few, String many) {
  final mod10 = n % 10, mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}
