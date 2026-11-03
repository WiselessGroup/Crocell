import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../brand/appearance.dart';
import '../host.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets/connect_button.dart';

Future<void> showCustomize(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const CustomizeDialog());

/// The picture on the connect button and the app icon. What it offers
/// depends on the system: see [AppearanceChoices].
class CustomizeDialog extends ConsumerWidget {
  const CustomizeDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(hostProvider);
    final look = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final theme = Theme.of(context);
    final t = context.tokens;
    final heading = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    final note = theme.textTheme.bodySmall?.copyWith(color: t.muted);
    final narrow = MediaQuery.sizeOf(context).width < 520;

    return AlertDialog(
      title: Text(tr('Оформление', 'Customize')),
      insetPadding: narrow ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24) : null,
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Картинка', 'Picture'), style: heading),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                children: [
                  for (final art in host.artChoices)
                    _ArtOption(
                      art: art,
                      selected: art == look.art,
                      onTap: () => notifier.set(look.copyWith(art: art)),
                    ),
                ],
              ),
              if (host.chooseIconBackground) ...[
                const SizedBox(height: 20),
                Text(tr('Фон иконки', 'Icon background'), style: heading),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _IconPreview(look: look),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final b in IconBackground.values)
                            _Swatch(
                              background: b,
                              selected: b == look.background,
                              onTap: () => notifier.set(look.copyWith(background: b)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(switch (host.kind) {
                HostKind.android => tr(
                  'Иконка на рабочем столе сменится через несколько секунд. Если значок пропадёт, добавьте его заново из списка приложений. '
                      'В окне обновления и в настройках Android значок останется стандартным, а в шторке может зависеть от телефона.',
                  'The home screen icon changes in a few seconds. If it disappears, add it again from the app list. '
                      'The update dialog and Android settings keep the standard icon, and the notification shade may depend on the phone.',
                ),
                HostKind.macos => tr(
                  'Фон значка следует за светлым или тёмным оформлением системы. В Dock значок меняется, пока Crocell запущен. '
                      'В уведомлениях останется стандартный.',
                  'The icon background follows the system\'s light or dark look. The Dock icon changes while Crocell is running. '
                      'Notifications keep the standard one.',
                ),
                _ => tr(
                  'На панели задач значок меняется, пока Crocell запущен. В уведомлениях останется стандартный.',
                  'The taskbar icon changes while Crocell is running. Notifications keep the standard one.',
                ),
              }, style: note),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Готово', 'Done')))],
    );
  }
}

class _ArtOption extends StatelessWidget {
  const _ArtOption({required this.art, required this.selected, required this.onTap});

  final AppArt art;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: art.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 94,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                // Always the dark medallion, as on the button.
                Container(
                  width: 72,
                  height: 72,
                  padding: EdgeInsets.all(art.isGlyph ? 12 : 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF181213),
                    border: Border.all(color: selected ? CrocellColors.primary : t.outline, width: selected ? 3 : 1),
                  ),
                  child: ArtLayers(art: art),
                ),
                const SizedBox(height: 6),
                Text(art.label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconPreview extends StatelessWidget {
  const _IconPreview({required this.look});

  final Appearance look;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      padding: EdgeInsets.all(look.art.isGlyph ? 10 : 3),
      decoration: BoxDecoration(
        color: look.background.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.tokens.outline),
      ),
      child: ArtLayers(art: look.art, iconBackground: look.background),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.background, required this.selected, required this.onTap});

  final IconBackground background;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: background.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: background.label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background.color,
              border: Border.all(
                color: selected ? CrocellColors.primary : context.tokens.outline,
                width: selected ? 3 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
