import 'package:clock/clock.dart';
import 'package:dartrosa/dartrosa.dart';
import 'package:drift/drift.dart';
import 'package:obhijatra_core/src/db/device_database.dart';
import 'package:obhijatra_core/src/forms/xform_info.dart';
import 'package:obhijatra_core/src/problem.dart';
import 'package:obhijatra_core/src/server/obhijatra_server.dart';
import 'package:obhijatra_core/src/server/server_models.dart';

/// What [FormRepository.refreshFromServer] did.
final class FormRefreshResult {
  /// Creates the summary.
  const FormRefreshResult({
    required this.added,
    required this.alreadyCached,
    required this.failed,
  });

  /// Versions downloaded and stored by this refresh.
  final List<CachedFormVersion> added;

  /// Published versions that were already on the device.
  final int alreadyCached;

  /// Versions that could not be stored, with the reason for each.
  final List<({RemoteFormVersion version, ProblemCode problem})> failed;
}

/// The forms and form versions cached on the device for offline use.
final class FormRepository {
  /// Creates the repository on [db].
  FormRepository(this._db);

  final DeviceDatabase _db;

  /// Downloads every published version [server] offers that is not cached
  /// yet. Cached versions are never changed or removed (drafts and queued
  /// submissions may still need them).
  ///
  /// Throws an [ObhijatraException] only when the list itself cannot be
  /// fetched; a version that fails is reported in
  /// [FormRefreshResult.failed].
  Future<FormRefreshResult> refreshFromServer(ObhijatraServer server) async {
    final remote = await server.listPublishedFormVersions();
    final added = <CachedFormVersion>[];
    final failed = <({RemoteFormVersion version, ProblemCode problem})>[];
    var cached = 0;
    for (final version in remote) {
      if (await formVersion(version.formId, version.version) != null) {
        cached++;
        continue;
      }
      try {
        final xml = await server.downloadXForm(version);
        added.add(
          await storeFormVersion(
            xformXml: xml,
            serverId: version.serverId,
            formServerId: version.formServerId,
            publishedAt: version.publishedAt,
            expected: (formId: version.formId, version: version.version),
          ),
        );
      } on ObhijatraException catch (e) {
        if (e.code.isTransient || e.code.blocksSync) rethrow;
        failed.add((version: version, problem: e.code));
      }
    }
    return FormRefreshResult(
      added: added,
      alreadyCached: cached,
      failed: failed,
    );
  }

  /// Checks and stores one XForm version.
  ///
  /// The XForm must load in the form engine and, when [expected] is given,
  /// carry that form id and version. Storing a version that is already
  /// cached with the same XML does nothing; with different XML it is
  /// refused, because published versions never change.
  Future<CachedFormVersion> storeFormVersion({
    required String xformXml,
    String? serverId,
    String? formServerId,
    DateTime? publishedAt,
    ({String formId, String version})? expected,
  }) async {
    final info = XFormInfo.read(xformXml);
    if (expected != null &&
        (info.formId != expected.formId || info.version != expected.version)) {
      throw const ObhijatraException(ProblemCode.formInvalid);
    }
    try {
      await FormDefinition.parse(xformXml);
    } on Object catch (e) {
      throw ObhijatraException(ProblemCode.formInvalid, cause: e);
    }

    final now = clock.now().toUtc();
    return _db.transaction(() async {
      final existing = await formVersion(info.formId, info.version);
      if (existing != null) {
        if (existing.xformXml != xformXml) {
          throw const ObhijatraException(ProblemCode.formInvalid);
        }
        return existing;
      }
      await _db
          .into(_db.cachedForms)
          .insertOnConflictUpdate(
            CachedFormsCompanion.insert(
              formId: info.formId,
              title: Value(info.title),
              serverId: Value(formServerId),
              updatedAt: now,
            ),
          );
      final row = CachedFormVersionsCompanion.insert(
        formId: info.formId,
        version: info.version,
        title: Value(info.title),
        xformXml: xformXml,
        serverId: Value(serverId),
        publishedAt: Value(publishedAt),
        downloadedAt: now,
      );
      return _db.into(_db.cachedFormVersions).insertReturning(row);
    });
  }

  /// Every cached form.
  Future<List<CachedForm>> forms() => (_db.select(
    _db.cachedForms,
  )..orderBy([(f) => OrderingTerm.asc(f.title)])).get();

  /// Every cached version of [formId], newest first.
  Future<List<CachedFormVersion>> versionsOf(String formId) =>
      (_db.select(_db.cachedFormVersions)
            ..where((v) => v.formId.equals(formId))
            ..orderBy([
              (v) => OrderingTerm.desc(v.publishedAt),
              (v) => OrderingTerm.desc(v.downloadedAt),
            ]))
          .get();

  /// The newest cached version of [formId], to start new instances with.
  Future<CachedFormVersion?> latestVersion(String formId) async =>
      (await versionsOf(formId)).firstOrNull;

  /// The cached [version] of [formId], if any.
  Future<CachedFormVersion?> formVersion(String formId, String version) =>
      (_db.select(_db.cachedFormVersions)
            ..where((v) => v.formId.equals(formId) & v.version.equals(version)))
          .getSingleOrNull();
}
