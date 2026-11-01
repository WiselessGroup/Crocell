import 'package:crocell/data/core_api.dart';
import 'package:crocell/notify/alerts.dart';
import 'package:flutter_test/flutter_test.dart';

Status st(ConnectionState s, {ProbeResult? check, String node = 'n1', String error = ''}) => Status(
      state: s,
      nodeId: node,
      error: error,
      liveCheck: check,
    );

final ok = ProbeResult(exitCountry: 'NL', exitColo: 'AMS', exitIp: '1.2.3.4');
final bad = ProbeResult(error: 'probe: timeout');
const on = ConnectionState.CONNECTION_STATE_CONNECTED;
const off = ConnectionState.CONNECTION_STATE_DISCONNECTED;
const failed = ConnectionState.CONNECTION_STATE_FAILED;

void main() {
  test('failed connect alerts once, with the reason', () {
    final a = alertFor(st(off), st(failed, error: 'engine: TUN did not start'));
    expect(a?.title, 'Не удалось подключиться');
    expect(a?.body, contains('TUN'));
    expect(alertFor(st(failed), st(failed)), isNull, reason: 'no repeat for the same failure');
  });

  test('a working connection is quiet', () {
    expect(alertFor(st(on), st(on, check: ok)), isNull);
    expect(alertFor(st(on, check: ok), st(on, check: ok)), isNull);
  });

  test('breaking and recovering', () {
    final broke = alertFor(st(on, check: ok), st(on, check: bad), nodeName: 'nlWISELESS');
    expect(broke?.title, 'VPN подключён, но интернет не идёт');
    expect(broke?.body, contains('nlWISELESS'));
    expect(alertFor(st(on, check: bad), st(on, check: bad)), isNull, reason: 'still broken: already said');
    expect(alertFor(st(on, check: bad), st(on, check: ok))?.title, 'Интернет через VPN снова работает');
  });

  test('switching to a working node is not a recovery to announce', () {
    expect(alertFor(st(on, check: bad, node: 'n1'), st(on, check: ok, node: 'n2')), isNull);
  });

  test('the service vanishing matters only while connected', () {
    expect(alertFor(st(on, check: ok), null)?.title, 'Служба Crocell остановилась');
    expect(alertFor(st(off), null), isNull);
  });
}
