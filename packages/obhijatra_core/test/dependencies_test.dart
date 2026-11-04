// Proves that every declared dependency resolves and loads on the plain Dart
// VM (no Flutter). Imports use only the platform-neutral libraries.
import 'package:dartrosa/dartrosa.dart' as dartrosa;
import 'package:dartrosa_entities/dartrosa_entities.dart' as entities;
import 'package:drift/drift.dart' as drift;
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod/riverpod.dart';
import 'package:sodium/sodium.dart' as sodium;
import 'package:test/test.dart';

void main() {
  test('dependencies load on the Dart VM', () {
    // Reference one symbol from each library so the imports are exercised.
    expect(const drift.Value<int>(1).value, 1);
    expect(sodium.Sodium, isNotNull);
    expect(dartrosa.DataType.values, isNotEmpty);
    expect(entities.EntitiesRepository, isNotNull);

    final pb = PocketBase('http://localhost:8090');
    expect(pb.baseURL, 'http://localhost:8090');

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final counter = Provider<int>((ref) => 42);
    expect(container.read(counter), 42);
  });
}
