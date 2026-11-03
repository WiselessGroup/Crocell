import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/state.dart';
import '../l10n.dart';
import '../update/how_to_update.dart';
import 'add_subscription.dart';
import 'connect_panel.dart';
import 'daemon_missing.dart';
import 'mac_menu.dart';
import 'nodes_view.dart';
import 'settings_screen.dart';

/// Wide windows show the node list next to the button; narrow ones keep the
/// button alone and open the list as a page. Same functions at every width.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const wideBreakpoint = 840.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reachable = ref.watch(daemonReachableProvider);

    void openSettings() =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

    final screen = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.comma, control: true): openSettings,
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): openSettings,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= wideBreakpoint;
          return Scaffold(
            appBar: AppBar(
              actions: [
                const UpdateButton(),
                if (reachable == true)
                  IconButton(
                    tooltip: tr('Добавить подписку', 'Add subscription'),
                    icon: const Icon(Icons.add_link_rounded),
                    onPressed: () => showAddSubscription(context),
                  ),
                IconButton(
                  tooltip: tr('Настройки', 'Settings'),
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: reachable == true ? openSettings : null,
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: switch (reachable) {
                false => const DaemonMissing(),
                null => const SizedBox.shrink(),
                true when wide => const Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: ConnectPanel()),
                      VerticalDivider(width: 1),
                      Expanded(flex: 6, child: NodesView()),
                    ],
                  ),
                true => ConnectPanel(
                    onOpenNodes: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: Text(tr('Ноды', 'Nodes')),
                          actions: [
                            IconButton(
                              tooltip: tr('Добавить подписку', 'Add subscription'),
                              icon: const Icon(Icons.add_link_rounded),
                              onPressed: () => showAddSubscription(context),
                            ),
                          ],
                        ),
                        body: const SafeArea(child: NodesView()),
                      ),
                    )),
                  ),
              },
            ),
          );
        }),
      ),
    );

    if (defaultTargetPlatform != TargetPlatform.macOS) return screen;
    return MacMenu(
      // The menu is there on every screen; settings open once, from home.
      onSettings: reachable == true ? () {
        if (ModalRoute.of(context)?.isCurrent ?? true) openSettings();
      } : null,
      child: screen,
    );
  }
}
