// This is a generated file - do not edit.
//
// Generated from crocell/v1/core.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'core.pb.dart' as $0;

export 'core.pb.dart';

@$pb.GrpcServiceName('crocell.v1.Core')
class CoreClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  CoreClient(super.channel, {super.options, super.interceptors});

  /// State
  $grpc.ResponseFuture<$0.Status> getStatus(
    $0.GetStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getStatus, request, options: options);
  }

  $grpc.ResponseStream<$0.Status> watchStatus(
    $0.WatchStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$watchStatus, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Connection
  $grpc.ResponseFuture<$0.Status> connect(
    $0.ConnectRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$connect, request, options: options);
  }

  $grpc.ResponseFuture<$0.Status> disconnect(
    $0.DisconnectRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$disconnect, request, options: options);
  }

  $grpc.ResponseFuture<$0.Status> selectNode(
    $0.SelectNodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$selectNode, request, options: options);
  }

  /// Subscriptions
  $grpc.ResponseFuture<$0.ListSubscriptionsResponse> listSubscriptions(
    $0.ListSubscriptionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listSubscriptions, request, options: options);
  }

  $grpc.ResponseFuture<$0.Subscription> addSubscription(
    $0.AddSubscriptionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$addSubscription, request, options: options);
  }

  $grpc.ResponseFuture<$0.Subscription> refreshSubscription(
    $0.RefreshSubscriptionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$refreshSubscription, request, options: options);
  }

  $grpc.ResponseFuture<$0.RemoveSubscriptionResponse> removeSubscription(
    $0.RemoveSubscriptionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$removeSubscription, request, options: options);
  }

  /// Node quality: entry, exit, latency. Streams results as they come.
  $grpc.ResponseStream<$0.ProbeResult> probeNodes(
    $0.ProbeNodesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$probeNodes, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Settings
  $grpc.ResponseFuture<$0.Settings> getSettings(
    $0.GetSettingsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSettings, request, options: options);
  }

  $grpc.ResponseFuture<$0.Settings> updateSettings(
    $0.Settings request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateSettings, request, options: options);
  }

  /// Running programs, to pick one for a routing rule.
  $grpc.ResponseFuture<$0.ListProcessesResponse> listProcesses(
    $0.ListProcessesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listProcesses, request, options: options);
  }

  /// geoip.dat / geosite.dat: when they were fetched and what is inside.
  $grpc.ResponseFuture<$0.GeoInfo> getGeoInfo(
    $0.GetGeoInfoRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getGeoInfo, request, options: options);
  }

  $grpc.ResponseFuture<$0.GeoInfo> updateGeo(
    $0.UpdateGeoRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateGeo, request, options: options);
  }

  // method descriptors

  static final _$getStatus = $grpc.ClientMethod<$0.GetStatusRequest, $0.Status>(
      '/crocell.v1.Core/GetStatus',
      ($0.GetStatusRequest value) => value.writeToBuffer(),
      $0.Status.fromBuffer);
  static final _$watchStatus =
      $grpc.ClientMethod<$0.WatchStatusRequest, $0.Status>(
          '/crocell.v1.Core/WatchStatus',
          ($0.WatchStatusRequest value) => value.writeToBuffer(),
          $0.Status.fromBuffer);
  static final _$connect = $grpc.ClientMethod<$0.ConnectRequest, $0.Status>(
      '/crocell.v1.Core/Connect',
      ($0.ConnectRequest value) => value.writeToBuffer(),
      $0.Status.fromBuffer);
  static final _$disconnect =
      $grpc.ClientMethod<$0.DisconnectRequest, $0.Status>(
          '/crocell.v1.Core/Disconnect',
          ($0.DisconnectRequest value) => value.writeToBuffer(),
          $0.Status.fromBuffer);
  static final _$selectNode =
      $grpc.ClientMethod<$0.SelectNodeRequest, $0.Status>(
          '/crocell.v1.Core/SelectNode',
          ($0.SelectNodeRequest value) => value.writeToBuffer(),
          $0.Status.fromBuffer);
  static final _$listSubscriptions = $grpc.ClientMethod<
          $0.ListSubscriptionsRequest, $0.ListSubscriptionsResponse>(
      '/crocell.v1.Core/ListSubscriptions',
      ($0.ListSubscriptionsRequest value) => value.writeToBuffer(),
      $0.ListSubscriptionsResponse.fromBuffer);
  static final _$addSubscription =
      $grpc.ClientMethod<$0.AddSubscriptionRequest, $0.Subscription>(
          '/crocell.v1.Core/AddSubscription',
          ($0.AddSubscriptionRequest value) => value.writeToBuffer(),
          $0.Subscription.fromBuffer);
  static final _$refreshSubscription =
      $grpc.ClientMethod<$0.RefreshSubscriptionRequest, $0.Subscription>(
          '/crocell.v1.Core/RefreshSubscription',
          ($0.RefreshSubscriptionRequest value) => value.writeToBuffer(),
          $0.Subscription.fromBuffer);
  static final _$removeSubscription = $grpc.ClientMethod<
          $0.RemoveSubscriptionRequest, $0.RemoveSubscriptionResponse>(
      '/crocell.v1.Core/RemoveSubscription',
      ($0.RemoveSubscriptionRequest value) => value.writeToBuffer(),
      $0.RemoveSubscriptionResponse.fromBuffer);
  static final _$probeNodes =
      $grpc.ClientMethod<$0.ProbeNodesRequest, $0.ProbeResult>(
          '/crocell.v1.Core/ProbeNodes',
          ($0.ProbeNodesRequest value) => value.writeToBuffer(),
          $0.ProbeResult.fromBuffer);
  static final _$getSettings =
      $grpc.ClientMethod<$0.GetSettingsRequest, $0.Settings>(
          '/crocell.v1.Core/GetSettings',
          ($0.GetSettingsRequest value) => value.writeToBuffer(),
          $0.Settings.fromBuffer);
  static final _$updateSettings = $grpc.ClientMethod<$0.Settings, $0.Settings>(
      '/crocell.v1.Core/UpdateSettings',
      ($0.Settings value) => value.writeToBuffer(),
      $0.Settings.fromBuffer);
  static final _$listProcesses =
      $grpc.ClientMethod<$0.ListProcessesRequest, $0.ListProcessesResponse>(
          '/crocell.v1.Core/ListProcesses',
          ($0.ListProcessesRequest value) => value.writeToBuffer(),
          $0.ListProcessesResponse.fromBuffer);
  static final _$getGeoInfo =
      $grpc.ClientMethod<$0.GetGeoInfoRequest, $0.GeoInfo>(
          '/crocell.v1.Core/GetGeoInfo',
          ($0.GetGeoInfoRequest value) => value.writeToBuffer(),
          $0.GeoInfo.fromBuffer);
  static final _$updateGeo =
      $grpc.ClientMethod<$0.UpdateGeoRequest, $0.GeoInfo>(
          '/crocell.v1.Core/UpdateGeo',
          ($0.UpdateGeoRequest value) => value.writeToBuffer(),
          $0.GeoInfo.fromBuffer);
}

@$pb.GrpcServiceName('crocell.v1.Core')
abstract class CoreServiceBase extends $grpc.Service {
  $core.String get $name => 'crocell.v1.Core';

  CoreServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetStatusRequest, $0.Status>(
        'GetStatus',
        getStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetStatusRequest.fromBuffer(value),
        ($0.Status value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.WatchStatusRequest, $0.Status>(
        'WatchStatus',
        watchStatus_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.WatchStatusRequest.fromBuffer(value),
        ($0.Status value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ConnectRequest, $0.Status>(
        'Connect',
        connect_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ConnectRequest.fromBuffer(value),
        ($0.Status value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DisconnectRequest, $0.Status>(
        'Disconnect',
        disconnect_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DisconnectRequest.fromBuffer(value),
        ($0.Status value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SelectNodeRequest, $0.Status>(
        'SelectNode',
        selectNode_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SelectNodeRequest.fromBuffer(value),
        ($0.Status value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListSubscriptionsRequest,
            $0.ListSubscriptionsResponse>(
        'ListSubscriptions',
        listSubscriptions_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListSubscriptionsRequest.fromBuffer(value),
        ($0.ListSubscriptionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AddSubscriptionRequest, $0.Subscription>(
        'AddSubscription',
        addSubscription_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AddSubscriptionRequest.fromBuffer(value),
        ($0.Subscription value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RefreshSubscriptionRequest, $0.Subscription>(
            'RefreshSubscription',
            refreshSubscription_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RefreshSubscriptionRequest.fromBuffer(value),
            ($0.Subscription value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RemoveSubscriptionRequest,
            $0.RemoveSubscriptionResponse>(
        'RemoveSubscription',
        removeSubscription_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RemoveSubscriptionRequest.fromBuffer(value),
        ($0.RemoveSubscriptionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ProbeNodesRequest, $0.ProbeResult>(
        'ProbeNodes',
        probeNodes_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.ProbeNodesRequest.fromBuffer(value),
        ($0.ProbeResult value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetSettingsRequest, $0.Settings>(
        'GetSettings',
        getSettings_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetSettingsRequest.fromBuffer(value),
        ($0.Settings value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Settings, $0.Settings>(
        'UpdateSettings',
        updateSettings_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Settings.fromBuffer(value),
        ($0.Settings value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListProcessesRequest, $0.ListProcessesResponse>(
            'ListProcesses',
            listProcesses_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListProcessesRequest.fromBuffer(value),
            ($0.ListProcessesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetGeoInfoRequest, $0.GeoInfo>(
        'GetGeoInfo',
        getGeoInfo_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetGeoInfoRequest.fromBuffer(value),
        ($0.GeoInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateGeoRequest, $0.GeoInfo>(
        'UpdateGeo',
        updateGeo_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateGeoRequest.fromBuffer(value),
        ($0.GeoInfo value) => value.writeToBuffer()));
  }

  $async.Future<$0.Status> getStatus_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetStatusRequest> $request) async {
    return getStatus($call, await $request);
  }

  $async.Future<$0.Status> getStatus(
      $grpc.ServiceCall call, $0.GetStatusRequest request);

  $async.Stream<$0.Status> watchStatus_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WatchStatusRequest> $request) async* {
    yield* watchStatus($call, await $request);
  }

  $async.Stream<$0.Status> watchStatus(
      $grpc.ServiceCall call, $0.WatchStatusRequest request);

  $async.Future<$0.Status> connect_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ConnectRequest> $request) async {
    return connect($call, await $request);
  }

  $async.Future<$0.Status> connect(
      $grpc.ServiceCall call, $0.ConnectRequest request);

  $async.Future<$0.Status> disconnect_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DisconnectRequest> $request) async {
    return disconnect($call, await $request);
  }

  $async.Future<$0.Status> disconnect(
      $grpc.ServiceCall call, $0.DisconnectRequest request);

  $async.Future<$0.Status> selectNode_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SelectNodeRequest> $request) async {
    return selectNode($call, await $request);
  }

  $async.Future<$0.Status> selectNode(
      $grpc.ServiceCall call, $0.SelectNodeRequest request);

  $async.Future<$0.ListSubscriptionsResponse> listSubscriptions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListSubscriptionsRequest> $request) async {
    return listSubscriptions($call, await $request);
  }

  $async.Future<$0.ListSubscriptionsResponse> listSubscriptions(
      $grpc.ServiceCall call, $0.ListSubscriptionsRequest request);

  $async.Future<$0.Subscription> addSubscription_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AddSubscriptionRequest> $request) async {
    return addSubscription($call, await $request);
  }

  $async.Future<$0.Subscription> addSubscription(
      $grpc.ServiceCall call, $0.AddSubscriptionRequest request);

  $async.Future<$0.Subscription> refreshSubscription_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RefreshSubscriptionRequest> $request) async {
    return refreshSubscription($call, await $request);
  }

  $async.Future<$0.Subscription> refreshSubscription(
      $grpc.ServiceCall call, $0.RefreshSubscriptionRequest request);

  $async.Future<$0.RemoveSubscriptionResponse> removeSubscription_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RemoveSubscriptionRequest> $request) async {
    return removeSubscription($call, await $request);
  }

  $async.Future<$0.RemoveSubscriptionResponse> removeSubscription(
      $grpc.ServiceCall call, $0.RemoveSubscriptionRequest request);

  $async.Stream<$0.ProbeResult> probeNodes_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ProbeNodesRequest> $request) async* {
    yield* probeNodes($call, await $request);
  }

  $async.Stream<$0.ProbeResult> probeNodes(
      $grpc.ServiceCall call, $0.ProbeNodesRequest request);

  $async.Future<$0.Settings> getSettings_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetSettingsRequest> $request) async {
    return getSettings($call, await $request);
  }

  $async.Future<$0.Settings> getSettings(
      $grpc.ServiceCall call, $0.GetSettingsRequest request);

  $async.Future<$0.Settings> updateSettings_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Settings> $request) async {
    return updateSettings($call, await $request);
  }

  $async.Future<$0.Settings> updateSettings(
      $grpc.ServiceCall call, $0.Settings request);

  $async.Future<$0.ListProcessesResponse> listProcesses_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListProcessesRequest> $request) async {
    return listProcesses($call, await $request);
  }

  $async.Future<$0.ListProcessesResponse> listProcesses(
      $grpc.ServiceCall call, $0.ListProcessesRequest request);

  $async.Future<$0.GeoInfo> getGeoInfo_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetGeoInfoRequest> $request) async {
    return getGeoInfo($call, await $request);
  }

  $async.Future<$0.GeoInfo> getGeoInfo(
      $grpc.ServiceCall call, $0.GetGeoInfoRequest request);

  $async.Future<$0.GeoInfo> updateGeo_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateGeoRequest> $request) async {
    return updateGeo($call, await $request);
  }

  $async.Future<$0.GeoInfo> updateGeo(
      $grpc.ServiceCall call, $0.UpdateGeoRequest request);
}
