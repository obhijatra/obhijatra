// Moving by whole days across daylight-saving changes. The checks hold in
// any time zone; run them under one with daylight saving to see them bite,
// for example: TZ=America/New_York flutter test test/calendar_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/src/data/calendar.dart';
import 'package:obhijatra_manager/src/data/export.dart';

/// The calendar date of [day], to compare dates without clock times.
DateTime date(DateTime day) => DateTime.utc(day.year, day.month, day.day);

void main() {
  final zone = DateTime(2026, 3, 9).timeZoneName;

  test('every day of 2025 to 2027 moves by exactly one calendar day, and '
      'stays at midnight ($zone)', () {
    for (var day = DateTime(2025); day.year < 2028; day = addDays(day, 1)) {
      final before = addDays(day, -1);
      final after = addDays(day, 1);
      for (final moved in <DateTime>[before, after]) {
        expect(moved.hour, 0, reason: '$day');
        expect(moved.minute, 0, reason: '$day');
      }
      expect(date(day).difference(date(before)).inDays, 1, reason: '$day');
      expect(date(after).difference(date(day)).inDays, 1, reason: '$day');
    }
  });

  test('the days around the 2026 changes ($zone)', () {
    // America/New_York: 8 March is 23 hours long; 1 November is 25.
    expect(addDays(DateTime(2026, 3, 9), -1), DateTime(2026, 3, 8));
    expect(addDays(DateTime(2026, 3, 9), -6), DateTime(2026, 3, 3));
    expect(addDays(DateTime(2026, 11, 2), -1), DateTime(2026, 11));
    // Europe/London: 29 March is 23 hours long; 25 October is 25.
    expect(addDays(DateTime(2026, 3, 30), -1), DateTime(2026, 3, 29));
    expect(addDays(DateTime(2026, 4, 4), -6), DateTime(2026, 3, 29));
    expect(addDays(DateTime(2026, 10, 26), -1), DateTime(2026, 10, 25));
    // Month and year ends.
    expect(addDays(DateTime(2026, 3), -1), DateTime(2026, 2, 28));
    expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027));
  });

  test('a download "from 1 March to 8 March" covers both whole days '
      '($zone)', () {
    final export = SubmissionExport(
      formRecordId: 'f1',
      formId: 'household_visit',
      firstDay: DateTime(2026, 3, 1, 13),
      lastDay: DateTime(2026, 3, 8, 22),
    );
    expect(export.from, DateTime(2026, 3));
    expect(export.to, DateTime(2026, 3, 9));
  });

  test('24 hours is not a day where the clocks change ($zone)', () {
    final midnight = DateTime(2026, 3, 9);
    final hours = midnight.subtract(const Duration(days: 1));
    if (midnight.timeZoneOffset != DateTime(2026, 3, 7).timeZoneOffset) {
      // What the old code did: the day before at 23:00, a day too early.
      expect(hours.day, 7);
    }
    expect(addDays(midnight, -1).day, 8);
  });
}
