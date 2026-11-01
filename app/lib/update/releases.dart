import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../host.dart';
import '../l10n.dart';
import '../notify/alerts.dart';
import '../version.dart';

const releasesRepo = 'WiselessGroup/Crocell';
const latestReleasePage = 'https://github.com/$releasesRepo/releases/latest';

/// Release files keep the same names from version to version, so these links
/// always lead to the newest one.
String latestDownload(String asset) => '$latestReleasePage/download/$asset';

/// What to download for an update here, or null when it is not a file.
String? releaseAsset(HostKind kind) => switch (kind) {
      HostKind.appImage => 'Crocell-x86_64.AppImage',
      HostKind.windows => 'Crocell-x86_64-Setup.exe',
      HostKind.macos => 'Crocell-arm64.dmg',
      HostKind.android => 'Crocell.apk',
      _ => null,
    };

/// "0.4.0" or "v0.4.0" as numbers. Null for anything else, "dev" included.
List<int>? parseVersion(String v) {
  final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(v.trim());
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

/// Whether [latest] is a later release than [current]. Builds that are not
/// releases never ask to update.
bool isNewer(String latest, String current) {
  final a = parseVersion(latest), b = parseVersion(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// Where the newest version number comes from.
abstract interface class ReleaseFeed {
  Future<String> latestVersion();
}

class GitHubReleases implements ReleaseFeed {
  @override
  Future<String> latestVersion() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse('https://api.github.com/repos/$releasesRepo/releases/latest'));
      req.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'Crocell/$appVersion');
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw HttpException('GitHub: ${res.statusCode}');
      final tag = (jsonDecode(body) as Map<String, dynamic>)['tag_name'] as String? ?? '';
      return tag.startsWith('v') ? tag.substring(1) : tag;
    } finally {
      client.close(force: true);
    }
  }
}

final releaseFeedProvider = Provider<ReleaseFeed>((ref) => GitHubReleases());

/// This build's version. Overridden in tests, where it is "dev".
final currentVersionProvider = Provider<String>((ref) => appVersion);

/// A newer release, once a check has found one. Null otherwise.
final availableUpdateProvider = NotifierProvider<UpdateNotifier, String?>(UpdateNotifier.new);

class UpdateNotifier extends Notifier<String?> {
  static const _every = Duration(hours: 6);
  static const tapPayload = 'update';

  DateTime? _checkedAt;
  String? _announced;

  @override
  String? build() => null;

  /// Asks GitHub for the newest release, at most every few hours, and says
  /// so once per version. Quiet when offline or when GitHub does not answer:
  /// nobody needs an error about an update check.
  Future<void> check() async {
    final current = ref.read(currentVersionProvider);
    if (parseVersion(current) == null) return;
    final now = DateTime.now();
    if (_checkedAt != null && now.difference(_checkedAt!) < _every) return;
    _checkedAt = now;

    final String latest;
    try {
      latest = await ref.read(releaseFeedProvider).latestVersion();
    } catch (_) {
      _checkedAt = null; // try again on the next connect
      return;
    }
    if (!isNewer(latest, current)) return;
    state = latest;
    if (_announced == latest) return;
    _announced = latest;
    await ref.read(notificationsProvider).show(
          tr('Вышла Crocell $latest', 'Crocell $latest is out'),
          tr('Нажмите, чтобы узнать, как обновиться.', 'Open it to see how to update.'),
          payload: tapPayload,
        );
  }
}
