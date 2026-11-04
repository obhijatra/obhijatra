/// Writing numbers, dates and times for a Bangladeshi reader.
library;

const List<String> _banglaDigits = <String>[
  '০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯', //
];

const List<String> _banglaMonths = <String>[
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', //
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর', //
];

const List<String> _banglaWeekdays = <String>[
  'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', //
  'রবিবার', //
];

const List<String> _englishMonths = <String>[
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December', //
];

const List<String> _englishWeekdays = <String>[
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday', //
];

/// Replaces every ASCII digit in [text] with its Bangla digit.
String toBanglaDigits(String text) => text.replaceAllMapped(
  RegExp('[0-9]'),
  (m) => _banglaDigits[int.parse(m[0]!)],
);

/// Writes [value] in Bangla digits when [bangla] is true.
String digits(int value, {required bool bangla}) =>
    bangla ? toBanglaDigits('$value') : '$value';

/// A full date: "Wednesday, 4 November 2026" or "বুধবার, ৪ নভেম্বর ২০২৬".
String fullDate(DateTime date, {required bool bangla}) {
  final weekday = (bangla
      ? _banglaWeekdays
      : _englishWeekdays)[date.weekday - 1];
  return '$weekday, ${shortDate(date, bangla: bangla, withYear: true)}';
}

/// A date: "4 November 2026" or "৪ নভেম্বর ২০২৬" (year optional).
String shortDate(DateTime date, {required bool bangla, bool withYear = true}) {
  final month = (bangla ? _banglaMonths : _englishMonths)[date.month - 1];
  final day = digits(date.day, bangla: bangla);
  final year = digits(date.year, bangla: bangla);
  return withYear ? '$day $month $year' : '$day $month';
}

/// A time of day: "9:15 am" or "সকাল ৯:১৫".
String timeOfDay(DateTime time, {required bool bangla}) {
  final h24 = time.hour;
  final minute = time.minute.toString().padLeft(2, '0');
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  if (!bangla) return '$h12:$minute ${h24 < 12 ? 'am' : 'pm'}';
  final period = switch (h24) {
    >= 4 && < 12 => 'সকাল',
    >= 12 && < 16 => 'দুপুর',
    >= 16 && < 18 => 'বিকাল',
    >= 18 && < 20 => 'সন্ধ্যা',
    _ => 'রাত',
  };
  return '$period ${toBanglaDigits('$h12:$minute')}';
}

/// A moment written for a sentence: "today at 9:15 am", "yesterday at …",
/// "3 November at …" or the Bangla forms "আজ সকাল ৯:১৫", "গতকাল …",
/// "৩ নভেম্বর, সকাল ৯:১৫". [now] is injected for tests.
String when(DateTime moment, {required bool bangla, required DateTime now}) {
  final local = moment.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final gap = today.difference(day).inDays;
  final time = timeOfDay(local, bangla: bangla);
  if (bangla) {
    if (gap == 0) return 'আজ $time';
    if (gap == 1) return 'গতকাল $time';
    return '${shortDate(local, bangla: true, withYear: local.year != now.year)}, $time';
  }
  if (gap == 0) return 'today at $time';
  if (gap == 1) return 'yesterday at $time';
  return '${shortDate(local, bangla: false, withYear: local.year != now.year)} at $time';
}
