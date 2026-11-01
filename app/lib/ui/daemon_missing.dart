import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// The service that holds the tunnel is not reachable. Explains what it is
/// and how to get it, then gets out of the way the moment it answers: the
/// status stream keeps retrying underneath.
class DaemonMissing extends StatelessWidget {
  const DaemonMissing({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final command = Platform.isLinux ? 'sudo crocelld install' : null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.power_settings_new_rounded, size: 44, color: t.muted),
              const SizedBox(height: 16),
              Text('Служба Crocell не запущена', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'VPN держит отдельная служба: система один раз выдаёт ей права, и дальше она работает, '
                'даже когда это окно закрыто.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
              ),
              const SizedBox(height: 20),
              if (command != null) ...[
                Text('Установите её одной командой:', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                  decoration: BoxDecoration(
                    color: t.raised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.outline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(command, style: const TextStyle(fontFamily: 'monospace', fontSize: 15)),
                      ),
                      IconButton(
                        tooltip: 'Скопировать команду',
                        icon: const Icon(Icons.copy_rounded),
                        onPressed: () => Clipboard.setData(ClipboardData(text: command)),
                      ),
                    ],
                  ),
                ),
              ] else
                Text(
                  'Установщик службы для этой системы ещё в работе. Пока запустите crocelld вручную от администратора.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 20),
              // No spinner: it would spin for as long as the service is
              // missing, and nothing here should cost CPU while idle.
              Text(
                'Как только служба заработает, Crocell откроется сам.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
