import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/state.dart';
import '../l10n.dart';
import '../logs.dart';
import '../theme.dart';
import '../version.dart';

Future<void> showLogs(BuildContext context) => showDialog<void>(context: context, builder: (_) => const LogsDialog());

/// The app's and the core's recent logs, to copy into a bug report.
class LogsDialog extends ConsumerStatefulWidget {
  const LogsDialog({super.key});

  @override
  ConsumerState<LogsDialog> createState() => _LogsDialogState();
}

class _LogsDialogState extends ConsumerState<LogsDialog> {
  late final Future<String> _text = _collect();
  bool _copied = false;

  Future<String> _collect() async {
    String core;
    try {
      core = await ref.read(coreApiProvider).getLogs();
    } catch (e) {
      core = '(no core log: $e)';
    }
    final status = ref.read(statusProvider).value;
    final header = 'Crocell $appVersion, core ${status?.coreVersion ?? '?'}, '
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    final app = appLogText();
    return [header, if (app.isNotEmpty) '--- app ---\n$app', '--- core ---\n${core.isEmpty ? '(empty)' : core}']
        .join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Text(tr('Логи', 'Logs')),
      insetPadding: size.width < 520 ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24) : null,
      content: SizedBox(
        width: 720,
        height: (size.height * 0.6).clamp(240, 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Ссылок на подписки здесь нет, адреса нод и ошибки есть. Скопируйте и пришлите вместе с описанием проблемы.', 'Subscription links are not included; node addresses and errors are. Copy this and send it along with a description of the problem.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: t.raised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.outline),
                ),
                child: FutureBuilder(
                  future: _text,
                  builder: (context, snap) => snap.hasData
                      // Newest at the bottom, and that is where it opens.
                      ? SingleChildScrollView(
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(snap.data!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Закрыть', 'Close'))),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: await _text));
            if (mounted) setState(() => _copied = true);
          },
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
          label: Text(_copied ? tr('Скопировано', 'Copied') : tr('Скопировать', 'Copy')),
        ),
      ],
    );
  }
}
