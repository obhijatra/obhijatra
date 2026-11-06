// Saving a download on Windows and macOS: the chosen file is left alone
// until the first byte, and removed after a failure only if this download
// had written to it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/files/download_saver_io.dart';

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('obhijatra-save'));
  tearDown(() => folder.deleteSync(recursive: true));

  String pathOf(String name) => '${folder.path}${Platform.pathSeparator}$name';

  test('a file chosen to be replaced keeps its contents when the download '
      'fails before its first byte', () async {
    final file = File(pathOf('household_visit_2026-11-06.zip'))
      ..writeAsStringSync('the earlier download');
    final target = FileTarget(file.path);
    await target.discard();
    expect(file.readAsStringSync(), 'the earlier download');
  });

  test('a new file appears only with the first byte, and goes again after '
      'a failure', () async {
    final file = File(pathOf('new.zip'));
    final target = FileTarget(file.path);
    expect(file.existsSync(), isFalse);
    await target.add(<int>[0x50, 0x4B]);
    expect(file.existsSync(), isTrue);
    await target.discard();
    expect(file.existsSync(), isFalse);
  });

  test(
    'a replaced file that was already emptied goes after a failure',
    () async {
      final file = File(pathOf('old.zip'))..writeAsStringSync('old');
      final target = FileTarget(file.path);
      await target.add(<int>[1, 2, 3]);
      await target.discard();
      expect(file.existsSync(), isFalse);
    },
  );

  test(
    'a finished download is exactly the bytes, under the chosen name',
    () async {
      final file = File(pathOf('household_visit_2026-11-06.zip'))
        ..writeAsStringSync('a much longer earlier download');
      final target = FileTarget(file.path);
      await target.add(<int>[0x50, 0x4B, 0x03, 0x04]);
      await target.add(<int>[5, 6]);
      final name = await target.finish(serverName: 'ignored_on_desktop.zip');
      expect(name, 'household_visit_2026-11-06.zip');
      expect(file.readAsBytesSync(), <int>[0x50, 0x4B, 0x03, 0x04, 5, 6]);
    },
  );

  test('a place that cannot be written says so, and leaves nothing', () async {
    final target = FileTarget(pathOf('missing-folder/new.zip'));
    await expectLater(
      target.add(<int>[1]),
      throwsA(
        isA<AppProblem>().having((p) => p.kind, 'kind', ProblemKind.saveFailed),
      ),
    );
    await target.discard();
    expect(Directory(pathOf('missing-folder')).existsSync(), isFalse);
  });
}
