import 'dart:io';

import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:test/test.dart';

void main() {
  test('core reports its version', () {
    expect(obhijatraCoreVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')));
  });

  test('pubspec version matches the version constant', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(match!.group(1), obhijatraCoreVersion);
  });

  test('core stays pure Dart (ADR 0004 import rules)', () {
    final offenders = <String>[];
    final forbidden = <Pattern>[
      RegExp(r'''import\s+['"]package:flutter'''),
      RegExp(r'''import\s+['"]dart:(html|js|js_interop|ui)'''),
      // Platform libraries come from the apps, so the core also runs on
      // the web (JavaScript and Wasm).
      RegExp(r'''import\s+['"]dart:(io|ffi|isolate)'''),
      RegExp(r'''import\s+['"]package:js/'''),
      // From drift, only the platform-neutral library is allowed.
      RegExp(r'''import\s+['"]package:drift/(?!drift\.dart['"])'''),
    ];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final pattern in forbidden) {
        if (pattern.allMatches(text).isNotEmpty) offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
