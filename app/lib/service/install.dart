import 'dart:io';

import '../host.dart';
import '../l10n.dart';

/// How the service that holds the tunnel gets installed or updated here.
/// Either a command the person runs (Linux, where sudo in a terminal is the
/// norm) or a button that brings up the system's own password prompt.
class ServiceInstaller {
  const ServiceInstaller({this.command, this.run});

  /// A command to copy into a terminal.
  final String? command;

  /// Installs now. Throws [ServiceInstallError] when it did not work.
  final Future<void> Function()? run;

  bool get available => command != null || run != null;
}

class ServiceInstallError implements Exception {
  const ServiceInstallError(this.message);
  final String message;
  @override
  String toString() => message;
}

ServiceInstaller serviceInstaller(Host host) => switch (host.kind) {
      HostKind.appImage || HostKind.linux => ServiceInstaller(command: installCommand(host)),
      HostKind.macos => ServiceInstaller(run: _installMacOS),
      HostKind.windows => ServiceInstaller(run: _installWindows),
      _ => const ServiceInstaller(),
    };

/// The Linux install command. From an AppImage the service lives inside the
/// image, so the image itself runs the installer.
String installCommand(Host host) {
  if (host.kind != HostKind.appImage) return 'sudo crocelld install';
  return "sudo '${host.appImagePath.replaceAll("'", r"'\''")}' crocelld install";
}

/// The service binary shipped next to the app.
String _bundled(String name) {
  final exe = File(Platform.resolvedExecutable).parent.path;
  // Crocell.app/Contents/MacOS/crocell → Crocell.app/Contents/Resources.
  if (Platform.isMacOS) return '${Directory(exe).parent.path}/Resources/$name';
  return '$exe${Platform.pathSeparator}$name';
}

/// macOS asks for the administrator password in its own dialog. The uid
/// tells the service who may control it, since root runs the installer.
Future<void> _installMacOS() async {
  final uid = (await Process.run('id', ['-u'])).stdout.toString().trim();
  final r = await Process.run('osascript', [
    '-e', 'on run argv',
    '-e', 'do shell script (quoted form of item 1 of argv) & " install -uid " & item 2 of argv '
        'with administrator privileges',
    '-e', 'end run',
    _bundled('crocelld'), uid,
  ]);
  if (r.exitCode != 0) throw ServiceInstallError(_why(r.stderr.toString()));
}

/// Windows shows its UAC prompt for Start-Process -Verb RunAs.
Future<void> _installWindows() async {
  final path = _bundled('crocelld.exe').replaceAll("'", "''");
  final r = await Process.run('powershell', [
    '-NoProfile', '-NonInteractive', '-Command',
    "\$p = Start-Process -FilePath '$path' -ArgumentList 'install' -Verb RunAs -WindowStyle Hidden -Wait -PassThru; exit \$p.ExitCode",
  ]);
  if (r.exitCode != 0) throw ServiceInstallError(_why(r.stderr.toString()));
}

String _why(String stderr) {
  // Cancelling the password prompt is a choice, not a failure to explain.
  if (stderr.contains('-128') || stderr.contains('canceled by the user') || stderr.contains('отменена')) {
    return tr('Установка отменена', 'Installation cancelled');
  }
  final text = stderr.trim();
  return text.isEmpty
      ? tr('Не удалось установить службу', "Couldn't install the service")
      : tr('Не удалось установить службу: $text', "Couldn't install the service: $text");
}
