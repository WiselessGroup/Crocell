import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';

/// The menu bar a Mac app is expected to have. Without it there is no
/// "Settings…" where people look for it, under the app's name.
class MacMenu extends StatelessWidget {
  const MacMenu({super.key, required this.onSettings, required this.child});

  final VoidCallback? onSettings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Crocell',
          menus: [
            const PlatformMenuItemGroup(members: [
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
            ]),
            PlatformMenuItemGroup(members: [
              PlatformMenuItem(
                label: tr('Настройки…', 'Settings…'),
                shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
                onSelected: onSettings,
              ),
            ]),
            const PlatformMenuItemGroup(members: [
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.servicesSubmenu),
            ]),
            const PlatformMenuItemGroup(members: [
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hideOtherApplications),
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.showAllApplications),
            ]),
            const PlatformMenuItemGroup(members: [
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
            ]),
          ],
        ),
        PlatformMenu(
          label: tr('Окно', 'Window'),
          menus: const [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.minimizeWindow),
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.zoomWindow),
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.toggleFullScreen),
          ],
        ),
      ],
      child: child,
    );
  }
}
