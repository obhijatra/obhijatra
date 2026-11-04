import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';

/// The forms on the phone, by title, kept up to date.
final cachedFormsProvider = StreamProvider<List<CachedForm>>((ref) async* {
  final db = await ref.watch(deviceDatabaseProvider.future);
  yield* (db.select(
    db.cachedForms,
  )..orderBy([(f) => OrderingTerm.asc(f.title)])).watch();
});

/// Drafts, most recently saved first, kept up to date.
final draftsProvider = StreamProvider<List<Draft>>((ref) async* {
  final db = await ref.watch(deviceDatabaseProvider.future);
  yield* (db.select(
    db.drafts,
  )..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])).watch();
});

/// Finished forms (sent or not), newest first, kept up to date.
final outboxEntriesProvider = StreamProvider<List<OutboxEntry>>((ref) async* {
  final db = await ref.watch(deviceDatabaseProvider.future);
  yield* (db.select(db.outbox)
        ..orderBy([(e) => OrderingTerm.desc(e.createdAt)])
        ..limit(100))
      .watch();
});
