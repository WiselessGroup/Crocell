import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crocell/main.dart';
import 'package:crocell/widgets/connect_button.dart';

void main() {
  testWidgets('connect button toggles state', (tester) async {
    await tester.pumpWidget(const CrocellApp());
    expect(find.text('Не подключено'), findsOneWidget);

    await tester.tap(find.byType(ConnectButton));
    await tester.pumpAndSettle();
    expect(find.text('Подключено'), findsOneWidget);

    await tester.tap(find.byType(ConnectButton));
    await tester.pumpAndSettle();
    expect(find.text('Не подключено'), findsOneWidget);
  });

  testWidgets('wings snap without animation when motion is reduced',
      (tester) async {
    var connected = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => ConnectButton(
              connected: connected,
              onPressed: () => setState(() => connected = !connected),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ConnectButton));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
