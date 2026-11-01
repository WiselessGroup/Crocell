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
