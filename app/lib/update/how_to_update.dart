import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/state.dart';
import '../host.dart';
import '../notify/alerts.dart';
import '../service/install.dart';
import '../theme.dart';
import '../ui/daemon_missing.dart';
import 'releases.dart';

/// The app's navigator, so a notification click can open a dialog from
/// outside the widget tree.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// The machine the app runs on. Overridden in tests.
final hostProvider = Provider<Host>((ref) => Host.detect());

/// Opens "how to update" when the update notification is clicked. Watch it
/// once from the root widget.
final updatePromptProvider = Provider<void>((ref) {
  final sub = ref.watch(notificationsProvider).taps.listen((payload) {
    if (payload != UpdateNotifier.tapPayload) return;
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) showHowToUpdate(context);
  });
  ref.onDispose(sub.cancel);
});

Future<void> showHowToUpdate(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const HowToUpdate());

/// Steps for this system, from download to running the new version.
class HowToUpdate extends ConsumerWidget {
  const HowToUpdate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final host = ref.watch(hostProvider);
    final latest = ref.watch(availableUpdateProvider);
    final current = ref.watch(currentVersionProvider);
    final asset = releaseAsset(host.kind);

    final steps = <Widget>[];
    void step(String text, [Widget? extra]) => steps.add(_Step(n: steps.length + 1, text: text, extra: extra));
    final download = asset == null
        ? null
        : OutlinedButton.icon(
            onPressed: () => _open(latestDownload(asset)),
            icon: const Icon(Icons.download_rounded),
            label: Text('Скачать $asset'),
          );

    switch (host.kind) {
      case HostKind.appImage:
        step('Если Crocell стоит через Gear Lever, откройте Gear Lever и нажмите «Обновить» у Crocell. '
            'Если нет, скачайте новый образ и замените им старый файл.', download);
        step('Перезапустите Crocell и обновите службу, она живёт отдельно от образа:',
            InstallServiceAction(installer: serviceInstaller(host), label: 'Обновить службу'));
      case HostKind.windows:
        step('Скачайте установщик.', download);
        step('Запустите его. Он закроет Crocell, обновит программу и службу и запустит всё снова. '
            'Подписки и настройки останутся.');
        step('Если Windows покажет «Windows защитила ваш компьютер», нажмите «Подробнее», '
            'а затем «Выполнить в любом случае».');
      case HostKind.macos:
        step('Скачайте образ диска.', download);
        step('Откройте его и перетащите Crocell в «Программы», согласившись заменить старую версию.');
        step('Запустите Crocell и нажмите «Обновить службу», когда он попросит. macOS спросит пароль.');
        step('Если macOS не даёт открыть Crocell: «Системные настройки» → «Конфиденциальность и безопасность» '
            '→ «Всё равно открыть».');
      case HostKind.android:
        step('Скачайте новую версию.', download);
        step('Откройте скачанный файл и нажмите «Обновить». Если Android спросит, разрешите установку из браузера.');
        step('Подписки и настройки останутся.');
      case HostKind.linux:
      case HostKind.other:
        step('Этот Crocell собран из исходников. Обновите их, пересоберите приложение и переустановите службу: '
            'sudo crocelld install.');
    }

    return AlertDialog(
      title: const Text('Как обновить Crocell'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                latest == null ? 'У вас Crocell $current.' : 'Вышла версия $latest, у вас $current.',
                style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
              ),
              const SizedBox(height: 16),
              ...steps,
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => _open(latestReleasePage), child: const Text('Что нового')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text, this.extra});

  final int n;
  final String text;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.raised, shape: BoxShape.circle, border: Border.all(color: t.outline)),
            child: Text('$n', style: theme.textTheme.labelMedium),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 3), child: Text(text)),
                if (extra != null) ...[const SizedBox(height: 10), extra!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// A newer release is out: a quiet button in the toolbar, next to settings.
class UpdateButton extends ConsumerWidget {
  const UpdateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(availableUpdateProvider);
    if (latest == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Вышла Crocell $latest',
      icon: Badge(
        backgroundColor: Theme.of(context).colorScheme.primary,
        smallSize: 8,
        child: const Icon(Icons.system_update_alt_rounded),
      ),
      onPressed: () => showHowToUpdate(context),
    );
  }
}

/// The service is older than the app: the app was updated, the service
/// (a copy outside the app on Linux and macOS) was not. Old services do
/// not report a version at all.
bool serviceOutdated(String coreVersion, String appVersion) {
  if (parseVersion(appVersion) == null) return false; // dev builds
  return coreVersion != appVersion;
}

/// Shown above the connect button until the service matches the app.
class ServiceOutdatedBanner extends ConsumerWidget {
  const ServiceOutdatedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(hostProvider);
    final status = ref.watch(statusProvider).value;
    final current = ref.watch(currentVersionProvider);
    if (host.embeddedCore || status == null || !serviceOutdated(status.coreVersion, current)) {
      return const SizedBox.shrink();
    }
    final installer = serviceInstaller(host);
    if (!installer.available) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final t = context.tokens;
    final old = status.coreVersion.isEmpty ? 'старой версии' : 'версии ${status.coreVersion}';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Обновите службу Crocell', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Приложение уже $current, а служба, которая держит VPN, осталась $old. '
            'Исправления новой версии заработают после её обновления.',
            style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
          ),
          const SizedBox(height: 12),
          InstallServiceAction(installer: installer, label: 'Обновить службу'),
        ],
      ),
    );
  }
}

/// Fire-and-forget update check, for the connect button.
void checkForUpdate(WidgetRef ref) => unawaited(ref.read(availableUpdateProvider.notifier).check());
