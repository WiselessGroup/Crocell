import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';

import '../src/proto/crocell/v1/core.pbgrpc.dart';

export '../src/proto/crocell/v1/core.pb.dart';
export '../src/proto/crocell/v1/core.pbenum.dart';

/// What the UI needs from crocelld. The gRPC client implements it; tests use
/// a fake.
abstract interface class CoreApi {
  Stream<Status> watchStatus();
  Future<Status> connect({String subscriptionId = '', String nodeId = ''});
  Future<Status> disconnect();
  Future<Status> selectNode(String subscriptionId, String nodeId);

  Future<List<Subscription>> listSubscriptions();
  Future<Subscription> addSubscription(String url);
  Future<Subscription> refreshSubscription(String id);
  Future<void> removeSubscription(String id);

  Stream<ProbeResult> probeNodes(String subscriptionId, {List<String> nodeIds});

  Future<Settings> getSettings();
  Future<Settings> updateSettings(Settings settings);
}

/// Something went wrong in a way the person can read.
class CoreError implements Exception {
  const CoreError(this.message, {this.unavailable = false});

  final String message;

  /// The service is not running or not reachable at all.
  final bool unavailable;

  @override
  String toString() => message;
}

/// Where crocelld listens. CROCELL_SOCKET overrides it for development.
String defaultSocketPath() {
  final override = Platform.environment['CROCELL_SOCKET'];
  if (override != null && override.isNotEmpty) return override;
  if (Platform.isMacOS) return '/var/run/crocell/crocelld.sock';
  if (Platform.isWindows) return r'C:\ProgramData\Crocell\crocelld.sock';
  return '/run/crocell/crocelld.sock';
}

class GrpcCoreApi implements CoreApi {
  GrpcCoreApi(String socketPath)
      : _channel = ClientChannel(
          InternetAddress(socketPath, type: InternetAddressType.unix),
          port: 0,
          options: const ChannelOptions(
            credentials: ChannelCredentials.insecure(),
            // The daemon is local: fail fast and let the UI say so.
            connectTimeout: Duration(seconds: 2),
          ),
        ) {
    _client = CoreClient(_channel);
  }

  final ClientChannel _channel;
  late final CoreClient _client;

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on GrpcError catch (e) {
      throw _map(e);
    }
  }

  Stream<T> _stream<T>(Stream<T> Function() f) {
    return f().handleError((Object e) => throw _map(e as GrpcError),
        test: (e) => e is GrpcError);
  }

  static CoreError _map(GrpcError e) {
    if (e.code == StatusCode.unavailable || e.code == StatusCode.deadlineExceeded) {
      return const CoreError('Служба Crocell не отвечает', unavailable: true);
    }
    return CoreError(e.message ?? e.codeName);
  }

  @override
  Stream<Status> watchStatus() => _stream(() => _client.watchStatus(WatchStatusRequest()));

  @override
  Future<Status> connect({String subscriptionId = '', String nodeId = ''}) =>
      _call(() => _client.connect(ConnectRequest(subscriptionId: subscriptionId, nodeId: nodeId)));

  @override
  Future<Status> disconnect() => _call(() => _client.disconnect(DisconnectRequest()));

  @override
  Future<Status> selectNode(String subscriptionId, String nodeId) => _call(() =>
      _client.selectNode(SelectNodeRequest(subscriptionId: subscriptionId, nodeId: nodeId)));

  @override
  Future<List<Subscription>> listSubscriptions() async =>
      (await _call(() => _client.listSubscriptions(ListSubscriptionsRequest()))).subscriptions;

  @override
  Future<Subscription> addSubscription(String url) =>
      _call(() => _client.addSubscription(AddSubscriptionRequest(url: url)));

  @override
  Future<Subscription> refreshSubscription(String id) =>
      _call(() => _client.refreshSubscription(RefreshSubscriptionRequest(id: id)));

  @override
  Future<void> removeSubscription(String id) =>
      _call(() => _client.removeSubscription(RemoveSubscriptionRequest(id: id)));

  @override
  Stream<ProbeResult> probeNodes(String subscriptionId, {List<String> nodeIds = const []}) =>
      _stream(() => _client.probeNodes(ProbeNodesRequest(subscriptionId: subscriptionId, nodeIds: nodeIds)));

  @override
  Future<Settings> getSettings() => _call(() => _client.getSettings(GetSettingsRequest()));

  @override
  Future<Settings> updateSettings(Settings settings) => _call(() => _client.updateSettings(settings));

  Future<void> close() => _channel.shutdown();
}
