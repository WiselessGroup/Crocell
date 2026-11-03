import 'dart:io';

import '../host.dart';
import '../l10n.dart';

/// GNOME has no tiles for apps; the toggle in Quick Settings is a small
/// Shell extension that crocelld carries and installs for the person.
bool gnomeToggleAvailable(Host host, [Map<String, String>? env]) {
  if (host.kind != HostKind.appImage && host.kind != HostKind.linux) return false;
  final desktop = (env ?? Platform.environment)['XDG_CURRENT_DESKTOP'] ?? '';
  return desktop.toUpperCase().contains('GNOME');
}

/// The extension is there, but from another version of the app. The Shell does
/// not update it by itself: a new one takes a reinstall and a new login.
bool gnomeToggleOutdated(String appVersion, [Map<String, String>? env]) {
  env ??= Platform.environment;
  final data = env['XDG_DATA_HOME'] ?? '${env['HOME'] ?? ''}/.local/share';
  final dir = '$data/gnome-shell/extensions/crocell@wiseless.net';
  if (!Directory(dir).existsSync()) return false;
  final file = File('$dir/crocell-version');
  return !file.existsSync() || file.readAsStringSync().trim() != appVersion;
}

/// Installs and enables the extension. Runs as the person, not root:
/// extensions live in the home directory.
Future<void> installGnomeToggle(Host host) async {
  final cmd = host.kind == HostKind.appImage
      ? [host.appImagePath, 'crocelld', 'gnome-extension', 'install']
      : ['crocelld', 'gnome-extension', 'install'];
  final r = await Process.run(cmd.first, cmd.sublist(1));
  if (r.exitCode != 0) {
    final why = '${r.stderr}'.trim();
    throw Exception(tr('Не получилось: $why', 'Did not work: $why'));
  }
}
