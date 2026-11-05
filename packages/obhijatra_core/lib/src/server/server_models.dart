import 'dart:async';

import 'package:obhijatra_core/src/problem.dart';
import 'package:obhijatra_core/src/server/semver.dart';

/// The API version under `/api/obhijatra/v1/` that this core speaks.
const String supportedApiVersion = '1';

/// The largest difference between the phone's clock and the server's that
/// sync accepts. Beyond it the sync engine stops with
/// [ProblemCode.clockSkew]: form times would be wrong, the session would
/// look expired (or valid) when it is not, and device-signed requests
/// (zero-trust milestone) allow only five minutes.
const Duration maxClockSkew = Duration(minutes: 10);

/// The server's answer to `GET /api/obhijatra/v1/meta`.
final class ServerMeta {
  /// Creates the handshake answer.
  const ServerMeta({
    required this.serverVersion,
    required this.schemaVersion,
    required this.apiVersion,
    required this.minClientVersion,
    this.serverTime,
  });

  /// Reads the JSON body of the meta route; [serverTime] is the time in the
  /// answer's HTTP `Date` header, if it had one.
  factory ServerMeta.fromJson(
    Map<String, Object?> json, {
    DateTime? serverTime,
  }) {
    final server = json['server_version'];
    final schema = json['schema_version'];
    final api = json['api_version'];
    final minClient = json['min_client_version'];
    if (server is! String ||
        schema is! num ||
        api is! String ||
        minClient is! String) {
      throw const ObhijatraException(ProblemCode.unexpectedResponse);
    }
    return ServerMeta(
      serverVersion: server,
      schemaVersion: schema.toInt(),
      apiVersion: api,
      minClientVersion: minClient,
      serverTime: serverTime?.toUtc(),
    );
  }

  /// The obhijatra-server release.
  final String serverVersion;

  /// The server database schema version; 0 means not set up yet.
  final int schemaVersion;

  /// The version of the routes under `/api/obhijatra/v1/`.
  final String apiVersion;

  /// The oldest app release the server accepts.
  final String minClientVersion;

  /// The server's clock when it answered (UTC, whole seconds, from the HTTP
  /// `Date` header), or `null` when the answer carried no date.
  final DateTime? serverTime;

  /// Whether the phone's clock, reading [deviceNow] when this answer
  /// arrived, differs from [serverTime] by more than [maxClockSkew], ahead
  /// or behind. `false` when the server sent no time.
  bool clockSkewed(DateTime deviceNow) {
    final server = serverTime;
    if (server == null) return false;
    return server.difference(deviceNow).abs() > maxClockSkew;
  }

  /// Why an app at [appVersion] must not sync with this server, or `null`
  /// when it may.
  ProblemCode? syncBlocker(String appVersion) {
    if (apiVersion != supportedApiVersion) {
      return ProblemCode.serverIncompatible;
    }
    if (schemaVersion < 1) return ProblemCode.serverNotSetUp;
    try {
      if (compareVersions(appVersion, minClientVersion) < 0) {
        return ProblemCode.appUpdateRequired;
      }
    } on FormatException {
      return ProblemCode.serverIncompatible;
    }
    return null;
  }
}

/// The ways to sign in a server offers (`GET /api/obhijatra/v1/signin/methods`).
final class SignInMethods {
  /// Creates the answer.
  const SignInMethods({
    required this.password,
    required this.google,
    required this.phone,
  });

  /// Reads the JSON body of the methods route. A missing `password` counts
  /// as offered (every server offers it); a missing `google` or `phone` as
  /// not offered.
  factory SignInMethods.fromJson(Map<String, Object?> json) => SignInMethods(
    password: json['password'] != false,
    google: json['google'] == true,
    phone: json['phone'] == true,
  );

  /// What a server from before these methods offers: email and password.
  static const SignInMethods passwordOnly = SignInMethods(
    password: true,
    google: false,
    phone: false,
  );

  /// Email address and password.
  final bool password;

  /// Google, in a secure browser tab.
  final bool google;

  /// A 6-digit code sent by SMS to the account's mobile number.
  final bool phone;
}

/// The number of digits in an SMS sign-in code.
const int phoneCodeLength = 6;

/// The server's answer to a request for an SMS sign-in code. It is the same
/// whether or not the number belongs to an account (then no SMS is sent).
final class PhoneCodeRequest {
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

  /// How long to wait before offering to send a new code.
  final Duration resendAfter;
}

/// Lets the person stop a sign-in that waits for them, such as Google's page
/// in the browser: pass it to `ObhijatraServer.signInWithGoogle` and call
/// [cancel] when they tap Cancel. A sign-in that finishes after [cancel] is
/// thrown away.
final class SignInCancellation {
  final Completer<void> _cancelled = Completer<void>();

  /// Whether [cancel] was called.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _cancelled.future;

  /// Stops the sign-in; calling it again does nothing.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

/// The fewest characters a password may have (the server's rule).
const int minPasswordLength = 12;

/// The most characters a password may have (the server's limit).
const int maxPasswordLength = 71;

/// The field user signed in on this device.
final class SignedInUser {
  /// Creates the user description.
  const SignedInUser({
    required this.id,
    required this.email,
    required this.name,
    required this.locationPath,
    this.mustChangePassword = false,
  });

  /// The `field_users` record id.
  final String id;

  /// The sign-in email.
  final String email;

  /// The display name.
  final String name;

  /// The user's place in the organisation tree.
  final String locationPath;

  /// Whether an organisation admin gave this account a one-time password,
  /// so the person must choose their own (see
  /// `ObhijatraServer.changePassword`) before anything else works.
  final bool mustChangePassword;
}

/// A published form version on the server.
final class RemoteFormVersion {
  /// Creates the description.
  const RemoteFormVersion({
    required this.serverId,
    required this.formServerId,
    required this.formId,
    required this.title,
    required this.version,
    required this.xformFileName,
    required this.publishedAt,
  });

  /// The `form_versions` record id.
  final String serverId;

  /// The `forms` record id.
  final String formServerId;

  /// The XForm form id.
  final String formId;

  /// The form title.
  final String? title;

  /// The XForm version string.
  final String version;

  /// The stored name of the XForm file on the server.
  final String xformFileName;

  /// When the version was published, if the server says.
  final DateTime? publishedAt;
}

/// How the server answered a submission upload that it accepted.
enum ReceiptStatus {
  /// Stored for the first time.
  received,

  /// Already stored by an earlier try; nothing changed.
  alreadyReceived,
}

/// The server's confirmation that it holds a submission.
final class SubmissionReceipt {
  /// Creates the receipt.
  const SubmissionReceipt({
    required this.serverId,
    required this.instanceId,
    required this.status,
  });

  /// The `submissions` record id.
  final String serverId;

  /// The instance id the server stored.
  final String instanceId;

  /// Whether this try stored it or an earlier one did.
  final ReceiptStatus status;
}
