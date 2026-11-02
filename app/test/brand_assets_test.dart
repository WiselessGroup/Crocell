import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // flutter_svg only understands a subset of SVG. If a redrawn logo uses
  // something it can't parse, the connect button silently renders nothing.
  for (final name in [
    'wing-left',
    'wing-right',
    'figure',
    'glyph-wing-left',
    'glyph-wing-right',
    'glyph-figure',
    'glyph-star',
  ]) {
    testWidgets('$name.svg parses', (tester) async {
      final svg = File('assets/brand/$name.svg').readAsStringSync();
      final info = await tester.runAsync(
        () => vg.loadPicture(SvgStringLoader(svg), null),
      );
      expect(info, isNotNull);
      expect(info!.size.width, greaterThan(0));
      info.picture.dispose();
    });
  }
}
