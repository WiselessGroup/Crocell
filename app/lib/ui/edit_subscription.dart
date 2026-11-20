import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/state.dart';
import '../l10n.dart';

/// Name, link and User-Agent of one subscription.
///
/// The app never has the link in full, only its masked form, so the field
/// starts empty and a link can only be replaced whole.
class EditSubscriptionDialog extends ConsumerStatefulWidget {
  const EditSubscriptionDialog({super.key, required this.sub});

  final Subscription sub;

  @override
  ConsumerState<EditSubscriptionDialog> createState() => _EditSubscriptionDialogState();
}

class _EditSubscriptionDialogState extends ConsumerState<EditSubscriptionDialog> {
  late final _title = TextEditingController(text: widget.sub.title);
  final _url = TextEditingController();
  late final _agent = TextEditingController(text: widget.sub.userAgent);
  late bool _advanced = widget.sub.userAgent.isNotEmpty;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _agent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(subscriptionsProvider.notifier).edit(
            widget.sub.id,
            title: _title.text.trim(),
            url: _url.text.trim(),
            userAgent: _agent.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(tr('Изменить подписку', 'Edit subscription')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: tr('Название', 'Name'),
                helperText: tr('Пусто: как называет провайдер', "Empty: the provider's name"),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              enabled: !_busy,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: tr('Новая ссылка', 'New link'),
                hintText: widget.sub.urlMasked,
                helperText: tr('Пусто: ссылка остаётся прежней', 'Empty: the link stays as it is'),
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 8),
            if (!_advanced)
              TextButton(
                onPressed: _busy ? null : () => setState(() => _advanced = true),
                child: Text(tr('Дополнительно', 'More options')),
              )
            else ...[
              const SizedBox(height: 8),
              TextField(
                controller: _agent,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'User-Agent',
                  hintText: tr('По умолчанию', 'Default'),
                  helperText: tr(
                    'Нужен, только если провайдер отдаёт подписку лишь своему приложению, например INCY/1.0. '
                        'Пусто: как обычно.',
                    'Only for providers that serve the subscription to their own app alone, e.g. INCY/1.0. '
                        'Empty: as usual.',
                  ),
                  helperMaxLines: 4,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(tr('Отмена', 'Cancel'))),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr('Сохранить', 'Save')),
        ),
      ],
    );
  }
}
