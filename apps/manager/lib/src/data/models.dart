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
    this.phone = '',
  });

  /// Record id.
  final String id;

  /// Full name; may be empty.
  final String name;

  /// Sign-in email; may be empty for someone who signs in by SMS code.
  final String email;

  /// Mobile number in international form, or empty.
  final String phone;

  /// One of the server's staff roles, for example `org_admin`.
  final String role;

  /// The name to show: the full name, else the email, else the number.
  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return phone;
  }

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

// ------------------------------------------------------------ sign-in

/// The ways to sign in a server offers. Email and password always work.
@immutable
class SignInMethods {
  /// Creates the set of methods.
  const SignInMethods({this.google = false, this.phone = false});

  /// Reads the server's answer.
  factory SignInMethods.fromJson(Map<String, dynamic> json) => SignInMethods(
    google: json['google'] == true,
    phone: json['phone'] == true,
  );

  /// Email and password only (also what an older server offers).
  static const SignInMethods passwordOnly = SignInMethods();

  /// "Continue with Google" is offered.
  final bool google;

  /// "Sign in with an SMS code" is offered.
  final bool phone;

  @override
  bool operator ==(Object other) =>
      other is SignInMethods && other.google == google && other.phone == phone;

  @override
  int get hashCode => Object.hash(google, phone);
}

/// The answer to "send me a code". It looks the same whether or not the
/// number has an account, so it says nothing about who has one.
@immutable
class PhoneCodeRequest {
  /// Creates the answer.
  const PhoneCodeRequest({
    required this.codeId,
    required this.phone,
    required this.expiresIn,
    required this.resendAfter,
  });

  /// Names the code when it is checked.
  final String codeId;

  /// The number the code was asked for, in international form.
  final String phone;

  /// How long the code works.
  final Duration expiresIn;

  /// How long to wait before offering a new code.
  final Duration resendAfter;
}

/// How the server calls the SMS provider.
enum SmsMethod {
  /// The details go in the body (most providers).
  post('POST'),

  /// The details go in the address.
  get('GET');

  const SmsMethod(this.wire);

  /// The value the server stores.
  final String wire;

  /// Reads a stored value; anything else counts as [post].
  static SmsMethod fromWire(String? wire) =>
      (wire ?? '').toUpperCase() == 'GET' ? SmsMethod.get : SmsMethod.post;
}

/// How the body of a POST request is written.
enum SmsBodyFormat {
  /// `application/json`.
  json('json'),

  /// `application/x-www-form-urlencoded`.
  form('form');

  const SmsBodyFormat(this.wire);

  /// The value the server stores.
  final String wire;

  /// Reads a stored value; anything else counts as [json].
  static SmsBodyFormat fromWire(String? wire) =>
      (wire ?? '').toLowerCase() == 'form' ? SmsBodyFormat.form : json;
}

/// One extra header sent to the SMS provider.
@immutable
class SmsHeader {
  /// Creates a header.
  const SmsHeader({required this.name, required this.value});

  /// Reads a header.
  factory SmsHeader.fromJson(Map<String, dynamic> json) =>
      SmsHeader(name: _text(json['name']), value: _text(json['value']));

  /// For example `Authorization`.
  final String name;

  /// For example `Bearer {secret}`.
  final String value;

  /// The shape the server reads.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is SmsHeader && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);
}

/// The SMS provider settings the server keeps. The secret key itself is
/// never sent back, only whether one is saved.
@immutable
class SmsProviderSettings {
  /// Creates the settings; the defaults are an empty POST with a JSON body.
  const SmsProviderSettings({
    this.method = SmsMethod.post,
    this.url = '',
    this.bodyFormat = SmsBodyFormat.json,
    this.body = '',
    this.headers = const <SmsHeader>[],
    this.secretSet = false,
    this.successText = '',
  });

  /// Reads the server's answer.
  factory SmsProviderSettings.fromJson(Map<String, dynamic> json) =>
      SmsProviderSettings(
        method: SmsMethod.fromWire(json['method'] as String?),
        url: _text(json['url']),
        bodyFormat: SmsBodyFormat.fromWire(json['content_type'] as String?),
        body: _text(json['body']),
        headers: <SmsHeader>[
          for (final header in _list(json['headers']))
            if (header is Map<String, dynamic>) SmsHeader.fromJson(header),
        ],
        secretSet: json['secret_set'] == true,
        successText: _text(json['success_text']),
      );

  /// GET or POST.
  final SmsMethod method;

  /// The provider's address for sending; may hold placeholders.
  final String url;

  /// JSON or form (POST only).
  final SmsBodyFormat bodyFormat;

  /// The body template (POST only).
  final String body;

  /// Extra headers.
  final List<SmsHeader> headers;

  /// Whether a secret key is saved.
  final bool secretSet;

  /// Text the provider's reply must contain; empty means any 2xx reply.
  final String successText;
}

/// What happened when the server last asked the provider to send an SMS.
@immutable
class SmsSendResult {
  /// Creates a result.
  const SmsSendResult({
    required this.at,
    required this.ok,
    required this.status,
    required this.reply,
  });

  /// Reads the server's answer.
  factory SmsSendResult.fromJson(Map<String, dynamic> json) => SmsSendResult(
    at: DateTime.tryParse(_text(json['at']))?.toLocal() ?? DateTime.now(),
    ok: json['ok'] == true,
    status: (json['status'] as num?)?.toInt() ?? 0,
    reply: _text(json['reply']),
  );

  /// When it was sent.
  final DateTime at;

  /// Whether the provider accepted the message.
  final bool ok;

  /// The provider's HTTP status; 0 when it did not answer.
  final int status;

  /// The start of the provider's reply, or what went wrong.
  final String reply;
}

/// Google sign-in as an org admin sees it.
@immutable
class GoogleSignInSettings {
  /// Creates the settings.
  const GoogleSignInSettings({
    this.enabled = false,
    this.clientId = '',
    this.clientSecretSet = false,
    this.redirectUrl = '',
  });

  /// Reads the server's answer.
  factory GoogleSignInSettings.fromJson(Map<String, dynamic> json) =>
      GoogleSignInSettings(
        enabled: json['enabled'] == true,
        clientId: _text(json['client_id']),
        clientSecretSet: json['client_secret_set'] == true,
        redirectUrl: _text(json['redirect_url']),
      );

  /// Whether "Continue with Google" is offered.
  final bool enabled;

  /// The client ID from the organisation's Google Cloud project.
  final String clientId;

  /// Whether a client secret is saved.
  final bool clientSecretSet;

  /// The address to register with Google as an authorised redirect URI.
  final String redirectUrl;

  /// Whether Google will accept [redirectUrl]: it must be `https://` with a
  /// domain name, not a bare IP address.
  bool get redirectUrlUsable {
    final uri = Uri.tryParse(redirectUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    final host = uri.host;
    final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
    return !ipv4 && !host.contains(':') && host.contains('.');
  }
}

/// SMS-code sign-in as an org admin sees it.
@immutable
class PhoneSignInSettings {
  /// Creates the settings.
  const PhoneSignInSettings({
    this.enabled = false,
    this.sms = const SmsProviderSettings(),
    this.lastSend,
    this.codeLifetime = const Duration(minutes: 5),
  });

  /// Reads the server's answer.
  factory PhoneSignInSettings.fromJson(Map<String, dynamic> json) {
    final sms = json['sms'];
    final last = json['last_send'];
    return PhoneSignInSettings(
      enabled: json['enabled'] == true,
      sms: sms is Map<String, dynamic>
          ? SmsProviderSettings.fromJson(sms)
          : const SmsProviderSettings(),
      lastSend: last is Map<String, dynamic>
          ? SmsSendResult.fromJson(last)
          : null,
      codeLifetime: Duration(
        seconds: (json['code_lifetime_seconds'] as num?)?.toInt() ?? 300,
      ),
    );
  }

  /// Whether "Sign in with an SMS code" is offered.
  final bool enabled;

  /// How the server reaches the SMS provider.
  final SmsProviderSettings sms;

  /// The latest send since the server started, if any.
  final SmsSendResult? lastSend;

  /// How long a code works.
  final Duration codeLifetime;
}

/// Every sign-in setting an org admin can change.
@immutable
class SignInSettings {
  /// Creates the settings.
  const SignInSettings({
    this.google = const GoogleSignInSettings(),
    this.phone = const PhoneSignInSettings(),
  });

  /// Reads the server's answer.
  factory SignInSettings.fromJson(Map<String, dynamic> json) {
    final google = json['google'];
    final phone = json['phone'];
    return SignInSettings(
      google: google is Map<String, dynamic>
          ? GoogleSignInSettings.fromJson(google)
          : const GoogleSignInSettings(),
      phone: phone is Map<String, dynamic>
          ? PhoneSignInSettings.fromJson(phone)
          : const PhoneSignInSettings(),
    );
  }

  /// Google sign-in.
  final GoogleSignInSettings google;

  /// SMS-code sign-in.
  final PhoneSignInSettings phone;
}

/// SMS provider settings as typed, to save or to test. An empty [secret]
/// keeps the saved key.
@immutable
class SmsProviderDraft {
  /// Creates a draft.
  const SmsProviderDraft({
    required this.method,
    required this.url,
    required this.bodyFormat,
    required this.body,
    required this.headers,
    required this.secret,
    required this.successText,
  });

  /// GET or POST.
  final SmsMethod method;

  /// The provider's address.
  final String url;

  /// JSON or form (POST only).
  final SmsBodyFormat bodyFormat;

  /// The body template (POST only).
  final String body;

  /// Extra headers, without empty rows.
  final List<SmsHeader> headers;

  /// A new secret key, or empty to keep the saved one.
  final String secret;

  /// Optional text the provider's reply must contain.
  final String successText;

  /// The shape the server reads.
  Map<String, dynamic> toJson() {
    final post = method == SmsMethod.post;
    return <String, dynamic>{
      'method': method.wire,
      'url': url,
      'content_type': post ? bodyFormat.wire : '',
      'body': post ? body : '',
      'headers': <Map<String, dynamic>>[
        for (final header in headers) header.toJson(),
      ],
      'secret': secret,
      'success_text': successText,
    };
  }
}

/// What an org admin saves. Empty secrets keep the saved ones.
@immutable
class SignInSettingsUpdate {
  /// Creates the update.
  const SignInSettingsUpdate({
    required this.googleEnabled,
    required this.googleClientId,
    required this.googleClientSecret,
    required this.phoneEnabled,
    required this.sms,
  });

  /// Whether Google sign-in is on.
  final bool googleEnabled;

  /// The Google client ID.
  final String googleClientId;

  /// A new Google client secret, or empty to keep the saved one.
  final String googleClientSecret;

  /// Whether SMS-code sign-in is on.
  final bool phoneEnabled;

  /// The SMS provider settings.
  final SmsProviderDraft sms;

  /// The shape the server reads.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'google': <String, dynamic>{
      'enabled': googleEnabled,
      'client_id': googleClientId,
      'client_secret': googleClientSecret,
    },
    'phone': <String, dynamic>{'enabled': phoneEnabled, 'sms': sms.toJson()},
  };
}

String _text(Object? value) => value is String ? value : '';

List<Object?> _list(Object? value) =>
    value is List<Object?> ? value : const <Object?>[];
