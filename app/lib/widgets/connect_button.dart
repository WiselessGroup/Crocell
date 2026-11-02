import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../brand/appearance.dart';
import '../l10n.dart';
import '../theme.dart';

/// The picture from the logo: the glyph or the figure, as the person chose.
/// Wings spread when connected.
///
/// Layers come from the brand SVGs (scripts/brand-layers.py for the figure),
/// all sharing one viewBox so they stack exactly.
class ConnectButton extends StatefulWidget {
  const ConnectButton({
    super.key,
    required this.connected,
    required this.onPressed,
    this.art = AppArt.glyphRed,
    this.size = 240,
    this.label,
  });

  final AppArt art;

  final bool connected;

  /// Null disables the button (busy, or nothing to connect to).
  final VoidCallback? onPressed;
  final double size;

  /// What a screen reader announces. Defaults to connect/disconnect.
  final String? label;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _focus = false;

  late final AnimationController _wings = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    reverseDuration: const Duration(milliseconds: 320),
    value: widget.connected ? 1 : 0,
  );

  late final Animation<double> _spread = CurvedAnimation(
    parent: _wings,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(ConnectButton old) {
    super.didUpdateWidget(old);
    if (old.connected == widget.connected) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      _wings.value = widget.connected ? 1 : 0;
    } else if (widget.connected) {
      _wings.forward();
    } else {
      _wings.reverse();
    }
  }

  @override
  void dispose() {
    _wings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      toggled: widget.connected,
      label:
          widget.label ??
          (widget.connected ? tr('Отключить VPN', 'Disconnect VPN') : tr('Подключить VPN', 'Connect VPN')),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        // No clipping: the wing tips reach into the corners of the square,
        // a circular clip cut them off. Only the ink is circular.
        child: Material(
          type: MaterialType.transparency,
          // InkWell, not a bare GestureDetector: keyboard focus, Enter/Space,
          // hover and the pressed state come with it.
          child: InkWell(
            onTap: widget.onPressed,
            onHover: (v) => setState(() => _hover = v),
            onFocusChange: (v) => setState(() => _focus = v),
            customBorder: const CircleBorder(),
            focusColor: CrocellColors.primary.withValues(alpha: 0.18),
            hoverColor: CrocellColors.accent.withValues(alpha: 0.10),
            child: AnimatedOpacity(
              opacity: widget.onPressed == null && !widget.connected ? 0.6 : 1,
              duration: const Duration(milliseconds: 150),
              child: AnimatedBuilder(
                animation: _spread,
                builder: (context, _) {
                  final t = _spread.value;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _Glow(intensity: t.clamp(0, 1)),
                      _Disc(connected: widget.connected, lit: (_hover || _focus) && widget.onPressed != null),
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: widget.art.isGlyph ? 0.62 : 1,
                          heightFactor: widget.art.isGlyph ? 0.62 : 1,
                          child: ArtLayers(art: widget.art, spread: t),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The picture itself, wings at [spread] (0 folded, 1 open). Also the preview
/// in "Customize", so a choice looks there as it will on the button.
class ArtLayers extends StatelessWidget {
  const ArtLayers({super.key, required this.art, this.spread = 1, this.iconBackground});

  final AppArt art;
  final double spread;

  /// Set when previewing the app icon: glyph colours adapt to it.
  final IconBackground? iconBackground;

  // Shoulder pivots as Alignment. The figure's come from the data-pivot
  // attributes in the SVG (viewBox 99 59 1055 1055), the glyph's from where
  // its wings meet the body (11, 12.4 and 21, 12.4 of 32).
  static const _figureLeft = Alignment(-0.274, -0.249), _figureRight = Alignment(0.238, -0.249);
  static const _glyphLeft = Alignment(-0.3125, -0.225), _glyphRight = Alignment(0.3125, -0.225);

  @override
  Widget build(BuildContext context) {
    if (art.isGlyph) {
      final bg = iconBackground;
      ColorFilter tint(Color c) => ColorFilter.mode(bg == null ? c : onIconBackground(c, bg), BlendMode.srcIn);
      return Stack(
        fit: StackFit.expand,
        children: [
          _wing(SvgPicture.asset('assets/brand/glyph-wing-left.svg', colorFilter: tint(art.wings)), _glyphLeft, 1),
          _wing(SvgPicture.asset('assets/brand/glyph-wing-right.svg', colorFilter: tint(art.wings)), _glyphRight, -1),
          SvgPicture.asset('assets/brand/glyph-figure.svg', colorFilter: tint(art.figure)),
          SvgPicture.asset('assets/brand/glyph-star.svg', colorFilter: tint(art.star)),
        ],
      );
    }
    final filter = art == AppArt.crocellGrey ? greyscale : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        _wing(SvgPicture.asset('assets/brand/wing-left.svg', colorFilter: filter), _figureLeft, 1),
        _wing(SvgPicture.asset('assets/brand/wing-right.svg', colorFilter: filter), _figureRight, -1),
        SvgPicture.asset('assets/brand/figure.svg', colorFilter: filter),
      ],
    );
  }

  Widget _wing(Widget picture, Alignment pivot, int sign) {
    // Folded: tucked behind the shoulders, small and invisible.
    return Opacity(
      opacity: spread.clamp(0, 1),
      child: Transform.rotate(
        alignment: pivot,
        angle: sign * (1 - spread) * 0.9,
        child: Transform.scale(alignment: pivot, scale: 0.4 + 0.6 * spread, child: picture),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.intensity});

  final double intensity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            CrocellColors.accent.withValues(alpha: 0.10 + 0.35 * intensity),
            CrocellColors.accent.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// The disc the figure stands on. It is what makes the figure read as a
/// button: a visible edge (≥3:1 against the background, unlike the glow),
/// lit on hover and focus, red when connected. The wings break out of it.
class _Disc extends StatelessWidget {
  const _Disc({required this.connected, required this.lit});

  final bool connected;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Ring: #6E5A58 is 3.0:1 on the dark background, #8E807E 3.6:1 on light.
    final idle = dark ? const Color(0xFF6E5A58) : const Color(0xFF8E807E);
    final ring = connected || lit ? CrocellColors.primary : idle;

    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.82,
        heightFactor: 0.82,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Always a dark medallion: the figure is white, and on a light
            // disc it lost its silhouette. In the light theme the dark disc
            // is also the button's edge.
            gradient: const RadialGradient(center: Alignment(0, -0.3), colors: [Color(0xFF2A2021), Color(0xFF120D0D)]),
            border: Border.all(color: ring, width: connected ? 3 : 2),
          ),
        ),
      ),
    );
  }
}
