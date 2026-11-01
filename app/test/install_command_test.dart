import 'package:crocell/ui/daemon_missing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('installed system-wide, the binary is on PATH', () {
    expect(installCommand({}), 'sudo crocelld install');
  });

  test('from an AppImage, the image runs the installer', () {
    expect(
      installCommand({'APPIMAGE': '/home/me/AppImages/crocell.appimage'}),
      "sudo '/home/me/AppImages/crocell.appimage' crocelld install",
    );
  });

  test('quotes survive in the image path', () {
    expect(
      installCommand({'APPIMAGE': "/home/me/It's/Crocell.AppImage"}),
      r"sudo '/home/me/It'\''s/Crocell.AppImage' crocelld install",
    );
  });
}
