/// Low-level exceptions thrown *inside* the data layer.
///
/// The distinction from `Failure` matters: a `Failure` is something the UI is
/// expected to render, so it carries a user-facing message. An exception here
/// is a programming or storage fault that a repository catches and translates
/// — it should never reach a widget.
library;

/// The local database could not satisfy a read or write.
class CacheException implements Exception {
  const CacheException(this.message);

  final String message;

  @override
  String toString() => 'CacheException($message)';
}

/// A response parsed as valid JSON but did not match the contract in
/// `backend/docs/API.md` — a missing field, an unexpected enum value, or a
/// `data` payload of the wrong shape.
class ContractException implements Exception {
  const ContractException(this.message);

  final String message;

  @override
  String toString() => 'ContractException($message)';
}
