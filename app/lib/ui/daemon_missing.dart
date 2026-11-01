import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../host.dart';
import '../service/install.dart';
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
    final host = Host.detect();
    final installer = serviceInstaller(host);

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
              if (host.embeddedCore)
                Text(
                  'Ядро Crocell не запустилось. Закройте приложение и откройте снова.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                )
              else if (installer.available)
                InstallServiceAction(installer: installer, label: 'Установить службу')
              else
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

/// Installs the service: a command to copy on Linux, a button with the
/// system's password prompt on macOS and Windows.
class InstallServiceAction extends StatefulWidget {
  const InstallServiceAction({super.key, required this.installer, required this.label});

  final ServiceInstaller installer;

  /// The button text, for the platforms with a button.
  final String label;

  @override
  State<InstallServiceAction> createState() => _InstallServiceActionState();
}

class _InstallServiceActionState extends State<InstallServiceAction> {
  bool _busy = false;
  String? _error;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.installer.run!();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final command = widget.installer.command;

    if (command != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Выполните в терминале:', style: theme.textTheme.bodyMedium),
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
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : _run,
          icon: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_rounded),
          label: Text(widget.label),
        ),
        const SizedBox(height: 8),
        Text(
          'Система попросит пароль администратора.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}
