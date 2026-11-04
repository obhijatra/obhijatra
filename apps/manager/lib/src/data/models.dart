import 'package:flutter/foundation.dart';

/// Where a submission stands in the review. The server stores [wire].
enum ReviewState {
  /// Arrived from a phone; nobody has looked at it yet.
  received('Received'),

  /// Changed after it arrived.
  edited('Edited'),

  /// A reviewer found something to check.
  hasIssues('HasIssues'),

  /// A reviewer accepted it.
  approved('Approved'),

  /// A reviewer turned it down.
  rejected('Rejected');

  const ReviewState(this.wire);

  /// The value stored by the server.
  final String wire;

  /// Reads a stored value; anything unknown counts as [received].
  static ReviewState fromWire(String? wire) => values.firstWhere(
    (state) => state.wire == wire,
    orElse: () => ReviewState.received,
  );
}

/// The signed-in member of staff.
@immutable
class StaffUser {
  /// Creates a staff user.
  const StaffUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  /// Record id.
  final String id;

  /// Full name; may be empty.
  final String name;

  /// Sign-in email.
  final String email;

  /// One of the server's staff roles, for example `org_admin`.
  final String role;

  /// The name to show: the full name, or the email when there is none.
  String get displayName => name.trim().isEmpty ? email : name.trim();

  /// Up to two capital letters for the avatar.
  String get initials {
    final parts = displayName
        .split(RegExp(r'[\s@.]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = String.fromCharCode(parts.first.runes.first);
    if (parts.length == 1) return first.toUpperCase();
    final second = String.fromCharCode(parts[1].runes.first);
    return (first + second).toUpperCase();
  }

  /// Organisation admins upload and publish forms.
  bool get isOrgAdmin => role == 'org_admin';

  /// Whether the server lets this role change a submission's review state.
  bool get canReview =>
      role == 'org_admin' || role == 'supervisor' || role == 'branch_manager';
}

/// One uploaded version of a form.
@immutable
class FormVersion {
  /// Creates a version.
  const FormVersion({
    required this.id,
    required this.formRecordId,
    required this.version,
    required this.published,
    required this.created,
    required this.xformFile,
    this.publishedAt,
  });

  /// Record id.
  final String id;

  /// Record id of the form this belongs to.
  final String formRecordId;

  /// The version string inside the XForm.
  final String version;

  /// Published versions are read-only.
  final bool published;

  /// When it was uploaded.
  final DateTime created;

  /// When it was published, if it was.
  final DateTime? publishedAt;

  /// Stored file name of the XForm.
  final String xformFile;
}

/// A form with its versions, newest first.
@immutable
class FormSummary {
  /// Creates a form.
  const FormSummary({
    required this.id,
    required this.formId,
    required this.title,
    required this.versions,
  });

  /// Record id.
  final String id;

  /// The XForm's own form id.
  final String formId;

  /// Title; may be empty.
  final String title;

  /// Versions you may see, newest first.
  final List<FormVersion> versions;

  /// The title, or the form id when there is no title.
  String get displayTitle => title.trim().isEmpty ? formId : title.trim();

  /// The newest published version, if any.
  FormVersion? get latestPublished {
    for (final version in versions) {
      if (version.published) return version;
    }
    return null;
  }
}

/// One row of the submissions table.
@immutable
class SubmissionRow {
  /// Creates a row.
  const SubmissionRow({
    required this.id,
    required this.instanceId,
    required this.formRecordId,
    required this.formVersionId,
    required this.formTitle,
    required this.collector,
    required this.locationPath,
    required this.receivedAt,
    required this.state,
    required this.comment,
    required this.commentSupported,
  });

  /// Record id.
  final String id;

  /// The instance id inside the XML.
  final String instanceId;

  /// Record id of the form.
  final String formRecordId;

  /// Record id of the form version the phone used.
  final String formVersionId;

  /// Form title, or empty when the server did not say.
  final String formTitle;

  /// Name of the field officer, or empty when the server did not say.
  final String collector;

  /// Materialised location path, for example `/abc.../def.../`.
  final String locationPath;

  /// When the server received it.
  final DateTime receivedAt;

  /// Review state.
  final ReviewState state;

  /// The reviewer's note, if the server stores one and one was left.
  final String comment;

  /// Whether the server returned a review note field at all.
  final bool commentSupported;

  /// Copy with a new state and note.
  SubmissionRow withReview(ReviewState newState, String newComment) =>
      SubmissionRow(
        id: id,
        instanceId: instanceId,
        formRecordId: formRecordId,
        formVersionId: formVersionId,
        formTitle: formTitle,
        collector: collector,
        locationPath: locationPath,
        receivedAt: receivedAt,
        state: newState,
        comment: newComment,
        commentSupported: commentSupported,
      );
}

/// One page of submissions.
@immutable
class SubmissionPage {
  /// Creates a page.
  const SubmissionPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  /// The rows on this page.
  final List<SubmissionRow> items;

  /// 1-based page number.
  final int page;

  /// Rows per page.
  final int perPage;

  /// Rows matching the filters, over all pages.
  final int totalItems;

  /// Number of pages.
  final int totalPages;
}

/// Everything the server needs to find a page of submissions.
@immutable
class SubmissionQuery {
  /// Creates a query.
  const SubmissionQuery({
    this.formRecordId,
    this.from,
    this.to,
    this.state,
    this.page = 1,
  });

  /// Only this form.
  final String? formRecordId;

  /// Received at or after this moment.
  final DateTime? from;

  /// Received before this moment.
  final DateTime? to;

  /// Only this review state.
  final ReviewState? state;

  /// 1-based page.
  final int page;

  /// How many rows the server sends per page.
  static const int perPage = 50;

  /// Copy with some parts replaced. Use [clearForm], [clearState] to unset.
  SubmissionQuery copyWith({
    String? formRecordId,
    bool clearForm = false,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    ReviewState? state,
    bool clearState = false,
    int? page,
  }) => SubmissionQuery(
    formRecordId: clearForm ? null : (formRecordId ?? this.formRecordId),
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
    state: clearState ? null : (state ?? this.state),
    page: page ?? this.page,
  );

  /// The same filters on page 1 and without a review state: what the counts
  /// beside the review tabs are based on.
  SubmissionQuery get forCounts =>
      SubmissionQuery(formRecordId: formRecordId, from: from, to: to);

  @override
  bool operator ==(Object other) =>
      other is SubmissionQuery &&
      other.formRecordId == formRecordId &&
      other.from == from &&
      other.to == to &&
      other.state == state &&
      other.page == page;

  @override
  int get hashCode => Object.hash(formRecordId, from, to, state, page);
}

/// One answer in a submission. A protected answer carries no value at all:
/// the value is dropped while the XML is read, so no screen can show it.
@immutable
class Answer {
  /// An ordinary answer.
  const Answer.shown({required this.label, required String this.value})
    : isProtected = false;

  /// A protected answer; there is deliberately nowhere to keep its value.
  const Answer.protected({required this.label})
    : value = null,
      isProtected = true;

  /// The question's label (or its name when the form has no label).
  final String label;

  /// The answer text; always null when [isProtected].
  final String? value;

  /// Whether the form marks this answer as protected.
  final bool isProtected;
}
