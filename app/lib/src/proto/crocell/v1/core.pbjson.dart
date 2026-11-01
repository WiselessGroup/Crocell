// This is a generated file - do not edit.
//
// Generated from crocell/v1/core.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use connectionStateDescriptor instead')
const ConnectionState$json = {
  '1': 'ConnectionState',
  '2': [
    {'1': 'CONNECTION_STATE_UNSPECIFIED', '2': 0},
    {'1': 'CONNECTION_STATE_DISCONNECTED', '2': 1},
    {'1': 'CONNECTION_STATE_CONNECTING', '2': 2},
    {'1': 'CONNECTION_STATE_CONNECTED', '2': 3},
    {'1': 'CONNECTION_STATE_DISCONNECTING', '2': 4},
    {'1': 'CONNECTION_STATE_FAILED', '2': 5},
  ],
};

/// Descriptor for `ConnectionState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List connectionStateDescriptor = $convert.base64Decode(
    'Cg9Db25uZWN0aW9uU3RhdGUSIAocQ09OTkVDVElPTl9TVEFURV9VTlNQRUNJRklFRBAAEiEKHU'
    'NPTk5FQ1RJT05fU1RBVEVfRElTQ09OTkVDVEVEEAESHwobQ09OTkVDVElPTl9TVEFURV9DT05O'
    'RUNUSU5HEAISHgoaQ09OTkVDVElPTl9TVEFURV9DT05ORUNURUQQAxIiCh5DT05ORUNUSU9OX1'
    'NUQVRFX0RJU0NPTk5FQ1RJTkcQBBIbChdDT05ORUNUSU9OX1NUQVRFX0ZBSUxFRBAF');

@$core.Deprecated('Use tunnelModeDescriptor instead')
const TunnelMode$json = {
  '1': 'TunnelMode',
  '2': [
    {'1': 'TUNNEL_MODE_UNSPECIFIED', '2': 0},
    {'1': 'TUNNEL_MODE_SYSTEM_PROXY', '2': 1},
    {'1': 'TUNNEL_MODE_TUN', '2': 2},
  ],
};

/// Descriptor for `TunnelMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List tunnelModeDescriptor = $convert.base64Decode(
    'CgpUdW5uZWxNb2RlEhsKF1RVTk5FTF9NT0RFX1VOU1BFQ0lGSUVEEAASHAoYVFVOTkVMX01PRE'
    'VfU1lTVEVNX1BST1hZEAESEwoPVFVOTkVMX01PREVfVFVOEAI=');

@$core.Deprecated('Use routeActionDescriptor instead')
const RouteAction$json = {
  '1': 'RouteAction',
  '2': [
    {'1': 'ROUTE_ACTION_UNSPECIFIED', '2': 0},
    {'1': 'ROUTE_ACTION_PROXY', '2': 1},
    {'1': 'ROUTE_ACTION_DIRECT', '2': 2},
    {'1': 'ROUTE_ACTION_BLOCK', '2': 3},
  ],
};

/// Descriptor for `RouteAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List routeActionDescriptor = $convert.base64Decode(
    'CgtSb3V0ZUFjdGlvbhIcChhST1VURV9BQ1RJT05fVU5TUEVDSUZJRUQQABIWChJST1VURV9BQ1'
    'RJT05fUFJPWFkQARIXChNST1VURV9BQ1RJT05fRElSRUNUEAISFgoSUk9VVEVfQUNUSU9OX0JM'
    'T0NLEAM=');

@$core.Deprecated('Use ruleKindDescriptor instead')
const RuleKind$json = {
  '1': 'RuleKind',
  '2': [
    {'1': 'RULE_KIND_UNSPECIFIED', '2': 0},
    {'1': 'RULE_KIND_PROCESS_PATH', '2': 1},
    {'1': 'RULE_KIND_PROCESS_NAME', '2': 2},
    {'1': 'RULE_KIND_DOMAIN', '2': 3},
    {'1': 'RULE_KIND_DOMAIN_WILDCARD', '2': 4},
    {'1': 'RULE_KIND_DOMAIN_SUFFIX', '2': 5},
    {'1': 'RULE_KIND_IP_CIDR', '2': 6},
    {'1': 'RULE_KIND_GEOSITE', '2': 7},
    {'1': 'RULE_KIND_GEOIP', '2': 8},
  ],
};

/// Descriptor for `RuleKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List ruleKindDescriptor = $convert.base64Decode(
    'CghSdWxlS2luZBIZChVSVUxFX0tJTkRfVU5TUEVDSUZJRUQQABIaChZSVUxFX0tJTkRfUFJPQ0'
    'VTU19QQVRIEAESGgoWUlVMRV9LSU5EX1BST0NFU1NfTkFNRRACEhQKEFJVTEVfS0lORF9ET01B'
    'SU4QAxIdChlSVUxFX0tJTkRfRE9NQUlOX1dJTERDQVJEEAQSGwoXUlVMRV9LSU5EX0RPTUFJTl'
    '9TVUZGSVgQBRIVChFSVUxFX0tJTkRfSVBfQ0lEUhAGEhUKEVJVTEVfS0lORF9HRU9TSVRFEAcS'
    'EwoPUlVMRV9LSU5EX0dFT0lQEAg=');

@$core.Deprecated('Use statusDescriptor instead')
const Status$json = {
  '1': 'Status',
  '2': [
    {
      '1': 'state',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.crocell.v1.ConnectionState',
      '10': 'state'
    },
    {'1': 'subscription_id', '3': 2, '4': 1, '5': 9, '10': 'subscriptionId'},
    {'1': 'node_id', '3': 3, '4': 1, '5': 9, '10': 'nodeId'},
    {
      '1': 'connected_since',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'connectedSince'
    },
    {
      '1': 'traffic',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.crocell.v1.Traffic',
      '10': 'traffic'
    },
    {'1': 'error', '3': 6, '4': 1, '5': 9, '10': 'error'},
    {
      '1': 'tunnel_mode',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.crocell.v1.TunnelMode',
      '10': 'tunnelMode'
    },
    {'1': 'mixed_port', '3': 8, '4': 1, '5': 13, '10': 'mixedPort'},
    {
      '1': 'live_check',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.crocell.v1.ProbeResult',
      '10': 'liveCheck'
    },
    {'1': 'checking', '3': 10, '4': 1, '5': 8, '10': 'checking'},
    {'1': 'core_version', '3': 11, '4': 1, '5': 9, '10': 'coreVersion'},
  ],
};

/// Descriptor for `Status`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List statusDescriptor = $convert.base64Decode(
    'CgZTdGF0dXMSMQoFc3RhdGUYASABKA4yGy5jcm9jZWxsLnYxLkNvbm5lY3Rpb25TdGF0ZVIFc3'
    'RhdGUSJwoPc3Vic2NyaXB0aW9uX2lkGAIgASgJUg5zdWJzY3JpcHRpb25JZBIXCgdub2RlX2lk'
    'GAMgASgJUgZub2RlSWQSQwoPY29ubmVjdGVkX3NpbmNlGAQgASgLMhouZ29vZ2xlLnByb3RvYn'
    'VmLlRpbWVzdGFtcFIOY29ubmVjdGVkU2luY2USLQoHdHJhZmZpYxgFIAEoCzITLmNyb2NlbGwu'
    'djEuVHJhZmZpY1IHdHJhZmZpYxIUCgVlcnJvchgGIAEoCVIFZXJyb3ISNwoLdHVubmVsX21vZG'
    'UYByABKA4yFi5jcm9jZWxsLnYxLlR1bm5lbE1vZGVSCnR1bm5lbE1vZGUSHQoKbWl4ZWRfcG9y'
    'dBgIIAEoDVIJbWl4ZWRQb3J0EjYKCmxpdmVfY2hlY2sYCSABKAsyFy5jcm9jZWxsLnYxLlByb2'
    'JlUmVzdWx0UglsaXZlQ2hlY2sSGgoIY2hlY2tpbmcYCiABKAhSCGNoZWNraW5nEiEKDGNvcmVf'
    'dmVyc2lvbhgLIAEoCVILY29yZVZlcnNpb24=');

@$core.Deprecated('Use trafficDescriptor instead')
const Traffic$json = {
  '1': 'Traffic',
  '2': [
    {'1': 'up_bytes', '3': 1, '4': 1, '5': 4, '10': 'upBytes'},
    {'1': 'down_bytes', '3': 2, '4': 1, '5': 4, '10': 'downBytes'},
    {'1': 'up_rate', '3': 3, '4': 1, '5': 4, '10': 'upRate'},
    {'1': 'down_rate', '3': 4, '4': 1, '5': 4, '10': 'downRate'},
  ],
};

/// Descriptor for `Traffic`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trafficDescriptor = $convert.base64Decode(
    'CgdUcmFmZmljEhkKCHVwX2J5dGVzGAEgASgEUgd1cEJ5dGVzEh0KCmRvd25fYnl0ZXMYAiABKA'
    'RSCWRvd25CeXRlcxIXCgd1cF9yYXRlGAMgASgEUgZ1cFJhdGUSGwoJZG93bl9yYXRlGAQgASgE'
    'Ughkb3duUmF0ZQ==');

@$core.Deprecated('Use getStatusRequestDescriptor instead')
const GetStatusRequest$json = {
  '1': 'GetStatusRequest',
};

/// Descriptor for `GetStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStatusRequestDescriptor =
    $convert.base64Decode('ChBHZXRTdGF0dXNSZXF1ZXN0');

@$core.Deprecated('Use watchStatusRequestDescriptor instead')
const WatchStatusRequest$json = {
  '1': 'WatchStatusRequest',
};

/// Descriptor for `WatchStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchStatusRequestDescriptor =
    $convert.base64Decode('ChJXYXRjaFN0YXR1c1JlcXVlc3Q=');

@$core.Deprecated('Use connectRequestDescriptor instead')
const ConnectRequest$json = {
  '1': 'ConnectRequest',
  '2': [
    {'1': 'subscription_id', '3': 1, '4': 1, '5': 9, '10': 'subscriptionId'},
    {'1': 'node_id', '3': 2, '4': 1, '5': 9, '10': 'nodeId'},
  ],
};

/// Descriptor for `ConnectRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectRequestDescriptor = $convert.base64Decode(
    'Cg5Db25uZWN0UmVxdWVzdBInCg9zdWJzY3JpcHRpb25faWQYASABKAlSDnN1YnNjcmlwdGlvbk'
    'lkEhcKB25vZGVfaWQYAiABKAlSBm5vZGVJZA==');

@$core.Deprecated('Use disconnectRequestDescriptor instead')
const DisconnectRequest$json = {
  '1': 'DisconnectRequest',
};

/// Descriptor for `DisconnectRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List disconnectRequestDescriptor =
    $convert.base64Decode('ChFEaXNjb25uZWN0UmVxdWVzdA==');

@$core.Deprecated('Use selectNodeRequestDescriptor instead')
const SelectNodeRequest$json = {
  '1': 'SelectNodeRequest',
  '2': [
    {'1': 'subscription_id', '3': 1, '4': 1, '5': 9, '10': 'subscriptionId'},
    {'1': 'node_id', '3': 2, '4': 1, '5': 9, '10': 'nodeId'},
  ],
};

/// Descriptor for `SelectNodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List selectNodeRequestDescriptor = $convert.base64Decode(
    'ChFTZWxlY3ROb2RlUmVxdWVzdBInCg9zdWJzY3JpcHRpb25faWQYASABKAlSDnN1YnNjcmlwdG'
    'lvbklkEhcKB25vZGVfaWQYAiABKAlSBm5vZGVJZA==');

@$core.Deprecated('Use subscriptionDescriptor instead')
const Subscription$json = {
  '1': 'Subscription',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'url_masked', '3': 3, '4': 1, '5': 9, '10': 'urlMasked'},
    {'1': 'format', '3': 4, '4': 1, '5': 9, '10': 'format'},
    {'1': 'upload_bytes', '3': 5, '4': 1, '5': 4, '10': 'uploadBytes'},
    {'1': 'download_bytes', '3': 6, '4': 1, '5': 4, '10': 'downloadBytes'},
    {'1': 'total_bytes', '3': 7, '4': 1, '5': 4, '10': 'totalBytes'},
    {
      '1': 'expire',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'expire'
    },
    {
      '1': 'update_interval_hours',
      '3': 9,
      '4': 1,
      '5': 13,
      '10': 'updateIntervalHours'
    },
    {'1': 'web_page', '3': 10, '4': 1, '5': 9, '10': 'webPage'},
    {'1': 'support', '3': 11, '4': 1, '5': 9, '10': 'support'},
    {'1': 'announce', '3': 12, '4': 1, '5': 9, '10': 'announce'},
    {
      '1': 'fetched_at',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'fetchedAt'
    },
    {
      '1': 'nodes',
      '3': 14,
      '4': 3,
      '5': 11,
      '6': '.crocell.v1.Node',
      '10': 'nodes'
    },
  ],
};

/// Descriptor for `Subscription`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscriptionDescriptor = $convert.base64Decode(
    'CgxTdWJzY3JpcHRpb24SDgoCaWQYASABKAlSAmlkEhQKBXRpdGxlGAIgASgJUgV0aXRsZRIdCg'
    'p1cmxfbWFza2VkGAMgASgJUgl1cmxNYXNrZWQSFgoGZm9ybWF0GAQgASgJUgZmb3JtYXQSIQoM'
    'dXBsb2FkX2J5dGVzGAUgASgEUgt1cGxvYWRCeXRlcxIlCg5kb3dubG9hZF9ieXRlcxgGIAEoBF'
    'INZG93bmxvYWRCeXRlcxIfCgt0b3RhbF9ieXRlcxgHIAEoBFIKdG90YWxCeXRlcxIyCgZleHBp'
    'cmUYCCABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgZleHBpcmUSMgoVdXBkYXRlX2'
    'ludGVydmFsX2hvdXJzGAkgASgNUhN1cGRhdGVJbnRlcnZhbEhvdXJzEhkKCHdlYl9wYWdlGAog'
    'ASgJUgd3ZWJQYWdlEhgKB3N1cHBvcnQYCyABKAlSB3N1cHBvcnQSGgoIYW5ub3VuY2UYDCABKA'
    'lSCGFubm91bmNlEjkKCmZldGNoZWRfYXQYDSABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0'
    'YW1wUglmZXRjaGVkQXQSJgoFbm9kZXMYDiADKAsyEC5jcm9jZWxsLnYxLk5vZGVSBW5vZGVz');

@$core.Deprecated('Use nodeDescriptor instead')
const Node$json = {
  '1': 'Node',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'type', '3': 3, '4': 1, '5': 9, '10': 'type'},
    {'1': 'network', '3': 4, '4': 1, '5': 9, '10': 'network'},
    {'1': 'server', '3': 5, '4': 1, '5': 9, '10': 'server'},
    {'1': 'port', '3': 6, '4': 1, '5': 13, '10': 'port'},
    {
      '1': 'last_probe',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.crocell.v1.ProbeResult',
      '10': 'lastProbe'
    },
  ],
};

/// Descriptor for `Node`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeDescriptor = $convert.base64Decode(
    'CgROb2RlEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEhIKBHR5cGUYAyABKA'
    'lSBHR5cGUSGAoHbmV0d29yaxgEIAEoCVIHbmV0d29yaxIWCgZzZXJ2ZXIYBSABKAlSBnNlcnZl'
    'chISCgRwb3J0GAYgASgNUgRwb3J0EjYKCmxhc3RfcHJvYmUYByABKAsyFy5jcm9jZWxsLnYxLl'
    'Byb2JlUmVzdWx0UglsYXN0UHJvYmU=');

@$core.Deprecated('Use listSubscriptionsRequestDescriptor instead')
const ListSubscriptionsRequest$json = {
  '1': 'ListSubscriptionsRequest',
};

/// Descriptor for `ListSubscriptionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSubscriptionsRequestDescriptor =
    $convert.base64Decode('ChhMaXN0U3Vic2NyaXB0aW9uc1JlcXVlc3Q=');

@$core.Deprecated('Use listSubscriptionsResponseDescriptor instead')
const ListSubscriptionsResponse$json = {
  '1': 'ListSubscriptionsResponse',
  '2': [
    {
      '1': 'subscriptions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.crocell.v1.Subscription',
      '10': 'subscriptions'
    },
  ],
};

/// Descriptor for `ListSubscriptionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSubscriptionsResponseDescriptor =
    $convert.base64Decode(
        'ChlMaXN0U3Vic2NyaXB0aW9uc1Jlc3BvbnNlEj4KDXN1YnNjcmlwdGlvbnMYASADKAsyGC5jcm'
        '9jZWxsLnYxLlN1YnNjcmlwdGlvblINc3Vic2NyaXB0aW9ucw==');

@$core.Deprecated('Use addSubscriptionRequestDescriptor instead')
const AddSubscriptionRequest$json = {
  '1': 'AddSubscriptionRequest',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
  ],
};

/// Descriptor for `AddSubscriptionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addSubscriptionRequestDescriptor = $convert
    .base64Decode('ChZBZGRTdWJzY3JpcHRpb25SZXF1ZXN0EhAKA3VybBgBIAEoCVIDdXJs');

@$core.Deprecated('Use refreshSubscriptionRequestDescriptor instead')
const RefreshSubscriptionRequest$json = {
  '1': 'RefreshSubscriptionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `RefreshSubscriptionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshSubscriptionRequestDescriptor =
    $convert.base64Decode(
        'ChpSZWZyZXNoU3Vic2NyaXB0aW9uUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use removeSubscriptionRequestDescriptor instead')
const RemoveSubscriptionRequest$json = {
  '1': 'RemoveSubscriptionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `RemoveSubscriptionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeSubscriptionRequestDescriptor =
    $convert.base64Decode(
        'ChlSZW1vdmVTdWJzY3JpcHRpb25SZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use removeSubscriptionResponseDescriptor instead')
const RemoveSubscriptionResponse$json = {
  '1': 'RemoveSubscriptionResponse',
};

/// Descriptor for `RemoveSubscriptionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeSubscriptionResponseDescriptor =
    $convert.base64Decode('ChpSZW1vdmVTdWJzY3JpcHRpb25SZXNwb25zZQ==');

@$core.Deprecated('Use probeNodesRequestDescriptor instead')
const ProbeNodesRequest$json = {
  '1': 'ProbeNodesRequest',
  '2': [
    {'1': 'subscription_id', '3': 1, '4': 1, '5': 9, '10': 'subscriptionId'},
    {'1': 'node_ids', '3': 2, '4': 3, '5': 9, '10': 'nodeIds'},
  ],
};

/// Descriptor for `ProbeNodesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List probeNodesRequestDescriptor = $convert.base64Decode(
    'ChFQcm9iZU5vZGVzUmVxdWVzdBInCg9zdWJzY3JpcHRpb25faWQYASABKAlSDnN1YnNjcmlwdG'
    'lvbklkEhkKCG5vZGVfaWRzGAIgAygJUgdub2RlSWRz');

@$core.Deprecated('Use probeResultDescriptor instead')
const ProbeResult$json = {
  '1': 'ProbeResult',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 9, '10': 'nodeId'},
    {'1': 'entry_ips', '3': 2, '4': 3, '5': 9, '10': 'entryIps'},
    {'1': 'entry_country', '3': 3, '4': 1, '5': 9, '10': 'entryCountry'},
    {'1': 'exit_ip', '3': 4, '4': 1, '5': 9, '10': 'exitIp'},
    {'1': 'exit_country', '3': 5, '4': 1, '5': 9, '10': 'exitCountry'},
    {'1': 'exit_colo', '3': 6, '4': 1, '5': 9, '10': 'exitColo'},
    {'1': 'latency_ms', '3': 7, '4': 1, '5': 13, '10': 'latencyMs'},
    {'1': 'error', '3': 8, '4': 1, '5': 9, '10': 'error'},
    {
      '1': 'probed_at',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'probedAt'
    },
  ],
};

/// Descriptor for `ProbeResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List probeResultDescriptor = $convert.base64Decode(
    'CgtQcm9iZVJlc3VsdBIXCgdub2RlX2lkGAEgASgJUgZub2RlSWQSGwoJZW50cnlfaXBzGAIgAy'
    'gJUghlbnRyeUlwcxIjCg1lbnRyeV9jb3VudHJ5GAMgASgJUgxlbnRyeUNvdW50cnkSFwoHZXhp'
    'dF9pcBgEIAEoCVIGZXhpdElwEiEKDGV4aXRfY291bnRyeRgFIAEoCVILZXhpdENvdW50cnkSGw'
    'oJZXhpdF9jb2xvGAYgASgJUghleGl0Q29sbxIdCgpsYXRlbmN5X21zGAcgASgNUglsYXRlbmN5'
    'TXMSFAoFZXJyb3IYCCABKAlSBWVycm9yEjcKCXByb2JlZF9hdBgJIAEoCzIaLmdvb2dsZS5wcm'
    '90b2J1Zi5UaW1lc3RhbXBSCHByb2JlZEF0');

@$core.Deprecated('Use routeRuleDescriptor instead')
const RouteRule$json = {
  '1': 'RouteRule',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.crocell.v1.RuleKind',
      '10': 'kind'
    },
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
    {
      '1': 'action',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.crocell.v1.RouteAction',
      '10': 'action'
    },
  ],
};

/// Descriptor for `RouteRule`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List routeRuleDescriptor = $convert.base64Decode(
    'CglSb3V0ZVJ1bGUSKAoEa2luZBgBIAEoDjIULmNyb2NlbGwudjEuUnVsZUtpbmRSBGtpbmQSFA'
    'oFdmFsdWUYAiABKAlSBXZhbHVlEi8KBmFjdGlvbhgDIAEoDjIXLmNyb2NlbGwudjEuUm91dGVB'
    'Y3Rpb25SBmFjdGlvbg==');

@$core.Deprecated('Use dnsSettingsDescriptor instead')
const DnsSettings$json = {
  '1': 'DnsSettings',
  '2': [
    {'1': 'servers', '3': 1, '4': 3, '5': 9, '10': 'servers'},
    {'1': 'direct_servers', '3': 2, '4': 3, '5': 9, '10': 'directServers'},
    {'1': 'real_ip', '3': 3, '4': 1, '5': 8, '10': 'realIp'},
  ],
};

/// Descriptor for `DnsSettings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dnsSettingsDescriptor = $convert.base64Decode(
    'CgtEbnNTZXR0aW5ncxIYCgdzZXJ2ZXJzGAEgAygJUgdzZXJ2ZXJzEiUKDmRpcmVjdF9zZXJ2ZX'
    'JzGAIgAygJUg1kaXJlY3RTZXJ2ZXJzEhcKB3JlYWxfaXAYAyABKAhSBnJlYWxJcA==');

@$core.Deprecated('Use geoSettingsDescriptor instead')
const GeoSettings$json = {
  '1': 'GeoSettings',
  '2': [
    {'1': 'geoip_source', '3': 1, '4': 1, '5': 9, '10': 'geoipSource'},
    {'1': 'geosite_source', '3': 2, '4': 1, '5': 9, '10': 'geositeSource'},
    {'1': 'update_hours', '3': 3, '4': 1, '5': 13, '10': 'updateHours'},
  ],
};

/// Descriptor for `GeoSettings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List geoSettingsDescriptor = $convert.base64Decode(
    'CgtHZW9TZXR0aW5ncxIhCgxnZW9pcF9zb3VyY2UYASABKAlSC2dlb2lwU291cmNlEiUKDmdlb3'
    'NpdGVfc291cmNlGAIgASgJUg1nZW9zaXRlU291cmNlEiEKDHVwZGF0ZV9ob3VycxgDIAEoDVIL'
    'dXBkYXRlSG91cnM=');

@$core.Deprecated('Use settingsDescriptor instead')
const Settings$json = {
  '1': 'Settings',
  '2': [
    {
      '1': 'tunnel_mode',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.crocell.v1.TunnelMode',
      '10': 'tunnelMode'
    },
    {'1': 'mixed_port', '3': 3, '4': 1, '5': 13, '10': 'mixedPort'},
    {'1': 'tun_stack', '3': 4, '4': 1, '5': 9, '10': 'tunStack'},
    {
      '1': 'rules',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.crocell.v1.RouteRule',
      '10': 'rules'
    },
    {
      '1': 'final_action',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.crocell.v1.RouteAction',
      '10': 'finalAction'
    },
    {
      '1': 'dns',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.crocell.v1.DnsSettings',
      '10': 'dns'
    },
    {
      '1': 'geo',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.crocell.v1.GeoSettings',
      '10': 'geo'
    },
    {'1': 'disable_ipv6', '3': 9, '4': 1, '5': 8, '10': 'disableIpv6'},
    {'1': 'allow_lan', '3': 10, '4': 1, '5': 8, '10': 'allowLan'},
    {'1': 'connect_on_start', '3': 11, '4': 1, '5': 8, '10': 'connectOnStart'},
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
};

/// Descriptor for `Settings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settingsDescriptor = $convert.base64Decode(
    'CghTZXR0aW5ncxI3Cgt0dW5uZWxfbW9kZRgBIAEoDjIWLmNyb2NlbGwudjEuVHVubmVsTW9kZV'
    'IKdHVubmVsTW9kZRIdCgptaXhlZF9wb3J0GAMgASgNUgltaXhlZFBvcnQSGwoJdHVuX3N0YWNr'
    'GAQgASgJUgh0dW5TdGFjaxIrCgVydWxlcxgFIAMoCzIVLmNyb2NlbGwudjEuUm91dGVSdWxlUg'
    'VydWxlcxI6CgxmaW5hbF9hY3Rpb24YBiABKA4yFy5jcm9jZWxsLnYxLlJvdXRlQWN0aW9uUgtm'
    'aW5hbEFjdGlvbhIpCgNkbnMYByABKAsyFy5jcm9jZWxsLnYxLkRuc1NldHRpbmdzUgNkbnMSKQ'
    'oDZ2VvGAggASgLMhcuY3JvY2VsbC52MS5HZW9TZXR0aW5nc1IDZ2VvEiEKDGRpc2FibGVfaXB2'
    'NhgJIAEoCFILZGlzYWJsZUlwdjYSGwoJYWxsb3dfbGFuGAogASgIUghhbGxvd0xhbhIoChBjb2'
    '5uZWN0X29uX3N0YXJ0GAsgASgIUg5jb25uZWN0T25TdGFydEoECAIQAw==');

@$core.Deprecated('Use getSettingsRequestDescriptor instead')
const GetSettingsRequest$json = {
  '1': 'GetSettingsRequest',
};

/// Descriptor for `GetSettingsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSettingsRequestDescriptor =
    $convert.base64Decode('ChJHZXRTZXR0aW5nc1JlcXVlc3Q=');

@$core.Deprecated('Use listProcessesRequestDescriptor instead')
const ListProcessesRequest$json = {
  '1': 'ListProcessesRequest',
};

/// Descriptor for `ListProcessesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listProcessesRequestDescriptor =
    $convert.base64Decode('ChRMaXN0UHJvY2Vzc2VzUmVxdWVzdA==');

@$core.Deprecated('Use processDescriptor instead')
const Process$json = {
  '1': 'Process',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {'1': 'label', '3': 3, '4': 1, '5': 9, '10': 'label'},
  ],
};

/// Descriptor for `Process`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List processDescriptor = $convert.base64Decode(
    'CgdQcm9jZXNzEhIKBG5hbWUYASABKAlSBG5hbWUSEgoEcGF0aBgCIAEoCVIEcGF0aBIUCgVsYW'
    'JlbBgDIAEoCVIFbGFiZWw=');

@$core.Deprecated('Use listProcessesResponseDescriptor instead')
const ListProcessesResponse$json = {
  '1': 'ListProcessesResponse',
  '2': [
    {
      '1': 'processes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.crocell.v1.Process',
      '10': 'processes'
    },
  ],
};

/// Descriptor for `ListProcessesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listProcessesResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0UHJvY2Vzc2VzUmVzcG9uc2USMQoJcHJvY2Vzc2VzGAEgAygLMhMuY3JvY2VsbC52MS'
    '5Qcm9jZXNzUglwcm9jZXNzZXM=');

@$core.Deprecated('Use getLogsRequestDescriptor instead')
const GetLogsRequest$json = {
  '1': 'GetLogsRequest',
};

/// Descriptor for `GetLogsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getLogsRequestDescriptor =
    $convert.base64Decode('Cg5HZXRMb2dzUmVxdWVzdA==');

@$core.Deprecated('Use logsDescriptor instead')
const Logs$json = {
  '1': 'Logs',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `Logs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logsDescriptor =
    $convert.base64Decode('CgRMb2dzEhIKBHRleHQYASABKAlSBHRleHQ=');

@$core.Deprecated('Use getGeoInfoRequestDescriptor instead')
const GetGeoInfoRequest$json = {
  '1': 'GetGeoInfoRequest',
};

/// Descriptor for `GetGeoInfoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGeoInfoRequestDescriptor =
    $convert.base64Decode('ChFHZXRHZW9JbmZvUmVxdWVzdA==');

@$core.Deprecated('Use updateGeoRequestDescriptor instead')
const UpdateGeoRequest$json = {
  '1': 'UpdateGeoRequest',
};

/// Descriptor for `UpdateGeoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateGeoRequestDescriptor =
    $convert.base64Decode('ChBVcGRhdGVHZW9SZXF1ZXN0');

@$core.Deprecated('Use geoInfoDescriptor instead')
const GeoInfo$json = {
  '1': 'GeoInfo',
  '2': [
    {
      '1': 'geoip_updated',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'geoipUpdated'
    },
    {
      '1': 'geosite_updated',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'geositeUpdated'
    },
    {'1': 'geoip_categories', '3': 3, '4': 3, '5': 9, '10': 'geoipCategories'},
    {
      '1': 'geosite_categories',
      '3': 4,
      '4': 3,
      '5': 9,
      '10': 'geositeCategories'
    },
    {'1': 'updating', '3': 5, '4': 1, '5': 8, '10': 'updating'},
    {'1': 'error', '3': 6, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `GeoInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List geoInfoDescriptor = $convert.base64Decode(
    'CgdHZW9JbmZvEj8KDWdlb2lwX3VwZGF0ZWQYASABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZX'
    'N0YW1wUgxnZW9pcFVwZGF0ZWQSQwoPZ2Vvc2l0ZV91cGRhdGVkGAIgASgLMhouZ29vZ2xlLnBy'
    'b3RvYnVmLlRpbWVzdGFtcFIOZ2Vvc2l0ZVVwZGF0ZWQSKQoQZ2VvaXBfY2F0ZWdvcmllcxgDIA'
    'MoCVIPZ2VvaXBDYXRlZ29yaWVzEi0KEmdlb3NpdGVfY2F0ZWdvcmllcxgEIAMoCVIRZ2Vvc2l0'
    'ZUNhdGVnb3JpZXMSGgoIdXBkYXRpbmcYBSABKAhSCHVwZGF0aW5nEhQKBWVycm9yGAYgASgJUg'
    'VlcnJvcg==');
