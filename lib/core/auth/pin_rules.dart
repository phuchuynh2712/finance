/// What a PIN may be and how long it lives (FR-010, FR-013, FR-014).
///
/// Pure Dart: every rule is a plain unit test. The numbers are the product's
/// own, inside the limits of constitution v1.8.0 (Security): at least 6
/// digits, at most 10 consecutive wrong tries, valid at most 12 months.
library;

/// Exactly six digits.
const int pinLength = 6;

/// Consecutive wrong PINs after which the PIN is invalidated.
const int maxWrongTries = 5;

/// A PIN expires this long after it was set or last changed: 365 days, never
/// more than the 12 months the standard allows.
const Duration pinValidity = Duration(days: 365);

/// Why a typed PIN is refused as a new PIN.
enum PinFormatError { notSixDigits, easy }

/// Exactly [pinLength] characters, all `0`–`9`.
bool isWellFormed(String pin) =>
    pin.length == pinLength && RegExp(r'^[0-9]+$').hasMatch(pin);

/// All one digit (`111111`), or a straight run up or down (`123456`,
/// `654321`). Anything else, repeated pairs and triples included, is accepted.
bool isEasy(String pin) {
  if (!isWellFormed(pin)) return false;
  final digits = pin.codeUnits;
  var allSame = true;
  var ascending = true;
  var descending = true;
  for (var i = 1; i < digits.length; i++) {
    final step = digits[i] - digits[i - 1];
    if (step != 0) allSame = false;
    if (step != 1) ascending = false;
    if (step != -1) descending = false;
  }
  return allSame || ascending || descending;
}

/// `null` when [pin] may be used as a new PIN.
PinFormatError? validate(String pin) {
  if (!isWellFormed(pin)) return PinFormatError.notSixDigits;
  if (isEasy(pin)) return PinFormatError.easy;
  return null;
}

/// `true` from exactly [pinValidity] after [setAt].
bool isExpired(DateTime setAt, DateTime now) =>
    !now.isBefore(setAt.add(pinValidity));
