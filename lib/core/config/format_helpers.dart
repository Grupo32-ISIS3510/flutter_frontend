// Paquete intl: provee formateo y localización (números, fechas, plurales).
// Requiere haber inicializado el locale en main() con initializeDateFormatting('es').
import 'package:intl/intl.dart';

// Clase de utilidades estáticas (sin instanciar). Centraliza el formateo
// para mantener consistencia visual en toda la app.
class FormatHelpers {
  // Formateadores creados UNA sola vez (static final) por costos de inicialización.
  // locale 'es_CO' aplica reglas colombianas (ej: separador de miles con punto).
  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',                  // \$ porque $ es interpolación en Dart
    decimalDigits: 0,              // COP no usa decimales en uso diario
  );

  // dd = día con 0, MMM = mes abreviado, yyyy = año 4 dígitos.
  static final _dateFormat = DateFormat('dd MMM yyyy', 'es');
  static final _shortDateFormat = DateFormat('dd/MM', 'es');

  // Sintaxis de arrow function: cuerpo de una sola expresión.
  static String currency(double amount) => _currencyFormat.format(amount);

  static String date(DateTime date) => _dateFormat.format(date);

  static String shortDate(DateTime date) => _shortDateFormat.format(date);

  // CORAZÓN DEL INDICADOR DE DÍAS RESTANTES.
  // Convierte el int técnico en lenguaje humano contextual.
  // Maneja correctamente la pluralización del español (día vs días).
  // Para apps multi-idioma robustas se usaría la sintaxis ICU plural de intl.
  static String daysRemaining(int days) {
    if (days < 0) return 'Vencido hace ${-days} día${-days == 1 ? '' : 's'}';
    if (days == 0) return 'Vence hoy';
    if (days == 1) return 'Vence mañana';
    return 'Vence en $days días';
  }

  // Formatea cantidad: si es entera muestra "2", si tiene decimales "1.5".
  // roundToDouble() devuelve el valor redondeado en double; si coincide con
  // el original, significa que era entero y podemos mostrar sin decimales.
  static String quantity(double qty, String? unit) {
    final qtyStr = qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(1);
    // Si no hay unidad, solo el número. Si hay → "2 L", "1.5 kg".
    if (unit == null || unit.isEmpty) return qtyStr;
    return '$qtyStr $unit';
  }
}
