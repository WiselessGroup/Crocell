import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../brand/appearance.dart';
import '../data/core_api.dart';
import '../data/state.dart';
import '../host.dart';
import '../l10n.dart';
import '../platform/android.dart';
import '../service/gnome.dart';
import '../theme.dart';
import '../version.dart';
import 'common.dart';
import 'customize_dialog.dart';
import 'logs_dialog.dart';
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
      appBar: AppBar(title: Text(tr('Настройки', 'Settings'))),
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
                    _Heading(tr('Маршрутизация', 'Routing')),
                    Text(
                      tr(
                        'Что куда идёт, пока VPN включён. Точное правило важнее общего: '
                        'сайт победит набор, в который входит, программа — любой сайт. '
                        'Локальная сеть всегда идёт напрямую. Нажмите на правило, чтобы перенести его в другой список.',
                        'What goes where while the VPN is on. A specific rule beats a general one: '
                        'a site beats a set that contains it, a program beats any site. '
                        'The local network always goes direct. Select a rule to move it to another list.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
                    ),
                    const SizedBox(height: 16),
                    RoutingPanel(rules: value.rules),
                    const SizedBox(height: 16),
                    _FinalPicker(action: value.finalAction),
                    const SizedBox(height: 32),
                    _Heading(tr('Базы geosite и geoip', 'Geosite and geoip databases')),
                    const _GeoCard(),
                    const SizedBox(height: 32),
                    _Advanced(settings: value),
                    const SizedBox(height: 32),
                    _Heading(tr('О Crocell', 'About Crocell')),
                    Text(
                      tr(
                        'Версия $appVersion. Ядро — mihomo. Свободная программа под лицензией GPL-3.0. '
                        'Подписки и настройки хранятся на диске в зашифрованном виде.',
                        'Version $appVersion. Core: mihomo. Free software under the GPL-3.0 license. '
                        'Subscriptions and settings are stored encrypted on disk.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (ref.watch(hostProvider).artChoices.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => showCustomize(context),
                            icon: const Icon(Icons.palette_outlined),
                            label: Text(tr('Оформление', 'Customize')),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => showLogs(context),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: Text(tr('Логи', 'Logs')),
                        ),
                        if (gnomeToggleAvailable(ref.watch(hostProvider)))
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await installGnomeToggle(ref.read(hostProvider));
                                if (context.mounted) {
                                  showMessage(
                                    context,
                                    tr('Готово. Перезайдите в систему, и Crocell появится в быстрых настройках.',
                                        'Done. Log out and back in, and Crocell shows up in Quick Settings.'),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) showError(context, e);
                              }
                            },
                            icon: const Icon(Icons.toggle_on_outlined),
                            label: Text(tr('Добавить в быстрые настройки GNOME', 'Add to GNOME quick settings')),
                          ),
                      ],
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
        Text(tr('Всё остальное', 'Everything else'), style: Theme.of(context).textTheme.titleSmall),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, icon: const Icon(Icons.shield_outlined), label: Text(tr('Через VPN', 'Through VPN'))),
            ButtonSegment(value: true, icon: const Icon(Icons.north_east_rounded), label: Text(tr('Напрямую', 'Direct'))),
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
        ? tr('Ещё не скачаны. Скачаются сами, как только в правилах появится geosite или geoip.', "Not downloaded yet. They'll download by themselves as soon as a geosite or geoip rule shows up.")
        : tr(
            'Обновлены ${_ago(updated.reduce((a, b) => a.isBefore(b) ? a : b))} · '
                '${info.geositeCategories.length} наборов сайтов, ${info.geoipCategories.length} наборов IP',
            'Updated ${_ago(updated.reduce((a, b) => a.isBefore(b) ? a : b))} · '
                '${_sets(info.geositeCategories.length, 'site')}, ${_sets(info.geoipCategories.length, 'IP')}',
          );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line, style: theme.textTheme.bodyMedium),
        if (info.error.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            tr('Не получилось обновить: ${info.error}', "Couldn't update: ${info.error}"),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          tr('Источник и частоту обновления можно поменять в «Дополнительно».', 'You can change the source and update frequency under "Advanced".'),
          style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
        ),
      ],
    );
    final button = FilledButton.tonalIcon(
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
      label: Text(info.updating ? tr('Обновляю…', 'Updating…') : tr('Обновить', 'Update')),
    );

    // A phone has no room beside the text: the button goes under it.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) => c.maxWidth < 480
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [text, const SizedBox(height: 12), button],
                )
              : Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: 12),
                    button,
                  ],
                ),
        ),
      ),
    );
  }

  static String _sets(int n, String kind) => '$n $kind ${n == 1 ? 'set' : 'sets'}';

  static String _ago(DateTime when) {
    final d = DateTime.now().difference(when);
    if (d.inMinutes < 1) return tr('только что', 'just now');
    if (d.inHours < 1) return tr('${d.inMinutes} мин назад', '${d.inMinutes} min ago');
    if (d.inDays < 1) return tr('${d.inHours} ч назад', '${d.inHours} h ago');
    return tr('${d.inDays} дн назад', "${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago");
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
  late final _port = TextEditingController(
    text: '${widget.settings.mixedPort == 0 ? 7890 : widget.settings.mixedPort}',
  );
  late final _geoip = TextEditingController(text: widget.settings.geo.geoipSource);
  late final _geosite = TextEditingController(text: widget.settings.geo.geositeSource);
  late final _geoHours = TextEditingController(
    text: widget.settings.geo.updateHours == 0 ? '' : '${widget.settings.geo.updateHours}',
  );
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

  List<String> _lines(TextEditingController c) => [
    for (final l in c.text.split(RegExp(r'[\n,]')))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  Future<void> _save() async {
    final port = int.tryParse(_port.text.trim());
    if (port == null) {
      setState(() => _error = tr('Порт — это число от 1024 до 65535', 'The port must be a number from 1024 to 65535'));
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
    final android = ref.watch(hostProvider).embeddedCore;
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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          alignLabelWithHint: true,
        ),
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(tr('Дополнительно', 'Advanced'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(tr('DNS, IPv6, порт, источники баз', 'DNS, IPv6, port, database sources'), style: theme.textTheme.bodySmall?.copyWith(color: t.muted)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        shape: const Border(),
        children: [
          if (android) const _HideNotification(),
          // On a phone the system starts the VPN (always-on), and nobody
          // shares a phone's VPN with the LAN.
          if (!android)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Подключаться при запуске', 'Connect on startup')),
              subtitle: Text(tr('Служба поднимет последнюю ноду сама, даже до входа в систему.', 'The service will bring up the last node by itself, even before you log in.')),
              value: s.connectOnStart,
              onChanged: (v) => _edit((s) => s.connectOnStart = v),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('IPv6'),
            subtitle: Text(tr('Выключите, если сайты по IPv6 открываются мимо VPN или не открываются вовсе.', "Turn off if sites over IPv6 bypass the VPN or don't open at all.")),
            value: !s.disableIpv6,
            onChanged: (v) => _edit((s) => s.disableIpv6 = !v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Настоящие IP-адреса вместо Fake-IP', 'Real IP addresses instead of Fake-IP')),
            subtitle: Text(tr('Медленнее, но некоторые игры и P2P-программы без этого не работают в туннеле.', "Slower, but some games and P2P programs don't work in the tunnel without it.")),
            value: s.dns.realIp,
            onChanged: (v) => _edit((s) => s.dns = (s.dns.deepCopy()..realIp = v)),
          ),
          if (!android)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Пускать устройства из локальной сети', 'Allow devices from the local network')),
              subtitle: Text(
                tr('Телефон или приставка смогут ходить через этот компьютер, на порт ${s.mixedPort == 0 ? 7890 : s.mixedPort}.', 'A phone or game console can go through this computer, on port ${s.mixedPort == 0 ? 7890 : s.mixedPort}.'),
              ),
              value: s.allowLan,
              onChanged: (v) => _edit((s) => s.allowLan = v),
            ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final stack = DropdownButtonFormField<String>(
                initialValue: s.tunStack.isEmpty ? 'mixed' : s.tunStack,
                isExpanded: true, // shrink with the window instead of overflowing it
                decoration: InputDecoration(labelText: tr('Стек туннеля', 'Tunnel stack')),
                items: [
                  DropdownMenuItem(
                    value: 'mixed',
                    child: Text(tr('Смешанный (рекомендуется)', 'Mixed (recommended)'), overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(value: 'system', child: Text(tr('Системный', 'System'))),
                  const DropdownMenuItem(value: 'gvisor', child: Text('gVisor')),
                ],
                onChanged: (v) => _edit((s) => s.tunStack = v ?? 'mixed'),
              );
              final port = field(_port, tr('Порт прокси', 'Proxy port'));
              // Android always tunnels with gVisor: nothing to choose.
              if (android) return port;
              if (c.maxWidth < 480) {
                return Column(children: [stack, const SizedBox(height: 12), port]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: stack),
                  const SizedBox(width: 12),
                  SizedBox(width: 140, child: port),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          field(
            _dns,
            tr('DNS-серверы', 'DNS servers'),
            hint: 'https://1.1.1.1/dns-query\nhttps://8.8.8.8/dns-query',
            helper: tr('По одному в строке, запросы идут через VPN. Пусто — Cloudflare и Google.', 'One per line, queries go through the VPN. Empty means Cloudflare and Google.'),
            lines: 3,
          ),
          field(
            _directDns,
            tr('DNS для прямых соединений', 'DNS for direct connections'),
            hint: '77.88.8.8',
            helper: tr('Для сайтов и программ из «Напрямую». Пусто — Яндекс и Cloudflare.', 'For sites and programs in "Direct". Empty means Yandex and Cloudflare.'),
            lines: 2,
          ),
          field(_geoip, tr('Источник geoip.dat', 'geoip.dat source'), hint: tr('Ссылка или путь к файлу', 'Link or file path'), helper: tr('Пусто — runetfreedom.', 'Empty means runetfreedom.')),
          field(_geosite, tr('Источник geosite.dat', 'geosite.dat source'), hint: tr('Ссылка или путь к файлу', 'Link or file path'), helper: tr('Пусто — runetfreedom.', 'Empty means runetfreedom.')),
          SizedBox(width: 220, child: field(_geoHours, tr('Обновлять базы, часов', 'Database update interval, hours'), hint: '24')),
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
                  : Text(tr('Сохранить', 'Save')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Android: the ongoing notification can go in tunnel mode, where the
/// system itself keeps the VPN service alive. Proxy mode keeps it.
class _HideNotification extends StatefulWidget {
  const _HideNotification();

  @override
  State<_HideNotification> createState() => _HideNotificationState();
}

class _HideNotificationState extends State<_HideNotification> {
  bool? _hide;

  @override
  void initState() {
    super.initState();
    hideVpnNotification().then((v) {
      if (mounted) setState(() => _hide = v);
    }).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(tr('Не показывать уведомление', 'Hide the notification')),
      subtitle: Text(tr(
        'В режиме туннеля VPN держит сама система, уведомление ему не нужно. Crocell попросит не ограничивать '
            'его в фоне. В режиме прокси уведомление останется: без него Android усыпит прокси.',
        'In tunnel mode the system itself keeps the VPN running, so it needs no notification. Crocell will ask '
            'not to be restricted in the background. Proxy mode keeps it: without it Android puts the proxy to sleep.',
      )),
      value: _hide ?? false,
      onChanged: _hide == null
          ? null
          : (v) async {
              setState(() => _hide = v);
              try {
                await setHideVpnNotification(v);
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
    );
  }
}
