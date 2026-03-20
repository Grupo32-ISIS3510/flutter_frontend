import 'package:intl/intl.dart';

class FormatHelpers {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('dd MMM yyyy', 'es');
  static final _shortDateFormat = DateFormat('dd/MM', 'es');

  static String currency(double amount) => _currencyFormat.format(amount);

  static String date(DateTime date) => _dateFormat.format(date);

  static String shortDate(DateTime date) => _shortDateFormat.format(date);

  static String daysRemaining(int days) {
    if (days < 0) return 'Vencido hace ${-days} día${-days == 1 ? '' : 's'}';
    if (days == 0) return 'Vence hoy';
    if (days == 1) return 'Vence mañana';
    return 'Vence en $days días';
  }

  static String quantity(double qty, String? unit) {
    final qtyStr = qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(1);
    if (unit == null || unit.isEmpty) return qtyStr;
    return '$qtyStr $unit';
  }
}
