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

  /// A subscription link, a share link, a vpn:// key or a WireGuard config:
  /// what the core can read, judged by the start of it.
  static bool looksReadable(String s) {
    final text = s.trim();
    if (text.toLowerCase().startsWith('[interface]')) return true;
    final uri = Uri.tryParse(text.split('\n').first);
    if (uri == null || !uri.hasScheme) return false;
    if (uri.scheme == 'https' || uri.scheme == 'http') return uri.host.isNotEmpty;
    return const {
      'vless', 'vmess', 'trojan', 'ss', 'ssr', 'hysteria', 'hysteria2', 'hy2', 'tuic',
      'wireguard', 'wg', 'awg', 'amneziawg', 'vpn',
    }.contains(uri.scheme);
  }

  Future<void> _pasteIfLink({bool auto = false}) async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    if (!mounted) return;
    if (looksReadable(text) || !auto) {
      setState(() {
        _url.text = text;
        _fromClipboard = auto && text.isNotEmpty;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    if (!looksReadable(url)) {
      setState(() => _error = tr(
        'Нужна ссылка, которая начинается с https://, ключ vpn:// или конфиг WireGuard',
        'This needs a link starting with https://, a vpn:// key or a WireGuard config',
      ));
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
      // The text and a six-line field don't fit a small phone with the
      // keyboard open.
      scrollable: true,
      title: Text(tr('Добавить подписку', 'Add subscription')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(
                'Вставьте то, что дал ваш VPN-сервис: ссылку на подписку, ссылку на ноду, ключ vpn:// из AmneziaVPN '
                    'или конфиг WireGuard. Crocell сам разберётся с форматом.',
                'Paste what your VPN service gave you: a subscription link, a node link, a vpn:// key from AmneziaVPN '
                    'or a WireGuard config. Crocell will figure out the format.',
              )),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              autofocus: true,
              enabled: !_busy,
              // A WireGuard config is many lines.
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {
                _error = null;
                _fromClipboard = false;
              }),
              decoration: InputDecoration(
                labelText: tr('Ссылка или конфиг', 'Link or config'),
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
