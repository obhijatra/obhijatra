/// Reading mobile numbers the way people type them, into the international
/// form (E.164) the server stores, with Bangladesh (+880) as the default
/// country.
library;

/// The only form of phone number the server stores and accepts: a plus, a
/// country code that does not start with 0, and 8 to 15 digits in all
/// (E.164).
final RegExp e164Pattern = RegExp(r'^\+[1-9][0-9]{7,14}$');

/// Bangladesh's country calling code, the default for numbers typed
/// without one.
const String bangladeshCallingCode = '880';

/// A Bangladeshi mobile number after +880 and without the leading 0: 1, an
/// operator digit from 3 to 9, then 8 digits. Written in the country this
/// is 013 to 019 and 11 digits in all. 010 to 012 are not given to any
/// mobile operator.
final RegExp _bangladeshMobile = RegExp(r'^1[3-9][0-9]{8}$');

/// What people type between the digits of a phone number: spaces (also
/// non-breaking and thin ones), hyphens and dashes, dots, slashes and
/// brackets.
final RegExp _separators = RegExp(r'[\s   \-‐-―./()]');

/// Why typed text is not a mobile number the server can send a code to.
enum PhoneNumberIssue {
  /// Nothing was typed.
  empty,

  /// Something other than digits, a leading `+` and separators was typed.
  notANumber,

  /// A Bangladeshi number that is not a mobile number: the wrong number of
  /// digits, or not starting with 013 to 019.
  notBangladeshiMobile,

  /// A number with another country code that cannot be a phone number
  /// (too short or too long).
  notInternational,
}

/// The result of reading a typed phone number: the number in international
/// form, or why it is not one.
typedef PhoneNumberResult = ({String? e164, PhoneNumberIssue? issue});

/// Reads what the person typed as a mobile number.
///
/// Numbers without a country code are Bangladeshi: `01712345678`,
/// `1712345678`, `+880 1712-345678`, `8801712345678`, `008801712345678` and
/// `+88 01712 345678` all become `+8801712345678`. Bangla and other
/// non-Latin digits are read as digits. A number with another country code
/// (`+44…` or `0044…`) is kept if it has the international form.
PhoneNumberResult parsePhoneNumber(String input) {
  final text = toAsciiDigits(input).replaceAll(_separators, '');
  if (text.isEmpty) return (e164: null, issue: PhoneNumberIssue.empty);
  if (!RegExp(r'^\+?[0-9]+$').hasMatch(text)) {
    return (e164: null, issue: PhoneNumberIssue.notANumber);
  }

  // The digits after the country code's plus.
  final String international;
  if (text.startsWith('+')) {
    international = text.substring(1);
  } else if (text.startsWith('00')) {
    international = text.substring(2); // the international call prefix
  } else if (text.startsWith(bangladeshCallingCode)) {
    international = text;
  } else {
    // A number as dialled in Bangladesh: drop the trunk 0 if there is one.
    international =
        bangladeshCallingCode +
        (text.startsWith('0') ? text.substring(1) : text);
  }

  if (international.startsWith(bangladeshCallingCode)) {
    var national = international.substring(bangladeshCallingCode.length);
    // "+880 01712…": the trunk 0 is often typed after the country code.
    if (national.startsWith('0')) national = national.substring(1);
    if (!_bangladeshMobile.hasMatch(national)) {
      return (e164: null, issue: PhoneNumberIssue.notBangladeshiMobile);
    }
    return (e164: '+$bangladeshCallingCode$national', issue: null);
  }
  final e164 = '+$international';
  if (!e164Pattern.hasMatch(e164)) {
    return (e164: null, issue: PhoneNumberIssue.notInternational);
  }
  return (e164: e164, issue: null);
}

/// Writes a number in international form for reading: a Bangladeshi mobile
/// number as `+880 1712-345678`, anything else unchanged.
String formatPhoneNumber(String e164) {
  const prefix = '+$bangladeshCallingCode';
  if (e164.startsWith(prefix)) {
    final national = e164.substring(prefix.length);
    if (_bangladeshMobile.hasMatch(national)) {
      return '$prefix ${national.substring(0, 4)}-${national.substring(4)}';
    }
  }
  return e164;
}

/// The first digit (zero) of each digit block people may type: Bangla,
/// Arabic-Indic, Eastern Arabic-Indic (Persian and Urdu) and Devanagari.
const List<int> _zeroes = <int>[0x09E6, 0x0660, 0x06F0, 0x0966];

/// Replaces Bangla and other non-Latin digits in [text] with `0` to `9`;
/// everything else stays as it is.
String toAsciiDigits(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    var mapped = rune;
    for (final zero in _zeroes) {
      if (rune >= zero && rune <= zero + 9) {
        mapped = 0x30 + rune - zero;
        break;
      }
    }
    out.writeCharCode(mapped);
  }
  return out.toString();
}
