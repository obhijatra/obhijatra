import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:obhijatra_core/src/db/device_database.dart';
import 'package:obhijatra_core/src/forms/form_entry.dart';

/// Forms being filled in. Save after every screen so that a crash or a
/// flat battery never loses more than the current screen.
final class DraftRepository {
  /// Creates the repository on [db].
  DraftRepository(this._db);

  final DeviceDatabase _db;

  /// Saves the current state of [session] as its draft.
  Future<void> save(FormEntrySession session) async {
    final now = clock.now().toUtc();
    final xml = session.saveDraft();
    await _db
        .into(_db.drafts)
        .insert(
          DraftsCompanion.insert(
            instanceId: session.instanceId,
            formId: session.form.formId,
            formVersion: session.form.version,
            instanceXml: xml,
            createdAt: now,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (old) =>
                DraftsCompanion(instanceXml: Value(xml), updatedAt: Value(now)),
          ),
        );
  }

  /// The draft with [instanceId], if any.
  Future<Draft?> find(String instanceId) => (_db.select(
    _db.drafts,
  )..where((d) => d.instanceId.equals(instanceId))).getSingleOrNull();

  /// Every draft, most recently saved first.
  Future<List<Draft>> all() => (_db.select(
    _db.drafts,
  )..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])).get();

  /// Every draft, most recently saved first, now and after every change
  /// (a save, a delete, or a draft finished into the outbox).
  Stream<List<Draft>> watchDrafts() => (_db.select(
    _db.drafts,
  )..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])).watch();

  /// Discards the draft with [instanceId] (the user chose to delete it).
  Future<void> delete(String instanceId) => (_db.delete(
    _db.drafts,
  )..where((d) => d.instanceId.equals(instanceId))).go();
}
