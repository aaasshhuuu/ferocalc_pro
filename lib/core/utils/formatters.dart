import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _indianCurrencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _indianCurrencyWithDecimalFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _indianNumberFormatter = NumberFormat.decimalPattern('en_IN');

  static String formatCurrency(double amount, {bool withDecimals = false}) {
    if (withDecimals) {
      return _indianCurrencyWithDecimalFormatter.format(amount);
    }
    return _indianCurrencyFormatter.format(amount);
  }

  static String formatNumber(double number) {
    return _indianNumberFormatter.format(number);
  }

  static String formatPercentage(double value) {
    return '${value.toStringAsFixed(2)}%';
  }

  static String formatCompactNumber(double number) {
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(2)}Cr';
    } else if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(2)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(2)}K';
    }
    return number.toStringAsFixed(0);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }
}
