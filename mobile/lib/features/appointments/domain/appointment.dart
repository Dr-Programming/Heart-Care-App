/// When, before the visit, the patient is reminded.
enum ReminderTiming {
  twoDaysBefore('2d'),
  dayBefore('1d'),
  sameDay('0d');

  const ReminderTiming(this.code);

  /// Stored and used in notification payloads.
  final String code;

  static ReminderTiming? fromCode(String code) {
    for (final ReminderTiming t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// A clinic visit the patient has booked. Kept on this phone only.
class Appointment {
  const Appointment({
    required this.id,
    required this.at,
    this.place = '',
    this.note = '',
    this.reminders = const <ReminderTiming>{
      ReminderTiming.twoDaysBefore,
      ReminderTiming.dayBefore,
      ReminderTiming.sameDay,
    },
  });

  final String id;
  final DateTime at;

  /// The clinic or doctor.
  final String place;

  /// What the visit is for, or anything to remember.
  final String note;
  final Set<ReminderTiming> reminders;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'at': at.toIso8601String(),
    'place': place,
    'note': note,
    'reminders': <String>[for (final ReminderTiming t in reminders) t.code],
  };

  static Appointment? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? id = json['id'];
    final DateTime? at = json['at'] is String
        ? DateTime.tryParse(json['at'] as String)
        : null;
    if (id is! String || at == null) return null;
    final Object? reminders = json['reminders'];
    return Appointment(
      id: id,
      at: at,
      place: json['place'] is String ? json['place'] as String : '',
      note: json['note'] is String ? json['note'] as String : '',
      reminders: reminders is List
          ? <ReminderTiming>{
              for (final Object? code in reminders)
                if (code is String && ReminderTiming.fromCode(code) != null)
                  ReminderTiming.fromCode(code)!,
            }
          : const <ReminderTiming>{},
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Appointment &&
      other.id == id &&
      other.at == at &&
      other.place == place &&
      other.note == note &&
      other.reminders.length == reminders.length &&
      other.reminders.containsAll(reminders);

  @override
  int get hashCode => Object.hash(id, at, place, note, reminders.length);
}

/// Evening reminders go out at this hour.
const int eveningReminderHour = 18;

/// When each of [appointment]'s reminders fires, leaving out any that are
/// already in the past.
///
/// * 2 days before and the day before: at 18:00, time to prepare.
/// * On the day: 2 hours before, but not before 06:00 (an early visit gets
///   its reminder at 06:00, or 30 minutes before if that is earlier still).
Map<ReminderTiming, DateTime> reminderTimes(
  Appointment appointment, {
  DateTime? now,
}) {
  final DateTime at = appointment.at;
  final DateTime day = DateTime(at.year, at.month, at.day);
  final DateTime current = now ?? DateTime.now();

  DateTime sameDay = at.subtract(const Duration(hours: 2));
  final DateTime sixAm = day.add(const Duration(hours: 6));
  if (sameDay.isBefore(sixAm)) sameDay = sixAm;
  if (!sameDay.isBefore(at)) sameDay = at.subtract(const Duration(minutes: 30));

  final Map<ReminderTiming, DateTime> all = <ReminderTiming, DateTime>{
    ReminderTiming.twoDaysBefore: DateTime(
      day.year,
      day.month,
      day.day - 2,
      eveningReminderHour,
    ),
    ReminderTiming.dayBefore: DateTime(
      day.year,
      day.month,
      day.day - 1,
      eveningReminderHour,
    ),
    ReminderTiming.sameDay: sameDay,
  };
  return <ReminderTiming, DateTime>{
    for (final MapEntry<ReminderTiming, DateTime> e in all.entries)
      if (appointment.reminders.contains(e.key) &&
          e.value.isAfter(current) &&
          e.value.isBefore(at))
        e.key: e.value,
  };
}

/// Whole days from today until the visit (0 = today). Counted on calendar
/// dates, so a daylight-saving change in between does not shorten it.
int daysUntil(Appointment appointment, {DateTime? now}) {
  final DateTime current = now ?? DateTime.now();
  final DateTime today = DateTime.utc(current.year, current.month, current.day);
  final DateTime day = DateTime.utc(
    appointment.at.year,
    appointment.at.month,
    appointment.at.day,
  );
  return day.difference(today).inDays;
}
