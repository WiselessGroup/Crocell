import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/rules.dart';
import '../data/state.dart';
import '../theme.dart';
import '../version.dart';
import 'add_rule.dart';
import 'common.dart';

/// Routing first (what goes where), then the geo databases, then the few
/// advanced knobs people actually touch. The tunnel mode lives on the home
/// screen, next to the button it affects.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: switch (settings) {
        AsyncData(:final value) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Heading('Маршрутизация'),
                      Text(
                        'Что куда идёт, пока VPN включён. Точное правило важнее общего: '
                        'сайт из списка победит набор geosite, программа — любой сайт. '
                        'Локальная сеть всегда идёт напрямую.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
                      ),
                      const SizedBox(height: 16),
                      _RouteBlocks(rules: value.rules),
                      const SizedBox(height: 16),
                      _FinalPicker(action: value.finalAction),
                      const SizedBox(height: 32),
                      const _Heading('Базы geosite и geoip'),
                      const _GeoCard(),
                      const SizedBox(height: 32),
                      _Advanced(settings: value),
                      const SizedBox(height: 32),
                      const _Heading('О Crocell'),
                      Text(
                        'Версия $appVersion. Ядро — mihomo. Свободная программа под лицензией GPL-3.0. '
                        'Подписки и настройки хранятся на диске в зашифрованном виде.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      );
}

const _blocks = [
  (action: RouteAction.ROUTE_ACTION_PROXY, title: 'Через VPN', icon: Icons.shield_outlined),
  (action: RouteAction.ROUTE_ACTION_DIRECT, title: 'Напрямую', icon: Icons.north_east_rounded),
  (action: RouteAction.ROUTE_ACTION_BLOCK, title: 'Блокировать', icon: Icons.block_rounded),
];

/// Three lists side by side on a wide window, stacked on a narrow one.
class _RouteBlocks extends StatelessWidget {
  const _RouteBlocks({required this.rules});

  final List<RouteRule> rules;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cards = [
        for (final b in _blocks)
          _RouteBlock(
            action: b.action,
            title: b.title,
            icon: b.icon,
            rules: [for (final r in rules) if (r.action == b.action) r],
          ),
      ];
      if (c.maxWidth < 900) {
        return Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: card)]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, card) in cards.indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: card),
          ],
        ],
      );
    });
  }
}

class _RouteBlock extends ConsumerWidget {
  const _RouteBlock({required this.action, required this.title, required this.icon, required this.rules});

  final RouteAction action;
  final String title;
  final IconData icon;
  final List<RouteRule> rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (rules.isNotEmpty) Text('${rules.length}', style: theme.textTheme.bodySmall?.copyWith(color: t.muted)),
                IconButton(
                  tooltip: 'Добавить в «$title»',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => showAddRule(context, action, title),
                ),
              ],
            ),
          ),
          const Divider(),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Пока пусто', style: theme.textTheme.bodySmall?.copyWith(color: t.muted)),
            ),
          for (final r in rules)
            ListTile(
              dense: true,
              leading: Icon(ruleIcon(r), size: 20, color: t.muted),
              title: Text(ruleTitle(r), overflow: TextOverflow.ellipsis),
              subtitle: Text(ruleKindLabel(r), overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: 'Убрать ${ruleTitle(r)}',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () async {
                  try {
                    await ref.read(settingsProvider.notifier).removeRule(r);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FinalPicker extends ConsumerWidget {
  const _FinalPicker({required this.action});

  final RouteAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direct = action == RouteAction.ROUTE_ACTION_DIRECT;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        Text('Всё остальное', style: Theme.of(context).textTheme.titleSmall),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.shield_outlined), label: Text('Через VPN')),
            ButtonSegment(value: true, icon: Icon(Icons.north_east_rounded), label: Text('Напрямую')),
          ],
          selected: {direct},
          onSelectionChanged: (v) async {
            try {
              await ref
                  .read(settingsProvider.notifier)
                  .setFinal(v.first ? RouteAction.ROUTE_ACTION_DIRECT : RouteAction.ROUTE_ACTION_PROXY);
            } catch (e) {
              if (context.mounted) showError(context, e);
            }
          },
        ),
      ],
    );
  }
}

class _GeoCard extends ConsumerWidget {
  const _GeoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(geoInfoProvider).value;
    final theme = Theme.of(context);
    final t = context.tokens;
    if (info == null) return const SizedBox(height: 48);

    final updated = [
      if (info.hasGeositeUpdated()) info.geositeUpdated.toDateTime(),
      if (info.hasGeoipUpdated()) info.geoipUpdated.toDateTime(),
    ];
    final line = updated.isEmpty
        ? 'Ещё не скачаны. Скачаются сами, как только в правилах появится geosite или geoip.'
        : 'Обновлены ${_ago(updated.reduce((a, b) => a.isBefore(b) ? a : b))} · '
            '${info.geositeCategories.length} наборов сайтов, ${info.geoipCategories.length} наборов IP';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line, style: theme.textTheme.bodyMedium),
                  if (info.error.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Не получилось обновить: ${info.error}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 4),
                  Text('Источник и частоту обновления можно поменять в «Дополнительно».',
                      style: theme.textTheme.bodySmall?.copyWith(color: t.muted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: info.updating
                  ? null
                  : () async {
                      try {
                        await ref.read(geoInfoProvider.notifier).refresh();
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
              icon: info.updating
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
              label: Text(info.updating ? 'Обновляю…' : 'Обновить'),
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime when) {
    final d = DateTime.now().difference(when);
    if (d.inMinutes < 1) return 'только что';
    if (d.inHours < 1) return '${d.inMinutes} мин назад';
    if (d.inDays < 1) return '${d.inHours} ч назад';
    return '${d.inDays} дн назад';
  }
}

/// The handful of knobs worth having. Switches apply at once; text fields
/// apply with «Сохранить», so a half-typed DNS address never goes live.
class _Advanced extends ConsumerStatefulWidget {
  const _Advanced({required this.settings});

  final Settings settings;

  @override
  ConsumerState<_Advanced> createState() => _AdvancedState();
}

class _AdvancedState extends ConsumerState<_Advanced> {
  late final _dns = TextEditingController(text: widget.settings.dns.servers.join('\n'));
  late final _directDns = TextEditingController(text: widget.settings.dns.directServers.join('\n'));
  late final _port = TextEditingController(text: '${widget.settings.mixedPort == 0 ? 7890 : widget.settings.mixedPort}');
  late final _geoip = TextEditingController(text: widget.settings.geo.geoipSource);
  late final _geosite = TextEditingController(text: widget.settings.geo.geositeSource);
  late final _geoHours = TextEditingController(
      text: widget.settings.geo.updateHours == 0 ? '' : '${widget.settings.geo.updateHours}');
  bool _dirty = false;

  @override
  void dispose() {
    for (final c in [_dns, _directDns, _port, _geoip, _geosite, _geoHours]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _edit(void Function(Settings s) change) async {
    try {
      await ref.read(settingsProvider.notifier).edit(change);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  List<String> _lines(TextEditingController c) =>
      [for (final l in c.text.split(RegExp(r'[\n,]'))) if (l.trim().isNotEmpty) l.trim()];

  Future<void> _save() async {
    final port = int.tryParse(_port.text.trim());
    if (port == null) {
      showError(context, 'Порт — это число от 1024 до 65535');
      return;
    }
    final hours = int.tryParse(_geoHours.text.trim()) ?? 0;
    await _edit((s) {
      s.dns = DnsSettings(servers: _lines(_dns), directServers: _lines(_directDns), realIp: s.dns.realIp);
      s.mixedPort = port;
      s.geo = GeoSettings(geoipSource: _geoip.text.trim(), geositeSource: _geosite.text.trim(), updateHours: hours);
    });
    if (mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final t = context.tokens;
    final theme = Theme.of(context);
    void dirty(_) => setState(() => _dirty = true);

    Widget field(TextEditingController c, String label, {String? hint, String? helper, int lines = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            minLines: lines,
            maxLines: lines,
            autocorrect: false,
            onChanged: dirty,
            decoration: InputDecoration(labelText: label, hintText: hint, helperText: helper, helperMaxLines: 2, alignLabelWithHint: true),
          ),
        );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text('Дополнительно', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text('DNS, IPv6, порт, источники баз', style: theme.textTheme.bodySmall?.copyWith(color: t.muted)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        shape: const Border(),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Подключаться при запуске'),
            subtitle: const Text('Служба поднимет последнюю ноду сама, даже до входа в систему.'),
            value: s.connectOnStart,
            onChanged: (v) => _edit((s) => s.connectOnStart = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('IPv6'),
            subtitle: const Text('Выключите, если сайты по IPv6 открываются мимо VPN или не открываются вовсе.'),
            value: !s.disableIpv6,
            onChanged: (v) => _edit((s) => s.disableIpv6 = !v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Настоящие IP-адреса вместо Fake-IP'),
            subtitle: const Text('Медленнее, но некоторые игры и P2P-программы без этого не работают в туннеле.'),
            value: s.dns.realIp,
            onChanged: (v) => _edit((s) => s.dns = (s.dns.deepCopy()..realIp = v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Пускать устройства из локальной сети'),
            subtitle: Text('Телефон или приставка смогут ходить через этот компьютер, на порт ${s.mixedPort == 0 ? 7890 : s.mixedPort}.'),
            value: s.allowLan,
            onChanged: (v) => _edit((s) => s.allowLan = v),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            final stack = DropdownButtonFormField<String>(
              initialValue: s.tunStack.isEmpty ? 'mixed' : s.tunStack,
              isExpanded: true, // shrink with the window instead of overflowing it
              decoration: const InputDecoration(labelText: 'Стек туннеля'),
              items: const [
                DropdownMenuItem(value: 'mixed', child: Text('Смешанный (рекомендуется)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'system', child: Text('Системный')),
                DropdownMenuItem(value: 'gvisor', child: Text('gVisor')),
              ],
              onChanged: (v) => _edit((s) => s.tunStack = v ?? 'mixed'),
            );
            final port = field(_port, 'Порт прокси');
            if (c.maxWidth < 480) {
              return Column(children: [stack, const SizedBox(height: 12), port]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: stack), const SizedBox(width: 12), SizedBox(width: 140, child: port)],
            );
          }),
          const SizedBox(height: 12),
          field(_dns, 'DNS-серверы',
              hint: 'https://1.1.1.1/dns-query\nhttps://8.8.8.8/dns-query',
              helper: 'По одному в строке, запросы идут через VPN. Пусто — Cloudflare и Google.',
              lines: 3),
          field(_directDns, 'DNS для прямых соединений',
              hint: 'system', helper: 'Пусто — системный DNS.', lines: 2),
          field(_geoip, 'Источник geoip.dat', hint: 'Ссылка или путь к файлу', helper: 'Пусто — runetfreedom.'),
          field(_geosite, 'Источник geosite.dat', hint: 'Ссылка или путь к файлу', helper: 'Пусто — runetfreedom.'),
          SizedBox(width: 220, child: field(_geoHours, 'Обновлять базы, часов', hint: '24')),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _dirty ? _save : null, child: const Text('Сохранить')),
          ),
        ],
      ),
    );
  }
}
