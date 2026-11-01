import 'package:flutter/material.dart';

import '../data/core_api.dart';
import '../theme.dart';
import 'format.dart';

/// Two-letter country code in a rounded box. Text, so it reads on every
/// platform and to a screen reader; the full name goes in the label.
///
/// [claimed] marks a country taken from the node's name, not measured: it is
/// drawn quieter (outline, muted text) until a probe confirms the exit.
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
    final known = code.isNotEmpty;
    return Semantics(
      label: known ? (claimed ? 'По названию ${countryName(code)}' : 'Выход: ${countryName(code)}') : null,
      excludeSemantics: true,
      child: Tooltip(
        message: known ? (claimed ? '${countryName(code)}, по названию ноды' : 'Выход: ${countryName(code)}') : '',
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: claimed ? null : t.raised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.outline),
          ),
          child: known
              ? Text(
                  code.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: claimed ? FontWeight.w500 : FontWeight.w700,
                        color: claimed ? t.muted : null,
                        letterSpacing: 0.5,
                      ),
                )
              : Icon(Icons.public, size: size * 0.5, color: t.muted),
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
