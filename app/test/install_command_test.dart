import 'package:crocell/host.dart';
import 'package:crocell/service/install.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
