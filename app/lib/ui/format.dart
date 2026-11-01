import '../data/core_api.dart';

/// Country names people read, by ISO 3166-1 alpha-2. Text, not flag emoji:
/// Windows has no flag glyphs, and a flag alone is not accessible.
const _countries = {
  'RU': 'Россия', 'NL': 'Нидерланды', 'DE': 'Германия', 'PL': 'Польша', 'SG': 'Сингапур',
  'FI': 'Финляндия', 'SE': 'Швеция', 'NO': 'Норвегия', 'EE': 'Эстония', 'LV': 'Латвия',
  'LT': 'Литва', 'FR': 'Франция', 'GB': 'Великобритания', 'US': 'США', 'CA': 'Канада',
  'TR': 'Турция', 'KZ': 'Казахстан', 'AM': 'Армения', 'GE': 'Грузия', 'AT': 'Австрия',
  'CH': 'Швейцария', 'CZ': 'Чехия', 'IT': 'Италия', 'ES': 'Испания', 'PT': 'Португалия',
  'RO': 'Румыния', 'BG': 'Болгария', 'HU': 'Венгрия', 'RS': 'Сербия', 'MD': 'Молдова',
  'UA': 'Украина', 'BY': 'Беларусь', 'IL': 'Израиль', 'AE': 'ОАЭ', 'JP': 'Япония',
  'HK': 'Гонконг', 'KR': 'Южная Корея', 'IN': 'Индия', 'AU': 'Австралия', 'IE': 'Ирландия',
  'BE': 'Бельгия', 'DK': 'Дания', 'LU': 'Люксембург', 'CY': 'Кипр', 'GR': 'Греция',
};

String countryName(String code) => _countries[code.toUpperCase()] ?? code.toUpperCase();

/// Cloudflare PoP (IATA airport code) to a city: tells "Frankfurt" from
/// "Germany somewhere" without a GeoIP database.
const _colos = {
  'FRA': 'Франкфурт', 'AMS': 'Амстердам', 'WAW': 'Варшава', 'SIN': 'Сингапур', 'HEL': 'Хельсинки',
  'ARN': 'Стокгольм', 'OSL': 'Осло', 'CPH': 'Копенгаген', 'TLL': 'Таллин', 'RIX': 'Рига',
  'VNO': 'Вильнюс', 'LHR': 'Лондон', 'MAN': 'Манчестер', 'CDG': 'Париж', 'MRS': 'Марсель',
  'DUS': 'Дюссельдорф', 'HAM': 'Гамбург', 'MUC': 'Мюнхен', 'BER': 'Берлин', 'TXL': 'Берлин',
  'VIE': 'Вена', 'ZRH': 'Цюрих', 'PRG': 'Прага', 'MXP': 'Милан', 'FCO': 'Рим', 'MAD': 'Мадрид',
  'LIS': 'Лиссабон', 'OTP': 'Бухарест', 'SOF': 'София', 'BUD': 'Будапешт', 'BEG': 'Белград',
  'KIV': 'Кишинёв', 'IST': 'Стамбул', 'TLV': 'Тель-Авив', 'DXB': 'Дубай', 'ALA': 'Алматы',
  'EVN': 'Ереван', 'TBS': 'Тбилиси', 'DME': 'Москва', 'SVO': 'Москва', 'LED': 'Санкт-Петербург',
  'KJA': 'Красноярск', 'NRT': 'Токио', 'HKG': 'Гонконг', 'ICN': 'Сеул', 'BOM': 'Мумбаи',
  'SYD': 'Сидней', 'DUB': 'Дублин', 'BRU': 'Брюссель', 'LUX': 'Люксембург', 'ATH': 'Афины',
  'EWR': 'Нью-Йорк', 'IAD': 'Вашингтон', 'ORD': 'Чикаго', 'LAX': 'Лос-Анджелес', 'SJC': 'Сан-Хосе',
  'YYZ': 'Торонто',
};

String? coloCity(String colo) => _colos[colo.toUpperCase()];

/// "Германия, Франкфурт", or just the country when the city is unknown.
String exitPlace(ProbeResult r) {
  final city = coloCity(r.exitColo);
  final country = countryName(r.exitCountry);
  return city == null || city == country ? country : '$country, $city';
}

enum Quality { good, slow, down, unknown }

/// What a probe means for a person, not a number to decode.
Quality quality(ProbeResult? r) {
  if (r == null || (!r.hasProbedAt() && r.error.isEmpty && r.exitIp.isEmpty)) return Quality.unknown;
  if (r.error.isNotEmpty) return Quality.down;
  return r.latencyMs <= 600 ? Quality.good : Quality.slow;
}

String qualityLabel(Quality q) => switch (q) {
      Quality.good => 'работает',
      Quality.slow => 'медленно',
      Quality.down => 'не отвечает',
      Quality.unknown => 'не проверено',
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
  const units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
  var v = n.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return i == 0 ? '${v.toInt()} ${units[i]}' : '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[i]}';
}

String speed(num bytesPerSecond) => '${bytes(bytesPerSecond)}/с';

String elapsed(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// "12,3 из 50 ГБ · до 12 декабря", or null when unlimited and endless.
String? quota(Subscription s) {
  final parts = <String>[];
  if (s.totalBytes > 0) {
    parts.add('${bytes((s.uploadBytes + s.downloadBytes).toInt())} из ${bytes(s.totalBytes.toInt())}');
  }
  if (s.hasExpire()) {
    final d = s.expire.toDateTime().toLocal();
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    parts.add('до ${d.day} ${months[d.month - 1]}');
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
    if (claimed.isNotEmpty) countryName(claimed),
    if (probe != null && probe.exitCountry.isNotEmpty) countryName(probe.exitCountry),
    if (probe != null) coloCity(probe.exitColo) ?? '',
  ].any((s) => s.toLowerCase().contains(q));
}
