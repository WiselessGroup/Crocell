// This is a generated file - do not edit.
//
// Generated from crocell/v1/core.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $1;

import 'core.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'core.pbenum.dart';

class Status extends $pb.GeneratedMessage {
  factory Status({
    ConnectionState? state,
    $core.String? subscriptionId,
    $core.String? nodeId,
    $1.Timestamp? connectedSince,
    Traffic? traffic,
    $core.String? error,
    TunnelMode? tunnelMode,
    $core.int? mixedPort,
  }) {
    final result = Status._();
    if (state != null) result.state = state;
    if (subscriptionId != null) result.subscriptionId = subscriptionId;
    if (nodeId != null) result.nodeId = nodeId;
    if (connectedSince != null) result.connectedSince = connectedSince;
    if (traffic != null) result.traffic = traffic;
    if (error != null) result.error = error;
    if (tunnelMode != null) result.tunnelMode = tunnelMode;
    if (mixedPort != null) result.mixedPort = mixedPort;
    return result;
  }

  Status._();

  factory Status.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Status()..mergeFromBuffer(data, registry);
  factory Status.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Status()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Status',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: Status.$_createMessage)
    ..aE<ConnectionState>(1, _omitFieldNames ? '' : 'state',
        enumValues: ConnectionState.values)
    ..aOS(2, _omitFieldNames ? '' : 'subscriptionId')
    ..aOS(3, _omitFieldNames ? '' : 'nodeId')
    ..aOM<$1.Timestamp>(4, _omitFieldNames ? '' : 'connectedSince',
        subBuilder: $1.Timestamp.$_createMessage)
    ..aOM<Traffic>(5, _omitFieldNames ? '' : 'traffic',
        subBuilder: Traffic.$_createMessage)
    ..aOS(6, _omitFieldNames ? '' : 'error')
    ..aE<TunnelMode>(7, _omitFieldNames ? '' : 'tunnelMode',
        enumValues: TunnelMode.values)
    ..aI(8, _omitFieldNames ? '' : 'mixedPort', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Status clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Status copyWith(void Function(Status) updates) =>
      super.copyWith((message) => updates(message as Status)) as Status;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Status() / Status.new instead')
  static Status create() => Status._();
  static $pb.GeneratedMessage $_createMessage() => Status._();
  @$core.override
  Status createEmptyInstance() => Status._();
  @$core.pragma('dart2js:noInline')
  static Status getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Status>(Status.$_createMessage);
  static Status? _defaultInstance;

  @$pb.TagNumber(1)
  ConnectionState get state => $_getN(0);
  @$pb.TagNumber(1)
  set state(ConnectionState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasState() => $_has(0);
  @$pb.TagNumber(1)
  void clearState() => $_clearField(1);

  /// While disconnected: the node Connect would resume.
  @$pb.TagNumber(2)
  $core.String get subscriptionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set subscriptionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubscriptionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubscriptionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get nodeId => $_getSZ(2);
  @$pb.TagNumber(3)
  set nodeId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNodeId() => $_has(2);
  @$pb.TagNumber(3)
  void clearNodeId() => $_clearField(3);

  @$pb.TagNumber(4)
  $1.Timestamp get connectedSince => $_getN(3);
  @$pb.TagNumber(4)
  set connectedSince($1.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasConnectedSince() => $_has(3);
  @$pb.TagNumber(4)
  void clearConnectedSince() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.Timestamp ensureConnectedSince() => $_ensure(3);

  @$pb.TagNumber(5)
  Traffic get traffic => $_getN(4);
  @$pb.TagNumber(5)
  set traffic(Traffic value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasTraffic() => $_has(4);
  @$pb.TagNumber(5)
  void clearTraffic() => $_clearField(5);
  @$pb.TagNumber(5)
  Traffic ensureTraffic() => $_ensure(4);

  /// Human-readable reason when state is FAILED. Never contains secrets.
  @$pb.TagNumber(6)
  $core.String get error => $_getSZ(5);
  @$pb.TagNumber(6)
  set error($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasError() => $_has(5);
  @$pb.TagNumber(6)
  void clearError() => $_clearField(6);

  @$pb.TagNumber(7)
  TunnelMode get tunnelMode => $_getN(6);
  @$pb.TagNumber(7)
  set tunnelMode(TunnelMode value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasTunnelMode() => $_has(6);
  @$pb.TagNumber(7)
  void clearTunnelMode() => $_clearField(7);

  /// HTTP+SOCKS on 127.0.0.1 while connected, for the client to put into
  /// the system proxy settings (that has to happen as the user, not root).
  @$pb.TagNumber(8)
  $core.int get mixedPort => $_getIZ(7);
  @$pb.TagNumber(8)
  set mixedPort($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMixedPort() => $_has(7);
  @$pb.TagNumber(8)
  void clearMixedPort() => $_clearField(8);
}

class Traffic extends $pb.GeneratedMessage {
  factory Traffic({
    $fixnum.Int64? upBytes,
    $fixnum.Int64? downBytes,
    $fixnum.Int64? upRate,
    $fixnum.Int64? downRate,
  }) {
    final result = Traffic._();
    if (upBytes != null) result.upBytes = upBytes;
    if (downBytes != null) result.downBytes = downBytes;
    if (upRate != null) result.upRate = upRate;
    if (downRate != null) result.downRate = downRate;
    return result;
  }

  Traffic._();

  factory Traffic.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Traffic()..mergeFromBuffer(data, registry);
  factory Traffic.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Traffic()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Traffic',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: Traffic.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'upBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'downBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'upRate', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'downRate', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Traffic clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Traffic copyWith(void Function(Traffic) updates) =>
      super.copyWith((message) => updates(message as Traffic)) as Traffic;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Traffic() / Traffic.new instead')
  static Traffic create() => Traffic._();
  static $pb.GeneratedMessage $_createMessage() => Traffic._();
  @$core.override
  Traffic createEmptyInstance() => Traffic._();
  @$core.pragma('dart2js:noInline')
  static Traffic getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Traffic>(Traffic.$_createMessage);
  static Traffic? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get upBytes => $_getI64(0);
  @$pb.TagNumber(1)
  set upBytes($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUpBytes() => $_has(0);
  @$pb.TagNumber(1)
  void clearUpBytes() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get downBytes => $_getI64(1);
  @$pb.TagNumber(2)
  set downBytes($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDownBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearDownBytes() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get upRate => $_getI64(2);
  @$pb.TagNumber(3)
  set upRate($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUpRate() => $_has(2);
  @$pb.TagNumber(3)
  void clearUpRate() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get downRate => $_getI64(3);
  @$pb.TagNumber(4)
  set downRate($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDownRate() => $_has(3);
  @$pb.TagNumber(4)
  void clearDownRate() => $_clearField(4);
}

class GetStatusRequest extends $pb.GeneratedMessage {
  factory GetStatusRequest() => GetStatusRequest._();

  GetStatusRequest._();

  factory GetStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetStatusRequest()..mergeFromBuffer(data, registry);
  factory GetStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetStatusRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: GetStatusRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatusRequest copyWith(void Function(GetStatusRequest) updates) =>
      super.copyWith((message) => updates(message as GetStatusRequest))
          as GetStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetStatusRequest() / GetStatusRequest.new instead')
  static GetStatusRequest create() => GetStatusRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetStatusRequest._();
  @$core.override
  GetStatusRequest createEmptyInstance() => GetStatusRequest._();
  @$core.pragma('dart2js:noInline')
  static GetStatusRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetStatusRequest>(
          GetStatusRequest.$_createMessage);
  static GetStatusRequest? _defaultInstance;
}

class WatchStatusRequest extends $pb.GeneratedMessage {
  factory WatchStatusRequest() => WatchStatusRequest._();

  WatchStatusRequest._();

  factory WatchStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchStatusRequest()..mergeFromBuffer(data, registry);
  factory WatchStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchStatusRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: WatchStatusRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchStatusRequest copyWith(void Function(WatchStatusRequest) updates) =>
      super.copyWith((message) => updates(message as WatchStatusRequest))
          as WatchStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WatchStatusRequest() / WatchStatusRequest.new instead')
  static WatchStatusRequest create() => WatchStatusRequest._();
  static $pb.GeneratedMessage $_createMessage() => WatchStatusRequest._();
  @$core.override
  WatchStatusRequest createEmptyInstance() => WatchStatusRequest._();
  @$core.pragma('dart2js:noInline')
  static WatchStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WatchStatusRequest>(
          WatchStatusRequest.$_createMessage);
  static WatchStatusRequest? _defaultInstance;
}

class ConnectRequest extends $pb.GeneratedMessage {
  factory ConnectRequest({
    $core.String? subscriptionId,
    $core.String? nodeId,
  }) {
    final result = ConnectRequest._();
    if (subscriptionId != null) result.subscriptionId = subscriptionId;
    if (nodeId != null) result.nodeId = nodeId;
    return result;
  }

  ConnectRequest._();

  factory ConnectRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConnectRequest()..mergeFromBuffer(data, registry);
  factory ConnectRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConnectRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: ConnectRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'subscriptionId')
    ..aOS(2, _omitFieldNames ? '' : 'nodeId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectRequest copyWith(void Function(ConnectRequest) updates) =>
      super.copyWith((message) => updates(message as ConnectRequest))
          as ConnectRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ConnectRequest() / ConnectRequest.new instead')
  static ConnectRequest create() => ConnectRequest._();
  static $pb.GeneratedMessage $_createMessage() => ConnectRequest._();
  @$core.override
  ConnectRequest createEmptyInstance() => ConnectRequest._();
  @$core.pragma('dart2js:noInline')
  static ConnectRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ConnectRequest>(
          ConnectRequest.$_createMessage);
  static ConnectRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get subscriptionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set subscriptionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSubscriptionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSubscriptionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get nodeId => $_getSZ(1);
  @$pb.TagNumber(2)
  set nodeId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNodeId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNodeId() => $_clearField(2);
}

class DisconnectRequest extends $pb.GeneratedMessage {
  factory DisconnectRequest() => DisconnectRequest._();

  DisconnectRequest._();

  factory DisconnectRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DisconnectRequest()..mergeFromBuffer(data, registry);
  factory DisconnectRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DisconnectRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DisconnectRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: DisconnectRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DisconnectRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DisconnectRequest copyWith(void Function(DisconnectRequest) updates) =>
      super.copyWith((message) => updates(message as DisconnectRequest))
          as DisconnectRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DisconnectRequest() / DisconnectRequest.new instead')
  static DisconnectRequest create() => DisconnectRequest._();
  static $pb.GeneratedMessage $_createMessage() => DisconnectRequest._();
  @$core.override
  DisconnectRequest createEmptyInstance() => DisconnectRequest._();
  @$core.pragma('dart2js:noInline')
  static DisconnectRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DisconnectRequest>(
          DisconnectRequest.$_createMessage);
  static DisconnectRequest? _defaultInstance;
}

class SelectNodeRequest extends $pb.GeneratedMessage {
  factory SelectNodeRequest({
    $core.String? subscriptionId,
    $core.String? nodeId,
  }) {
    final result = SelectNodeRequest._();
    if (subscriptionId != null) result.subscriptionId = subscriptionId;
    if (nodeId != null) result.nodeId = nodeId;
    return result;
  }

  SelectNodeRequest._();

  factory SelectNodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SelectNodeRequest()..mergeFromBuffer(data, registry);
  factory SelectNodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SelectNodeRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SelectNodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: SelectNodeRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'subscriptionId')
    ..aOS(2, _omitFieldNames ? '' : 'nodeId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectNodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectNodeRequest copyWith(void Function(SelectNodeRequest) updates) =>
      super.copyWith((message) => updates(message as SelectNodeRequest))
          as SelectNodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SelectNodeRequest() / SelectNodeRequest.new instead')
  static SelectNodeRequest create() => SelectNodeRequest._();
  static $pb.GeneratedMessage $_createMessage() => SelectNodeRequest._();
  @$core.override
  SelectNodeRequest createEmptyInstance() => SelectNodeRequest._();
  @$core.pragma('dart2js:noInline')
  static SelectNodeRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SelectNodeRequest>(
          SelectNodeRequest.$_createMessage);
  static SelectNodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get subscriptionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set subscriptionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSubscriptionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSubscriptionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get nodeId => $_getSZ(1);
  @$pb.TagNumber(2)
  set nodeId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNodeId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNodeId() => $_clearField(2);
}

class Subscription extends $pb.GeneratedMessage {
  factory Subscription({
    $core.String? id,
    $core.String? title,
    $core.String? urlMasked,
    $core.String? format,
    $fixnum.Int64? uploadBytes,
    $fixnum.Int64? downloadBytes,
    $fixnum.Int64? totalBytes,
    $1.Timestamp? expire,
    $core.int? updateIntervalHours,
    $core.String? webPage,
    $core.String? support,
    $core.String? announce,
    $1.Timestamp? fetchedAt,
    $core.Iterable<Node>? nodes,
  }) {
    final result = Subscription._();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (urlMasked != null) result.urlMasked = urlMasked;
    if (format != null) result.format = format;
    if (uploadBytes != null) result.uploadBytes = uploadBytes;
    if (downloadBytes != null) result.downloadBytes = downloadBytes;
    if (totalBytes != null) result.totalBytes = totalBytes;
    if (expire != null) result.expire = expire;
    if (updateIntervalHours != null)
      result.updateIntervalHours = updateIntervalHours;
    if (webPage != null) result.webPage = webPage;
    if (support != null) result.support = support;
    if (announce != null) result.announce = announce;
    if (fetchedAt != null) result.fetchedAt = fetchedAt;
    if (nodes != null) result.nodes.addAll(nodes);
    return result;
  }

  Subscription._();

  factory Subscription.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Subscription()..mergeFromBuffer(data, registry);
  factory Subscription.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Subscription()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Subscription',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: Subscription.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'urlMasked')
    ..aOS(4, _omitFieldNames ? '' : 'format')
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'uploadBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'downloadBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'totalBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<$1.Timestamp>(8, _omitFieldNames ? '' : 'expire',
        subBuilder: $1.Timestamp.$_createMessage)
    ..aI(9, _omitFieldNames ? '' : 'updateIntervalHours',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(10, _omitFieldNames ? '' : 'webPage')
    ..aOS(11, _omitFieldNames ? '' : 'support')
    ..aOS(12, _omitFieldNames ? '' : 'announce')
    ..aOM<$1.Timestamp>(13, _omitFieldNames ? '' : 'fetchedAt',
        subBuilder: $1.Timestamp.$_createMessage)
    ..pPM<Node>(14, _omitFieldNames ? '' : 'nodes',
        subBuilder: Node.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscription clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscription copyWith(void Function(Subscription) updates) =>
      super.copyWith((message) => updates(message as Subscription))
          as Subscription;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Subscription() / Subscription.new instead')
  static Subscription create() => Subscription._();
  static $pb.GeneratedMessage $_createMessage() => Subscription._();
  @$core.override
  Subscription createEmptyInstance() => Subscription._();
  @$core.pragma('dart2js:noInline')
  static Subscription getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Subscription>(
          Subscription.$_createMessage);
  static Subscription? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// The link itself is a secret: the core keeps it, the client gets a
  /// masked version for display.
  @$pb.TagNumber(3)
  $core.String get urlMasked => $_getSZ(2);
  @$pb.TagNumber(3)
  set urlMasked($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUrlMasked() => $_has(2);
  @$pb.TagNumber(3)
  void clearUrlMasked() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get format => $_getSZ(3);
  @$pb.TagNumber(4)
  set format($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFormat() => $_has(3);
  @$pb.TagNumber(4)
  void clearFormat() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get uploadBytes => $_getI64(4);
  @$pb.TagNumber(5)
  set uploadBytes($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUploadBytes() => $_has(4);
  @$pb.TagNumber(5)
  void clearUploadBytes() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get downloadBytes => $_getI64(5);
  @$pb.TagNumber(6)
  set downloadBytes($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDownloadBytes() => $_has(5);
  @$pb.TagNumber(6)
  void clearDownloadBytes() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get totalBytes => $_getI64(6);
  @$pb.TagNumber(7)
  set totalBytes($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTotalBytes() => $_has(6);
  @$pb.TagNumber(7)
  void clearTotalBytes() => $_clearField(7);

  @$pb.TagNumber(8)
  $1.Timestamp get expire => $_getN(7);
  @$pb.TagNumber(8)
  set expire($1.Timestamp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasExpire() => $_has(7);
  @$pb.TagNumber(8)
  void clearExpire() => $_clearField(8);
  @$pb.TagNumber(8)
  $1.Timestamp ensureExpire() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.int get updateIntervalHours => $_getIZ(8);
  @$pb.TagNumber(9)
  set updateIntervalHours($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUpdateIntervalHours() => $_has(8);
  @$pb.TagNumber(9)
  void clearUpdateIntervalHours() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get webPage => $_getSZ(9);
  @$pb.TagNumber(10)
  set webPage($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasWebPage() => $_has(9);
  @$pb.TagNumber(10)
  void clearWebPage() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get support => $_getSZ(10);
  @$pb.TagNumber(11)
  set support($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSupport() => $_has(10);
  @$pb.TagNumber(11)
  void clearSupport() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get announce => $_getSZ(11);
  @$pb.TagNumber(12)
  set announce($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasAnnounce() => $_has(11);
  @$pb.TagNumber(12)
  void clearAnnounce() => $_clearField(12);

  @$pb.TagNumber(13)
  $1.Timestamp get fetchedAt => $_getN(12);
  @$pb.TagNumber(13)
  set fetchedAt($1.Timestamp value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasFetchedAt() => $_has(12);
  @$pb.TagNumber(13)
  void clearFetchedAt() => $_clearField(13);
  @$pb.TagNumber(13)
  $1.Timestamp ensureFetchedAt() => $_ensure(12);

  @$pb.TagNumber(14)
  $pb.PbList<Node> get nodes => $_getList(13);
}

class Node extends $pb.GeneratedMessage {
  factory Node({
    $core.String? id,
    $core.String? name,
    $core.String? type,
    $core.String? network,
    $core.String? server,
    $core.int? port,
    ProbeResult? lastProbe,
  }) {
    final result = Node._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (type != null) result.type = type;
    if (network != null) result.network = network;
    if (server != null) result.server = server;
    if (port != null) result.port = port;
    if (lastProbe != null) result.lastProbe = lastProbe;
    return result;
  }

  Node._();

  factory Node.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Node()..mergeFromBuffer(data, registry);
  factory Node.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Node()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Node',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: Node.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..aOS(4, _omitFieldNames ? '' : 'network')
    ..aOS(5, _omitFieldNames ? '' : 'server')
    ..aI(6, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aOM<ProbeResult>(7, _omitFieldNames ? '' : 'lastProbe',
        subBuilder: ProbeResult.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Node clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Node copyWith(void Function(Node) updates) =>
      super.copyWith((message) => updates(message as Node)) as Node;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Node() / Node.new instead')
  static Node create() => Node._();
  static $pb.GeneratedMessage $_createMessage() => Node._();
  @$core.override
  Node createEmptyInstance() => Node._();
  @$core.pragma('dart2js:noInline')
  static Node getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Node>(Node.$_createMessage);
  static Node? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get type => $_getSZ(2);
  @$pb.TagNumber(3)
  set type($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get network => $_getSZ(3);
  @$pb.TagNumber(4)
  set network($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNetwork() => $_has(3);
  @$pb.TagNumber(4)
  void clearNetwork() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get server => $_getSZ(4);
  @$pb.TagNumber(5)
  set server($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasServer() => $_has(4);
  @$pb.TagNumber(5)
  void clearServer() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get port => $_getIZ(5);
  @$pb.TagNumber(6)
  set port($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPort() => $_has(5);
  @$pb.TagNumber(6)
  void clearPort() => $_clearField(6);

  @$pb.TagNumber(7)
  ProbeResult get lastProbe => $_getN(6);
  @$pb.TagNumber(7)
  set lastProbe(ProbeResult value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasLastProbe() => $_has(6);
  @$pb.TagNumber(7)
  void clearLastProbe() => $_clearField(7);
  @$pb.TagNumber(7)
  ProbeResult ensureLastProbe() => $_ensure(6);
}

class ListSubscriptionsRequest extends $pb.GeneratedMessage {
  factory ListSubscriptionsRequest() => ListSubscriptionsRequest._();

  ListSubscriptionsRequest._();

  factory ListSubscriptionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSubscriptionsRequest()..mergeFromBuffer(data, registry);
  factory ListSubscriptionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSubscriptionsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSubscriptionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: ListSubscriptionsRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSubscriptionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSubscriptionsRequest copyWith(
          void Function(ListSubscriptionsRequest) updates) =>
      super.copyWith((message) => updates(message as ListSubscriptionsRequest))
          as ListSubscriptionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListSubscriptionsRequest() / ListSubscriptionsRequest.new instead')
  static ListSubscriptionsRequest create() => ListSubscriptionsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListSubscriptionsRequest._();
  @$core.override
  ListSubscriptionsRequest createEmptyInstance() =>
      ListSubscriptionsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListSubscriptionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSubscriptionsRequest>(
          ListSubscriptionsRequest.$_createMessage);
  static ListSubscriptionsRequest? _defaultInstance;
}

class ListSubscriptionsResponse extends $pb.GeneratedMessage {
  factory ListSubscriptionsResponse({
    $core.Iterable<Subscription>? subscriptions,
  }) {
    final result = ListSubscriptionsResponse._();
    if (subscriptions != null) result.subscriptions.addAll(subscriptions);
    return result;
  }

  ListSubscriptionsResponse._();

  factory ListSubscriptionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSubscriptionsResponse()..mergeFromBuffer(data, registry);
  factory ListSubscriptionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSubscriptionsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSubscriptionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: ListSubscriptionsResponse.$_createMessage)
    ..pPM<Subscription>(1, _omitFieldNames ? '' : 'subscriptions',
        subBuilder: Subscription.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSubscriptionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSubscriptionsResponse copyWith(
          void Function(ListSubscriptionsResponse) updates) =>
      super.copyWith((message) => updates(message as ListSubscriptionsResponse))
          as ListSubscriptionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListSubscriptionsResponse() / ListSubscriptionsResponse.new instead')
  static ListSubscriptionsResponse create() => ListSubscriptionsResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      ListSubscriptionsResponse._();
  @$core.override
  ListSubscriptionsResponse createEmptyInstance() =>
      ListSubscriptionsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListSubscriptionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSubscriptionsResponse>(
          ListSubscriptionsResponse.$_createMessage);
  static ListSubscriptionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Subscription> get subscriptions => $_getList(0);
}

class AddSubscriptionRequest extends $pb.GeneratedMessage {
  factory AddSubscriptionRequest({
    $core.String? url,
  }) {
    final result = AddSubscriptionRequest._();
    if (url != null) result.url = url;
    return result;
  }

  AddSubscriptionRequest._();

  factory AddSubscriptionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddSubscriptionRequest()..mergeFromBuffer(data, registry);
  factory AddSubscriptionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddSubscriptionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddSubscriptionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: AddSubscriptionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddSubscriptionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddSubscriptionRequest copyWith(
          void Function(AddSubscriptionRequest) updates) =>
      super.copyWith((message) => updates(message as AddSubscriptionRequest))
          as AddSubscriptionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AddSubscriptionRequest() / AddSubscriptionRequest.new instead')
  static AddSubscriptionRequest create() => AddSubscriptionRequest._();
  static $pb.GeneratedMessage $_createMessage() => AddSubscriptionRequest._();
  @$core.override
  AddSubscriptionRequest createEmptyInstance() => AddSubscriptionRequest._();
  @$core.pragma('dart2js:noInline')
  static AddSubscriptionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddSubscriptionRequest>(
          AddSubscriptionRequest.$_createMessage);
  static AddSubscriptionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);
}

class RefreshSubscriptionRequest extends $pb.GeneratedMessage {
  factory RefreshSubscriptionRequest({
    $core.String? id,
  }) {
    final result = RefreshSubscriptionRequest._();
    if (id != null) result.id = id;
    return result;
  }

  RefreshSubscriptionRequest._();

  factory RefreshSubscriptionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RefreshSubscriptionRequest()..mergeFromBuffer(data, registry);
  factory RefreshSubscriptionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RefreshSubscriptionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefreshSubscriptionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: RefreshSubscriptionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshSubscriptionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshSubscriptionRequest copyWith(
          void Function(RefreshSubscriptionRequest) updates) =>
      super.copyWith(
              (message) => updates(message as RefreshSubscriptionRequest))
          as RefreshSubscriptionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RefreshSubscriptionRequest() / RefreshSubscriptionRequest.new instead')
  static RefreshSubscriptionRequest create() => RefreshSubscriptionRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      RefreshSubscriptionRequest._();
  @$core.override
  RefreshSubscriptionRequest createEmptyInstance() =>
      RefreshSubscriptionRequest._();
  @$core.pragma('dart2js:noInline')
  static RefreshSubscriptionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefreshSubscriptionRequest>(
          RefreshSubscriptionRequest.$_createMessage);
  static RefreshSubscriptionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class RemoveSubscriptionRequest extends $pb.GeneratedMessage {
  factory RemoveSubscriptionRequest({
    $core.String? id,
  }) {
    final result = RemoveSubscriptionRequest._();
    if (id != null) result.id = id;
    return result;
  }

  RemoveSubscriptionRequest._();

  factory RemoveSubscriptionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveSubscriptionRequest()..mergeFromBuffer(data, registry);
  factory RemoveSubscriptionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveSubscriptionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveSubscriptionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: RemoveSubscriptionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveSubscriptionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveSubscriptionRequest copyWith(
          void Function(RemoveSubscriptionRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveSubscriptionRequest))
          as RemoveSubscriptionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveSubscriptionRequest() / RemoveSubscriptionRequest.new instead')
  static RemoveSubscriptionRequest create() => RemoveSubscriptionRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      RemoveSubscriptionRequest._();
  @$core.override
  RemoveSubscriptionRequest createEmptyInstance() =>
      RemoveSubscriptionRequest._();
  @$core.pragma('dart2js:noInline')
  static RemoveSubscriptionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveSubscriptionRequest>(
          RemoveSubscriptionRequest.$_createMessage);
  static RemoveSubscriptionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class RemoveSubscriptionResponse extends $pb.GeneratedMessage {
  factory RemoveSubscriptionResponse() => RemoveSubscriptionResponse._();

  RemoveSubscriptionResponse._();

  factory RemoveSubscriptionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveSubscriptionResponse()..mergeFromBuffer(data, registry);
  factory RemoveSubscriptionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveSubscriptionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveSubscriptionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: RemoveSubscriptionResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveSubscriptionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveSubscriptionResponse copyWith(
          void Function(RemoveSubscriptionResponse) updates) =>
      super.copyWith(
              (message) => updates(message as RemoveSubscriptionResponse))
          as RemoveSubscriptionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveSubscriptionResponse() / RemoveSubscriptionResponse.new instead')
  static RemoveSubscriptionResponse create() => RemoveSubscriptionResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      RemoveSubscriptionResponse._();
  @$core.override
  RemoveSubscriptionResponse createEmptyInstance() =>
      RemoveSubscriptionResponse._();
  @$core.pragma('dart2js:noInline')
  static RemoveSubscriptionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveSubscriptionResponse>(
          RemoveSubscriptionResponse.$_createMessage);
  static RemoveSubscriptionResponse? _defaultInstance;
}

class ProbeNodesRequest extends $pb.GeneratedMessage {
  factory ProbeNodesRequest({
    $core.String? subscriptionId,
    $core.Iterable<$core.String>? nodeIds,
  }) {
    final result = ProbeNodesRequest._();
    if (subscriptionId != null) result.subscriptionId = subscriptionId;
    if (nodeIds != null) result.nodeIds.addAll(nodeIds);
    return result;
  }

  ProbeNodesRequest._();

  factory ProbeNodesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProbeNodesRequest()..mergeFromBuffer(data, registry);
  factory ProbeNodesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProbeNodesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProbeNodesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: ProbeNodesRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'subscriptionId')
    ..pPS(2, _omitFieldNames ? '' : 'nodeIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProbeNodesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProbeNodesRequest copyWith(void Function(ProbeNodesRequest) updates) =>
      super.copyWith((message) => updates(message as ProbeNodesRequest))
          as ProbeNodesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ProbeNodesRequest() / ProbeNodesRequest.new instead')
  static ProbeNodesRequest create() => ProbeNodesRequest._();
  static $pb.GeneratedMessage $_createMessage() => ProbeNodesRequest._();
  @$core.override
  ProbeNodesRequest createEmptyInstance() => ProbeNodesRequest._();
  @$core.pragma('dart2js:noInline')
  static ProbeNodesRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProbeNodesRequest>(
          ProbeNodesRequest.$_createMessage);
  static ProbeNodesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get subscriptionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set subscriptionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSubscriptionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSubscriptionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get nodeIds => $_getList(1);
}

class ProbeResult extends $pb.GeneratedMessage {
  factory ProbeResult({
    $core.String? nodeId,
    $core.Iterable<$core.String>? entryIps,
    $core.String? entryCountry,
    $core.String? exitIp,
    $core.String? exitCountry,
    $core.String? exitColo,
    $core.int? latencyMs,
    $core.String? error,
    $1.Timestamp? probedAt,
  }) {
    final result = ProbeResult._();
    if (nodeId != null) result.nodeId = nodeId;
    if (entryIps != null) result.entryIps.addAll(entryIps);
    if (entryCountry != null) result.entryCountry = entryCountry;
    if (exitIp != null) result.exitIp = exitIp;
    if (exitCountry != null) result.exitCountry = exitCountry;
    if (exitColo != null) result.exitColo = exitColo;
    if (latencyMs != null) result.latencyMs = latencyMs;
    if (error != null) result.error = error;
    if (probedAt != null) result.probedAt = probedAt;
    return result;
  }

  ProbeResult._();

  factory ProbeResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProbeResult()..mergeFromBuffer(data, registry);
  factory ProbeResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProbeResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProbeResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: ProbeResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'nodeId')
    ..pPS(2, _omitFieldNames ? '' : 'entryIps')
    ..aOS(3, _omitFieldNames ? '' : 'entryCountry')
    ..aOS(4, _omitFieldNames ? '' : 'exitIp')
    ..aOS(5, _omitFieldNames ? '' : 'exitCountry')
    ..aOS(6, _omitFieldNames ? '' : 'exitColo')
    ..aI(7, _omitFieldNames ? '' : 'latencyMs', fieldType: $pb.PbFieldType.OU3)
    ..aOS(8, _omitFieldNames ? '' : 'error')
    ..aOM<$1.Timestamp>(9, _omitFieldNames ? '' : 'probedAt',
        subBuilder: $1.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProbeResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProbeResult copyWith(void Function(ProbeResult) updates) =>
      super.copyWith((message) => updates(message as ProbeResult))
          as ProbeResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ProbeResult() / ProbeResult.new instead')
  static ProbeResult create() => ProbeResult._();
  static $pb.GeneratedMessage $_createMessage() => ProbeResult._();
  @$core.override
  ProbeResult createEmptyInstance() => ProbeResult._();
  @$core.pragma('dart2js:noInline')
  static ProbeResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProbeResult>(
          ProbeResult.$_createMessage);
  static ProbeResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get nodeId => $_getSZ(0);
  @$pb.TagNumber(1)
  set nodeId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get entryIps => $_getList(1);

  @$pb.TagNumber(3)
  $core.String get entryCountry => $_getSZ(2);
  @$pb.TagNumber(3)
  set entryCountry($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEntryCountry() => $_has(2);
  @$pb.TagNumber(3)
  void clearEntryCountry() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get exitIp => $_getSZ(3);
  @$pb.TagNumber(4)
  set exitIp($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExitIp() => $_has(3);
  @$pb.TagNumber(4)
  void clearExitIp() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get exitCountry => $_getSZ(4);
  @$pb.TagNumber(5)
  set exitCountry($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExitCountry() => $_has(4);
  @$pb.TagNumber(5)
  void clearExitCountry() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get exitColo => $_getSZ(5);
  @$pb.TagNumber(6)
  set exitColo($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasExitColo() => $_has(5);
  @$pb.TagNumber(6)
  void clearExitColo() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get latencyMs => $_getIZ(6);
  @$pb.TagNumber(7)
  set latencyMs($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLatencyMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearLatencyMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get error => $_getSZ(7);
  @$pb.TagNumber(8)
  set error($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasError() => $_has(7);
  @$pb.TagNumber(8)
  void clearError() => $_clearField(8);

  @$pb.TagNumber(9)
  $1.Timestamp get probedAt => $_getN(8);
  @$pb.TagNumber(9)
  set probedAt($1.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasProbedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearProbedAt() => $_clearField(9);
  @$pb.TagNumber(9)
  $1.Timestamp ensureProbedAt() => $_ensure(8);
}

class AppRule extends $pb.GeneratedMessage {
  factory AppRule({
    $core.String? app,
    AppMode? mode,
  }) {
    final result = AppRule._();
    if (app != null) result.app = app;
    if (mode != null) result.mode = mode;
    return result;
  }

  AppRule._();

  factory AppRule.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AppRule()..mergeFromBuffer(data, registry);
  factory AppRule.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AppRule()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AppRule',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: AppRule.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'app')
    ..aE<AppMode>(2, _omitFieldNames ? '' : 'mode', enumValues: AppMode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppRule clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppRule copyWith(void Function(AppRule) updates) =>
      super.copyWith((message) => updates(message as AppRule)) as AppRule;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AppRule() / AppRule.new instead')
  static AppRule create() => AppRule._();
  static $pb.GeneratedMessage $_createMessage() => AppRule._();
  @$core.override
  AppRule createEmptyInstance() => AppRule._();
  @$core.pragma('dart2js:noInline')
  static AppRule getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AppRule>(AppRule.$_createMessage);
  static AppRule? _defaultInstance;

  /// Android: package name. Desktop: executable name or full path.
  @$pb.TagNumber(1)
  $core.String get app => $_getSZ(0);
  @$pb.TagNumber(1)
  set app($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasApp() => $_has(0);
  @$pb.TagNumber(1)
  void clearApp() => $_clearField(1);

  @$pb.TagNumber(2)
  AppMode get mode => $_getN(1);
  @$pb.TagNumber(2)
  set mode(AppMode value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMode() => $_has(1);
  @$pb.TagNumber(2)
  void clearMode() => $_clearField(2);
}

class Settings extends $pb.GeneratedMessage {
  factory Settings({
    TunnelMode? tunnelMode,
    $core.Iterable<AppRule>? appRules,
    $core.int? mixedPort,
    $core.String? tunStack,
  }) {
    final result = Settings._();
    if (tunnelMode != null) result.tunnelMode = tunnelMode;
    if (appRules != null) result.appRules.addAll(appRules);
    if (mixedPort != null) result.mixedPort = mixedPort;
    if (tunStack != null) result.tunStack = tunStack;
    return result;
  }

  Settings._();

  factory Settings.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Settings()..mergeFromBuffer(data, registry);
  factory Settings.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Settings()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Settings',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: Settings.$_createMessage)
    ..aE<TunnelMode>(1, _omitFieldNames ? '' : 'tunnelMode',
        enumValues: TunnelMode.values)
    ..pPM<AppRule>(2, _omitFieldNames ? '' : 'appRules',
        subBuilder: AppRule.$_createMessage)
    ..aI(3, _omitFieldNames ? '' : 'mixedPort', fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'tunStack')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Settings clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Settings copyWith(void Function(Settings) updates) =>
      super.copyWith((message) => updates(message as Settings)) as Settings;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Settings() / Settings.new instead')
  static Settings create() => Settings._();
  static $pb.GeneratedMessage $_createMessage() => Settings._();
  @$core.override
  Settings createEmptyInstance() => Settings._();
  @$core.pragma('dart2js:noInline')
  static Settings getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Settings>(Settings.$_createMessage);
  static Settings? _defaultInstance;

  @$pb.TagNumber(1)
  TunnelMode get tunnelMode => $_getN(0);
  @$pb.TagNumber(1)
  set tunnelMode(TunnelMode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTunnelMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearTunnelMode() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<AppRule> get appRules => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get mixedPort => $_getIZ(2);
  @$pb.TagNumber(3)
  set mixedPort($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMixedPort() => $_has(2);
  @$pb.TagNumber(3)
  void clearMixedPort() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get tunStack => $_getSZ(3);
  @$pb.TagNumber(4)
  set tunStack($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTunStack() => $_has(3);
  @$pb.TagNumber(4)
  void clearTunStack() => $_clearField(4);
}

class GetSettingsRequest extends $pb.GeneratedMessage {
  factory GetSettingsRequest() => GetSettingsRequest._();

  GetSettingsRequest._();

  factory GetSettingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSettingsRequest()..mergeFromBuffer(data, registry);
  factory GetSettingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSettingsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSettingsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'crocell.v1'),
      createEmptyInstance: GetSettingsRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSettingsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSettingsRequest copyWith(void Function(GetSettingsRequest) updates) =>
      super.copyWith((message) => updates(message as GetSettingsRequest))
          as GetSettingsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetSettingsRequest() / GetSettingsRequest.new instead')
  static GetSettingsRequest create() => GetSettingsRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetSettingsRequest._();
  @$core.override
  GetSettingsRequest createEmptyInstance() => GetSettingsRequest._();
  @$core.pragma('dart2js:noInline')
  static GetSettingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSettingsRequest>(
          GetSettingsRequest.$_createMessage);
  static GetSettingsRequest? _defaultInstance;
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
