import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../host.dart';
import '../l10n.dart';
import '../theme.dart';

/// What the connect button and the app icon show. The plain glyph is the
/// default: the winged figure is the brand's lore, and not everyone wants a
/// demon on their phone. The names are stored, and on Android they are part
/// of the launcher alias, so they must not change.
enum AppArt {
  glyphRed('glyph_red'),
  glyphEmber('glyph_ember'),
  glyphWhite('glyph_white'),
  glyphInverse('glyph_inverse'),
  crocell('crocell'),
  crocellGrey('crocell_grey');

  const AppArt(this.id);
  final String id;

  bool get isGlyph => this != crocell && this != crocellGrey;

  /// Glyph layers' colours; the figure variants have their own.
  Color get wings => switch (this) {
    glyphEmber => CrocellColors.secondary,
    glyphWhite || glyphInverse => const Color(0xFFFAF8F8),
    _ => CrocellColors.primary,
  };

  Color get figure => switch (this) {
    glyphEmber => const Color(0xFFFAF8F8),
    glyphWhite => const Color(0xFFFAF8F8),
    glyphInverse => CrocellColors.primary,
    _ => CrocellColors.accent,
  };

  /// The star above the head.
  Color get star => this == glyphEmber ? CrocellColors.secondary : wings;

  String get label => switch (this) {
    glyphRed => tr('Красный', 'Red'),
    glyphEmber => tr('Янтарный', 'Ember'),
    glyphWhite => tr('Белый', 'White'),
    glyphInverse => tr('Инверсия', 'Inverse'),
    crocell => tr('Кроцелл', 'Crocell'),
    crocellGrey => tr('Кроцелл, серый', 'Crocell, grey'),
  };
}

/// The app icon's background.
enum IconBackground {
  dark('dark', Color(0xFF0E0B0B)),
  paper('paper', Color(0xFFFBF8F7)),
  crimson('crimson', Color(0xFF860111)),
  ember('ember', Color(0xFFD4572A));

  const IconBackground(this.id, this.color);
  final String id;
  final Color color;

  String get label => switch (this) {
    dark => tr('Тёмный', 'Dark'),
    paper => tr('Светлый', 'Light'),
    crimson => tr('Багровый', 'Crimson'),
    ember => tr('Янтарный', 'Ember'),
  };
}

/// A glyph layer on an icon background: the art's own colour, unless it would
/// melt into the background (white on paper, ember on ember), then white or
/// ink, whichever shows. scripts/android-icon-aliases.py does the same.
Color onIconBackground(Color layer, IconBackground background) {
  double ratio(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  const white = Color(0xFFFAF8F8), ink = Color(0xFF1A1212);
  if (ratio(layer, background.color) >= 1.6) return layer;
  return ratio(white, background.color) >= ratio(ink, background.color) ? white : ink;
}

class Appearance {
  const Appearance({this.art = AppArt.glyphRed, this.background = IconBackground.dark});

  final AppArt art;
  final IconBackground background;

  Appearance copyWith({AppArt? art, IconBackground? background}) =>
      Appearance(art: art ?? this.art, background: background ?? this.background);

  static const _artKey = 'appearance_art', _backgroundKey = 'appearance_background';

  /// Read before the first frame, so a chosen picture never flashes the
  /// default one first.
  static Future<Appearance> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return Appearance(
        art: AppArt.values.where((a) => a.id == p.getString(_artKey)).firstOrNull ?? AppArt.glyphRed,
        background:
            IconBackground.values.where((b) => b.id == p.getString(_backgroundKey)).firstOrNull ?? IconBackground.dark,
      );
    } catch (_) {
      return const Appearance();
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_artKey, art.id);
      await p.setString(_backgroundKey, background.id);
    } catch (_) {
      // No preferences store (tests): it lasts until the app closes.
    }
  }
}

/// What each system lets people choose.
extension AppearanceChoices on Host {
  /// Empty where there is nothing to choose. Linux has no way to change an
  /// app's icon from inside (the desktop file decides), so it keeps the
  /// figure everywhere rather than a button at odds with the launcher.
  List<AppArt> get artChoices => switch (kind) {
    HostKind.appImage || HostKind.linux || HostKind.other => const [],
    HostKind.macos => const [AppArt.glyphRed, AppArt.crocell],
    HostKind.windows || HostKind.android => AppArt.values,
  };

  /// macOS follows the system's light or dark look instead of asking.
  bool get chooseIconBackground => kind == HostKind.windows || kind == HostKind.android;

  /// The running app's own icon can be changed here.
  bool get hasAppIcon => kind == HostKind.windows || kind == HostKind.macos || kind == HostKind.android;

  /// A saved choice this system cannot show becomes the nearest one it can.
  Appearance fit(Appearance a) {
    final choices = artChoices;
    if (choices.isEmpty) return Appearance(art: AppArt.crocell, background: a.background);
    if (choices.contains(a.art)) return a;
    return Appearance(art: a.art.isGlyph ? AppArt.glyphRed : AppArt.crocell, background: a.background);
  }
}

/// Set in main() from [Appearance.load]. Tests start from the default.
Appearance initialAppearance = const Appearance();

final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(AppearanceNotifier.new);

class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() => ref.watch(hostProvider).fit(initialAppearance);

  void set(Appearance next) {
    state = next;
    next.save();
  }
}

/// A desaturated figure, the "grey" Crocell. Black and white stay as they are.
const greyscale = ColorFilter.matrix([
  0.30, 0.59, 0.11, 0, 0, //
  0.30, 0.59, 0.11, 0, 0, //
  0.30, 0.59, 0.11, 0, 0, //
  0, 0, 0, 1, 0, //
]);
