import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../host.dart';
import '../sysproxy/sysproxy.dart' show Runner;

/// The app in the person's Windows startup list, hidden in the tray. The
/// service starts by itself and holds the tunnel; this is for the icon and the
/// window. Written by the app, not the installer: the installer runs as an
/// administrator, whose HKCU may be someone else's.
class Autostart {
  Autostart({Runner? run, String? executable})
      : _run = run ?? _reg,
        _executable = executable ?? Platform.resolvedExecutable;

  final Runner _run;
  final String _executable;

  static const _key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _value = 'Crocell';
  static const _chosen = 'autostart_chosen';

  String get _command => '"$_executable" --hidden';

  Future<bool> isEnabled() async => await _current() != null;

  Future<void> setEnabled(bool on) async {
    if (on) {
      await _run('reg', ['add', _key, '/v', _value, '/t', 'REG_SZ', '/d', _command, '/f']);
    } else {
      await _run('reg', ['delete', _key, '/v', _value, '/f']);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chosen, true);
  }

  /// On by itself the first time. After that the person's choice stands, and
  /// only the path follows the app if it moved.
  Future<void> applyOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_chosen) != true) {
      await setEnabled(true);
      return;
    }
    final current = await _current();
    if (current != null && current != _command) await setEnabled(true);
  }

  Future<String?> _current() async {
    try {
      final out = await _run('reg', ['query', _key, '/v', _value]);
      return RegExp('$_value\\s+REG_SZ\\s+(.*)\$', multiLine: true).firstMatch(out)?.group(1)?.trim();
    } catch (_) {
      return null; // reg fails when the value is not there
    }
  }

  static Future<String> _reg(String executable, List<String> args) async {
    final r = await Process.run(executable, args);
    if (r.exitCode != 0) throw Exception('$executable: ${r.stderr}');
    return '${r.stdout}';
  }
}

/// Null where the app does not start by itself. macOS needs a Developer ID
/// first, Linux has nothing to show without a window.
final autostartProvider = Provider<Autostart?>((ref) => ref.watch(hostProvider).kind == HostKind.windows ? Autostart() : null);
