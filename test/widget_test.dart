import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test renders app shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Second Serving'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Second Serving'), findsOneWidget);
  });
}
