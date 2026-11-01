import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_api.dart';

/// Where the core listens. Android overrides it with the socket of the core
/// inside the app.
final coreEndpointProvider = Provider<CoreEndpoint>((ref) => defaultEndpoint());

/// The connection to crocelld. Overridden in tests.
final coreApiProvider = Provider<CoreApi>((ref) {
  final api = GrpcCoreApi(ref.watch(coreEndpointProvider));
  ref.onDispose(api.close);
  return api;
});

/// Live status from the daemon. When the daemon goes away the stream errors,
/// and we keep retrying quietly: the moment it is back, the UI is back.
final statusProvider = StreamProvider<Status>((ref) async* {
  final api = ref.watch(coreApiProvider);
  while (true) {
    try {
      yield* api.watchStatus();
      // A clean end means the daemon shut down.
      throw const CoreError('Служба Crocell остановилась', unavailable: true);
    } on CoreError catch (e) {
      if (!e.unavailable) rethrow;
      // Surface the outage, then try again shortly.
      yield* Stream<Status>.error(e);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
}, retry: (_, _) => null);

/// True while the daemon answers. Null until the first answer or error.
final daemonReachableProvider = Provider<bool?>((ref) {
  final status = ref.watch(statusProvider);
  return switch (status) {
    AsyncData() => true,
    AsyncError(:final error) => error is CoreError && error.unavailable ? false : true,
    _ => null,
  };
});

/// Subscriptions with their nodes. Probe results stream into the nodes as
/// they arrive.
final subscriptionsProvider =
    AsyncNotifierProvider<SubscriptionsNotifier, List<Subscription>>(SubscriptionsNotifier.new);

class SubscriptionsNotifier extends AsyncNotifier<List<Subscription>> {
  CoreApi get _api => ref.read(coreApiProvider);

  @override
  Future<List<Subscription>> build() {
    // Reload once the daemon comes back after an outage.
    ref.watch(daemonReachableProvider);
    return ref.read(coreApiProvider).listSubscriptions();
  }

  Future<Subscription> add(String url) async {
    final sub = await _api.addSubscription(url.trim());
    state = AsyncData([
      for (final s in state.value ?? <Subscription>[])
        if (s.id != sub.id) s,
      sub,
    ]);
    return sub;
  }

  Future<void> refresh(String id) async {
    final sub = await _api.refreshSubscription(id);
    _replace(sub);
  }

  Future<void> remove(String id) async {
    await _api.removeSubscription(id);
    state = AsyncData([
      for (final s in state.value ?? <Subscription>[])
        if (s.id != id) s,
    ]);
  }

  /// Probes every node of a subscription and updates them one by one.
  Future<void> probe(String subscriptionId) async {
    final probing = ref.read(probingProvider.notifier);
    probing.start(subscriptionId);
    try {
      await for (final r in _api.probeNodes(subscriptionId)) {
        final subs = state.value;
        if (subs == null) continue;
        state = AsyncData([
          for (final s in subs)
            if (s.id != subscriptionId)
              s
            else
              (s.deepCopy()
                ..nodes.clear()
                ..nodes.addAll([
                  for (final n in s.nodes) n.id == r.nodeId ? (n.deepCopy()..lastProbe = r) : n,
                ])),
        ]);
      }
    } finally {
      probing.stop(subscriptionId);
    }
  }

  void _replace(Subscription sub) {
    state = AsyncData([
      for (final s in state.value ?? <Subscription>[]) s.id == sub.id ? sub : s,
    ]);
  }
}

/// Subscriptions being probed right now.
final probingProvider = NotifierProvider<ProbingNotifier, Set<String>>(ProbingNotifier.new);

class ProbingNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};
  void start(String id) => state = {...state, id};
  void stop(String id) => state = {...state}..remove(id);
}

/// Daemon settings: tunnel mode, per-app rules.
final settingsProvider = AsyncNotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<Settings> {
  CoreApi get _api => ref.read(coreApiProvider);

  @override
  Future<Settings> build() {
    ref.watch(daemonReachableProvider);
    return ref.read(coreApiProvider).getSettings();
  }

  Future<void> _update(void Function(Settings s) edit) async {
    final current = state.value ?? await future;
    final next = current.deepCopy();
    edit(next);
    state = AsyncData(await _api.updateSettings(next));
  }

  Future<void> setMode(TunnelMode mode) => _update((s) => s.tunnelMode = mode);

  /// Adds rules to an action's list. A rule already in another list moves.
  Future<void> addRules(List<RouteRule> rules) => _update((s) {
        for (final r in rules) {
          s.rules.removeWhere((x) => x.kind == r.kind && x.value == r.value);
          s.rules.add(r);
        }
      });

  Future<void> removeRule(RouteRule rule) => removeRules([rule]);

  Future<void> removeRules(Iterable<RouteRule> rules) => _update((s) {
        for (final rule in rules) {
          s.rules.removeWhere((x) => x.kind == rule.kind && x.value == rule.value);
        }
      });

  Future<void> setFinal(RouteAction action) => _update((s) => s.finalAction = action);

  /// Any other edit, for the advanced section.
  Future<void> edit(void Function(Settings s) change) => _update(change);
}

/// Running programs, fetched when the picker opens.
final processesProvider = FutureProvider.autoDispose<List<Process>>((ref) => ref.read(coreApiProvider).listProcesses());

/// The geo databases: dates, categories, update.
final geoInfoProvider = AsyncNotifierProvider<GeoInfoNotifier, GeoInfo>(GeoInfoNotifier.new);

class GeoInfoNotifier extends AsyncNotifier<GeoInfo> {
  @override
  Future<GeoInfo> build() {
    ref.watch(daemonReachableProvider);
    return ref.read(coreApiProvider).getGeoInfo();
  }

  /// Fetches both databases now (Riverpod already has an `update`).
  Future<void> refresh() async {
    final current = state.value;
    if (current != null) state = AsyncData(current.deepCopy()..updating = true);
    state = AsyncData(await ref.read(coreApiProvider).updateGeo());
  }
}

/// Connect, disconnect, switch nodes. Errors bubble to the caller to show.
final connectionProvider = Provider<ConnectionActions>((ref) => ConnectionActions(ref));

class ConnectionActions {
  ConnectionActions(this._ref);
  final Ref _ref;

  CoreApi get _api => _ref.read(coreApiProvider);

  Future<Status> connect({String subscriptionId = '', String nodeId = ''}) =>
      _api.connect(subscriptionId: subscriptionId, nodeId: nodeId);

  Future<Status> disconnect() => _api.disconnect();

  Future<Status> select(String subscriptionId, String nodeId) => _api.selectNode(subscriptionId, nodeId);
}

extension StatusX on Status {
  bool get isConnected => state == ConnectionState.CONNECTION_STATE_CONNECTED;
  bool get isBusy =>
      state == ConnectionState.CONNECTION_STATE_CONNECTING ||
      state == ConnectionState.CONNECTION_STATE_DISCONNECTING;
  bool get isFailed => state == ConnectionState.CONNECTION_STATE_FAILED;
  bool get isConnecting => state == ConnectionState.CONNECTION_STATE_CONNECTING;
  bool get isDisconnecting => state == ConnectionState.CONNECTION_STATE_DISCONNECTING;
}

/// Finds a node across subscriptions.
({Subscription sub, Node node})? findNode(List<Subscription> subs, String subId, String nodeId) {
  for (final s in subs) {
    if (s.id != subId) continue;
    for (final n in s.nodes) {
      if (n.id == nodeId) return (sub: s, node: n);
    }
  }
  return null;
}
