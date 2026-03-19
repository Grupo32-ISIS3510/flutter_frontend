import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:second_serving_frontend/models/enums.dart';

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

class ReceiptScannerService {
  final ImagePicker _picker = ImagePicker();

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<File?> takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photo == null) return null;
    return File(photo.path);
  }

  Future<String?> extractText(File image) async {
    final inputImage = InputImage.fromFile(image);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final text = recognizedText.text.trim();
      return text.isEmpty ? null : text;
    } finally {
      textRecognizer.close();
    }
  }

  List<ScannedProduct> parseReceipt(String rawText) {
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final products = <ScannedProduct>[];

    for (final line in lines) {
      if (_isNoiseLine(line)) continue;

      final product = _parseLine(line);
      if (product != null) {
        products.add(product);
      }
    }

    return products;
  }

  /// Full flow: permission -> camera -> OCR -> parse
  Future<ScanResult> scan() async {
    final hasPermission = await requestCameraPermission();
    if (!hasPermission) {
      return ScanResult.failure('Permiso de cámara denegado');
    }

    final photo = await takePhoto();
    if (photo == null) {
      return ScanResult.failure('Captura cancelada');
    }

    final rawText = await extractText(photo);
    if (rawText == null) {
      return ScanResult.failure('No se detectó texto en la imagen');
    }

    final products = parseReceipt(rawText);
    if (products.isEmpty) {
      return ScanResult.failure('No se encontraron productos en el recibo');
    }

    return ScanResult.ok(products, rawText);
  }

  // --- Private helpers ---

  bool _isNoiseLine(String line) {
    final lower = line.toLowerCase();

    if (line.length < 3) return true;

    final noisePatterns = [
      'total', 'subtotal', 'sub-total', 'iva', 'impuesto',
      'cambio', 'efectivo', 'tarjeta', 'nit', 'factura',
      'fecha', 'hora', 'caja', 'cajero', 'tel', 'dir',
      'gracias', 'vuelva', 'bienvenido', 'recibo', 'ticket',
      'rut', 'boleta', 'cliente', 'vendedor', 'sucursal',
      'descuento', 'ahorro', 'puntos', 'devolucion',
      'forma de pago', 'medio de pago', 'transaccion',
    ];

    for (final pattern in noisePatterns) {
      if (lower.contains(pattern)) return true;
    }

    // Lines that are only numbers/symbols (dates, phone numbers, etc.)
    final stripped = line.replaceAll(RegExp(r'[\d\s\-\./,:\$#]'), '');
    if (stripped.isEmpty) return true;

    return false;
  }

  ScannedProduct? _parseLine(String line) {
    // Try to extract price (number with $ or large number at end)
    double? price;
    String cleanLine = line;

    final priceMatch = RegExp(r'\$?\s*([\d.,]+)\s*$').firstMatch(line);
    if (priceMatch != null) {
      final priceStr = priceMatch.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      final parsed = double.tryParse(priceStr);
      if (parsed != null && parsed >= 100) {
        price = parsed;
        cleanLine = line.substring(0, priceMatch.start).trim();
      }
    }

    // Try to extract quantity (xN, x N, N un, Nkg, etc.)
    double quantity = 1;
    String unit = 'unidades';

    final qtyPatterns = [
      RegExp(r'[xX]\s*(\d+\.?\d*)'),
      RegExp(r'(\d+\.?\d*)\s*(kg|gr|g|lt|l|ml|un|pz|pzas?)\b', caseSensitive: false),
      RegExp(r'^(\d+\.?\d*)\s+'),
    ];

    for (final pattern in qtyPatterns) {
      final match = pattern.firstMatch(cleanLine);
      if (match != null) {
        final qtyStr = match.group(1);
        if (qtyStr != null) {
          final parsed = double.tryParse(qtyStr);
          if (parsed != null && parsed > 0 && parsed < 1000) {
            quantity = parsed;
            if (match.groupCount >= 2 && match.group(2) != null) {
              unit = _normalizeUnit(match.group(2)!);
            }
            cleanLine = cleanLine.replaceFirst(match.group(0)!, '').trim();
          }
        }
        break;
      }
    }

    // Clean up the product name
    String name = cleanLine
        .replaceAll(RegExp(r'[\$]'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^[\d\s\-\.]+'), '')
        .trim();

    if (name.length < 2) return null;

    // Capitalize first letter
    name = name[0].toUpperCase() + name.substring(1).toLowerCase();

    return ScannedProduct(
      name: name,
      quantity: quantity,
      unit: unit,
      price: price,
      category: _guessCategory(name),
    );
  }

  String _normalizeUnit(String raw) {
    switch (raw.toLowerCase()) {
      case 'kg':
        return 'kg';
      case 'g':
      case 'gr':
        return 'gramos';
      case 'l':
      case 'lt':
        return 'litros';
      case 'ml':
        return 'ml';
      case 'un':
      case 'pz':
      case 'pza':
      case 'pzas':
        return 'unidades';
      default:
        return 'unidades';
    }
  }

  ItemCategory _guessCategory(String name) {
    final lower = name.toLowerCase();

    const categoryKeywords = {
      ItemCategory.dairy: [
        'leche', 'yogur', 'yogurt', 'queso', 'crema', 'mantequilla', 'kumis',
      ],
      ItemCategory.meat: [
        'pollo', 'carne', 'res', 'cerdo', 'pechuga', 'costilla', 'chorizo',
        'jamon', 'salchicha', 'tocineta', 'salmon', 'pescado', 'atun',
      ],
      ItemCategory.fruits: [
        'manzana', 'banana', 'banano', 'naranja', 'limon', 'fresa', 'uva',
        'piña', 'mango', 'aguacate', 'papaya', 'melon', 'sandia', 'mora',
        'fruta',
      ],
      ItemCategory.vegetables: [
        'tomate', 'cebolla', 'papa', 'zanahoria', 'lechuga', 'pepino',
        'brocoli', 'espinaca', 'pimenton', 'ajo', 'cilantro', 'apio',
        'maiz', 'verdura', 'arveja',
      ],
      ItemCategory.grains: [
        'arroz', 'pasta', 'pan', 'harina', 'avena', 'cereal', 'lenteja',
        'frijol', 'garbanzo', 'granola',
      ],
      ItemCategory.beverages: [
        'jugo', 'agua', 'gaseosa', 'cerveza', 'vino', 'cafe', 'te', 'soda',
        'refresco', 'bebida',
      ],
      ItemCategory.snacks: [
        'galleta', 'chocolate', 'dulce', 'chip', 'papa frita', 'gomita',
        'snack', 'barra',
      ],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) return entry.key;
      }
    }

    return ItemCategory.other;
  }
}
