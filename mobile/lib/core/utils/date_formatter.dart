import 'package:intl/intl.dart';

/// Date and time formatting shared by every feature.
///
/// Two different jobs live here and must not be confused:
///
///  * **Wire formats** (`toApiDate`, `toApiDateTime`) are what the API expects
///    on `from`/`to` query parameters and `scheduledDate`. They are fixed,
///    locale-independent, and must never be localised.
///  * **Display formats** take a locale so Amharic renders correctly.
abstract final class DateFormatter {
  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _clock = DateFormat('HH:mm');

  /// `yyyy-MM-dd` — the only date shape the API accepts on `from`, `to` and
  /// `scheduledDate`.
  static String toApiDate(DateTime date) => _apiDate.format(date);

  /// ISO-8601 in UTC, for `measuredAt` / `loggedAt`.
  ///
  /// Sent as UTC deliberately: a patient who logs a reading and then crosses
  /// a timezone must not have their clinical history reorder itself.
  static String toApiDateTime(DateTime value) =>
      value.toUtc().toIso8601String();

  /// `HH:mm` — the shape of a medication `scheduleTimes` entry. Local wall
  /// clock, because a reminder at 08:00 means 08:00 where the patient is.
  static String toClock(DateTime value) => _clock.format(value);

  static DateTime? parseApiDateTime(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toLocal();

  /// e.g. "22 Aug 2026". Pass the active locale code so Amharic month names
  /// are used when the app is in Amharic.
  static String displayDate(DateTime value, String localeCode) =>
      DateFormat.yMMMd(localeCode).format(value);

  /// e.g. "22 Aug 2026, 14:30".
  static String displayDateTime(DateTime value, String localeCode) =>
      '${displayDate(value, localeCode)}, ${_clock.format(value)}';

  /// Midnight local time on the day of [value] — the lower bound for
  /// "today's" queries.
  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Midnight local time [days] before today. `daysAgo(7)` gives the lower
  /// bound of a 7-day trend window.
  static DateTime daysAgo(int days, {DateTime? from}) {
    final DateTime base = startOfDay(from ?? DateTime.now());
    return base.subtract(Duration(days: days));
  }
}
