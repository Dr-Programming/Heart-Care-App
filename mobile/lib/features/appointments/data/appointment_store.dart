import 'dart:convert';

import '../../../core/db/daos/preferences_dao.dart';
import '../domain/appointment.dart';

/// The patient's appointments, stored on this phone with their other
/// settings, so they are cleared when a different patient signs in. The
/// server has no appointments yet, so they are not synced.
class AppointmentStore {
  const AppointmentStore(this._prefs);

  static const String storageKey = 'appointments';

  final PreferencesDao _prefs;

  Future<List<Appointment>> all() async => parse(await _prefs.get(storageKey));

  /// Soonest first.
  static List<Appointment> parse(String? raw) {
    if (raw == null) return const <Appointment>[];
    try {
      final Object? json = jsonDecode(raw);
      if (json is! List) return const <Appointment>[];
      return <Appointment>[
        for (final Object? item in json) ?Appointment.fromJson(item),
      ]..sort((Appointment a, Appointment b) => a.at.compareTo(b.at));
    } on FormatException {
      return const <Appointment>[];
    }
  }

  /// Adds [appointment], or replaces the one with the same id.
  Future<void> save(Appointment appointment) async {
    final List<Appointment> list = <Appointment>[
      for (final Appointment a in await all())
        if (a.id != appointment.id) a,
      appointment,
    ];
    await _write(list);
  }

  Future<void> delete(String id) async => _write(<Appointment>[
    for (final Appointment a in await all())
      if (a.id != id) a,
  ]);

  Future<void> _write(List<Appointment> list) => _prefs.set(
    storageKey,
    jsonEncode(<Map<String, Object>>[
      for (final Appointment a in list) a.toJson(),
    ]),
  );
}
