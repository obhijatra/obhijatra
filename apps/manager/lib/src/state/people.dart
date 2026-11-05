import 'dart:math';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/state/providers.dart';

/// Where one-time and hidden passwords get their randomness: always a
/// cryptographically secure source. Tests replace it with a predictable one.
final secureRandomProvider = Provider<Random>((ref) => Random.secure());

/// The People list's tab, search, filters, order and page. Starts again for
/// each person who signs in.
class PeopleFilterNotifier extends Notifier<PeopleQuery> {
  @override
  PeopleQuery build() {
    ref.watch(sessionProvider.select((user) => user?.id));
    return const PeopleQuery();
  }

  /// Shows office or field staff, from the first page.
  void setKind(PersonKind kind) => state = state.copyWith(kind: kind, page: 1);

  /// Looks for [text] in names, email addresses and mobile numbers.
  void setSearch(String text) {
    final search = text.trim();
    if (search == state.search) return;
    state = state.copyWith(search: search, page: 1);
  }

  /// Shows only people with [status], or everyone with null.
  void setStatus(PeopleStatus? status) => state = status == null
      ? state.copyWith(clearStatus: true, page: 1)
      : state.copyWith(status: status, page: 1);

  /// Shows only people in the place at [path] and below, or everywhere with
  /// null.
  void setPlace(String? path) => state = path == null
      ? state.copyWith(clearPlace: true, page: 1)
      : state.copyWith(placePath: path, page: 1);

  /// Changes the order.
  void setSort(PeopleSort sort) => state = state.copyWith(sort: sort, page: 1);

  /// Goes to [page].
  void setPage(int page) => state = state.copyWith(page: page);
}

/// Holds the People list's filters.
final peopleFilterProvider =
    NotifierProvider<PeopleFilterNotifier, PeopleQuery>(
      PeopleFilterNotifier.new,
    );

/// A page of people with the sign-in locks in force for them.
@immutable
class PeopleListing {
  /// Creates a listing.
  const PeopleListing({required this.page, required this.locks});

  /// The people.
  final PeoplePage page;

  /// Locks in force, by account id.
  final Map<String, List<SignInLock>> locks;

  /// Whether [person]'s sign-in is locked now.
  bool isLocked(Person person) => locks[person.id]?.isNotEmpty ?? false;
}

/// One page of people and their locks.
final peopleListProvider = FutureProvider.autoDispose
    .family<PeopleListing, PeopleQuery>((ref, query) {
      ref.watch(sessionProvider.select((user) => user?.id));
      final api = ref.read(apiProvider);
      return tracked(ref, () async {
        final page = await api.listPeople(query);
        final locks = page.items.isEmpty
            ? const <SignInLock>[]
            : await api.activeLocks(
                query.kind,
                page.items.map((person) => person.id),
              );
        final byAccount = <String, List<SignInLock>>{};
        for (final lock in locks) {
          byAccount.putIfAbsent(lock.accountId, () => <SignInLock>[]).add(lock);
        }
        return PeopleListing(page: page, locks: byAccount);
      });
    });

/// Every place in the organisation, as a tree.
final placesProvider = FutureProvider<PlaceDirectory>((ref) {
  ref.watch(sessionProvider.select((user) => user?.id));
  final api = ref.read(apiProvider);
  return tracked(ref, () async => PlaceDirectory(await api.listPlaces()));
});
