import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/src/state/providers.dart';

/// The places in the left-hand menu.
enum Section {
  /// Forms and their versions.
  forms,

  /// Submissions and review.
  submissions,

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

/// Lets a screen with unsaved changes ask before the person leaves it.
///
/// It is a plain holder rather than provider state: the screen attaches a
/// question while it is shown and detaches it when it goes, which may
/// happen while widgets are being built.
class LeaveGuard {
  Object? _owner;
  bool Function()? _hasUnsavedChanges;

  /// Makes [owner] the screen asked, with [hasUnsavedChanges].
  void attach(Object owner, bool Function() hasUnsavedChanges) {
    _owner = owner;
    _hasUnsavedChanges = hasUnsavedChanges;
  }

  /// Forgets [owner], unless another screen has attached since.
  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _hasUnsavedChanges = null;
  }

  /// Whether leaving now would lose changes.
  bool get hasUnsavedChanges => _hasUnsavedChanges?.call() ?? false;
}

/// The one [LeaveGuard] of the app.
final leaveGuardProvider = Provider<LeaveGuard>((ref) => LeaveGuard());
