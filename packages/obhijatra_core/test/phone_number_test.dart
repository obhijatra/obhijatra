import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:test/test.dart';

void main() {
  String? e164(String typed) => parsePhoneNumber(typed).e164;
  PhoneNumberIssue? issue(String typed) => parsePhoneNumber(typed).issue;

  group('parsePhoneNumber', () {
    test('reads a Bangladeshi mobile number however it is typed', () {
      for (final typed in [
        '01712345678',
        '1712345678',
        '+880 1712-345678',
        '+8801712345678',
        '8801712345678',
        '008801712345678',
        '+88 01712 345678', // country code typed as 88, then the 0
        '+880 01712345678', // the trunk 0 after the country code
        '(+880) 1712-345-678',
        '01712.345678',
        '01712 345678', // a non-breaking space
        '01712–345678', // an en dash
        '  01712345678  ',
      ]) {
        final result = parsePhoneNumber(typed);
        expect(result.e164, '+8801712345678', reason: typed);
        expect(result.issue, isNull, reason: typed);
      }
    });

    test('reads Bangla and other non-Latin digits', () {
      expect(e164('০১৭১২৩৪৫৬৭৮'), '+8801712345678');
      expect(e164('+৮৮০ ১৭১২-৩৪৫৬৭৮'), '+8801712345678');
      expect(e164('٠١٧١٢٣٤٥٦٧٨'), '+8801712345678'); // Arabic-Indic
      expect(e164('۰۱۷۱۲۳۴۵۶۷۸'), '+8801712345678'); // Persian/Urdu
    });

    test('accepts every mobile operator prefix, 013 to 019', () {
      for (var d = 3; d <= 9; d++) {
        expect(e164('01${d}12345678'), '+8801${d}12345678', reason: '01$d');
      }
    });

    test('refuses Bangladeshi numbers that are not mobile numbers', () {
      for (final typed in [
        '01012345678', // 010 to 012 belong to no mobile operator
        '01112345678',
        '01212345678',
        '0171234567', // 10 digits
        '017123456789', // 12 digits
        '029876543', // a Dhaka landline
        '+880 2 9876543',
        '880',
        '0',
        '+880',
      ]) {
        expect(
          issue(typed),
          PhoneNumberIssue.notBangladeshiMobile,
          reason: typed,
        );
        expect(e164(typed), isNull, reason: typed);
      }
    });

    test('says when nothing or no number was typed', () {
      expect(issue(''), PhoneNumberIssue.empty);
      expect(issue('   '), PhoneNumberIssue.empty);
      expect(issue(' - '), PhoneNumberIssue.empty);
      expect(issue('rahima'), PhoneNumberIssue.notANumber);
      expect(issue('017-ABC-5678'), PhoneNumberIssue.notANumber);
      expect(issue('+'), PhoneNumberIssue.notANumber);
      expect(issue('01712+345678'), PhoneNumberIssue.notANumber);
      expect(issue('++8801712345678'), PhoneNumberIssue.notANumber);
    });

    test('keeps numbers of other countries in international form', () {
      expect(e164('+44 7700 900123'), '+447700900123');
      expect(e164('0044 7700 900123'), '+447700900123');
      expect(e164('+91 98765 43210'), '+919876543210');
      expect(issue('+1234'), PhoneNumberIssue.notInternational);
      expect(issue('+0123456789'), PhoneNumberIssue.notInternational);
      expect(issue('+4412345678901234'), PhoneNumberIssue.notInternational);
      expect(issue('00'), PhoneNumberIssue.notInternational);
    });

    test('every accepted number has the form the server stores', () {
      for (final typed in ['01912345678', '+447700900123', '১৩১২৩৪৫৬৭৮']) {
        expect(e164Pattern.hasMatch(e164(typed)!), isTrue, reason: typed);
      }
    });
  });

  test('formatPhoneNumber writes Bangladeshi mobile numbers for reading', () {
    expect(formatPhoneNumber('+8801712345678'), '+880 1712-345678');
    expect(formatPhoneNumber('+8801912345678'), '+880 1912-345678');
    // Anything else stays as it is.
    expect(formatPhoneNumber('+447700900123'), '+447700900123');
    expect(formatPhoneNumber('+88029876543'), '+88029876543');
  });

  test('toAsciiDigits changes only digits', () {
    expect(toAsciiDigits('কোড ১২৩৪৫৬'), 'কোড 123456');
    expect(toAsciiDigits('০১২৩৪৫৬৭৮৯'), '0123456789');
    expect(toAsciiDigits('०१२३'), '0123'); // Devanagari
    expect(toAsciiDigits('abc 789'), 'abc 789');
    expect(toAsciiDigits(''), '');
  });
}
