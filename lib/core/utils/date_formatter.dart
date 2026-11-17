import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _standard = DateFormat('dd MMM yyyy');
  static final DateFormat _full = DateFormat('dd MMM yyyy, hh:mm a');

  static String formatStandardDate(DateTime date) {
    return _standard.format(date.toLocal());
  }

  static String formatIsoDate(DateTime date) {
    return _standard.format(date.toLocal());
  }

  static String formatFullDateTime(DateTime date) {
    return _full.format(date.toLocal());
  }

  static String formatRelative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        final m = diff.inMinutes;
        return m <= 1 ? 'just now' : '$m mins ago';
      }
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return formatStandardDate(date);
  }
}
