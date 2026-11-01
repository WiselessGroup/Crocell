import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/rules.dart';
import '../data/state.dart';
import '../theme.dart';

/// Adds rules to one of the three lists. Three ways in, because people
/// think of them differently: something they type (a site, an IP, a set),
/// a program they see running, or a ready-made set from the geo files.
Future<void> showAddRule(BuildContext context, RouteAction action, String listName) {
  return showDialog<void>(context: context, builder: (_) => _AddRuleDialog(action: action, listName: listName));
}

enum _Tab { site, program, set }

class _AddRuleDialog extends ConsumerStatefulWidget {
  const _AddRuleDialog({required this.action, required this.listName});

  final RouteAction action;
  final String listName;

  @override
  ConsumerState<_AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends ConsumerState<_AddRuleDialog> {
  var _tab = _Tab.site;
  final _sites = TextEditingController();
  final _search = TextEditingController();
  final _path = TextEditingController();
  final _picked = <String>{}; // program names or set inputs (geosite:x)
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _sites.dispose();
    _search.dispose();
    _path.dispose();
    super.dispose();
  }

  List<RouteRule> _collect() {
    final action = widget.action;
    switch (_tab) {
      case _Tab.site:
        final parsed = parseRuleInput(_sites.text);
        if (parsed.error != null) throw parsed.error!;
        return [for (final r in parsed.rules) RouteRule(kind: r.kind, value: r.value, action: action)];
      case _Tab.program:
        return [
          for (final name in _picked) RouteRule(kind: RuleKind.RULE_KIND_PROCESS_NAME, value: name, action: action),
          if (_path.text.trim().isNotEmpty)
            RouteRule(kind: RuleKind.RULE_KIND_PROCESS_PATH, value: _path.text.trim(), action: action),
        ];
      case _Tab.set:
        final parsed = parseRuleInput(_picked.join('\n'));
        return [for (final r in parsed.rules) RouteRule(kind: r.kind, value: r.value, action: action)];
    }
  }

  Future<void> _add() async {
    List<RouteRule> rules;
    try {
      rules = _collect();
    } catch (e) {
      setState(() => _error = '$e');
      return;
    }
    if (rules.isEmpty) {
      setState(() => _error = 'Ничего не выбрано');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(settingsProvider.notifier).addRules(rules);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 520;
    return AlertDialog(
      // Phones: the default 40 px inset leaves ~230 px for three tabs.
      insetPadding: narrow ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24) : null,
      title: Text('Добавить: ${widget.listName}'),
      content: SizedBox(
        width: 560,
        height: (size.height * 0.6).clamp(320, 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_Tab>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: _Tab.site, icon: narrow ? null : const Icon(Icons.language_rounded), label: const Text('Сайт или IP')),
                ButtonSegment(value: _Tab.program, icon: narrow ? null : const Icon(Icons.apps_rounded), label: const Text('Программа')),
                ButtonSegment(value: _Tab.set, icon: narrow ? null : const Icon(Icons.category_outlined), label: const Text('Набор')),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() {
                _tab = v.first;
                _picked.clear();
                _search.clear();
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: switch (_tab) {
                _Tab.site => _SiteTab(controller: _sites, onChanged: () => setState(() => _error = null)),
                _Tab.program => _ProgramTab(
                    search: _search,
                    path: _path,
                    picked: _picked,
                    onChanged: () => setState(() => _error = null),
                  ),
                _Tab.set => _SetTab(search: _search, picked: _picked, onChanged: () => setState(() => _error = null)),
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Отмена')),
        FilledButton(
          onPressed: _busy ? null : _add,
          child: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Добавить'),
        ),
      ],
    );
  }
}

class _SiteTab extends StatelessWidget {
  const _SiteTab({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final parsed = parseRuleInput(controller.text);
    final preview = [for (final r in parsed.rules) RouteRule(kind: r.kind, value: r.value)];

    // One scrolling list, so the field, the hint and the preview fit any
    // dialog height.
    return ListView(
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          autocorrect: false,
          keyboardType: TextInputType.multiline,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            labelText: 'Сайты, адреса или наборы',
            hintText: 'wiseless.net\n*.wiseless.net\n10.0.0.0/8',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'По одному в строке. wiseless.net — только этот домен, *.wiseless.net — его поддомены, '
          '+.wiseless.net — и то и другое. Ещё подходят IP и подсети (10.0.0.0/8), '
          'geosite:ru-blocked и geoip:telegram.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted),
        ),
        const SizedBox(height: 8),
        for (final r in preview)
          ListTile(
            dense: true,
            leading: Icon(ruleIcon(r), size: 20),
            title: Text(ruleTitle(r)),
            subtitle: Text(ruleKindLabel(r)),
          ),
      ],
    );
  }
}

class _ProgramTab extends ConsumerWidget {
  const _ProgramTab({required this.search, required this.path, required this.picked, required this.onChanged});

  final TextEditingController search;
  final TextEditingController path;
  final Set<String> picked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final procs = ref.watch(processesProvider);
    final q = search.text.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: search,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(hintText: 'Найти запущенную программу', prefixIcon: Icon(Icons.search_rounded)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (procs) {
            AsyncData(:final value) => ListView(
                children: [
                  for (final p in value)
                    if (q.isEmpty || p.name.toLowerCase().contains(q) || p.path.toLowerCase().contains(q))
                      CheckboxListTile(
                        dense: true,
                        value: picked.contains(p.name),
                        onChanged: (v) {
                          v == true ? picked.add(p.name) : picked.remove(p.name);
                          onChanged();
                        },
                        title: Text(p.name),
                        subtitle: p.path.isEmpty ? null : Text(p.path, overflow: TextOverflow.ellipsis),
                      ),
                ],
              ),
            AsyncError(:final error) => Center(child: Text('$error')),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: path,
          autocorrect: false,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            labelText: 'Или путь к программе',
            hintText: '/usr/bin/steam',
            prefixIcon: Icon(Icons.folder_outlined),
          ),
        ),
      ],
    );
  }
}

class _SetTab extends ConsumerWidget {
  const _SetTab({required this.search, required this.picked, required this.onChanged});

  final TextEditingController search;
  final Set<String> picked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(geoInfoProvider).value;
    final t = context.tokens;
    final theme = Theme.of(context);
    if (info == null) return const Center(child: CircularProgressIndicator());

    final all = [
      for (final c in info.geositeCategories) 'geosite:$c',
      for (final c in info.geoipCategories) 'geoip:$c',
    ];
    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Базы geosite и geoip ещё не скачаны. Они скачаются сами при подключении, '
              'или можно скачать их сейчас и выбрать набор.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: info.updating ? null : () => ref.read(geoInfoProvider.notifier).refresh(),
              icon: const Icon(Icons.download_rounded),
              label: Text(info.updating ? 'Скачиваю…' : 'Скачать базы'),
            ),
          ],
        ),
      );
    }

    final available = all.toSet();
    final suggested = [for (final s in geoSuggestions) if (available.contains(s.input)) s];
    final q = search.text.trim().toLowerCase();
    final matches = q.isEmpty ? <String>[] : all.where((c) => c.contains(q)).take(60).toList();

    void toggle(String input) {
      picked.contains(input) ? picked.remove(input) : picked.add(input);
      onChanged();
    }

    return ListView(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in suggested)
              FilterChip(
                label: Text(s.label),
                tooltip: s.input,
                selected: picked.contains(s.input),
                onSelected: (_) => toggle(s.input),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: search,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            hintText: 'Найти среди ${all.length} наборов',
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        for (final c in matches)
          CheckboxListTile(
            dense: true,
            value: picked.contains(c),
            onChanged: (_) => toggle(c),
            title: Text(c),
          ),
      ],
    );
  }
}

IconData ruleIcon(RouteRule r) => switch (r.kind) {
      RuleKind.RULE_KIND_DOMAIN => Icons.language_rounded,
      RuleKind.RULE_KIND_DOMAIN_WILDCARD || RuleKind.RULE_KIND_DOMAIN_SUFFIX => Icons.account_tree_outlined,
      RuleKind.RULE_KIND_IP_CIDR => Icons.lan_outlined,
      RuleKind.RULE_KIND_GEOSITE => Icons.category_outlined,
      RuleKind.RULE_KIND_GEOIP => Icons.map_outlined,
      RuleKind.RULE_KIND_PROCESS_NAME => Icons.apps_rounded,
      RuleKind.RULE_KIND_PROCESS_PATH => Icons.folder_outlined,
      _ => Icons.rule_rounded,
    };
