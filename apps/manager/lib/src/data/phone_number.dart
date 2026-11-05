/// Mobile numbers as people type them, and the international (E.164) form
/// the server keeps.
///
/// Bangladesh is the default country: "01712345678", "1712 345678",
/// "+880 1712-345678", "8801712345678" and the same in Bangla digits all
/// become `+8801712345678`. A number for another country must start with
/// `+` (or `00`) and its country code.
library;

/// The country code used when a number has none.
const String defaultCountryCode = '880';

final RegExp _separators = RegExp('[\\s\\-.()\u00A0\u2010-\u2015]');
final RegExp _e164 = RegExp(r'^\+[1-9][0-9]{7,14}$');
final RegExp _bangladeshMobile = RegExp(r'^\+8801[3-9][0-9]{8}$');

/// Replaces Bangla digits (০ to ৯) with 0 to 9; leaves everything else.
String latinDigits(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    out.writeCharCode(
      rune >= 0x09E6 && rune <= 0x09EF ? rune - 0x09E6 + 0x30 : rune,
    );
  }
  return out.toString();
}

/// The number in international form, for example `+8801712345678`, or null
/// when [input] is not a usable mobile number.
String? normalisePhone(String input) {
  final text = latinDigits(input.trim()).replaceAll(_separators, '');
  if (text.isEmpty) return null;
  final plus = text.startsWith('+');
  var digits = plus ? text.substring(1) : text;
  if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return null;

  final String international;
  if (plus) {
    international = digits;
  } else if (digits.startsWith('00')) {
    international = digits.substring(2);
  } else if (digits.startsWith(defaultCountryCode) && digits.length >= 13) {
    international = digits;
  } else {
    if (digits.startsWith('0')) digits = digits.substring(1);
    international = '$defaultCountryCode$digits';
  }

  var number = '+$international';
  // "+880 01712345678": the local 0 typed after the country code.
  if (number.startsWith('+8800') && number.length == 15) {
    number = '+880${number.substring(5)}';
  }
  if (!_e164.hasMatch(number)) return null;
  if (number.startsWith('+$defaultCountryCode') &&
      !_bangladeshMobile.hasMatch(number)) {
    return null;
  }
  return number;
}

/// A number in international form, spaced for reading: `+880 1712-345678`.
/// Numbers from other countries are shown as they are.
String displayPhone(String international) {
  if (_bangladeshMobile.hasMatch(international)) {
    final local = international.substring(4);
    return '+880 ${local.substring(0, 4)}-${local.substring(4)}';
  }
  return international;
}

/// Whether the text typed so far already says which country it is for, so
/// the `+880` in front of the field no longer applies.
bool hasOwnCountryCode(String input) {
  final text = latinDigits(input.trim());
  return text.startsWith('+') ||
      text.startsWith('00') ||
      (text.startsWith(defaultCountryCode) &&
          text.replaceAll(_separators, '').length >= 13);
}
