import 'package:intl/intl.dart';

abstract final class DateFormatter {
  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _clock = DateFormat('HH:mm');

  static String toApiDate(DateTime date) => _apiDate.format(date);

  static String toApiDateTime(DateTime value) =>
      value.toUtc().toIso8601String();

  static String toClock(DateTime value) => _clock.format(value);

  static DateTime? parseApiDateTime(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toLocal();

  static String displayDate(DateTime value, String localeCode) =>
      DateFormat.yMMMd(localeCode).format(value);

  static String displayDateTime(DateTime value, String localeCode) =>
      '${displayDate(value, localeCode)}, ${_clock.format(value)}';

  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime daysAgo(int days, {DateTime? from}) {
    final DateTime base = startOfDay(from ?? DateTime.now());
    return base.subtract(Duration(days: days));
  }
}
