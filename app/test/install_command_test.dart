import 'dart:io';

import 'package:crocell/host.dart';
import 'package:crocell/service/gnome.dart';
import 'package:crocell/service/install.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GNOME extension', () {
    late Directory data;
    late Directory ext;
    late Map<String, String> env;
    setUp(() {
      data = Directory.systemTemp.createTempSync('crocell-gnome');
      ext = Directory('${data.path}/gnome-shell/extensions/crocell@wiseless.net');
      env = {'XDG_DATA_HOME': data.path};
    });
    tearDown(() => data.deleteSync(recursive: true));

    test('not installed: nothing to update', () {
      expect(gnomeToggleOutdated('0.7.0', env), isFalse);
    });

    test('from before the version file: update', () {
      ext.createSync(recursive: true);
      expect(gnomeToggleOutdated('0.7.0', env), isTrue);
    });

    test('compares with the app', () {
      ext.createSync(recursive: true);
      File('${ext.path}/crocell-version').writeAsStringSync('0.7.0');
      expect(gnomeToggleOutdated('0.7.0', env), isFalse);
      expect(gnomeToggleOutdated('0.7.1', env), isTrue);
    });
  });

  test('installed system-wide, the binary is on PATH', () {
    expect(installCommand(Host.detect(os: 'linux', env: {})), 'sudo crocelld install');
  });

  test('from an AppImage, the image runs the installer', () {
    expect(
      installCommand(Host.detect(os: 'linux', env: {'APPIMAGE': '/home/me/AppImages/crocell.appimage'})),
      "sudo '/home/me/AppImages/crocell.appimage' crocelld install",
    );
  });

  test('quotes survive in the image path', () {
    expect(
      installCommand(Host.detect(os: 'linux', env: {'APPIMAGE': "/home/me/It's/Crocell.AppImage"})),
      r"sudo '/home/me/It'\''s/Crocell.AppImage' crocelld install",
    );
  });

  test('macOS and Windows install with a button, Android has nothing to install', () {
    expect(serviceInstaller(Host.detect(os: 'macos', env: {})).run, isNotNull);
    expect(serviceInstaller(Host.detect(os: 'windows', env: {})).run, isNotNull);
    expect(serviceInstaller(Host.detect(os: 'android', env: {})).available, isFalse);
  });
}
