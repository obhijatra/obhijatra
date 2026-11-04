import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/src/app.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

void main() {
  testWidgets('starts in Bangla and uses the Obhijatra theme', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ObhijatraManagerApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('স্বাগতম'), findsOneWidget);
    final context = tester.element(find.textContaining('স্বাগতম'));
    expect(Localizations.localeOf(context).languageCode, 'bn');
    expect(context.palette.bg, ObhijatraPalette.light.bg);
    // Bangla type scale: body text is 18, one step above English.
    expect(Theme.of(context).textTheme.bodyMedium!.fontSize, 18);
  });

  testWidgets('the language button switches to English and back', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ObhijatraManagerApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome to Obhijatra'), findsOneWidget);
    final context = tester.element(find.textContaining('Welcome'));
    expect(Theme.of(context).textTheme.bodyMedium!.fontSize, 16);

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();
    expect(find.textContaining('স্বাগতম'), findsOneWidget);
  });

  testWidgets('the language button is a 48 dp touch target', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ObhijatraManagerApp()));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(TextButton));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
