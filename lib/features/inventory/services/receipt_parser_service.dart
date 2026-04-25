import 'package:second_serving_frontend/shared/models/enums.dart';
import 'package:second_serving_frontend/features/inventory/services/receipt_scanner_service.dart';
import 'package:second_serving_frontend/features/inventory/services/shelf_life_estimator.dart';

/// Subsistema C del patrón Facade.
/// Transforma texto crudo de un recibo en una lista estructurada de
/// productos. Aplica filtrado de ruido, extracción de precio/cantidad
/// mediante regex, y clasificación automática por categoría.
/// Estima la fecha de vencimiento de cada producto basándose en su
/// categoría y la fecha de compra detectada en el recibo.
class ReceiptParserService {
  static final List<RegExp> _datePatterns = [
    RegExp(
      r'(?:fecha|date)\s*[:\-]?\s*(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})',
      caseSensitive: false,
    ),
    RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})'),
    RegExp(r'(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})'),
  ];

  List<ScannedProduct> parse(String rawText) {
    final purchaseDate = _extractPurchaseDate(rawText) ?? DateTime.now();

    final lines =
        rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final products = <ScannedProduct>[];

    for (final line in lines) {
      if (_isNoiseLine(line)) continue;
      final product = _parseLine(line);
      if (product != null) {
        product.expiryDate = ShelfLifeEstimator.estimateExpiryDate(
          product.category,
          purchaseDate: purchaseDate,
        );
        product.expiryDateFromOcr = false;
        products.add(product);
      }
    }

    return products;
  }

  /// Busca la fecha de compra/transacción en el recibo.
  /// Los recibos contienen fechas de transacción, no de vencimiento.
  DateTime? _extractPurchaseDate(String rawText) {
    for (final pattern in _datePatterns) {
      for (final match in pattern.allMatches(rawText)) {
        final date = _parseMatchToDate(match, pattern);
        if (date != null) return date;
      }
    }
    return null;
  }

  DateTime? _parseMatchToDate(RegExpMatch match, RegExp pattern) {
    try {
      int day, month, year;

      if (pattern == _datePatterns.last) {
        year = int.parse(match.group(1)!);
        month = int.parse(match.group(2)!);
        day = int.parse(match.group(3)!);
      } else {
        day = int.parse(match.group(1)!);
        month = int.parse(match.group(2)!);
        year = int.parse(match.group(3)!);
      }

      if (year < 100) year += 2000;

      if (month < 1 || month > 12) {
        if (day >= 1 && day <= 12) {
          final temp = day;
          day = month;
          month = temp;
        } else {
          return null;
        }
      }
      if (day < 1 || day > 31) return null;

      final date = DateTime(year, month, day);
      final now = DateTime.now();
      if (date.isAfter(now.add(const Duration(days: 1)))) return null;
      if (date.isBefore(now.subtract(const Duration(days: 90)))) return null;

      return date;
    } catch (_) {
      return null;
    }
  }

  bool _isNoiseLine(String line) {
    final lower = line.toLowerCase();
    if (line.length < 3) return true;

    const noisePatterns = [
      'total', 'subtotal', 'sub-total', 'iva', 'impuesto',
      'cambio', 'efectivo', 'tarjeta', 'nit', 'factura',
      'hora', 'caja', 'cajero', 'tel', 'dir',
      'gracias', 'vuelva', 'bienvenido', 'recibo', 'ticket',
      'rut', 'boleta', 'cliente', 'vendedor', 'sucursal',
      'descuento', 'ahorro', 'puntos', 'devolucion',
      'forma de pago', 'medio de pago', 'transaccion',
    ];

    for (final pattern in noisePatterns) {
      if (lower.contains(pattern)) return true;
    }

    final stripped = line.replaceAll(RegExp(r'[\d\s\-\./,:\$#]'), '');
    if (stripped.isEmpty) return true;

    return false;
  }

  ScannedProduct? _parseLine(String line) {
    double? price;
    String cleanLine = line;

    // Patron 1: precio al final con posible indicador de impuesto (I, T, E, G)
    // Ej: "LECHE ENTERA   4.500 I", "Arroz $3,200 T", "Pan 2.300"
    final pricePatterns = [
      RegExp(r'\$\s*([\d.,]+)\s*[A-Za-z]?\s*$'),
      RegExp(r'([\d]{1,3}(?:[.,]\d{3})+)\s*[A-Za-z]?\s*$'),
      RegExp(r'([\d.,]+)\s*[A-Za-z]?\s*$'),
    ];

    for (final pattern in pricePatterns) {
      final priceMatch = pattern.firstMatch(line);
      if (priceMatch != null) {
        final priceStr =
            priceMatch.group(1)!.replaceAll('.', '').replaceAll(',', '.');
        final parsed = double.tryParse(priceStr);
        if (parsed != null && parsed >= 50) {
          price = parsed;
          cleanLine = line.substring(0, priceMatch.start).trim();
          break;
        }
      }
    }

    double quantity = 1;
    String unit = 'unidades';

    final qtyPatterns = [
      RegExp(r'[xX]\s*(\d+\.?\d*)'),
      RegExp(r'(\d+\.?\d*)\s*(kg|gr|g|lt|l|ml|un|pz|pzas?)\b',
          caseSensitive: false),
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

    String name = cleanLine
        .replaceAll(RegExp(r'[\$]'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^[\d\s\-\.]+'), '')
        .trim();

    if (name.length < 2) return null;

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
