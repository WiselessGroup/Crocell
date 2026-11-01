import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/state.dart';
import '../l10n.dart';

/// Asks for a subscription link. Picks it up from the clipboard when one is
/// there, since that is where people bring it from.
Future<void> showAddSubscription(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _AddSubscriptionDialog());
}

class _AddSubscriptionDialog extends ConsumerStatefulWidget {
  const _AddSubscriptionDialog();

  @override
  ConsumerState<_AddSubscriptionDialog> createState() => _AddSubscriptionDialogState();
}

class _AddSubscriptionDialogState extends ConsumerState<_AddSubscriptionDialog> {
  final _url = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _fromClipboard = false;

  @override
  void initState() {
    super.initState();
    _pasteIfLink(auto: true);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  static bool _looksLikeLink(String s) {
    final uri = Uri.tryParse(s.trim());
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
  }

  Future<void> _pasteIfLink({bool auto = false}) async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    if (!mounted) return;
    if (_looksLikeLink(text) || !auto) {
      setState(() {
        _url.text = text;
        _fromClipboard = auto && text.isNotEmpty;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    if (!_looksLikeLink(url)) {
      setState(() => _error = tr('Нужна ссылка, которая начинается с https://', 'The link should start with https://'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sub = await ref.read(subscriptionsProvider.notifier).add(url);
      // Pick the first node so the big button works right away. Before pop:
      // ref is gone once the dialog is disposed.
      final status = ref.read(statusProvider).value;
      if ((status == null || status.nodeId.isEmpty) && sub.nodes.isNotEmpty) {
        await ref.read(connectionProvider).select(sub.id, sub.nodes.first.id);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Добавить подписку', 'Add subscription')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Вставьте ссылку, которую дал ваш VPN-сервис. Crocell сам разберётся с форматом.', 'Paste the link your VPN service gave you. Crocell will figure out the format.')),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              autofocus: true,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() {
                _error = null;
                _fromClipboard = false;
              }),
              decoration: InputDecoration(
                labelText: tr('Ссылка на подписку', 'Subscription link'),
                hintText: 'https://…',
                errorText: _error,
                errorMaxLines: 3,
                helperText: _fromClipboard ? tr('Взяли из буфера обмена', 'Taken from the clipboard') : null,
                suffixIcon: IconButton(
                  tooltip: tr('Вставить', 'Paste'),
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: _busy ? null : () => _pasteIfLink(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(tr('Отмена', 'Cancel'))),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr('Добавить', 'Add')),
        ),
      ],
    );
  }
}
