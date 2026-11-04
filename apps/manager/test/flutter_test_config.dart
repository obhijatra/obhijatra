import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real Noto fonts so that tests measure text the way the app
/// does (the default test font is far wider than Noto and hides or invents
/// overflow). Bangla is measured with its own font too.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const families = <String, List<String>>{
    'Noto Sans': <String>[
      'NotoSans-Regular',
      'NotoSans-Medium',
      'NotoSans-SemiBold',
      'NotoSans-Bold',
    ],
    'Noto Sans Bengali': <String>[
      'NotoSansBengali-Regular',
      'NotoSansBengali-Medium',
      'NotoSansBengali-SemiBold',
      'NotoSansBengali-Bold',
    ],
    'Noto Serif': <String>['NotoSerif-Regular', 'NotoSerif-SemiBold'],
    'Noto Serif Bengali': <String>[
      'NotoSerifBengali-Regular',
      'NotoSerifBengali-SemiBold',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader('packages/obhijatra_ui/${entry.key}');
    for (final file in entry.value) {
      loader.addFont(
        rootBundle.load('packages/obhijatra_ui/assets/fonts/$file.ttf'),
      );
    }
    await loader.load();
  }
  await testMain();
}
