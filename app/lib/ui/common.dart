import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../data/core_api.dart';
import '../theme.dart';
import 'format.dart';

/// A country as its flag. Vector flags from country_flags, not emoji:
/// Windows has no flag glyphs and would show two letters instead.
///
/// [claimed] marks a country taken from the node's name, not measured: the
/// flag is drawn half-transparent until a probe confirms the exit. The name
/// goes to the tooltip and the screen reader.
class CountryBadge extends StatelessWidget {
  const CountryBadge({super.key, required this.code, this.claimed = false, this.size = 36});

  /// ISO code, or empty when unknown.
  final String code;
  final bool claimed;
  final double size;

  /// The measured exit country if probed, else the claimed one.
  factory CountryBadge.forNode(Node node, {double size = 36}) {
    final exit = node.hasLastProbe() ? node.lastProbe.exitCountry : '';
    if (exit.isNotEmpty) return CountryBadge(code: exit, size: size);
    return CountryBadge(code: claimedCountry(node.name), claimed: true, size: size);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (code.isEmpty) {
      return SizedBox.square(
        dimension: size,
        child: Icon(Icons.public, size: size * 0.6, color: t.muted, semanticLabel: 'Страна неизвестна'),
      );
    }

    final name = countryName(code);
    final label = claimed ? '$name, по названию ноды' : 'Выход: $name';
    final width = size * 0.86, height = width * 0.72;

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: Opacity(
              opacity: claimed ? 0.45 : 1,
              child: Container(
                // A hairline so white flags (Finland, Japan) keep an edge.
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: t.outline),
                ),
                child: CountryFlag.fromCountryCode(
                  code,
                  theme: ImageTheme(width: width, height: height, shape: const RoundedRectangle(5)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quality as icon + word, never colour alone.
class QualityLine extends StatelessWidget {
  const QualityLine({super.key, required this.probe, this.compact = false});

  final ProbeResult? probe;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final q = quality(probe);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted);

    final (icon, color) = switch (q) {
      Quality.good => (Icons.check_circle_rounded, t.good),
      Quality.slow => (Icons.schedule_rounded, t.muted),
      Quality.down => (Icons.cancel_outlined, t.muted),
      Quality.unknown => (Icons.help_outline_rounded, t.muted),
    };

    final r = probe;
    final details = switch (q) {
      Quality.good || Quality.slow => 'Выход: ${exitPlace(r!)} · ${r.latencyMs} мс',
      Quality.down => 'Не отвечает',
      Quality.unknown => 'Не проверено',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            q == Quality.slow ? '$details · медленно' : details,
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$error'), behavior: SnackBarBehavior.floating));
}
