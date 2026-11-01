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

import 'package:protobuf/protobuf.dart' as $pb;

class ConnectionState extends $pb.ProtobufEnum {
  static const ConnectionState CONNECTION_STATE_UNSPECIFIED = ConnectionState._(
      0, _omitEnumNames ? '' : 'CONNECTION_STATE_UNSPECIFIED');
  static const ConnectionState CONNECTION_STATE_DISCONNECTED =
      ConnectionState._(
          1, _omitEnumNames ? '' : 'CONNECTION_STATE_DISCONNECTED');
  static const ConnectionState CONNECTION_STATE_CONNECTING =
      ConnectionState._(2, _omitEnumNames ? '' : 'CONNECTION_STATE_CONNECTING');
  static const ConnectionState CONNECTION_STATE_CONNECTED =
      ConnectionState._(3, _omitEnumNames ? '' : 'CONNECTION_STATE_CONNECTED');
  static const ConnectionState CONNECTION_STATE_DISCONNECTING =
      ConnectionState._(
          4, _omitEnumNames ? '' : 'CONNECTION_STATE_DISCONNECTING');
  static const ConnectionState CONNECTION_STATE_FAILED =
      ConnectionState._(5, _omitEnumNames ? '' : 'CONNECTION_STATE_FAILED');

  static const $core.List<ConnectionState> values = <ConnectionState>[
    CONNECTION_STATE_UNSPECIFIED,
    CONNECTION_STATE_DISCONNECTED,
    CONNECTION_STATE_CONNECTING,
    CONNECTION_STATE_CONNECTED,
    CONNECTION_STATE_DISCONNECTING,
    CONNECTION_STATE_FAILED,
  ];

  static final $core.List<ConnectionState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ConnectionState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ConnectionState._(super.value, super.name);
}

class TunnelMode extends $pb.ProtobufEnum {
  static const TunnelMode TUNNEL_MODE_UNSPECIFIED =
      TunnelMode._(0, _omitEnumNames ? '' : 'TUNNEL_MODE_UNSPECIFIED');
  static const TunnelMode TUNNEL_MODE_SYSTEM_PROXY =
      TunnelMode._(1, _omitEnumNames ? '' : 'TUNNEL_MODE_SYSTEM_PROXY');
  static const TunnelMode TUNNEL_MODE_TUN =
      TunnelMode._(2, _omitEnumNames ? '' : 'TUNNEL_MODE_TUN');

  static const $core.List<TunnelMode> values = <TunnelMode>[
    TUNNEL_MODE_UNSPECIFIED,
    TUNNEL_MODE_SYSTEM_PROXY,
    TUNNEL_MODE_TUN,
  ];

  static final $core.List<TunnelMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static TunnelMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TunnelMode._(super.value, super.name);
}

/// Where matching traffic goes.
class RouteAction extends $pb.ProtobufEnum {
  static const RouteAction ROUTE_ACTION_UNSPECIFIED =
      RouteAction._(0, _omitEnumNames ? '' : 'ROUTE_ACTION_UNSPECIFIED');
  static const RouteAction ROUTE_ACTION_PROXY =
      RouteAction._(1, _omitEnumNames ? '' : 'ROUTE_ACTION_PROXY');
  static const RouteAction ROUTE_ACTION_DIRECT =
      RouteAction._(2, _omitEnumNames ? '' : 'ROUTE_ACTION_DIRECT');
  static const RouteAction ROUTE_ACTION_BLOCK =
      RouteAction._(3, _omitEnumNames ? '' : 'ROUTE_ACTION_BLOCK');

  static const $core.List<RouteAction> values = <RouteAction>[
    ROUTE_ACTION_UNSPECIFIED,
    ROUTE_ACTION_PROXY,
    ROUTE_ACTION_DIRECT,
    ROUTE_ACTION_BLOCK,
  ];

  static final $core.List<RouteAction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static RouteAction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RouteAction._(super.value, super.name);
}

/// What a rule matches. Specific beats general: rules apply in this order,
/// so a single site in Proxy wins over a geosite set in Direct.
class RuleKind extends $pb.ProtobufEnum {
  static const RuleKind RULE_KIND_UNSPECIFIED =
      RuleKind._(0, _omitEnumNames ? '' : 'RULE_KIND_UNSPECIFIED');
  static const RuleKind RULE_KIND_PROCESS_PATH =
      RuleKind._(1, _omitEnumNames ? '' : 'RULE_KIND_PROCESS_PATH');
  static const RuleKind RULE_KIND_PROCESS_NAME =
      RuleKind._(2, _omitEnumNames ? '' : 'RULE_KIND_PROCESS_NAME');
  static const RuleKind RULE_KIND_DOMAIN =
      RuleKind._(3, _omitEnumNames ? '' : 'RULE_KIND_DOMAIN');
  static const RuleKind RULE_KIND_DOMAIN_WILDCARD =
      RuleKind._(4, _omitEnumNames ? '' : 'RULE_KIND_DOMAIN_WILDCARD');
  static const RuleKind RULE_KIND_DOMAIN_SUFFIX =
      RuleKind._(5, _omitEnumNames ? '' : 'RULE_KIND_DOMAIN_SUFFIX');
  static const RuleKind RULE_KIND_IP_CIDR =
      RuleKind._(6, _omitEnumNames ? '' : 'RULE_KIND_IP_CIDR');
  static const RuleKind RULE_KIND_GEOSITE =
      RuleKind._(7, _omitEnumNames ? '' : 'RULE_KIND_GEOSITE');
  static const RuleKind RULE_KIND_GEOIP =
      RuleKind._(8, _omitEnumNames ? '' : 'RULE_KIND_GEOIP');

  static const $core.List<RuleKind> values = <RuleKind>[
    RULE_KIND_UNSPECIFIED,
    RULE_KIND_PROCESS_PATH,
    RULE_KIND_PROCESS_NAME,
    RULE_KIND_DOMAIN,
    RULE_KIND_DOMAIN_WILDCARD,
    RULE_KIND_DOMAIN_SUFFIX,
    RULE_KIND_IP_CIDR,
    RULE_KIND_GEOSITE,
    RULE_KIND_GEOIP,
  ];

  static final $core.List<RuleKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static RuleKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RuleKind._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
