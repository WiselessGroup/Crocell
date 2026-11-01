import 'package:crocell/widgets/elapsed_text.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ticks once per second, on the second, whatever the start phase', (tester) async {
    final start = DateTime(2026, 11, 1, 12);
    // Connected 0.97 s ago: the worst phase for a 1 Hz sampler.
    var now = start.add(const Duration(milliseconds: 970));
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ElapsedText(since: start, now: () => now),
    ));
    expect(find.text('00:00'), findsOneWidget);

    final seen = <String>[];
    for (var i = 0; i < 5; i++) {
      // Advance the fake clock and the test timers together, 10 ms at a time.
      for (var ms = 0; ms < 1000; ms += 10) {
        now = now.add(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));
      }
      seen.add((tester.widget(find.byType(Text)) as Text).data!);
    }
    expect(seen, ['00:01', '00:02', '00:03', '00:04', '00:05'], reason: 'no skipped or repeated seconds');
  });

  testWidgets('a new connection restarts from zero', (tester) async {
    final now = DateTime(2026, 11, 1, 12, 10);
    Widget at(DateTime since) => Directionality(
          textDirection: TextDirection.ltr,
          child: ElapsedText(since: since, now: () => now),
        );
    await tester.pumpWidget(at(now.subtract(const Duration(minutes: 5))));
    expect(find.text('05:00'), findsOneWidget);
    await tester.pumpWidget(at(now));
    expect(find.text('00:00'), findsOneWidget);
  });
}
