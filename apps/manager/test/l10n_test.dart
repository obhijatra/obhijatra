import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> load(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

Set<String> placeholders(String s) =>
    RegExp(r'\{([A-Za-z_]\w*)\s*[,}]')
        .allMatches(s)
        .map((m) => m.group(1)!)
        .toSet();

void main() {
  final en = load('app_en.arb');
  final bn = load('app_bn.arb');
  final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
  final bnKeys = bn.keys.where((k) => !k.startsWith('@')).toSet();

  test('Bangla has every English string and no extras', () {
    expect(enKeys.difference(bnKeys), isEmpty);
    expect(bnKeys.difference(enKeys), isEmpty);
  });

  test('every Bangla string keeps the same placeholders', () {
    for (final key in enKeys.where((k) => k != '@@locale')) {
      expect(
        placeholders(bn[key] as String),
        placeholders(en[key] as String),
        reason: key,
      );
    }
  });

  test('the Bangla file is marked as a draft for the owner to review', () {
    expect(bn['@@x-translation-status'], 'DRAFT');
  });

  test('no Bangla string is empty', () {
    for (final key in bnKeys.where((k) => k != '@@locale')) {
      expect((bn[key] as String).trim(), isNotEmpty, reason: key);
    }
  });
}
