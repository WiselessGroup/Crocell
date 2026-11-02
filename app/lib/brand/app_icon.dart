import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../host.dart';
import '../logs.dart';
import '../platform/android.dart';
import 'appearance.dart';

const _window = MethodChannel('crocell/window');

/// The launcher alias for a choice, declared in AndroidManifest.xml by
/// scripts/make-icons.sh.
String androidIconAlias(Appearance a) => 'Icon_${a.art.id}_${a.background.id}';

/// Keeps the app's icon in step with the choice. Android's sticks once set
/// (an enabled launcher alias). Windows and macOS only have the running
/// app's icon, so it is set again on every start, and on macOS whenever the
/// system switches between light and dark. Watch it once from the root widget.
final appIconProvider = Provider<void>((ref) {
  final host = ref.watch(hostProvider);
  if (!host.hasAppIcon) return;

  Future<void> apply(Appearance a) async {
    try {
      if (host.kind == HostKind.android) {
        await androidCore.invokeMethod<void>('setIcon', androidIconAlias(a));
        return;
      }
      final png = await renderAppIcon(
        a.art,
        host.kind == HostKind.macos ? _systemBackground() : a.background,
        macTile: host.kind == HostKind.macos,
      );
      await _window.invokeMethod<void>('setIcon', png);
    } catch (e) {
      appLog('app icon: $e');
    }
  }

  ref.listen(appearanceProvider, (_, next) => apply(next), fireImmediately: host.kind != HostKind.android);

  if (host.kind == HostKind.macos) {
    final watcher = _BrightnessWatcher(() => apply(ref.read(appearanceProvider)));
    WidgetsBinding.instance.addObserver(watcher);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(watcher));
  }
});

IconBackground _systemBackground() => ui.PlatformDispatcher.instance.platformBrightness == ui.Brightness.dark
    ? IconBackground.dark
    : IconBackground.paper;

class _BrightnessWatcher with WidgetsBindingObserver {
  _BrightnessWatcher(this.changed);
  final VoidCallback changed;

  @override
  void didChangePlatformBrightness() => changed();
}

/// Draws the icon: the background, then the picture with its wings open.
/// [macTile] leaves the margin and the rounded corners macOS icons have.
Future<Uint8List> renderAppIcon(AppArt art, IconBackground background, {bool macTile = false}) async {
  const size = 512.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final tile = macTile ? const Rect.fromLTWH(50, 50, 412, 412) : const Rect.fromLTWH(0, 0, size, size);
  final corner = Radius.circular(macTile ? 92 : 96);
  canvas.drawRRect(RRect.fromRectAndRadius(tile, corner), Paint()..color = background.color);

  // The glyph is sparse and takes more of the tile than the figure does.
  final share = art.isGlyph ? 0.74 : 0.92;
  final side = tile.width * share;
  final at = tile.center - Offset(side / 2, side / 2);

  Future<void> layer(String asset, ui.ColorFilter? filter) async {
    final info = await vg.loadPicture(SvgAssetLoader('assets/brand/$asset.svg'), null);
    final k = side / info.size.width;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(k);
    canvas.saveLayer(Offset.zero & info.size, Paint()..colorFilter = filter);
    canvas.drawPicture(info.picture);
    canvas.restore();
    canvas.restore();
    info.picture.dispose();
  }

  if (art.isGlyph) {
    ui.ColorFilter tint(Color c) => ui.ColorFilter.mode(onIconBackground(c, background), ui.BlendMode.srcIn);
    await layer('glyph-wing-left', tint(art.wings));
    await layer('glyph-wing-right', tint(art.wings));
    await layer('glyph-figure', tint(art.figure));
    await layer('glyph-star', tint(art.star));
  } else {
    final grey = art == AppArt.crocellGrey ? greyscale : null;
    for (final name in ['wing-left', 'wing-right', 'figure']) {
      await layer(name, grey);
    }
  }

  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
