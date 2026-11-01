// Talks to a real crocelld over its unix socket. Skipped unless
// CROCELL_SOCKET and CROCELL_TEST_SUB are set; never connects to a node.
//
//   CROCELL_SOCKET=$XDG_RUNTIME_DIR/crl.sock CROCELL_TEST_SUB=http://127.0.0.1:18765/sub/x \
//     flutter test test/daemon_integration_test.dart
import 'dart:io';

import 'package:crocell/data/core_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final socket = Platform.environment['CROCELL_SOCKET'];
  final sub = Platform.environment['CROCELL_TEST_SUB'];
  final skip = socket == null || sub == null ? 'set CROCELL_SOCKET and CROCELL_TEST_SUB' : null;

  test('gRPC over the unix socket: status, add, list, settings', () async {
    final api = GrpcCoreApi(socket!);
    try {
      final first = await api.watchStatus().first;
      expect(first.state, ConnectionState.CONNECTION_STATE_DISCONNECTED);

      final added = await api.addSubscription(sub!);
      expect(added.nodes, isNotEmpty);
      expect(added.urlMasked, isNot(contains(Uri.parse(sub).pathSegments.last)));

      final list = await api.listSubscriptions();
      expect(list.map((s) => s.id), contains(added.id));

      final settings = await api.getSettings();
      settings.appRules.add(AppRule(app: 'steam', mode: AppMode.APP_MODE_BYPASS));
      final saved = await api.updateSettings(settings);
      expect(saved.appRules.single.app, 'steam');

      await expectLater(api.connect(subscriptionId: 'nope'), throwsA(isA<CoreError>()));
    } finally {
      await api.close();
    }
  }, skip: skip);

  test('a missing daemon is reported as unavailable', () async {
    final api = GrpcCoreApi('/nonexistent/crocelld.sock');
    try {
      await expectLater(api.getSettings(), throwsA(isA<CoreError>().having((e) => e.unavailable, 'unavailable', isTrue)));
    } finally {
      await api.close();
    }
  });
}
