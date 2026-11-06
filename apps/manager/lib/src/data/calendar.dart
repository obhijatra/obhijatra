/// [day]'s date moved by [days] calendar days, at midnight local time.
///
/// Calendar arithmetic, never a number of hours: a day across a
/// daylight-saving change is 23 or 25 hours long, so taking 24 hours from
/// a midnight can land at 23:00 on the day before, or at 01:00 on the same
/// day.
DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);
