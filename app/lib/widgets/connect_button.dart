import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// The figure from the logo. Wings spread when connected.
///
/// Layers come from assets/brand/crocell-mark-winged.svg split by
/// scripts/brand-layers.py, all three share one viewBox so they stack exactly.
class ConnectButton extends StatefulWidget {
  const ConnectButton({
    super.key,
    required this.connected,
    required this.onPressed,
    this.size = 240,
    this.label,
  });

  final bool connected;

  /// Null disables the button (busy, or nothing to connect to).
  final VoidCallback? onPressed;
  final double size;

  /// What a screen reader announces. Defaults to connect/disconnect.
  final String? label;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  // Shoulder pivots, from the data-pivot attributes in the SVG
  // (viewBox 99 59 1055 1055), as Alignment.
  static const _leftPivot = Alignment(-0.274, -0.249);
  static const _rightPivot = Alignment(0.238, -0.249);

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
      label: widget.label ?? (widget.connected ? 'Отключить VPN' : 'Подключить VPN'),
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
                      _Disc(
                        connected: widget.connected,
                        lit: (_hover || _focus) && widget.onPressed != null,
                      ),
                      _wing('wing-left', _leftPivot, t, sign: 1),
                      _wing('wing-right', _rightPivot, t, sign: -1),
                      SvgPicture.asset('assets/brand/figure.svg'),
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

  Widget _wing(String name, Alignment pivot, double t, {required int sign}) {
    // Folded: tucked behind the shoulders, small and invisible.
    return Opacity(
      opacity: t.clamp(0, 1),
      child: Transform.rotate(
        alignment: pivot,
        angle: sign * (1 - t) * 0.9,
        child: Transform.scale(
          alignment: pivot,
          scale: 0.4 + 0.6 * t,
          child: SvgPicture.asset('assets/brand/$name.svg'),
        ),
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
            gradient: const RadialGradient(
              center: Alignment(0, -0.3),
              colors: [Color(0xFF2A2021), Color(0xFF120D0D)],
            ),
            border: Border.all(color: ring, width: connected ? 3 : 2),
          ),
        ),
      ),
    );
  }
}
