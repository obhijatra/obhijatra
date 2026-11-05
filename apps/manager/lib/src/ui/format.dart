import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';

/// Date and time text in the language on screen.
abstract final class Format {
  static String _locale(BuildContext context) =>
      Localizations.localeOf(context).toString();

  /// "Today, 10:32", "Yesterday, 16:20" or "2 November, 14:10".
  static String when(BuildContext context, DateTime moment, {DateTime? now}) {
    final l10n = AppLocalizations.of(context);
    final locale = _locale(context);
    final current = now ?? DateTime.now();
    final time = DateFormat.Hm(locale).format(moment);
    final today = DateTime(current.year, current.month, current.day);
    final day = DateTime(moment.year, moment.month, moment.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return l10n.dateToday(time);
    if (difference == 1) return l10n.dateYesterday(time);
    final pattern = moment.year == current.year ? 'd MMMM' : 'd MMMM y';
    return l10n.dateOther(DateFormat(pattern, locale).format(moment), time);
  }

  /// "14:10" today, otherwise "7 November, 00:05": a moment in the next
  /// few hours.
  static String clock(BuildContext context, DateTime moment, {DateTime? now}) {
    final locale = _locale(context);
    final current = now ?? DateTime.now();
    final sameDay =
        moment.year == current.year &&
        moment.month == current.month &&
        moment.day == current.day;
    final time = DateFormat.Hm(locale).format(moment);
    if (sameDay) return time;
    return '${DateFormat('d MMMM', locale).format(moment)}, $time';
  }

  /// "12 October 2026".
  static String day(BuildContext context, DateTime moment) =>
      DateFormat('d MMMM y', _locale(context)).format(moment);

  /// "12 Oct 2026", for the custom date range.
  static String shortDay(BuildContext context, DateTime moment) =>
      DateFormat('d MMM y', _locale(context)).format(moment);

  /// A whole number with the language's digits and separators.
  static String number(BuildContext context, int value) =>
      NumberFormat.decimalPattern(_locale(context)).format(value);
}
