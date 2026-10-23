// lib/core/utils/formatters.dart
import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'es_ES',
  symbol: '€',
  decimalDigits: 2,
);

String formatCurrency(double amount) => _currencyFormat.format(amount);

final _dateFormat = DateFormat('d MMM yyyy', 'es_ES');
final _dateTimeFormat = DateFormat('d MMM yyyy, HH:mm', 'es_ES');
final _timeFormat = DateFormat('HH:mm', 'es_ES');

String formatDate(DateTime date) => _dateFormat.format(date);
String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
String formatTime(DateTime date) => _timeFormat.format(date);
