import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/rules.dart';
import '../data/state.dart';
import '../l10n.dart';
import '../theme.dart';
import 'add_rule.dart';
import 'common.dart';

/// Getters, not consts, so the texts follow the app's language.
List<({RouteAction action, String title, IconData icon})> get routeLists => [
  (action: RouteAction.ROUTE_ACTION_PROXY, title: tr('Через VPN', 'Through VPN'), icon: Icons.shield_outlined),
  (action: RouteAction.ROUTE_ACTION_DIRECT, title: tr('Напрямую', 'Direct'), icon: Icons.north_east_rounded),
  (action: RouteAction.ROUTE_ACTION_BLOCK, title: tr('Блокировать', 'Block'), icon: Icons.block_rounded),
];

String _listTitle(RouteAction a) => routeLists.firstWhere((l) => l.action == a).title;

/// What each list is for, when it is empty.
Map<RouteAction, String> get _emptyHint => {
  RouteAction.ROUTE_ACTION_PROXY: tr('Что идёт через VPN всегда, даже когда всё остальное напрямую.', 'What always goes through the VPN, even when everything else goes direct.'),
  RouteAction.ROUTE_ACTION_DIRECT: tr('Что идёт мимо VPN: банки, госуслуги, российские сайты, игры.', 'What bypasses the VPN: banks, government services, local sites, games.'),
  RouteAction.ROUTE_ACTION_BLOCK: tr('Что не открывается совсем: реклама, слежка.', "What doesn't open at all: ads, trackers."),
};

/// Rules of one kind, in the order people think about them: big sets
/// first, then single sites, addresses and programs.
List<({String title, Set<RuleKind> kinds})> get _groups => [
  (title: tr('Наборы', 'Sets'), kinds: {RuleKind.RULE_KIND_GEOSITE, RuleKind.RULE_KIND_GEOIP}),
  (
    title: tr('Сайты', 'Sites'),
    kinds: {RuleKind.RULE_KIND_DOMAIN, RuleKind.RULE_KIND_DOMAIN_SUFFIX, RuleKind.RULE_KIND_DOMAIN_WILDCARD},
  ),
  (title: tr('IP и подсети', 'IPs and subnets'), kinds: {RuleKind.RULE_KIND_IP_CIDR}),
  (title: tr('Программы', 'Programs'), kinds: {RuleKind.RULE_KIND_PROCESS_NAME, RuleKind.RULE_KIND_PROCESS_PATH}),
];

/// Lists past this many chips fold, so a pasted list of 300 domains does
/// not push everything else off the screen.
const _folded = 24;

/// The three lists as tabs over one panel. A rule is a chip: the cross
/// removes it, a click moves it to another list.
class RoutingPanel extends ConsumerStatefulWidget {
  const RoutingPanel({super.key, required this.rules});

  final List<RouteRule> rules;

  @override
  ConsumerState<RoutingPanel> createState() => _RoutingPanelState();
}

class _RoutingPanelState extends ConsumerState<RoutingPanel> {
  late RouteAction _list = _firstFilled();
  final _search = TextEditingController();
  final _open = <String>{}; // unfolded groups

  RouteAction _firstFilled() {
    for (final l in routeLists) {
      if (widget.rules.any((r) => r.action == l.action)) return l.action;
    }
    return RouteAction.ROUTE_ACTION_PROXY;
  }

  int _count(RouteAction a) => widget.rules.where((r) => r.action == a).length;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final title = _listTitle(_list);
    final inList = [
      for (final r in widget.rules)
        if (r.action == _list) r,
    ];
    final query = _search.text.trim().toLowerCase();
    // Both the shown name and the stored one: .рф is found as xn--p1ai too.
    bool hit(RouteRule r) => ruleTitle(r).toLowerCase().contains(query) || ruleInput(r).toLowerCase().contains(query);
    final shown = query.isEmpty
        ? inList
        : [
            for (final r in inList)
              if (hit(r)) r,
          ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            // Full width, so the three lists read as one control. On a
            // phone the icons go and the counts stay.
            child: LayoutBuilder(
              builder: (context, c) => SizedBox(
                width: double.infinity,
                child: SegmentedButton<RouteAction>(
                  showSelectedIcon: false,
                  segments: [
                    for (final l in routeLists)
                      ButtonSegment(
                        value: l.action,
                        icon: c.maxWidth < 520 ? null : Icon(l.icon),
                        label: c.maxWidth < 520
                            // Name over count, the name shrinking rather than
                            // breaking mid-word ("Блокироват-ь").
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(fit: BoxFit.scaleDown, child: Text(l.title, maxLines: 1)),
                                  Text('${_count(l.action)}'),
                                ],
                              )
                            : Text('${l.title}  ${_count(l.action)}'),
                      ),
                  ],
                  selected: {_list},
                  onSelectionChanged: (v) => setState(() {
                    _list = v.first;
                    _search.clear();
                  }),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
            // Wide: search or hint, then the buttons, on one line. Narrow:
            // the buttons get their own line instead of squeezing the text.
            child: LayoutBuilder(
              builder: (context, c) {
                final lead = inList.length > 8
                    ? TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: tr('Найти в «$title»', 'Search in "$title"'),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: tr('Очистить поиск', 'Clear search'),
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => setState(_search.clear),
                                ),
                        ),
                      )
                    : Text(_emptyHint[_list]!, style: theme.textTheme.bodySmall?.copyWith(color: t.muted));
                final buttons = [
                  Tooltip(
                    message: tr('Добавить в «$title»', 'Add to "$title"'),
                    child: FilledButton.tonalIcon(
                      onPressed: () => showAddRule(context, _list, title),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tr('Добавить правило', 'Add rule')),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: tr('Ещё', 'More'),
                    enabled: inList.isNotEmpty,
                    onSelected: (v) => switch (v) {
                      'copy' => _copy(inList),
                      _ => _clear(inList, title),
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'copy', child: Text(tr('Скопировать списком', 'Copy as a list'))),
                      PopupMenuItem(value: 'clear', child: Text(tr('Очистить список', 'Clear list'))),
                    ],
                  ),
                ];
                if (c.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(padding: const EdgeInsets.only(right: 8), child: lead),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(child: buttons[0]),
                          buttons[1],
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: lead),
                    const SizedBox(width: 8),
                    ...buttons,
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: inList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(tr('Пока пусто', 'Empty for now'), style: theme.textTheme.bodySmall?.copyWith(color: t.muted)),
                  )
                : shown.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(tr('Ничего не нашлось', 'Nothing found'), style: theme.textTheme.bodySmall?.copyWith(color: t.muted)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final g in _groups)
                        if (shown.any((r) => g.kinds.contains(r.kind)))
                          _group(g.title, [
                            for (final r in shown)
                              if (g.kinds.contains(r.kind)) r,
                          ], folding: query.isEmpty),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _group(String title, List<RouteRule> rules, {required bool folding}) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final key = '$_list/$title';
    final fold = folding && rules.length > _folded && !_open.contains(key);
    final visible = fold ? rules.take(_folded) : rules;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title · ${rules.length}', style: theme.textTheme.labelMedium?.copyWith(color: t.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final r in visible) _RuleChip(rule: r, onMove: (to) => _move(r, to), onRemove: () => _remove([r])),
              if (fold)
                ActionChip(
                  label: Text(tr('Ещё ${rules.length - _folded}', '${rules.length - _folded} more')),
                  onPressed: () => setState(() => _open.add(key)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _move(RouteRule r, RouteAction to) =>
      _guard(() => ref.read(settingsProvider.notifier).addRules([r.deepCopy()..action = to]));

  Future<void> _remove(List<RouteRule> rules) => _guard(() => ref.read(settingsProvider.notifier).removeRules(rules));

  Future<void> _copy(List<RouteRule> rules) async {
    await Clipboard.setData(ClipboardData(text: [for (final r in rules) ruleInput(r)].join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Скопировано правил: ${rules.length}', 'Rules copied: ${rules.length}'))));
    }
  }

  Future<void> _clear(List<RouteRule> rules, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Очистить «$title»?', 'Clear "$title"?')),
        content: Text(tr('Уйдут все ${rules.length} правил этого списка. Их можно сначала скопировать.', "${rules.length == 1 ? 'The rule' : 'All ${rules.length} rules'} in this list will be removed. You can copy ${rules.length == 1 ? 'it' : 'them'} first.")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Отмена', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Очистить', 'Clear'))),
        ],
      ),
    );
    if (ok == true) await _remove(rules);
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.rule, required this.onMove, required this.onRemove});

  final RouteRule rule;
  final void Function(RouteAction to) onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final title = ruleTitle(rule);
    return Tooltip(
      message: ruleKindLabel(rule),
      waitDuration: const Duration(milliseconds: 600),
      child: InputChip(
        // Dense with a mouse, finger-sized on a phone.
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: Theme.of(context).platform == TargetPlatform.android
            ? MaterialTapTargetSize.padded
            : MaterialTapTargetSize.shrinkWrap,
        avatar: Icon(ruleIcon(rule), size: 16, color: t.muted),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(title, overflow: TextOverflow.ellipsis),
        ),
        deleteButtonTooltipMessage: tr('Убрать $title', 'Remove $title'),
        onDeleted: onRemove,
        onPressed: () => _menu(context),
      ),
    );
  }

  Future<void> _menu(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    const remove = -1;
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(origin.dx, origin.dy, overlay.size.width - origin.dx, 0),
      items: [
        for (final (i, l) in routeLists.indexed)
          if (l.action != rule.action)
            PopupMenuItem(
              value: i,
              child: ListTile(leading: Icon(l.icon), title: Text(tr('Перенести в «${l.title}»', 'Move to "${l.title}"')), dense: true),
            ),
        PopupMenuItem(
          value: remove,
          child: ListTile(leading: const Icon(Icons.close_rounded), title: Text(tr('Убрать', 'Remove')), dense: true),
        ),
      ],
    );
    if (picked == null) return;
    picked == remove ? onRemove() : onMove(routeLists[picked].action);
  }
}
