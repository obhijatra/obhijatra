import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/files/download_saver.dart';

/// A saver that keeps files in memory, for widget tests.
class FakeDownloadSaver implements DownloadSaver {
  /// Creates the saver; [holdsInMemory] as a browser does.
  FakeDownloadSaver({this.holdsInMemory = false});

  @override
  final bool holdsInMemory;

  /// The names suggested to the Save dialog, in order.
  final List<String> suggested = <String>[];

  /// Set to make the next Save dialog be cancelled.
  bool cancelNext = false;

  /// Set to make writing fail.
  bool failWrites = false;

  /// Every file started, in order.
  final List<FakeTarget> targets = <FakeTarget>[];

  @override
  Future<DownloadTarget?> choose(String suggestedName) async {
    suggested.add(suggestedName);
    if (cancelNext) {
      cancelNext = false;
      return null;
    }
    final target = FakeTarget(this, suggestedName);
    targets.add(target);
    return target;
  }
}

/// One file of a [FakeDownloadSaver].
class FakeTarget implements DownloadTarget {
  /// Creates the file.
  FakeTarget(this._saver, this.suggestedName);

  final FakeDownloadSaver _saver;

  /// The name suggested for it.
  final String suggestedName;

  /// What was written.
  final List<int> bytes = <int>[];

  /// Whether it was finished, and under which name the server gave.
  bool finished = false;
  String? serverName;

  /// Whether it was thrown away.
  bool discarded = false;

  @override
  Future<void> add(List<int> chunk) async {
    if (_saver.failWrites) throw const AppProblem(ProblemKind.saveFailed);
    bytes.addAll(chunk);
  }

  @override
  Future<String> finish({String? serverName}) async {
    finished = true;
    this.serverName = serverName;
    return _saver.holdsInMemory ? (serverName ?? suggestedName) : suggestedName;
  }

  @override
  Future<void> discard() async {
    discarded = true;
    bytes.clear();
  }
}
