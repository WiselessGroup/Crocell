import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/state.dart';
import '../theme.dart';
import 'common.dart';

/// Rarely changed things. The tunnel mode lives on the home screen, next to
/// the button it affects.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: switch (settings) {
        AsyncData(:final value) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Программы', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Как отдельные программы ходят в сеть, пока VPN включён. Напрямую — для игр и всего, '
                        'что должно идти мимо VPN. Укажите имя программы (steam, telegram-desktop), путь к ней '
                        'или пакет на Android.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
                      ),
                      const SizedBox(height: 12),
                      _AppRules(rules: value.appRules),
                      const SizedBox(height: 32),
                      Text('О Crocell', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Версия 0.1.0. Ядро — mihomo. Свободная программа под лицензией GPL-3.0.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _AppRules extends ConsumerStatefulWidget {
  const _AppRules({required this.rules});

  final List<AppRule> rules;

  @override
  ConsumerState<_AppRules> createState() => _AppRulesState();
}

class _AppRulesState extends ConsumerState<_AppRules> {
  final _app = TextEditingController();

  @override
  void dispose() {
    _app.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _add() async {
    final app = _app.text.trim();
    if (app.isEmpty) return;
    await _run(() => ref.read(settingsProvider.notifier).setAppRule(app, AppMode.APP_MODE_BYPASS));
    _app.clear();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(settingsProvider.notifier);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final rule in widget.rules) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(rule.app,
                            style: Theme.of(context).textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        tooltip: 'Убрать ${rule.app}',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => _run(() => notifier.removeAppRule(rule.app)),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SegmentedButton<AppMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: AppMode.APP_MODE_PROXY, label: Text('Через VPN')),
                        ButtonSegment(value: AppMode.APP_MODE_BYPASS, label: Text('Напрямую')),
                        ButtonSegment(value: AppMode.APP_MODE_BLOCK, label: Text('Без сети')),
                      ],
                      selected: {rule.mode},
                      onSelectionChanged: (v) => _run(() => notifier.setAppRule(rule.app, v.first)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _app,
                    autocorrect: false,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(labelText: 'Программа', hintText: 'steam'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _add, child: const Text('Добавить')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
