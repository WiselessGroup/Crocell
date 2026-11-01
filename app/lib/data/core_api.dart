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

  Future<List<Process>> listProcesses();
  Future<GeoInfo> getGeoInfo();
  Future<GeoInfo> updateGeo();
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

/// Where crocelld listens: a unix socket, or on Windows loopback TCP with a
/// token, since Dart has no unix sockets there.
class CoreEndpoint {
  const CoreEndpoint.unix(this.path)
      : host = '',
        port = 0,
        tokenFile = '';
  const CoreEndpoint.tcp(this.host, this.port, this.tokenFile) : path = '';

  final String path;
  final String host;
  final int port;

  /// Holds the token every call must carry. Readable by local users only.
  final String tokenFile;

  bool get isUnix => path.isNotEmpty;
}

/// The service's address here. CROCELL_SOCKET overrides it for development.
/// On Android the core lives in the app and the platform says where.
CoreEndpoint defaultEndpoint() {
  final override = Platform.environment['CROCELL_SOCKET'];
  if (override != null && override.isNotEmpty) return CoreEndpoint.unix(override);
  if (Platform.isMacOS) return const CoreEndpoint.unix('/var/run/crocell/crocelld.sock');
  if (Platform.isWindows) {
    return const CoreEndpoint.tcp('127.0.0.1', 41890, r'C:\ProgramData\Crocell\client-token');
  }
  return const CoreEndpoint.unix('/run/crocell/crocelld.sock');
}

class GrpcCoreApi implements CoreApi {
  GrpcCoreApi(CoreEndpoint endpoint)
      : _channel = ClientChannel(
          endpoint.isUnix ? InternetAddress(endpoint.path, type: InternetAddressType.unix) : endpoint.host,
          port: endpoint.port,
          options: const ChannelOptions(
            credentials: ChannelCredentials.insecure(),
            // The daemon is local: fail fast and let the UI say so.
            connectTimeout: Duration(seconds: 2),
          ),
        ) {
    _client = CoreClient(_channel,
        options: endpoint.isUnix ? null : CallOptions(providers: [_tokenFrom(endpoint.tokenFile)]));
  }

  /// Read on every call: the service writes it on its first start, which
  /// may come after the app has started.
  static MetadataProvider _tokenFrom(String path) => (metadata, _) async {
        try {
          metadata['authorization'] = 'Bearer ${(await File(path).readAsString()).trim()}';
        } on FileSystemException {
          // No service yet: the call fails as unavailable anyway.
        }
      };

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
    // A missing token means the service was never installed here.
    if (e.code == StatusCode.unavailable ||
        e.code == StatusCode.deadlineExceeded ||
        e.code == StatusCode.unauthenticated) {
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

  @override
  Future<List<Process>> listProcesses() async =>
      (await _call(() => _client.listProcesses(ListProcessesRequest()))).processes;

  @override
  Future<GeoInfo> getGeoInfo() => _call(() => _client.getGeoInfo(GetGeoInfoRequest()));

  @override
  Future<GeoInfo> updateGeo() => _call(() => _client.updateGeo(UpdateGeoRequest(),
      // Two databases, ~100 MB from GitHub: give it time.
      options: CallOptions(timeout: const Duration(minutes: 4))));

  Future<void> close() => _channel.shutdown();
}
