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

/// What happens to one application's traffic while Crocell is on.
class AppMode extends $pb.ProtobufEnum {
  static const AppMode APP_MODE_UNSPECIFIED =
      AppMode._(0, _omitEnumNames ? '' : 'APP_MODE_UNSPECIFIED');
  static const AppMode APP_MODE_PROXY =
      AppMode._(1, _omitEnumNames ? '' : 'APP_MODE_PROXY');
  static const AppMode APP_MODE_BYPASS =
      AppMode._(2, _omitEnumNames ? '' : 'APP_MODE_BYPASS');
  static const AppMode APP_MODE_BLOCK =
      AppMode._(3, _omitEnumNames ? '' : 'APP_MODE_BLOCK');

  static const $core.List<AppMode> values = <AppMode>[
    APP_MODE_UNSPECIFIED,
    APP_MODE_PROXY,
    APP_MODE_BYPASS,
    APP_MODE_BLOCK,
  ];

  static final $core.List<AppMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static AppMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AppMode._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
