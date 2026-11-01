import 'package:crocell/data/core_api.dart';
import 'package:crocell/data/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every form a person types', () {
    final r = parseRuleInput('wiseless.net\n*.wiseless.net, +.wiseless.net\n'
        '10.0.0.0/8\n1.1.1.1\n2001:db8::/32\ngeosite:RU-Blocked\ngeoip:telegram\nhttps://Www.Example.com/path?q=1');
    expect(r.error, isNull);
    expect([for (final x in r.rules) (x.kind, x.value)], [
      (RuleKind.RULE_KIND_DOMAIN, 'wiseless.net'),
      (RuleKind.RULE_KIND_DOMAIN_WILDCARD, '*.wiseless.net'),
      (RuleKind.RULE_KIND_DOMAIN_SUFFIX, 'wiseless.net'),
      (RuleKind.RULE_KIND_IP_CIDR, '10.0.0.0/8'),
      (RuleKind.RULE_KIND_IP_CIDR, '1.1.1.1'),
      (RuleKind.RULE_KIND_IP_CIDR, '2001:db8::/32'),
      (RuleKind.RULE_KIND_GEOSITE, 'ru-blocked'),
      (RuleKind.RULE_KIND_GEOIP, 'telegram'),
      (RuleKind.RULE_KIND_DOMAIN, 'www.example.com'),
    ]);
  });

  test('v2ray lists paste as they are, whole zones included', () {
    final r = parseRuleInput('domain:ru\nDomain:xn--p1ai\ndomain:mail.ru\nfull:ya.ru');
    expect(r.error, isNull);
    expect([for (final x in r.rules) (x.kind, x.value)], [
      (RuleKind.RULE_KIND_DOMAIN_SUFFIX, 'ru'),
      (RuleKind.RULE_KIND_DOMAIN_SUFFIX, 'xn--p1ai'),
      (RuleKind.RULE_KIND_DOMAIN_SUFFIX, 'mail.ru'),
      (RuleKind.RULE_KIND_DOMAIN, 'ya.ru'),
    ]);
    // A zone on its own is still a typo, not "the domain ru".
    expect(parseRuleInput('ru').error, isNotNull);
    expect(parseRuleInput('full:ru').error, isNotNull);
  });

  test('nonsense is named in the error', () {
    for (final bad in ['not a domain', '10.0.0.0/40', 'geosite:', 'localhost', '*.']) {
      final r = parseRuleInput(bad);
      expect(r.error, isNotNull, reason: bad);
    }
  });

  test('wiseless.net and *.wiseless.net mean different things', () {
    final exact = RouteRule(kind: RuleKind.RULE_KIND_DOMAIN, value: 'wiseless.net');
    final subs = RouteRule(kind: RuleKind.RULE_KIND_DOMAIN_WILDCARD, value: '*.wiseless.net');
    expect(ruleKindLabel(exact), 'Только этот домен');
    expect(ruleKindLabel(subs), 'Поддомены');
  });
}
