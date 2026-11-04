import 'package:flutter_riverpod/flutter_riverpod.dart';

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
