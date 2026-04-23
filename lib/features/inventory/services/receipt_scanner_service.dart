import 'package:second_serving_frontend/shared/models/enums.dart';
import 'package:second_serving_frontend/features/inventory/services/camera_service.dart';
import 'package:second_serving_frontend/features/inventory/services/text_recognition_service.dart';
import 'package:second_serving_frontend/features/inventory/services/receipt_parser_service.dart';

class ScannedProduct {
  String name;
  double quantity;
  String unit;
  double? price;
  ItemCategory category;
  bool selected;

  ScannedProduct({
    required this.name,
    this.quantity = 1,
    this.unit = 'unidades',
    this.price,
    this.category = ItemCategory.other,
    this.selected = true,
  });
}

class ScanResult {
  final bool success;
  final List<ScannedProduct> products;
  final String? rawText;
  final String? errorMessage;

  const ScanResult({
    required this.success,
    this.products = const [],
    this.rawText,
    this.errorMessage,
  });

  factory ScanResult.failure(String message) =>
      ScanResult(success: false, errorMessage: message);

  factory ScanResult.ok(List<ScannedProduct> products, String rawText) =>
      ScanResult(success: true, products: products, rawText: rawText);
}

/// PATRÓN FACADE — Interfaz simplificada para el pipeline de escaneo de recibos.
///
/// Oculta la complejidad de tres subsistemas independientes:
///   • CameraService          — permisos y captura de foto
///   • TextRecognitionService — OCR con Google ML Kit
///   • ReceiptParserService   — parsing de texto crudo a productos estructurados
///
/// El cliente (AddItemScreen) solo interactúa con scan(), sin conocer
/// ni depender de ningún subsistema directamente.
class ReceiptScannerService {
  final CameraService _camera;
  final TextRecognitionService _ocr;
  final ReceiptParserService _parser;

  ReceiptScannerService({
    CameraService? camera,
    TextRecognitionService? ocr,
    ReceiptParserService? parser,
  })  : _camera = camera ?? CameraService(),
        _ocr = ocr ?? TextRecognitionService(),
        _parser = parser ?? ReceiptParserService();

  /// Orquesta el flujo completo: permiso → cámara → OCR → parsing.
  /// Devuelve un ScanResult que encapsula éxito/fallo de forma estructurada.
  Future<ScanResult> scan() async {
    final hasPermission = await _camera.requestPermission();
    if (!hasPermission) {
      return ScanResult.failure('Permiso de cámara denegado');
    }

    final photo = await _camera.takePhoto();
    if (photo == null) {
      return ScanResult.failure('Captura cancelada');
    }

    final rawText = await _ocr.extractText(photo);
    if (rawText == null) {
      return ScanResult.failure('No se detectó texto en la imagen');
    }

    final products = _parser.parse(rawText);
    if (products.isEmpty) {
      return ScanResult.failure('No se encontraron productos en el recibo');
    }

    return ScanResult.ok(products, rawText);
  }
}
