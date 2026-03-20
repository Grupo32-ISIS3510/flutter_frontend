import 'package:flutter_test/flutter_test.dart';
import 'package:second_serving_frontend/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SecondServingApp());
    await tester.pumpAndSettle();
    expect(find.text('Second Serving'), findsOneWidget);
  });
}
