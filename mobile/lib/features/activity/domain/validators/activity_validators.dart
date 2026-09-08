/// Local validation for an activity session, checked before it ever reaches
/// the network.
///
/// The only bound the API enforces on an activity session is
/// `durationMinutes` 1-1440 (`backend/docs/API.md` §6) — steps and distance
/// are optional with no range of their own. Checking it here means a bad
/// value fails fast, offline, instead of surfacing as a 400 after it syncs.
enum ActivityValidationError { durationOutOfRange }

Set<ActivityValidationError> validateActivitySession({
  required int durationMinutes,
}) {
  return <ActivityValidationError>{
    if (durationMinutes < 1 || durationMinutes > 1440)
      ActivityValidationError.durationOutOfRange,
  };
}
