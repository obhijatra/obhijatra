import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/state/providers.dart';

/// What the Places section shows.
enum PlacesPage {
  /// The organisation tree.
  tree,

  /// The spreadsheet import.
  import,
}

/// The page shown inside Places. Starts again at the tree for each person
/// who signs in.
class PlacesPageNotifier extends Notifier<PlacesPage> {
  @override
  PlacesPage build() {
    ref.watch(sessionProvider.select((user) => user?.id));
    return PlacesPage.tree;
  }

  /// Shows [page].
  void open(PlacesPage page) => state = page;
}

/// Holds the page shown inside Places.
final placesPageProvider = NotifierProvider<PlacesPageNotifier, PlacesPage>(
  PlacesPageNotifier.new,
);

/// Places this deep or less are open when the tree is first shown: the
/// organisation and the level inside it, so the level below that shows.
const int openUpToDepth = 1;

/// How the tree is shown: which places are open, whether closed places
/// show, and the search.
@immutable
class PlaceTreeView {
  /// Creates the view.
  const PlaceTreeView({
    this.opened = const <String, bool>{},
    this.showClosed = false,
    this.search = '',
  });

  /// Places opened or shut by hand, by record id; the rest follow
  /// [openUpToDepth].
  final Map<String, bool> opened;

  /// Whether closed places are shown.
  final bool showClosed;

  /// Text to find in names and codes.
  final String search;

  /// Whether the places inside [place], [depth] levels down, are shown.
  bool isOpen(Place place, int depth) =>
      opened[place.id] ?? depth <= openUpToDepth;

  /// A copy with some parts replaced.
  PlaceTreeView copyWith({
    Map<String, bool>? opened,
    bool? showClosed,
    String? search,
  }) => PlaceTreeView(
    opened: opened ?? this.opened,
    showClosed: showClosed ?? this.showClosed,
    search: search ?? this.search,
  );
}

/// The tree's view. Kept while the admin visits the import and comes back;
/// starts again for each person who signs in.
class PlaceTreeViewNotifier extends Notifier<PlaceTreeView> {
  @override
  PlaceTreeView build() {
    ref.watch(sessionProvider.select((user) => user?.id));
    return const PlaceTreeView();
  }

  /// Opens or shuts [place], [depth] levels down.
  void toggle(Place place, int depth) => state = state.copyWith(
    opened: <String, bool>{
      ...state.opened,
      place.id: !state.isOpen(place, depth),
    },
  );

  /// Opens every place in [ids], so a place inside them can be seen.
  void open(Iterable<String> ids) => state = state.copyWith(
    opened: <String, bool>{...state.opened, for (final id in ids) id: true},
  );

  /// Shows or hides closed places.
  void setShowClosed({required bool show}) =>
      state = state.copyWith(showClosed: show);

  /// Looks for [text] in names and codes.
  void setSearch(String text) {
    final search = text.trim();
    if (search != state.search) state = state.copyWith(search: search);
  }
}

/// Holds the tree's view.
final placeTreeViewProvider =
    NotifierProvider<PlaceTreeViewNotifier, PlaceTreeView>(
      PlaceTreeViewNotifier.new,
    );
