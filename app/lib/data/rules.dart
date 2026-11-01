import 'dart:io';

import 'core_api.dart';

/// A rule as typed, before it has an action.
class ParsedRule {
  const ParsedRule(this.kind, this.value);
  final RuleKind kind;
  final String value;
}

/// Reads what a person types into the site field, one entry per line or
/// comma. Same forms as `crocell ctl rule`:
///
///   wiseless.net        exactly this domain
///   *.wiseless.net      its subdomains, not the domain itself
///   +.wiseless.net      the domain and all subdomains
///   domain:ru           the same, as v2ray lists write it; zones allowed
///   full:wiseless.net   exactly this domain, v2ray style
///   10.0.0.0/8, 1.1.1.1 a subnet or one address (IPv6 too)
///   geosite:ru-blocked  a geosite.dat set
///   geoip:telegram      a geoip.dat set
///
/// Returns the rules and, for anything unreadable, an error naming it.
({List<ParsedRule> rules, String? error}) parseRuleInput(String text) {
  final rules = <ParsedRule>[];
  for (var raw in text.split(RegExp(r'[\n,]'))) {
    raw = raw.trim();
    if (raw.isEmpty) continue;
    final r = _parseOne(raw);
    if (r == null) return (rules: rules, error: '«$raw» — не похоже ни на сайт, ни на IP, ни на набор');
    rules.add(r);
  }
  return (rules: rules, error: null);
}

ParsedRule? _parseOne(String s) {
  final lower = s.toLowerCase();
  for (final (prefix, kind) in [('geosite:', RuleKind.RULE_KIND_GEOSITE), ('geoip:', RuleKind.RULE_KIND_GEOIP)]) {
    if (lower.startsWith(prefix)) {
      final name = lower.substring(prefix.length);
      return RegExp(r'^[a-z0-9_!@:-]+$').hasMatch(name) ? ParsedRule(kind, name) : null;
    }
  }
  if (_isIpOrCidr(s)) return ParsedRule(RuleKind.RULE_KIND_IP_CIDR, s);

  // People paste whole links: keep only the host. Before the wildcard
  // check, since a query string has a "?".
  if (lower.contains('://')) {
    final uri = Uri.tryParse(s);
    final host = uri?.host.toLowerCase() ?? '';
    return _isDomain(host) ? ParsedRule(RuleKind.RULE_KIND_DOMAIN, host) : null;
  }
  for (final prefix in ['+.', 'domain:']) {
    if (lower.startsWith(prefix)) {
      final d = lower.substring(prefix.length).trim();
      return _isDomain(d) || _isZone(d) ? ParsedRule(RuleKind.RULE_KIND_DOMAIN_SUFFIX, d) : null;
    }
  }
  if (lower.startsWith('full:')) {
    final d = lower.substring(5).trim();
    return _isDomain(d) ? ParsedRule(RuleKind.RULE_KIND_DOMAIN, d) : null;
  }
  if (lower.contains('*') || lower.contains('?')) {
    return _isDomain(lower.replaceAll(RegExp(r'[*?]'), 'a')) ? ParsedRule(RuleKind.RULE_KIND_DOMAIN_WILDCARD, lower) : null;
  }
  return _isDomain(lower) ? ParsedRule(RuleKind.RULE_KIND_DOMAIN, lower) : null;
}

bool _isIpOrCidr(String s) {
  final parts = s.split('/');
  if (parts.length > 2) return false;
  final ip = InternetAddress.tryParse(parts[0]);
  if (ip == null) return false;
  if (parts.length == 1) return true;
  final bits = int.tryParse(parts[1]);
  final max = ip.type == InternetAddressType.IPv4 ? 32 : 128;
  return bits != null && bits >= 0 && bits <= max;
}

bool _isDomain(String d) =>
    d.length <= 253 && RegExp(r'^([a-z0-9¡-￿]([a-z0-9¡-￿-]*[a-z0-9¡-￿])?\.)+[a-z¡-￿0-9-]{2,}$').hasMatch(d);

/// A whole zone, like ru or xn--p1ai: only as "everything under it".
bool _isZone(String d) => RegExp(r'^[a-z0-9¡-￿]([a-z0-9¡-￿-]{0,61}[a-z0-9¡-￿])$').hasMatch(d);

/// A rule as it would be typed, so a copied list pastes back as the same
/// rules (programs in the CLI's proc: form).
String ruleInput(RouteRule r) => switch (r.kind) {
      RuleKind.RULE_KIND_DOMAIN_SUFFIX => '+.${r.value}',
      RuleKind.RULE_KIND_GEOSITE => 'geosite:${r.value}',
      RuleKind.RULE_KIND_GEOIP => 'geoip:${r.value}',
      RuleKind.RULE_KIND_PROCESS_NAME => 'proc:${r.value}',
      _ => r.value,
    };

/// How a rule reads back in the list.
String ruleTitle(RouteRule r) => switch (r.kind) {
      RuleKind.RULE_KIND_DOMAIN_SUFFIX => '+.${r.value}',
      RuleKind.RULE_KIND_GEOSITE => 'geosite:${r.value}',
      RuleKind.RULE_KIND_GEOIP => 'geoip:${r.value}',
      RuleKind.RULE_KIND_PROCESS_PATH => r.value.split(RegExp(r'[/\\]')).last,
      _ => r.value,
    };

String ruleKindLabel(RouteRule r) => switch (r.kind) {
      RuleKind.RULE_KIND_DOMAIN => 'Только этот домен',
      RuleKind.RULE_KIND_DOMAIN_WILDCARD => 'Поддомены',
      RuleKind.RULE_KIND_DOMAIN_SUFFIX => 'Домен и поддомены',
      RuleKind.RULE_KIND_IP_CIDR => r.value.contains('/') ? 'Подсеть' : 'IP-адрес',
      RuleKind.RULE_KIND_GEOSITE => 'Набор сайтов',
      RuleKind.RULE_KIND_GEOIP => 'Набор IP-адресов',
      RuleKind.RULE_KIND_PROCESS_NAME => 'Программа',
      RuleKind.RULE_KIND_PROCESS_PATH => r.value,
      _ => '',
    };

/// Hand-picked sets worth suggesting, shown only if present in the files.
/// Names checked against runetfreedom's databases on 1 Nov 2026.
const geoSuggestions = <({String input, String label})>[
  (input: 'geosite:ru-blocked', label: 'Заблокированное в России'),
  (input: 'geoip:ru-blocked', label: 'Заблокированные в России IP'),
  (input: 'geosite:category-ru', label: 'Российские сайты'),
  (input: 'geoip:ru', label: 'Российские IP-адреса'),
  (input: 'geosite:ru-available-only-inside', label: 'Работает только из России'),
  (input: 'geosite:youtube', label: 'YouTube'),
  (input: 'geosite:telegram', label: 'Telegram'),
  (input: 'geoip:telegram', label: 'IP-адреса Telegram'),
  (input: 'geosite:openai', label: 'ChatGPT и OpenAI'),
  (input: 'geosite:discord', label: 'Discord'),
  (input: 'geosite:category-ads-all', label: 'Реклама'),
  (input: 'geosite:win-spy', label: 'Слежка Windows'),
];
