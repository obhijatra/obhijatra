/// Passwords the app makes up when an organisation admin adds a person.
///
/// Always pass a cryptographically secure source, `Random.secure()`; tests
/// pass a predictable one.
library;

import 'dart:math';

/// The letters and digits of a one-time password: lower case, without the
/// ones that are easy to confuse when read out (0 o 1 l i).
const String oneTimePasswordAlphabet = 'abcdefghjkmnpqrstuvwxyz23456789';

/// How many characters of [oneTimePasswordAlphabet] a one-time password has
/// (not counting the hyphens between groups).
const int oneTimePasswordLength = 12;

/// The characters of a hidden password.
const String _hiddenAlphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// A new one-time password, in three groups of four with hyphens between
/// them, for example `kfmw-tqzp-hrvx`. The hyphens are part of the
/// password, so the person can type it exactly as it is shown.
String newOneTimePassword(Random random) {
  final out = StringBuffer();
  for (var i = 0; i < oneTimePasswordLength; i++) {
    if (i > 0 && i % 4 == 0) out.write('-');
    out.write(
      oneTimePasswordAlphabet[random.nextInt(oneTimePasswordAlphabet.length)],
    );
  }
  return out.toString();
}

/// A long password nobody is ever shown, for a person who signs in only with
/// an SMS code or with Google. The server needs a password on every
/// account; this one cannot be guessed and is never used.
String newHiddenPassword(Random random) {
  final out = StringBuffer();
  for (var i = 0; i < 48; i++) {
    out.write(_hiddenAlphabet[random.nextInt(_hiddenAlphabet.length)]);
  }
  return out.toString();
}
