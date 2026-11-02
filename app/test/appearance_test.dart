import 'package:crocell/brand/appearance.dart';
import 'package:crocell/host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('what each system offers', () {
    Host host(String os) => Host.detect(os: os, env: const {});
    expect(host('linux').artChoices, isEmpty);
    expect(host('macos').artChoices, [AppArt.glyphRed, AppArt.crocell]);
    expect(host('windows').artChoices, AppArt.values);
    expect(host('android').artChoices, AppArt.values);
    expect(host('macos').chooseIconBackground, isFalse);
    expect(host('android').chooseIconBackground, isTrue);
  });

  test('a saved choice fits the system it runs on', () {
    Host host(String os) => Host.detect(os: os, env: const {});
    const white = Appearance(art: AppArt.glyphWhite);
    const grey = Appearance(art: AppArt.crocellGrey);
    expect(host('linux').fit(white).art, AppArt.crocell, reason: 'Linux is always Crocell');
    expect(host('macos').fit(white).art, AppArt.glyphRed);
    expect(host('macos').fit(grey).art, AppArt.crocell);
    expect(host('android').fit(white).art, AppArt.glyphWhite);
    expect(host('android').fit(const Appearance()).art, AppArt.glyphRed, reason: 'the glyph is the default');
  });

  test('a glyph layer never melts into the icon background', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
    }

    for (final art in AppArt.values.where((a) => a.isGlyph)) {
      for (final bg in IconBackground.values) {
        for (final layer in [art.wings, art.figure, art.star]) {
          expect(ratio(onIconBackground(layer, bg), bg.color), greaterThanOrEqualTo(1.6), reason: '${art.id} on ${bg.id}');
        }
      }
    }
    expect(onIconBackground(const Color(0xFFFAF8F8), IconBackground.dark), const Color(0xFFFAF8F8));
  });
}
