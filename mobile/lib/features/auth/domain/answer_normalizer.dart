/// Puts a security answer into one canonical form before it is hashed or
/// compared, so "Bole Primary", " bole  primary " and "BOLE PRIMARY" are the
/// same answer.
///
/// Must match the backend's `SecurityAnswerNormalizer` exactly: the phone
/// checks answers offline and the server checks them again when the change
/// syncs, and the two must agree. Trim, collapse whitespace runs to one space,
/// lowercase. No Unicode NFKC step on either side.
library;

const int minAnswerLength = 2;
const int maxAnswerLength = 100;

final RegExp _whitespace = RegExp(r'\s+', unicode: true);

String normalizeAnswer(String answer) =>
    answer.trim().replaceAll(_whitespace, ' ').toLowerCase();

/// Whether [answer] is 2–100 characters (code points) once normalised.
bool isValidAnswer(String answer) {
  final int length = normalizeAnswer(answer).runes.length;
  return length >= minAnswerLength && length <= maxAnswerLength;
}
