import 'dart:async';

import 'package:crocell/data/core_api.dart';
import 'package:fixnum/fixnum.dart';

/// In-memory crocelld for widget tests: records calls, answers like the real
/// daemon would, never touches a socket.
class FakeCore implements CoreApi {
  FakeCore({List<Subscription>? subs, Status? status, this.unavailable = false})
      : subs = subs ?? [],
        current = status ?? Status(state: ConnectionState.CONNECTION_STATE_DISCONNECTED);

  bool unavailable;
  List<Subscription> subs;
  Status current;
  Settings settings = Settings(tunnelMode: TunnelMode.TUNNEL_MODE_SYSTEM_PROXY, mixedPort: 7890);
  final calls = <String>[];
  final _status = StreamController<Status>.broadcast();

  void push(Status s) {
    current = s;
    _status.add(s);
  }

  @override
  Stream<Status> watchStatus() async* {
    if (unavailable) throw const CoreError('Служба Crocell не отвечает', unavailable: true);
    yield current;
    yield* _status.stream;
  }

  @override
  Future<Status> connect({String subscriptionId = '', String nodeId = ''}) async {
    calls.add('connect');
    push(current.deepCopy()
      ..state = ConnectionState.CONNECTION_STATE_CONNECTED
      ..tunnelMode = settings.tunnelMode
      ..mixedPort = 7890);
    return current;
  }

  @override
  Future<Status> disconnect() async {
    calls.add('disconnect');
    push(current.deepCopy()..state = ConnectionState.CONNECTION_STATE_DISCONNECTED);
    return current;
  }

  @override
  Future<Status> selectNode(String subscriptionId, String nodeId) async {
    calls.add('select $nodeId');
    push(current.deepCopy()
      ..subscriptionId = subscriptionId
      ..nodeId = nodeId);
    return current;
  }

  @override
  Future<List<Subscription>> listSubscriptions() async => subs;

  @override
  Future<Subscription> addSubscription(String url) async {
    calls.add('add $url');
    final sub = sampleSubscription();
    subs = [...subs, sub];
    return sub;
  }

  @override
  Future<Subscription> refreshSubscription(String id) async => subs.firstWhere((s) => s.id == id);

  @override
  Future<void> removeSubscription(String id) async {
    calls.add('remove $id');
    subs = subs.where((s) => s.id != id).toList();
  }

  @override
  Stream<ProbeResult> probeNodes(String subscriptionId, {List<String> nodeIds = const []}) async* {
    calls.add('probe $subscriptionId');
    yield ProbeResult(nodeId: 'n1', exitCountry: 'DE', exitColo: 'FRA', exitIp: '203.0.113.7', latencyMs: 145);
    yield ProbeResult(nodeId: 'n2', error: 'probe: timeout');
  }

  @override
  Future<Settings> getSettings() async => settings;

  @override
  Future<Settings> updateSettings(Settings s) async {
    calls.add('settings ${s.tunnelMode.name} ${s.appRules.map((r) => '${r.app}=${r.mode.name}').join(',')}');
    settings = s;
    return s;
  }
}

Subscription sampleSubscription() => Subscription(
      id: 'sub1',
      title: 'WISELESS',
      urlMasked: 'https://ftn.example.net/sub/…c03d1c',
      totalBytes: Int64(0),
      nodes: [
        Node(id: 'n1', name: 'autoWISELESS-1', type: 'vless', network: 'xhttp', server: 'dc.example.com', port: 443),
        Node(id: 'n2', name: 'nlWISELESS', type: 'vless', network: 'xhttp', server: 'nl.example.com', port: 443),
        Node(id: 'n3', name: 'autoWISELESS-2 (HYSTERIA)', type: 'hysteria2', server: 'hy.example.com', port: 443),
      ],
    );

/// A big provider-style subscription: flag-prefixed names, 150 nodes.
Subscription bigSubscription() {
  const flags = {'CH': '🇨🇭', 'FI': '🇫🇮', 'FR': '🇫🇷', 'GB': '🇬🇧'};
  const names = {'CH': 'Швейцария', 'FI': 'Финляндия', 'FR': 'Франция', 'GB': 'Великобритания'};
  final codes = flags.keys.toList();
  return Subscription(
    id: 'sub2',
    title: 'ALLVPN',
    urlMasked: 'https://ftn.example.net/sub/…f9dbca',
    nodes: [
      for (var i = 0; i < 150; i++)
        Node(
          id: 'b$i',
          name: '${flags[codes[i % 4]]} Provider $i | ${names[codes[i % 4]]}',
          type: 'vless',
          network: i.isEven ? 'grpc' : 'tcp',
          server: 'n$i.example.com',
          port: 443,
        ),
    ],
  );
}
