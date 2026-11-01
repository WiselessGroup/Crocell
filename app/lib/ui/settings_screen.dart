import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/state.dart';
import '../theme.dart';
import '../version.dart';
import 'common.dart';
import 'routing_panel.dart';

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
                        'сайт победит набор, в который входит, программа — любой сайт. '
                        'Локальная сеть всегда идёт напрямую. Нажмите на правило, чтобы перенести его в другой список.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
                      ),
                      const SizedBox(height: 16),
                      RoutingPanel(rules: value.rules),
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
  bool _saving = false;
  String? _error; // why the last save was refused, shown by the button

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
      setState(() => _error = 'Порт — это число от 1024 до 65535');
      return;
    }
    final hours = int.tryParse(_geoHours.text.trim()) ?? 0;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // A new geo source is downloaded and checked by the service before it
      // is saved, so this can take a few seconds and can be refused.
      await ref.read(settingsProvider.notifier).edit((s) {
        s.dns = DnsSettings(servers: _lines(_dns), directServers: _lines(_directDns), realIp: s.dns.realIp);
        s.mixedPort = port;
        s.geo = GeoSettings(geoipSource: _geoip.text.trim(), geositeSource: _geosite.text.trim(), updateHours: hours);
      });
      ref.invalidate(geoInfoProvider);
      final saved = ref.read(settingsProvider).value;
      if (mounted && saved != null) {
        setState(() {
          _dirty = false;
          // The service may have tidied a link (a GitHub page into the file).
          _geoip.text = saved.geo.geoipSource;
          _geosite.text = saved.geo.geositeSource;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final t = context.tokens;
    final theme = Theme.of(context);
    void dirty(_) => setState(() {
          _dirty = true;
          _error = null;
        });

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
              hint: '77.88.8.8',
              helper: 'Для сайтов и программ из «Напрямую». Пусто — Яндекс и Cloudflare.',
              lines: 2),
          field(_geoip, 'Источник geoip.dat', hint: 'Ссылка или путь к файлу', helper: 'Пусто — runetfreedom.'),
          field(_geosite, 'Источник geosite.dat', hint: 'Ссылка или путь к файлу', helper: 'Пусто — runetfreedom.'),
          SizedBox(width: 220, child: field(_geoHours, 'Обновлять базы, часов', hint: '24')),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _dirty && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}
