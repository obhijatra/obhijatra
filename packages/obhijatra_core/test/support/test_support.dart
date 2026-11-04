// Shared helpers for the obhijatra_core tests: databases, key stores, the
// sample form and a form-filling script.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:obhijatra_core/obhijatra_core.dart';

/// The sample household-visit XForm written for these tests.
final String householdVisitXForm = File('test/fixtures/household_visit.xml')
    .readAsStringSync();

/// The sample form's id and version.
const String sampleFormId = 'household_visit';

/// The sample form's version.
const String sampleFormVersion = '2026110401';

/// A fresh in-memory device database.
DeviceDatabase memoryDatabase() => DeviceDatabase(NativeDatabase.memory());

/// A key store that keeps the key in memory.
final class MemoryKeyStore implements KeyStore {
  /// Creates an empty key store, or one holding [hex].
  MemoryKeyStore([this.hex]);

  /// The stored key, as hex.
  String? hex;

  /// How many keys were created.
  int created = 0;

  @override
  Future<DatabaseKey?> readDatabaseKey() async {
    final stored = hex;
    return stored == null ? null : DatabaseKey.fromHex(stored);
  }

  @override
  Future<DatabaseKey> createDatabaseKey() async {
    created++;
    final key = DatabaseKey.generate();
    hex = key.toHex();
    return key;
  }
}

/// Opens an encrypted SQLite3MultipleCiphers file, as the apps will.
final class FileDatabaseOpener implements DeviceDatabaseOpener {
  /// Creates an opener for [file].
  FileDatabaseOpener(this.file);

  /// The database file.
  final File file;

  @override
  Future<bool> databaseExists() async => file.existsSync();

  @override
  QueryExecutor open(DatabaseKey key) {
    final hex = key.toHex();
    return NativeDatabase(
      file,
      setup: (db) {
        db.execute("PRAGMA hexkey = '$hex'");
        // Fail now, not at the first real query, if the key is wrong.
        db.execute('SELECT count(*) FROM sqlite_master');
      },
    );
  }
}

/// Attachment files held in memory, keyed by path.
final class MemoryAttachments implements AttachmentStore {
  /// Creates the store with [files].
  MemoryAttachments([Map<String, List<int>>? files]) : files = files ?? {};

  /// The files, by path.
  final Map<String, List<int>> files;

  @override
  Future<Uint8List> read(String path) async {
    final bytes = files[path];
    if (bytes == null) {
      throw const ObhijatraException(ProblemCode.attachmentMissing);
    }
    return Uint8List.fromList(bytes);
  }
}

/// Answers the question on the current screen of [session] whose label
/// starts with [labelStart] (English labels), failing if it is not there.
ValidationMessage? answerByLabel(
  FormEntrySession session,
  String labelStart,
  String? text,
) {
  final screen = session.screen;
  if (screen is! QuestionScreen) {
    throw StateError('Not on a question screen: $screen');
  }
  final question = screen.questions.firstWhere(
    (q) => (q.label ?? '').startsWith(labelStart),
    orElse: () => throw StateError(
      'No "$labelStart" on screen: '
      '${screen.questions.map((q) => q.label).toList()}',
    ),
  );
  return session.answer(question, text);
}

/// The label of the first question on the current screen, or the screen
/// type when it is not a question screen.
String currentLabel(FormEntrySession session) => switch (session.screen) {
  QuestionScreen(:final questions) => questions.first.label ?? '',
  RepeatPromptScreen() => '<repeat prompt>',
  EndOfFormScreen() => '<end>',
};

/// Fills the sample form for a household that was met, then finalises it.
Future<FinalisedInstance> fillHouseholdVisit({
  String head = 'Rahima Begum',
  String size = '5',
  String children = '2',
  String visitDate = '2026-11-03',
}) async {
  final session = await FormEntrySession.start(xformXml: householdVisitXForm);
  try {
    void step(String label, String value) {
      final problem = answerByLabel(session, label, value);
      if (problem != null) {
        throw StateError('"$label" refused "$value": ${problem.issue}');
      }
      final moved = session.next();
      if (moved is Blocked) {
        throw StateError('Blocked at "$label": ${moved.messages.first.issue}');
      }
    }

    step('Date of visit', visitDate);
    step('What happened', 'met');
    step('Name of the household head', head);
    step('How many people', size);
    step('How many of them', children);
    step('Notes', 'Visited after the morning meeting.');
    final result = session.finalise();
    if (result is! Finalised) throw StateError('Not finalised: $result');
    return result.instance;
  } finally {
    await session.close();
  }
}
