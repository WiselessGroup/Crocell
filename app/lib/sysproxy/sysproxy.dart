import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import '../l10n.dart';

/// Points the desktop proxy settings at crocelld's mixed port and puts the
/// previous settings back. Runs as the person, not root: these are their
/// settings. Same platforms as core/sysproxy in Go.
///
/// What was there before is saved to a file, so a crash or a kill -9 does not
/// leave the browser pointing at a dead port: [recover] restores it on the
/// next start.
class SystemProxy {
  SystemProxy({Runner? run, String? stateFile, Map<String, String>? env})
      : _run = run ?? _processRun,
        _env = env ?? Platform.environment,
        _stateFile = stateFile ?? _defaultStateFile(env ?? Platform.environment);

  final Runner _run;
  final Map<String, String> _env;
  final String _stateFile;

  static const host = '127.0.0.1';

  bool get isSupported => _backend() != null;

  /// True if we set it and have not restored it yet (also after a crash).
  bool get isActive => File(_stateFile).existsSync();

  Future<void> enable(int port) async {
    final backend = _backend();
    if (backend == null) throw SystemProxyError(tr('Системный прокси на этой системе не настраивается', "The system proxy can't be set on this system"));
    if (isActive) await restore(); // re-pointing at another port

    final saved = await backend.read(_run);
    await _save({'backend': backend.name, 'values': saved});
    try {
      await backend.apply(_run, await backend.values(_run, host, port));
    } catch (_) {
      await restore();
      rethrow;
    }
  }

  /// Puts back what was there before [enable]. Safe to call any time.
  Future<void> restore() async {
    final file = File(_stateFile);
    if (!file.existsSync()) return;
    final saved = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final backend = _backends.where((b) => b.name == saved['backend']).firstOrNull;
    if (backend != null) {
      await backend.apply(_run, (saved['values'] as List).cast<String>());
    }
    await file.delete();
  }

  /// Called on start: if the last run did not restore, do it now.
  Future<void> recover() => restore();

  Future<void> _save(Map<String, Object> data) async {
    final file = File(_stateFile);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  _Backend? _backend() {
    if (Platform.isMacOS) return _darwin;
    if (Platform.isWindows) return _windows;
    if (Platform.isLinux) {
      final desktop = (_env['XDG_CURRENT_DESKTOP'] ?? '').toUpperCase();
      if (desktop.contains('KDE')) return _kde;
      return _gnome; // GNOME, Cinnamon, Budgie, Pantheon and friends
    }
    return null;
  }

  static String _defaultStateFile(Map<String, String> env) {
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '.';
    if (Platform.isWindows) return '${env['APPDATA'] ?? home}\\Crocell\\sysproxy.json';
    if (Platform.isMacOS) return '$home/Library/Application Support/Crocell/sysproxy.json';
    return '${env['XDG_STATE_HOME'] ?? '$home/.local/state'}/crocell/sysproxy.json';
  }
}

class SystemProxyError implements Exception {
  const SystemProxyError(this.message);
  final String message;
  @override
  String toString() => message;
}

typedef Runner = Future<String> Function(String executable, List<String> args);

Future<String> _processRun(String executable, List<String> args) async {
  final r = await Process.run(executable, args);
  if (r.exitCode != 0) {
    throw SystemProxyError('$executable ${args.join(' ')}: ${(r.stderr as String).trim()}');
  }
  return (r.stdout as String).trim();
}

/// One desktop's way of storing proxy settings as an ordered list of values.
class _Backend {
  const _Backend(this.name, this.read, this.apply, this.values);
  final String name;
  final Future<List<String>> Function(Runner run) read;
  final Future<void> Function(Runner run, List<String> values) apply;
  final Future<List<String>> Function(Runner run, String host, int port) values;
}

final _backends = [_gnome, _kde, _darwin, _windows];

const _gnomeKeys = [
  ('org.gnome.system.proxy', 'mode'),
  ('org.gnome.system.proxy', 'ignore-hosts'),
  ('org.gnome.system.proxy.http', 'host'),
  ('org.gnome.system.proxy.http', 'port'),
  ('org.gnome.system.proxy.https', 'host'),
  ('org.gnome.system.proxy.https', 'port'),
  ('org.gnome.system.proxy.socks', 'host'),
  ('org.gnome.system.proxy.socks', 'port'),
];

final _gnome = _Backend(
  'gnome',
  (run) async => [for (final (schema, key) in _gnomeKeys) await run('gsettings', ['get', schema, key])],
  (run, values) async {
    for (var i = 0; i < _gnomeKeys.length; i++) {
      final (schema, key) = _gnomeKeys[i];
      await run('gsettings', ['set', schema, key, values[i]]);
    }
  },
  (run, host, port) async => [
    "'manual'",
    "['localhost', '127.0.0.0/8', '::1', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '169.254.0.0/16', '*.local']",
    "'$host'", '$port', "'$host'", '$port', "'$host'", '$port',
  ],
);

const _kdeKeys = ['ProxyType', 'httpProxy', 'httpsProxy', 'socksProxy', 'NoProxyFor'];

Future<String> _kdeTool(Runner run, String kind) async {
  // Plasma 6 ships kwriteconfig6, Plasma 5 kwriteconfig5.
  try {
    await run('which', ['k${kind}config6']);
    return 'k${kind}config6';
  } catch (_) {
    return 'k${kind}config5';
  }
}

final _kde = _Backend(
  'kde',
  (run) async {
    final tool = await _kdeTool(run, 'read');
    return [
      for (final key in _kdeKeys)
        await run(tool, ['--file', 'kioslaverc', '--group', 'Proxy Settings', '--key', key]).catchError((_) => ''),
    ];
  },
  (run, values) async {
    final tool = await _kdeTool(run, 'write');
    for (var i = 0; i < _kdeKeys.length; i++) {
      await run(tool, ['--file', 'kioslaverc', '--group', 'Proxy Settings', '--key', _kdeKeys[i], values[i]]);
    }
    // Running apps reread proxy settings on this signal.
    await run('dbus-send', [
      '--type=signal', '/KIO/Scheduler', 'org.kde.KIO.Scheduler.reparseSlaveConfiguration', 'string:',
    ]).catchError((_) => '');
  },
  (run, host, port) async => [
    '1',
    'http://$host $port',
    'http://$host $port',
    'socks://$host $port',
    'localhost,127.0.0.0/8,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,.local',
  ],
);

// macOS: values are "service|kind|enabled|server|port" for every enabled
// network service, since we can't know which one carries the traffic.
const _darwinKinds = [
  ('-getwebproxy', '-setwebproxy', '-setwebproxystate'),
  ('-getsecurewebproxy', '-setsecurewebproxy', '-setsecurewebproxystate'),
  ('-getsocksfirewallproxy', '-setsocksfirewallproxy', '-setsocksfirewallproxystate'),
];

Future<List<String>> _darwinServices(Runner run) async {
  final out = await run('networksetup', ['-listallnetworkservices']);
  return [
    for (final (i, line) in out.split('\n').indexed)
      if (i > 0 && line.trim().isNotEmpty && !line.startsWith('*')) line.trim(),
  ];
}

final _darwin = _Backend(
  'darwin',
  (run) async {
    final values = <String>[];
    for (final svc in await _darwinServices(run)) {
      for (final (i, (get, _, _)) in _darwinKinds.indexed) {
        final out = await run('networksetup', [get, svc]);
        String field(String name) =>
            RegExp('^$name: (.*)\$', multiLine: true).firstMatch(out)?.group(1)?.trim() ?? '';
        values.add([svc, '$i', field('Enabled'), field('Server'), field('Port')].join('|'));
      }
    }
    return values;
  },
  (run, values) async {
    for (final v in values) {
      final [svc, kind, enabled, server, port] = v.split('|');
      final (_, set, state) = _darwinKinds[int.parse(kind)];
      if (enabled == 'Yes' && server.isNotEmpty) {
        await run('networksetup', [set, svc, server, port]);
      } else {
        await run('networksetup', [state, svc, 'off']);
      }
    }
  },
  (run, host, port) async => [
    for (final svc in await _darwinServices(run))
      for (var i = 0; i < _darwinKinds.length; i++) [svc, '$i', 'Yes', host, '$port'].join('|'),
  ],
);

const _internetOptionSettingsChanged = 39;
const _internetOptionRefresh = 37;

/// Tells running browsers to read the settings again: without this they find
/// out in their own time. Same calls as core/sysproxy for the CLI. The registry
/// already has the new values, so failing here costs a delay and nothing more.
void _announceWindowsProxyChange() {
  if (!Platform.isWindows) return;
  try {
    final setOption = DynamicLibrary.open('wininet.dll').lookupFunction<
        Int32 Function(Pointer<Void>, Uint32, Pointer<Void>, Uint32),
        int Function(Pointer<Void>, int, Pointer<Void>, int)>('InternetSetOptionW');
    setOption(nullptr, _internetOptionSettingsChanged, nullptr, 0);
    setOption(nullptr, _internetOptionRefresh, nullptr, 0);
  } catch (_) {}
}

const _winKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
const _winBypass =
    'localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;'
    '172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;169.254.*;<local>';

Future<String> _regQuery(Runner run, String name) async {
  try {
    final out = await run('reg', ['query', _winKey, '/v', name]);
    final m = RegExp('$name\\s+REG_\\w+\\s+(.*)\$', multiLine: true).firstMatch(out);
    return m?.group(1)?.trim() ?? '';
  } catch (_) {
    return '';
  }
}

final _windows = _Backend(
  'windows',
  (run) async => [
    await _regQuery(run, 'ProxyEnable'),
    await _regQuery(run, 'ProxyServer'),
    await _regQuery(run, 'ProxyOverride'),
  ],
  (run, values) async {
    final enable = values[0].isEmpty ? '0' : (int.tryParse(values[0].replaceFirst('0x', ''), radix: 16) ?? 0).toString();
    await run('reg', ['add', _winKey, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', enable, '/f']);
    for (final (i, name) in [(1, 'ProxyServer'), (2, 'ProxyOverride')]) {
      if (values[i].isEmpty) {
        await run('reg', ['delete', _winKey, '/v', name, '/f']).catchError((_) => '');
      } else {
        await run('reg', ['add', _winKey, '/v', name, '/t', 'REG_SZ', '/d', values[i], '/f']);
      }
    }
    _announceWindowsProxyChange();
  },
  (run, host, port) async => ['0x1', '$host:$port', _winBypass],
);
