import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:second_serving_frontend/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RecipesScreen scroll perf (PPoF #3)', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Ir a la pestaña Recetas (item del bottom nav)
    await tester.tap(find.text('Recetas'));
    await tester.pumpAndSettle();

    await binding.watchPerformance(() async {
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 5; i++) {
        await tester.fling(list, const Offset(0, -400), 3000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'recipes_scroll');
  });
}
