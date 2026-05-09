import 'package:intl/intl.dart';

final NumberFormat pesoFormatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

String formatPeso(double amount) => pesoFormatter.format(amount);

String formatPercent(double value) => '${(value * 100).clamp(0, 999).toStringAsFixed(0)}%';

String formatShortDate(DateTime dateTime) => DateFormat('MMM d, yyyy').format(dateTime);

String formatDayLabel(DateTime dateTime) => DateFormat('EEE').format(dateTime);

String titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}