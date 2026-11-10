import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/rules.dart';
import '../data/state.dart';
import '../host.dart';
import '../l10n.dart';
import '../theme.dart';
import 'common.dart';
import 'add_rule.dart' show ruleIcon;
import 'routing_panel.dart';

/// A routing link, as Happ and INCY take them: happ://routing/onadd/…, any
/// scheme. Only the shape; the core reads the inside.
bool looksLikeRoutingLink(String s) => RegExp(r'^[a-z][a-z0-9+.-]*://routing/', caseSensitive: false).hasMatch(s.trim());

/// Reads a routing link and shows what it would add.
Future<void> importRoutingLink(BuildContext context, WidgetRef ref, String text) async {
  final RoutingProfile profile;
  try {
    profile = await ref.read(coreApiProvider).readRouting(text.trim());
  } catch (e) {
    if (context.mounted) showError(context, e);
    return;
  }
  if (context.mounted) await showRoutingImport(context, ref, profile);
}

/// The provider's routing profile, after a subscription is added or
/// refreshed by hand. Asks on add when the profile is new or changed; on a
/// refresh only when the person took it before and it has changed since,
/// so a "no" is not asked again and again.
Future<void> offerSubscriptionRouting(BuildContext context, WidgetRef ref, Subscription sub, {required bool refreshed}) async {
  if (!sub.hasRouting() || sub.routing.rules.isEmpty) return;
  final p = sub.routing;
  final settings = await ref.read(settingsProvider.future);
  final had = [
    for (final r in settings.rules)
      if (r.group == p.name) r,
  ];
  if (refreshed && had.isEmpty) return;
  if (had.isNotEmpty && _sameRules(had, _forThisDevice(ref, p.rules), settings.rules)) return;
  if (context.mounted) await showRoutingImport(context, ref, p, provider: sub.title);
}

bool _sameRules(List<RouteRule> had, List<RouteRule> offered, List<RouteRule> all) {
  String key(RouteRule r) => '${r.kind.value}|${r.value}|${r.action.value}';
  // A rule kept out because the person has their own is not a change.
  final mine = {
    for (final r in all)
      if (r.group.isEmpty) '${r.kind.value}|${r.value}',
  };
  final want = {
    for (final r in offered)
      if (!mine.contains('${r.kind.value}|${r.value}')) key(r),
  };
  return want.length == had.length && had.every((r) => want.contains(key(r)));
}

/// What the dialog would add by default: no Android packages on a computer,
/// no sets missing from the local databases.
List<RouteRule> _forThisDevice(WidgetRef ref, List<RouteRule> rules) {
  final android = ref.read(hostProvider).kind == HostKind.android;
  final geo = ref.read(geoInfoProvider).value;
  return [
    for (final r in rules)
      if ((android || r.kind != RuleKind.RULE_KIND_PROCESS_NAME) && _known(geo, r)) r,
  ];
}

/// Unknown when the databases are not read yet: then nothing is held back.
bool _known(GeoInfo? geo, RouteRule r) => switch (r.kind) {
      RuleKind.RULE_KIND_GEOSITE => geo == null || geo.geositeCategories.isEmpty || geo.geositeCategories.contains(r.value),
      RuleKind.RULE_KIND_GEOIP => geo == null || geo.geoipCategories.isEmpty || geo.geoipCategories.contains(r.value),
      _ => true,
    };

Future<void> showRoutingImport(BuildContext context, WidgetRef ref, RoutingProfile profile, {String provider = ''}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _RoutingImportDialog(profile: profile, provider: provider),
  );
}

/// Asks for a routing link, from the clipboard when there is one.
Future<void> showRoutingLinkInput(BuildContext context, WidgetRef ref) async {
  final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
  if (!context.mounted) return;
  final controller = TextEditingController(text: looksLikeRoutingLink(clip) ? clip : '');
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Правила из ссылки', 'Rules from a link')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(
              'Ссылка с правилами от VPN-сервиса, такая же, как для Happ или INCY: happ://routing/… '
                  'Перед добавлением Crocell покажет, что в ней.',
              'A routing link from your VPN service, the same as for Happ or INCY: happ://routing/… '
                  'Crocell shows what is inside before adding anything.',
            )),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'happ://routing/onadd/…'),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Отмена', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(tr('Посмотреть', 'Show'))),
      ],
    ),
  );
  controller.dispose();
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  await importRoutingLink(context, ref, text);
}

class _RoutingImportDialog extends ConsumerStatefulWidget {
  const _RoutingImportDialog({required this.profile, required this.provider});

  final RoutingProfile profile;
  final String provider;

  @override
  ConsumerState<_RoutingImportDialog> createState() => _RoutingImportDialogState();
}

class _RoutingImportDialogState extends ConsumerState<_RoutingImportDialog> {
  // Both start unticked: they change the person's own choices, in either
  // direction, and apply to more than this profile.
  bool _final = false;
  bool _dnsGeo = false;
  bool _busy = false;

  RoutingProfile get p => widget.profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final settings = ref.watch(settingsProvider).value;
    final all = settings?.rules ?? <RouteRule>[];
    final android = ref.watch(hostProvider).kind == HostKind.android;

    final mine = {
      for (final r in all)
        if (r.group.isEmpty) '${r.kind.value}|${r.value}',
    };
    final apps = p.rules.where((r) => r.kind == RuleKind.RULE_KIND_PROCESS_NAME).length;
    // A set missing from the databases stops mihomo from starting. Unless
    // the profile's own databases come along, such sets stay out.
    final geo = ref.watch(geoInfoProvider).value;
    bool known(RouteRule r) => _known(geo, r);
    final missing = [
      for (final r in p.rules)
        if (!known(r)) '${r.kind == RuleKind.RULE_KIND_GEOIP ? 'geoip' : 'geosite'}:${r.value}',
    ];
    final usable = [
      for (final r in p.rules)
        if ((android || r.kind != RuleKind.RULE_KIND_PROCESS_NAME) && (_dnsGeo || known(r))) r,
    ];
    final kept = usable.where((r) => mine.contains('${r.kind.value}|${r.value}')).length;
    final adding = usable.length - kept;
    final replaces = all.any((r) => r.group == p.name);

    final currentFinal = settings?.finalAction ?? RouteAction.ROUTE_ACTION_PROXY;
    final offersFinal = p.finalAction != RouteAction.ROUTE_ACTION_UNSPECIFIED &&
        p.finalAction != (currentFinal == RouteAction.ROUTE_ACTION_UNSPECIFIED ? RouteAction.ROUTE_ACTION_PROXY : currentFinal);
    final dnsGeo = [
      if (p.dns.servers.isNotEmpty) tr('DNS через VPN: ${p.dns.servers.join(', ')}', 'DNS through the VPN: ${p.dns.servers.join(', ')}'),
      if (p.dns.directServers.isNotEmpty) tr('DNS для прямых: ${p.dns.directServers.join(', ')}', 'DNS for direct: ${p.dns.directServers.join(', ')}'),
      if (p.geo.geoipSource.isNotEmpty) 'geoip: ${p.geo.geoipSource}',
      if (p.geo.geositeSource.isNotEmpty) 'geosite: ${p.geo.geositeSource}',
    ];
    final nothing = adding == 0 && !offersFinal && dnsGeo.isEmpty;

    return AlertDialog(
      scrollable: true,
      title: Text(tr('Правила «${p.name}»', 'Rules "${p.name}"')),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                widget.provider.isNotEmpty
                    ? tr('Их предлагает подписка «${widget.provider}».', 'The subscription "${widget.provider}" offers them.')
                    : tr('Вот что в ссылке.', "Here is what's in the link."),
                tr('Правила лягут отдельной группой, её можно убрать целиком в настройках маршрутизации.',
                    'They go in as a group that can be removed at once in the routing settings.'),
                if (replaces) tr('Прежние правила этой группы заменятся.', "The group's earlier rules will be replaced."),
              ].join(' '),
              style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
            ),
            for (final l in routeLists)
              if (usable.any((r) => r.action == l.action)) _list(l.title, l.icon, [for (final r in usable) if (r.action == l.action) r]),
            if (kept > 0)
              _note(tr('Правил, которые у вас уже есть: $kept. Ваши останутся как есть.',
                  'Rules you already have: $kept. Yours stay as they are.')),
            if (!android && apps > 0)
              _note(tr('Приложения Android ($apps) пропущены: они для телефона.',
                  'Android apps ($apps) are left out: they are for a phone.')),
            if (missing.isNotEmpty && !_dnsGeo)
              _note(tr('Этих наборов нет в ваших базах geosite/geoip, пропустим: ${missing.join(', ')}',
                  "These sets aren't in your geosite/geoip databases and will be skipped: ${missing.join(', ')}")),
            if (p.unsupported.isNotEmpty)
              _note(tr('Этого Crocell пока не умеет, пропустит: ${p.unsupported.join(', ')}',
                  "Crocell can't do these yet and will skip them: ${p.unsupported.join(', ')}")),
            if (offersFinal) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _final,
                onChanged: _busy ? null : (v) => setState(() => _final = v ?? false),
                title: Text(p.finalAction == RouteAction.ROUTE_ACTION_DIRECT
                    ? tr('Всё остальное мимо VPN', 'Everything else past the VPN')
                    : tr('Всё остальное через VPN', 'Everything else through the VPN')),
                subtitle: p.finalAction == RouteAction.ROUTE_ACTION_DIRECT
                    ? Text(
                        tr('Профиль просит пускать напрямую всё, чего нет в правилах. Тогда через VPN пойдёт только список «Через VPN».',
                            'The profile asks to send everything not in the rules direct. Then only the "Through VPN" list uses the VPN.'),
                        style: TextStyle(color: t.brandText),
                      )
                    : Text(tr('Сейчас всё остальное у вас идёт напрямую.', 'Everything else goes direct for you now.')),
              ),
            ],
            if (dnsGeo.isNotEmpty) ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _dnsGeo,
                onChanged: _busy ? null : (v) => setState(() => _dnsGeo = v ?? false),
                title: Text(tr('Взять и DNS с базами geosite/geoip', 'Take the DNS and geosite/geoip databases too')),
                subtitle: Text(
                  [
                    ...dnsGeo,
                    tr('Это для всех правил, не только этих.', 'This applies to all rules, not just these.'),
                  ].join('\n'),
                ),
              ),
            ],
            if (nothing)
              _note(tr('Нового здесь ничего нет.', 'Nothing new here.')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(tr('Не добавлять', "Don't add"))),
        FilledButton(
          onPressed: _busy || nothing ? null : () => _apply(usable),
          child: Text(adding > 0 ? tr('Добавить $adding', 'Add $adding') : tr('Применить', 'Apply')),
        ),
      ],
    );
  }

  Widget _list(String title, IconData icon, List<RouteRule> rules) {
    final t = context.tokens;
    const shown = 24;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: t.muted),
            const SizedBox(width: 6),
            Text('$title · ${rules.length}', style: Theme.of(context).textTheme.labelLarge),
          ]),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final r in rules.take(shown))
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(ruleIcon(r), size: 16, color: t.muted),
                  label: Text(ruleTitle(r)),
                ),
              if (rules.length > shown) Chip(visualDensity: VisualDensity.compact, label: Text(tr('и ещё ${rules.length - shown}', 'and ${rules.length - shown} more'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.muted)),
      );

  Future<void> _apply(List<RouteRule> rules) async {
    setState(() => _busy = true);
    try {
      await ref.read(settingsProvider.notifier).applyRouting(
            p.name,
            rules,
            finalAction: _final ? p.finalAction : null,
            dns: _dnsGeo ? p.dns : null,
            geo: _dnsGeo ? p.geo : null,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }
}
