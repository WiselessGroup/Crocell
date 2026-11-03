import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_api.dart';
import '../data/state.dart';
import 'sysproxy.dart';

final systemProxyProvider = Provider<SystemProxy>((ref) => SystemProxy());

/// Last system proxy problem, shown on the home screen. Null when fine.
final systemProxyErrorProvider = NotifierProvider<_ErrorNotifier, String?>(_ErrorNotifier.new);

class _ErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? message) => state = message;
}

/// Keeps the desktop proxy settings in step with the daemon: pointed at the
/// mixed port while connected in system-proxy mode, restored otherwise.
/// Watch it once from the root widget.
final systemProxyControllerProvider = Provider<void>((ref) {
  final proxy = ref.watch(systemProxyProvider);
  if (!proxy.isSupported) return;

  var pointedAt = 0;
  var applying = false;
  var busy = Future<void>.value();

  // Leftovers from a crash: the daemon is not ours to trust yet.
  busy = proxy.recover().catchError((Object e) => ref.read(systemProxyErrorProvider.notifier).set('$e'));

  ref.listen(statusProvider, (_, next) {
    final status = next.value;
    final want = status != null &&
            status.isConnected &&
            status.tunnelMode == TunnelMode.TUNNEL_MODE_SYSTEM_PROXY
        ? status.mixedPort
        : 0;
    // The GNOME extension puts the proxy back when the service goes away for
    // a while. If the service then comes back connected, point at it again.
    final takenBack = want > 0 && want == pointedAt && !applying && !proxy.isActive;
    if (want == pointedAt && !takenBack) return;
    pointedAt = want;
    applying = true;

    busy = busy.then((_) async {
      try {
        if (want > 0) {
          await proxy.enable(want);
        } else {
          await proxy.restore();
        }
        ref.read(systemProxyErrorProvider.notifier).set(null);
      } catch (e) {
        ref.read(systemProxyErrorProvider.notifier).set('$e');
      } finally {
        applying = false;
      }
    });
  }, fireImmediately: true);

  ref.onDispose(() => proxy.restore());
});
