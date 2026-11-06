import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/state/providers.dart';

/// The places in the left-hand menu.
enum Section {
  /// Forms and their versions.
  forms,

  /// Submissions and review.
  submissions,

  /// Office and field staff (organisation admins only).
  people,

  /// The organisation tree: head office, regions, areas, branches
  /// (organisation admins only).
  places,

  /// Devices to approve and switch off (organisation admins and branch
  /// managers), and everyone's own devices ("My devices").
  devices,

  /// Language and sign out.
  settings,

  /// Version, licence and credits.
  about,
}

/// The place being shown.
class SectionNotifier extends Notifier<Section> {
  @override
  Section build() => Section.forms;

  /// Goes to [section].
  void go(Section section) => state = section;
}

/// Holds the place being shown.
final sectionProvider = NotifierProvider<SectionNotifier, Section>(
  SectionNotifier.new,
);

/// The pages inside Settings.
enum SettingsPage {
  /// Language and account.
  overview,

  /// Google and SMS-code sign-in (organisation admins only).
  signInMethods,
}

/// The page shown inside Settings. Starts again at the overview for each
/// person who signs in.
class SettingsPageNotifier extends Notifier<SettingsPage> {
  @override
  SettingsPage build() {
    ref.watch(sessionProvider.select((user) => user?.id));
    return SettingsPage.overview;
  }

  /// Shows [page].
  void open(SettingsPage page) => state = page;
}

/// Holds the page shown inside Settings.
final settingsPageProvider =
    NotifierProvider<SettingsPageNotifier, SettingsPage>(
      SettingsPageNotifier.new,
    );

/// What to ask before leaving a screen: a title, one sentence and the
/// label of the button that leaves.
class LeavePrompt {
  /// Creates the question.
  const LeavePrompt({
    required this.title,
    required this.body,
    required this.leave,
  });

  /// The dialog's title.
  final String title;

  /// What would be lost.
  final String body;

  /// The button that leaves anyway.
  final String leave;
}

/// Lets a screen with unsaved changes ask before the person leaves it.
///
/// It is a plain holder rather than provider state: the screen attaches a
/// question while it is shown and detaches it when it goes, which may
/// happen while widgets are being built.
class LeaveGuard {
  Object? _owner;
  bool Function()? _hasUnsavedChanges;
  LeavePrompt Function(AppLocalizations l10n)? _prompt;

  /// Makes [owner] the screen asked, with [hasUnsavedChanges]. [prompt]
  /// replaces the usual "Leave without saving?" question.
  void attach(
    Object owner,
    bool Function() hasUnsavedChanges, {
    LeavePrompt Function(AppLocalizations l10n)? prompt,
  }) {
    _owner = owner;
    _hasUnsavedChanges = hasUnsavedChanges;
    _prompt = prompt;
  }

  /// Forgets [owner], unless another screen has attached since.
  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _hasUnsavedChanges = null;
    _prompt = null;
  }

  /// Whether leaving now would lose changes.
  bool get hasUnsavedChanges => _hasUnsavedChanges?.call() ?? false;

  /// The question to ask, in the language on screen.
  LeavePrompt promptIn(AppLocalizations l10n) =>
      _prompt?.call(l10n) ??
      LeavePrompt(
        title: l10n.leaveTitle,
        body: l10n.leaveBody,
        leave: l10n.leaveDiscard,
      );
}

/// The one [LeaveGuard] of the app.
final leaveGuardProvider = Provider<LeaveGuard>((ref) => LeaveGuard());

/// What the People section shows.
enum PeopleMode {
  /// The list of people.
  list,

  /// The form to add a person.
  add,

  /// One person's page.
  edit,
}

/// The page shown inside People.
@immutable
class PeopleView {
  /// The list.
  const PeopleView.list() : mode = PeopleMode.list, kind = null, id = null;

  /// The form to add a person of [kind].
  const PeopleView.add(PersonKind this.kind) : mode = PeopleMode.add, id = null;

  /// The page of the person [id] of [kind].
  const PeopleView.edit(PersonKind this.kind, String this.id)
    : mode = PeopleMode.edit;

  /// Which page.
  final PeopleMode mode;

  /// The kind of person added or shown.
  final PersonKind? kind;

  /// The person shown.
  final String? id;

  @override
  bool operator ==(Object other) =>
      other is PeopleView &&
      other.mode == mode &&
      other.kind == kind &&
      other.id == id;

  @override
  int get hashCode => Object.hash(mode, kind, id);
}

/// The page shown inside People. Starts again at the list for each person
/// who signs in.
class PeopleViewNotifier extends Notifier<PeopleView> {
  @override
  PeopleView build() {
    ref.watch(sessionProvider.select((user) => user?.id));
    return const PeopleView.list();
  }

  /// Shows [view].
  void open(PeopleView view) => state = view;
}

/// Holds the page shown inside People.
final peopleViewProvider = NotifierProvider<PeopleViewNotifier, PeopleView>(
  PeopleViewNotifier.new,
);
