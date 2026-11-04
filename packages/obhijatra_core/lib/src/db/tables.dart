import 'package:drift/drift.dart';

/// Where a finalised submission is on its way to the server.
///
/// Stored by name, so values may be added but never renamed.
enum OutboxState {
  /// Waiting to be sent (first try or a retry after a temporary problem).
  queued,

  /// Being sent right now; found at start-up it means the app stopped
  /// mid-send, and the entry is queued again (the server is idempotent).
  sending,

  /// The server confirmed it holds this submission. Final.
  sent,

  /// The server refused it for a reason that needs a person to act.
  problem,
}

/// Forms known on this device (one row per form id).
@DataClassName('CachedForm')
class CachedForms extends Table {
  /// The XForm's form id (the `id` attribute of its primary instance).
  TextColumn get formId => text()();

  /// The form title shown in lists.
  TextColumn get title => text().nullable()();

  /// The id of the server's `forms` record, if downloaded from a server.
  TextColumn get serverId => text().nullable()();

  /// When this row last changed.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {formId};
}

/// Every downloaded version of every form; a version is immutable.
@DataClassName('CachedFormVersion')
class CachedFormVersions extends Table {
  /// The form id this version belongs to.
  TextColumn get formId => text()();

  /// The `version` attribute of the XForm's primary instance.
  TextColumn get version => text()();

  /// The form title from this version's XForm.
  TextColumn get title => text().nullable()();

  /// The complete XForm XML.
  TextColumn get xformXml => text()();

  /// JSON list of the version's media files (empty until media ships).
  TextColumn get manifest => text().withDefault(const Constant('[]'))();

  /// The id of the server's `form_versions` record, if any.
  TextColumn get serverId => text().nullable()();

  /// When the server published this version, if known.
  DateTimeColumn get publishedAt => dateTime().nullable()();

  /// When this device stored this version.
  DateTimeColumn get downloadedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {formId, version};
}

/// Forms being filled in, saved after every screen so nothing is lost.
@DataClassName('Draft')
@TableIndex(name: 'drafts_form', columns: {#formId, #formVersion})
class Drafts extends Table {
  /// The instance's `meta/instanceID`, kept when the draft is finalised.
  TextColumn get instanceId => text()();

  /// The form id.
  TextColumn get formId => text()();

  /// The form version the draft is filled against.
  TextColumn get formVersion => text()();

  /// The partial instance XML (non-relevant answers included).
  TextColumn get instanceXml => text()();

  /// When the draft was first saved.
  DateTimeColumn get createdAt => dateTime()();

  /// When the draft was last saved.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {instanceId};
}

/// Finalised submissions waiting for, or confirmed by, the server.
///
/// A row is never deleted before the server confirms it; [instanceXml] is
/// sent byte for byte the same on every try, because the server recognises
/// a retry by the SHA-256 of the XML. Once the server confirms it
/// ([OutboxState.sent]), the XML and the attachment list are emptied and
/// the files removed: the row stays as a small receipt (instance id, form,
/// times, state) for the list of sent forms.
@DataClassName('OutboxEntry')
@TableIndex(name: 'outbox_state_due', columns: {#state, #nextAttemptAt})
class Outbox extends Table {
  /// The submission's `meta/instanceID`; the server's idempotency key.
  TextColumn get instanceId => text()();

  /// The form id.
  TextColumn get formId => text()();

  /// The form version the submission was filled with.
  TextColumn get formVersion => text()();

  /// The final instance XML exactly as it will be uploaded; empty once the
  /// server has confirmed the submission.
  TextColumn get instanceXml => text()();

  /// The SHA-256 (lower-case hex) of the instance XML as the form engine
  /// finalised it, before field protection, so that queuing the same
  /// instance again is recognised without protecting it again, and still
  /// after the XML is removed. Added in schema version 2.
  TextColumn get plaintextSha256 => text().nullable()();

  /// JSON list of local paths of files sent with the submission; empty once
  /// the server has confirmed the submission.
  TextColumn get attachments => text().withDefault(const Constant('[]'))();

  /// Where the submission is on its way to the server.
  TextColumn get state => textEnum<OutboxState>()();

  /// How many times sending has been tried since it was last queued by a
  /// person.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// The [ProblemCode] name of the last failure, if any.
  TextColumn get lastError => text().nullable()();

  /// The server's own message for the last failure, for support staff.
  TextColumn get lastErrorMessage => text().nullable()();

  /// Not to be tried before this time (exponential backoff).
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  /// The id of the server's `submissions` record, once sent.
  TextColumn get serverId => text().nullable()();

  /// When the submission was finalised.
  DateTimeColumn get createdAt => dateTime()();

  /// When this row last changed.
  DateTimeColumn get updatedAt => dateTime()();

  /// When the server confirmed the submission.
  DateTimeColumn get sentAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {instanceId};
}

/// Small key-value settings (session, last sync time and the like).
@DataClassName('DeviceSetting')
class DeviceSettings extends Table {
  @override
  String get tableName => 'settings';

  /// The setting's name.
  TextColumn get key => text()();

  /// The setting's value.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
