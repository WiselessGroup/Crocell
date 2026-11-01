import 'dart:io';

import 'package:crocell/sysproxy/sysproxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GNOME', () {
    late Map<String, String> store;
    late Directory dir;

    Future<String> fakeGsettings(String exe, List<String> args) async {
      expect(exe, 'gsettings');
      final key = '${args[1]} ${args[2]}';
      if (args[0] == 'get') return store[key] ?? "''";
      store[key] = args[3];
      return '';
    }

    setUp(() {
      dir = Directory.systemTemp.createTempSync('crocell-sysproxy');
      store = {'org.gnome.system.proxy mode': "'none'", 'org.gnome.system.proxy.http port': '0'};
    });
    tearDown(() => dir.deleteSync(recursive: true));

    SystemProxy make() => SystemProxy(
          run: fakeGsettings,
          stateFile: '${dir.path}/sysproxy.json',
          env: const {'XDG_CURRENT_DESKTOP': 'GNOME'},
        );

    test('enable points at the port, restore puts everything back', () async {
      if (!Platform.isLinux) return;
      final before = Map.of(store);
      final p = make();

      await p.enable(7890);
      expect(store['org.gnome.system.proxy mode'], "'manual'");
      expect(store['org.gnome.system.proxy.socks port'], '7890');
      expect(p.isActive, isTrue);

      await p.restore();
      expect(store['org.gnome.system.proxy mode'], before['org.gnome.system.proxy mode']);
      expect(store['org.gnome.system.proxy.http port'], '0');
      expect(p.isActive, isFalse);
    });

    test('a crash does not leave the proxy behind: recover restores it', () async {
      if (!Platform.isLinux) return;
      await make().enable(7890);
      // New process, same state file.
      await make().recover();
      expect(store['org.gnome.system.proxy mode'], "'none'");
    });
  });
}
