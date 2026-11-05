import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/app.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/state/file_picker.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// A file chooser that returns what a test says.
class FakePicker implements FormFilePicker {
  PickedFile? next;

  @override
  Future<PickedFile?> pickFormFile() async => next;
}

/// A spreadsheet chooser that returns what a test says.
class FakeCsvPicker implements CsvFilePicker {
  PickedFile? next;

  /// The size limit the screen asked for, each time.
  final List<int> limits = <int>[];

  @override
  Future<PickedFile?> pickCsvFile({required int maxBytes}) async {
    limits.add(maxBytes);
    return next;
  }
}

PickedFile pickedText(String name, String text) =>
    PickedFile(name: name, bytes: Uint8List.fromList(utf8.encode(text)));

/// Starts the whole app against [api] at [size], in [lang].
Future<void> pumpManager(
  WidgetTester tester,
  FakeManagerApi api, {
  String lang = 'en',
  Size size = const Size(1280, 900),
  FakePicker? picker,
  FakeCsvPicker? csvPicker,
  List<Override> overrides = const <Override>[],
  bool settle = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ManagerRoot(
      overrides: <Override>[
        apiProvider.overrideWithValue(api),
        initialLocaleProvider.overrideWithValue(Locale(lang)),
        if (picker != null) formFilePickerProvider.overrideWithValue(picker),
        if (csvPicker != null)
          csvFilePickerProvider.overrideWithValue(csvPicker),
        ...overrides,
      ],
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The strings of the language on screen.
AppLocalizations l10nOf(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

StaffUser staff(String role) => StaffUser(
  id: 'u1',
  name: 'Tania Rahman',
  email: 'tania@example.org',
  role: role,
);

/// The plain text of everything drawn on screen.
String everyWord(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((w) => w.text.toPlainText())
    .join('\n');

/// Whether keyboard focus is on, or inside, the widget [target].
bool focusIsOn(WidgetTester tester, Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  var found = false;
  tester.element(target.first).visitAncestorElements((element) {
    if (element == focused) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Counts the focus rings that are drawing right now.
int visibleFocusRings(WidgetTester tester) =>
    tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((box) {
      final decoration = box.decoration;
      return box.position == DecorationPosition.foreground &&
          decoration is BoxDecoration &&
          decoration.border != null;
    }).length;
