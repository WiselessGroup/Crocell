import '../data/core_api.dart';
import '../l10n.dart';

/// Country names people read, by ISO 3166-1 alpha-2, in Russian and
/// English. Text, not flag emoji: Windows has no flag glyphs, and a flag
/// alone is not accessible.
const _countries = {
  'RU': ('Россия', 'Russia'), 'NL': ('Нидерланды', 'Netherlands'), 'DE': ('Германия', 'Germany'),
  'PL': ('Польша', 'Poland'), 'SG': ('Сингапур', 'Singapore'), 'FI': ('Финляндия', 'Finland'),
  'SE': ('Швеция', 'Sweden'), 'NO': ('Норвегия', 'Norway'), 'EE': ('Эстония', 'Estonia'),
  'LV': ('Латвия', 'Latvia'), 'LT': ('Литва', 'Lithuania'), 'FR': ('Франция', 'France'),
  'GB': ('Великобритания', 'United Kingdom'), 'US': ('США', 'USA'), 'CA': ('Канада', 'Canada'),
  'TR': ('Турция', 'Turkey'), 'KZ': ('Казахстан', 'Kazakhstan'), 'AM': ('Армения', 'Armenia'),
  'GE': ('Грузия', 'Georgia'), 'AT': ('Австрия', 'Austria'), 'CH': ('Швейцария', 'Switzerland'),
  'CZ': ('Чехия', 'Czechia'), 'IT': ('Италия', 'Italy'), 'ES': ('Испания', 'Spain'),
  'PT': ('Португалия', 'Portugal'), 'RO': ('Румыния', 'Romania'), 'BG': ('Болгария', 'Bulgaria'),
  'HU': ('Венгрия', 'Hungary'), 'RS': ('Сербия', 'Serbia'), 'MD': ('Молдова', 'Moldova'),
  'UA': ('Украина', 'Ukraine'), 'BY': ('Беларусь', 'Belarus'), 'IL': ('Израиль', 'Israel'),
  'AE': ('ОАЭ', 'UAE'), 'JP': ('Япония', 'Japan'), 'HK': ('Гонконг', 'Hong Kong'),
  'KR': ('Южная Корея', 'South Korea'), 'IN': ('Индия', 'India'), 'AU': ('Австралия', 'Australia'),
  'IE': ('Ирландия', 'Ireland'), 'BE': ('Бельгия', 'Belgium'), 'DK': ('Дания', 'Denmark'),
  'LU': ('Люксембург', 'Luxembourg'), 'CY': ('Кипр', 'Cyprus'), 'GR': ('Греция', 'Greece'),
};

/// The country's name in the app's language, or the code if unknown.
String countryName(String code) {
  final c = _countries[code.toUpperCase()];
  return c == null ? code.toUpperCase() : tr(c.$1, c.$2);
}

/// Both names, so a search finds a country typed in either language.
List<String> _countryNames(String code) {
  final c = _countries[code.toUpperCase()];
  return c == null ? [code.toUpperCase()] : [c.$1, c.$2];
}

/// Cloudflare PoP (IATA airport code) to a city: tells "Frankfurt" from
/// "Germany somewhere" without a GeoIP database.
const _colos = {
  'FRA': ('Франкфурт', 'Frankfurt'), 'AMS': ('Амстердам', 'Amsterdam'), 'WAW': ('Варшава', 'Warsaw'),
  'SIN': ('Сингапур', 'Singapore'), 'HEL': ('Хельсинки', 'Helsinki'), 'ARN': ('Стокгольм', 'Stockholm'),
  'OSL': ('Осло', 'Oslo'), 'CPH': ('Копенгаген', 'Copenhagen'), 'TLL': ('Таллин', 'Tallinn'),
  'RIX': ('Рига', 'Riga'), 'VNO': ('Вильнюс', 'Vilnius'), 'LHR': ('Лондон', 'London'),
  'MAN': ('Манчестер', 'Manchester'), 'CDG': ('Париж', 'Paris'), 'MRS': ('Марсель', 'Marseille'),
  'DUS': ('Дюссельдорф', 'Düsseldorf'), 'HAM': ('Гамбург', 'Hamburg'), 'MUC': ('Мюнхен', 'Munich'),
  'BER': ('Берлин', 'Berlin'), 'TXL': ('Берлин', 'Berlin'), 'VIE': ('Вена', 'Vienna'),
  'ZRH': ('Цюрих', 'Zurich'), 'PRG': ('Прага', 'Prague'), 'MXP': ('Милан', 'Milan'),
  'FCO': ('Рим', 'Rome'), 'MAD': ('Мадрид', 'Madrid'), 'LIS': ('Лиссабон', 'Lisbon'),
  'OTP': ('Бухарест', 'Bucharest'), 'SOF': ('София', 'Sofia'), 'BUD': ('Будапешт', 'Budapest'),
  'BEG': ('Белград', 'Belgrade'), 'KIV': ('Кишинёв', 'Chișinău'), 'IST': ('Стамбул', 'Istanbul'),
  'TLV': ('Тель-Авив', 'Tel Aviv'), 'DXB': ('Дубай', 'Dubai'), 'ALA': ('Алматы', 'Almaty'),
  'EVN': ('Ереван', 'Yerevan'), 'TBS': ('Тбилиси', 'Tbilisi'), 'DME': ('Москва', 'Moscow'),
  'SVO': ('Москва', 'Moscow'), 'LED': ('Санкт-Петербург', 'Saint Petersburg'),
  'KJA': ('Красноярск', 'Krasnoyarsk'), 'NRT': ('Токио', 'Tokyo'), 'HKG': ('Гонконг', 'Hong Kong'),
  'ICN': ('Сеул', 'Seoul'), 'BOM': ('Мумбаи', 'Mumbai'), 'SYD': ('Сидней', 'Sydney'),
  'DUB': ('Дублин', 'Dublin'), 'BRU': ('Брюссель', 'Brussels'), 'LUX': ('Люксембург', 'Luxembourg'),
  'ATH': ('Афины', 'Athens'), 'EWR': ('Нью-Йорк', 'New York'), 'IAD': ('Вашингтон', 'Washington'),
  'ORD': ('Чикаго', 'Chicago'), 'LAX': ('Лос-Анджелес', 'Los Angeles'), 'SJC': ('Сан-Хосе', 'San Jose'),
  'YYZ': ('Торонто', 'Toronto'),
};

/// The city in the app's language, or null if the PoP is unknown.
String? coloCity(String colo) {
  final c = _colos[colo.toUpperCase()];
  return c == null ? null : tr(c.$1, c.$2);
}

/// Both names of the city, for search; empty if the PoP is unknown.
List<String> _cityNames(String colo) {
  final c = _colos[colo.toUpperCase()];
  return c == null ? const [] : [c.$1, c.$2];
}

/// "Германия, Франкфурт" ("Germany, Frankfurt"), or just the country when
/// the city is unknown.
String exitPlace(ProbeResult r) {
  final city = coloCity(r.exitColo);
  final country = countryName(r.exitCountry);
  return city == null || city == country ? country : '$country, $city';
}

/// cut: the node answers, but the provider breaks off anything bigger than
/// a few kilobytes on the way to it. As useless as down, with another cause.
enum Quality { good, slow, cut, down, unknown }

/// What a probe means for a person, not a number to decode.
Quality quality(ProbeResult? r) {
  if (r == null || (!r.hasProbedAt() && r.error.isEmpty && r.exitIp.isEmpty)) return Quality.unknown;
  if (r.cut) return Quality.cut;
  if (r.error.isNotEmpty) return Quality.down;
  return r.latencyMs <= 600 ? Quality.good : Quality.slow;
}

/// Why the live check failed, in one phrase that ends with what to do.
/// Null while it works. The core works out the reason; this only words it.
String? whyBroken(ProbeResult r) {
  if (r.error.isEmpty && !r.cut) return null;
  if (r.cut) return _cutText;
  return switch (r.verdict) {
    Verdict.VERDICT_NO_INTERNET => tr('Нет интернета. Проверьте Wi-Fi или мобильную сеть.', 'No internet. Check Wi-Fi or mobile data.'),
    Verdict.VERDICT_WHITELIST => tr(
        'Мобильный интернет в режиме белого списка: открываются только разрешённые сайты. Помогут ноды с пометкой БС.',
        'Mobile internet is in whitelist mode: only allowed sites open. Nodes marked БС or WL can help.'),
    Verdict.VERDICT_CUT => _cutText,
    Verdict.VERDICT_NODE_BLOCKED =>
      tr('Провайдер не пускает к этой ноде. Попробуйте другую.', "Your provider doesn't let you reach this node. Try another one."),
    Verdict.VERDICT_NODE_DOWN =>
      tr('Сеть в порядке, но нода не отвечает. Попробуйте другую.', 'The network is fine, but the node is not responding. Try another one.'),
    Verdict.VERDICT_INTERCEPTED => tr('Провайдер подменяет защищённые соединения. Попробуйте другую ноду или другую сеть.',
        'Your provider tampers with secure connections. Try another node or another network.'),
    _ => tr('Интернет через VPN не идёт. Попробуйте другую ноду.', "The internet isn't getting through the VPN. Try another node."),
  };
}

String get _cutText =>
    tr('Провайдер обрывает соединения с этой нодой. Попробуйте другую.', 'Your provider cuts connections to this node. Try another one.');

/// Whether another node is the way out. Not when the whole network is down.
bool anotherNodeHelps(ProbeResult r) => whyBroken(r) != null && r.verdict != Verdict.VERDICT_NO_INTERNET;

/// Another VPN or DPI bypasser running alongside, said once, after a failure.
String? alongside(ProbeResult r) {
  if (r.otherTools.isEmpty) return null;
  final names = r.otherTools.join(', ');
  return tr('Ещё работает $names. Два VPN сразу часто мешают друг другу.', "$names is running too. Two VPNs at once often get in each other's way.");
}

/// The live check found a mobile network in whitelist mode.
bool onWhitelistNetwork(Status? s) =>
    s != null &&
    s.state == ConnectionState.CONNECTION_STATE_CONNECTED &&
    s.hasLiveCheck() &&
    s.liveCheck.verdict == Verdict.VERDICT_WHITELIST;

/// Nodes likeliest to get through a whitelist first, the rest in the
/// provider's order.
List<Node> whitelistFirst(List<Node> nodes) {
  final indexed = [for (var i = 0; i < nodes.length; i++) (i, nodes[i])];
  indexed.sort((a, b) {
    final byHint = b.$2.whitelist.value.compareTo(a.$2.whitelist.value);
    return byHint != 0 ? byHint : a.$1.compareTo(b.$1);
  });
  return [for (final (_, n) in indexed) n];
}

/// The node to try on a whitelist network: marked by the provider, or at
/// least likely, other than the one in use. The current subscription first.
({Subscription sub, Node node})? bestWhitelistNode(List<Subscription> subs, Status s) {
  ({Subscription sub, Node node})? best;
  for (final sub in [...subs.where((x) => x.id == s.subscriptionId), ...subs.where((x) => x.id != s.subscriptionId)]) {
    for (final n in sub.nodes) {
      if (n.id == s.nodeId && sub.id == s.subscriptionId) continue;
      if (n.whitelist.value < WhitelistHint.WHITELIST_HINT_LIKELY.value) continue;
      if (best == null || n.whitelist.value > best.node.whitelist.value) best = (sub: sub, node: n);
    }
  }
  return best;
}

String qualityLabel(Quality q) => switch (q) {
      Quality.good => tr('работает', 'working'),
      Quality.slow => tr('медленно', 'slow'),
      Quality.cut => tr('обрывает провайдер', 'cut off by the provider'),
      Quality.down => tr('не отвечает', 'not responding'),
      Quality.unknown => tr('не проверено', 'not checked'),
    };

String nodeKind(Node n) {
  final type = switch (n.type) {
    'vless' => 'VLESS',
    'vmess' => 'VMess',
    'trojan' => 'Trojan',
    'ss' => 'Shadowsocks',
    'hysteria2' => 'Hysteria 2',
    'tuic' => 'TUIC',
    'wireguard' => 'WireGuard',
    'amneziawg' => 'AmneziaWG',
    // Run in a compatible mode for now, see the core's subscription/naive.go.
    'naive' => 'NaiveProxy',
    _ => n.type,
  };
  final net = switch (n.network) {
    '' || 'tcp' => '',
    'xhttp' => 'XHTTP',
    'ws' => 'WebSocket',
    'grpc' => 'gRPC',
    final other => other,
  };
  return net.isEmpty ? type : '$type · $net';
}

String bytes(num n) {
  final units = lang == Lang.ru ? const ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'] : const ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = n.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return i == 0 ? '${v.toInt()} ${units[i]}' : '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[i]}';
}

String speed(num bytesPerSecond) => tr('${bytes(bytesPerSecond)}/с', '${bytes(bytesPerSecond)}/s');

String elapsed(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// "12,3 из 50 ГБ · до 12 декабря", or null when unlimited and endless.
String? quota(Subscription s) {
  final parts = <String>[];
  if (s.totalBytes > 0) {
    final used = bytes((s.uploadBytes + s.downloadBytes).toInt()), total = bytes(s.totalBytes.toInt());
    parts.add(tr('$used из $total', '$used of $total'));
  }
  if (s.hasExpire()) {
    final d = s.expire.toDateTime().toLocal();
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    const monthsEn = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    parts.add(tr('до ${d.day} ${months[d.month - 1]}', 'until ${monthsEn[d.month - 1]} ${d.day}'));
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The country a node claims in its name, from a flag emoji ("🇨🇭 Reducto
/// VPN"). A claim, not a fact: the probe tells where it really exits.
String claimedCountry(String name) {
  final runes = name.runes.toList();
  for (var i = 0; i + 1 < runes.length; i++) {
    final a = runes[i], b = runes[i + 1];
    if (_isRegional(a) && _isRegional(b)) {
      return String.fromCharCodes([a - 0x1F1E6 + 0x41, b - 0x1F1E6 + 0x41]);
    }
  }
  return '';
}

bool _isRegional(int r) => r >= 0x1F1E6 && r <= 0x1F1FF;

/// The name without a leading flag: the badge already shows the country,
/// and Windows would draw the flag as two letters anyway.
String displayName(String name) {
  final runes = name.runes.toList();
  if (runes.length > 2 && _isRegional(runes[0]) && _isRegional(runes[1])) {
    return String.fromCharCodes(runes.skip(2)).trimLeft();
  }
  return name;
}

/// Matches a node by name, claimed or exit country, or protocol.
bool nodeMatches(Node n, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final probe = n.hasLastProbe() ? n.lastProbe : null;
  final claimed = claimedCountry(n.name);
  return [
    n.name,
    nodeKind(n),
    if (claimed.isNotEmpty) ..._countryNames(claimed),
    if (probe != null && probe.exitCountry.isNotEmpty) ..._countryNames(probe.exitCountry),
    if (probe != null) ..._cityNames(probe.exitColo),
  ].any((s) => s.toLowerCase().contains(q));
}
