import 'package:intl/intl.dart';

/// App-wide date/time formatting and parsing helpers.
class AppDateUtils {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _isoFormat =
      DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");

  /// Formats [date] as dd/MM/yyyy.
  static String formatDate(DateTime date) => _dateFormat.format(date);

  /// Formats [date] as dd/MM/yyyy HH:mm.
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  /// Parses [dateStr] as dd/MM/yyyy; returns null if invalid.
  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      return _dateFormat.parse(dateStr.trim());
    } catch (_) {
      return null;
    }
  }

  /// Parses [dateStr] as dd/MM/yyyy HH:mm; returns null if invalid.
  static DateTime? parseDateTime(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      return _dateTimeFormat.parse(dateStr.trim());
    } catch (_) {
      return null;
    }
  }

  /// Returns start of day (00:00:00.000) for [date].
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Returns end of day (23:59:59.999) for [date].
  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  /// Number of calendar days between [start] and [end] (inclusive of start, exclusive of end).
  static int daysBetween(DateTime start, DateTime end) {
    final s = startOfDay(start);
    final e = startOfDay(end);
    return e.difference(s).inDays;
  }

  /// Whether [date] is today (same calendar day).
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
