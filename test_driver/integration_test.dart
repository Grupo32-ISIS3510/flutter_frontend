import 'package:integration_test/integration_test_driver.dart';

/// Driver para ejecutar los tests de `integration_test/` en modo --profile
/// con `flutter drive`. Vuelca el reporte de `watchPerformance` en
/// `build/integration_response_data.json`.
Future<void> main() => integrationDriver();
