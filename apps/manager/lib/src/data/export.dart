import 'package:flutter/foundation.dart' show immutable;
import 'package:obhijatra_manager/src/data/models.dart';

// Downloading a form's submissions as a zip package in ODK Central's layout
// (docs/decisions/0009-data-export.md).

/// The route that streams the zip package.
const String exportSubmissionsPath = '/api/obhijatra/v1/exports/submissions';

/// What to download: one form, optionally only some days and review
/// states, with or without the submissions' files.
@immutable
class SubmissionExport {
  /// Creates the request.
  const SubmissionExport({
    required this.formRecordId,
    required this.formId,
    this.firstDay,
    this.lastDay,
    this.reviewStates = const <ReviewState>{...ReviewState.values},
    this.includeMedia = true,
  });

  /// The forms record id.
  final String formRecordId;

  /// The form's own id (`form_id`), for the file name.
  final String formId;

  /// The first day included, in the person's own time zone; null for no
  /// start.
  final DateTime? firstDay;

  /// The last day included, in the person's own time zone; null for no
  /// end.
  final DateTime? lastDay;

  /// The review states to include; all of them by default.
  final Set<ReviewState> reviewStates;

  /// Whether photos and other files go in the package.
  final bool includeMedia;

  /// The start: [firstDay] at 00:00 local time, or null.
  DateTime? get from => switch (firstDay) {
    final DateTime day => DateTime(day.year, day.month, day.day),
    null => null,
  };

  /// The end, exclusive: the day after [lastDay] at 00:00 local time, so
  /// "to 30 November" means "before 1 December 00:00", or null.
  DateTime? get to => switch (lastDay) {
    final DateTime day => DateTime(day.year, day.month, day.day + 1),
    null => null,
  };

  /// The request body. Review states are left out when all are chosen.
  Map<String, Object> toJson() => <String, Object>{
    'form': formRecordId,
    if (from case final DateTime start) 'from': rfc3339WithOffset(start),
    if (to case final DateTime end) 'to': rfc3339WithOffset(end),
    if (reviewStates.length < ReviewState.values.length)
      'review_states': <String>[
        // In a fixed order, whatever order they were chosen in.
        for (final state in ReviewState.values)
          if (reviewStates.contains(state)) state.wire,
      ],
    'include_media': includeMedia,
  };
}

/// [moment] (local time) as RFC 3339 with the local offset, for example
/// `2026-11-01T00:00:00+06:00`.
String rfc3339WithOffset(DateTime moment) {
  final local = moment.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
      '${two(local.second)}$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}

/// The name to suggest for the package before the server names it, as the
/// server does: `<form id>_<date>.zip`.
String suggestedExportName(String formId, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final day = '${now.year}-${two(now.month)}-${two(now.day)}';
  return '${safeFileName(formId.isEmpty ? 'submissions' : formId)}_$day.zip';
}

/// The file name in a `Content-Disposition` header, made safe (letters,
/// digits, `.`, `-` and `_` only, ending in `.zip`), or null.
String? exportFileName(String? contentDisposition) {
  if (contentDisposition == null) return null;
  final match = RegExp(r'filename="?([^";]+)"?').firstMatch(contentDisposition);
  if (match == null) return null;
  final name = safeFileName(match.group(1)!);
  return name.toLowerCase().endsWith('.zip') && name.length > 4 ? name : null;
}

/// [name] with every character other than letters, digits, `.`, `-` and
/// `_` replaced by `_`, and no leading dot.
String safeFileName(String name) {
  final safe = name.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
  return safe.replaceFirst(RegExp(r'^\.+'), '');
}

/// The person stopped a download (see `ManagerApi.downloadSubmissions`).
class DownloadStopped implements Exception {
  /// Creates the signal.
  const DownloadStopped();

  @override
  String toString() => 'DownloadStopped';
}
