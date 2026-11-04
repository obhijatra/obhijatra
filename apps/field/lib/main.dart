import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_field/src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The Noto fonts are bundled under the SIL Open Font Licence; list it with
  // the other open-source licences.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'packages/obhijatra_ui/assets/fonts/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(<String>['Noto fonts'], text);
  });
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  runApp(
    ProviderScope(
      // A failed start is shown to the person; never retry in the background
      // (the key store and database must not be hammered).
      retry: (retryCount, error) => null,
      child: const ObhijatraFieldApp(),
    ),
  );
}
