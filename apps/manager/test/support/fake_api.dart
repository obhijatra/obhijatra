import 'dart:async';
import 'dart:typed_data';

import 'package:obhijatra_manager/src/data/manager_api.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/problem.dart';

/// A server stand-in for widget tests.
class FakeManagerApi implements ManagerApi {
  FakeManagerApi({
    this.user,
    this.forms = const <FormSummary>[],
    this.organisation = 'Sample Development Society',
  });

  StaffUser? user;
  List<FormSummary> forms;
  String organisation;

  /// XForm text by version record id.
  final Map<String, String> xforms = <String, String>{};

  /// Instance XML by submission id.
  final Map<String, String> instances = <String, String>{};

  /// Rows for the submissions table, newest first. When [totalOverride] is
  /// set, [rowFor] makes the rows up on demand.
  List<SubmissionRow> submissions = <SubmissionRow>[];
  int? totalOverride;
  SubmissionRow Function(int index)? rowFor;
  Map<String, String> locations = <String, String>{};

  /// While not null, every call waits for it (shows the loading state).
  Completer<void>? gate;

  /// While not null, every data call throws it.
  AppProblem? failWith;

  /// Set to make [downloadXForm] fail on its own.
  AppProblem? xformFailure;

  /// Set to make [setReview] fail.
  AppProblem? reviewFailure;

  final List<SubmissionQuery> queries = <SubmissionQuery>[];
  final List<(SubmissionRow, ReviewState, String?)> reviews =
      <(SubmissionRow, ReviewState, String?)>[];
  final List<({String formId, String version, String title})> uploads =
      <({String formId, String version, String title})>[];
  final List<FormVersion> published = <FormVersion>[];
  int signOuts = 0;
  AppProblem? signInFailure;

  // ---------------------------------------------------------- sign-in

  /// What [signInMethods] answers.
  SignInMethods methods = SignInMethods.passwordOnly;

  /// Numbers codes were asked for, in order.
  final List<String> codeRequests = <String>[];

  /// Set to make [requestPhoneCode] fail.
  AppProblem? codeRequestFailure;

  /// The code that works; any other is wrong.
  String validCode = '123456';

  /// Codes tried, in order.
  final List<(String, String)> codeChecks = <(String, String)>[];

  /// Set to make [signInWithPhoneCode] fail whatever the code.
  AppProblem? codeCheckFailure;

  /// Who signs in with a right SMS code.
  StaffUser phoneUser = const StaffUser(
    id: 'u2',
    name: 'Nasrin Sultana',
    email: '',
    phone: '+8801712345678',
    role: 'supervisor',
  );

  /// The page [signInWithGoogle] passes to `openUrl`.
  Uri googlePage = Uri.parse('https://accounts.example.com/signin?state=s1');

  /// What the browser step ends with; complete it from a test.
  Completer<StaffUser?> googleResult = Completer<StaffUser?>();

  /// Set to make [signInWithGoogle] fail at once (before any page opens).
  AppProblem? googleFailure;

  /// Whether a Google sign-in is waiting for the browser.
  bool googleWaiting = false;

  /// What [loadSignInSettings] answers.
  SignInSettings settings = const SignInSettings(
    google: GoogleSignInSettings(
      redirectUrl: 'https://data.example.org/api/oauth2-redirect',
    ),
  );

  /// Set to make [loadSignInSettings] fail.
  AppProblem? settingsLoadFailure;

  /// Set to make the next [saveSignInSettings] fail; it is then cleared.
  AppProblem? saveFailure;

  /// Every update saved, in order.
  final List<SignInSettingsUpdate> saves = <SignInSettingsUpdate>[];

  /// What [sendTestSms] answers.
  SmsSendResult testResult = SmsSendResult(
    at: DateTime(2026, 11, 5, 14, 32),
    ok: true,
    status: 200,
    reply: '{"status":"SUCCESS"}',
  );

  /// Set to make [sendTestSms] fail.
  AppProblem? testFailure;

  /// Every test SMS asked for, in order.
  final List<(String, SmsProviderDraft)> tests = <(String, SmsProviderDraft)>[];

  Future<void> _enter() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  StaffUser? get currentUser => user;

  @override
  String get serverUrl => 'https://data.example.org';

  /// Whether [signIn] answers with an account that has a one-time
  /// password.
  bool signInMustChange = false;

  /// The role of the account [signIn] answers with.
  String signInRole = 'org_admin';

  /// Every password sign-in, in order.
  final List<(String, String)> signIns = <(String, String)>[];

  @override
  Future<StaffUser> signIn(String email, String password) async {
    final f = signInFailure;
    if (f != null) throw f;
    signIns.add((email, password));
    return user = StaffUser(
      id: 'u1',
      name: 'Tania Rahman',
      email: email,
      role: signInRole,
      mustChangePassword: signInMustChange,
    );
  }

  @override
  void signOut() {
    signOuts++;
    user = null;
  }

  @override
  Future<SignInMethods> signInMethods() async => methods;

  @override
  Future<PhoneCodeRequest> requestPhoneCode(String phone) async {
    final failure = codeRequestFailure;
    if (failure != null) throw failure;
    codeRequests.add(phone);
    return PhoneCodeRequest(
      codeId: 'code${codeRequests.length}',
      phone: phone,
      expiresIn: const Duration(minutes: 5),
      resendAfter: const Duration(seconds: 60),
    );
  }

  @override
  Future<StaffUser> signInWithPhoneCode(String codeId, String code) async {
    codeChecks.add((codeId, code));
    final failure = codeCheckFailure;
    if (failure != null) throw failure;
    if (code != validCode) {
      throw const AppProblem(ProblemKind.codeWrong, statusCode: 400);
    }
    return user = phoneUser;
  }

  @override
  Future<StaffUser?> signInWithGoogle({
    required FutureOr<void> Function(Uri url) openUrl,
    required Future<void> cancelled,
  }) async {
    final failure = googleFailure;
    if (failure != null) throw failure;
    googleWaiting = true;
    await openUrl(googlePage);
    try {
      final signedIn = await Future.any<StaffUser?>(<Future<StaffUser?>>[
        googleResult.future,
        cancelled.then((_) => null),
      ]);
      if (signedIn != null) user = signedIn;
      return signedIn;
    } finally {
      googleWaiting = false;
    }
  }

  @override
  Future<SignInSettings> loadSignInSettings() async {
    await _enter();
    final failure = settingsLoadFailure;
    if (failure != null) throw failure;
    return settings;
  }

  @override
  Future<SignInSettings> saveSignInSettings(SignInSettingsUpdate update) async {
    await _enter();
    final failure = saveFailure;
    if (failure != null) {
      saveFailure = null;
      throw failure;
    }
    saves.add(update);
    final sms = update.sms;
    return settings = SignInSettings(
      google: GoogleSignInSettings(
        enabled: update.googleEnabled,
        clientId: update.googleClientId,
        clientSecretSet:
            update.googleClientSecret.isNotEmpty ||
            (settings.google.clientSecretSet &&
                update.googleClientId.isNotEmpty),
        redirectUrl: settings.google.redirectUrl,
      ),
      phone: PhoneSignInSettings(
        enabled: update.phoneEnabled,
        sms: SmsProviderSettings(
          method: sms.method,
          url: sms.url,
          bodyFormat: sms.bodyFormat,
          body: sms.method == SmsMethod.post ? sms.body : '',
          headers: sms.headers,
          secretSet: sms.secret.isNotEmpty || settings.phone.sms.secretSet,
          successText: sms.successText,
        ),
        lastSend: settings.phone.lastSend,
      ),
    );
  }

  @override
  Future<SmsSendResult> sendTestSms(String phone, SmsProviderDraft sms) async {
    await _enter();
    final failure = testFailure;
    if (failure != null) throw failure;
    tests.add((phone, sms));
    return testResult;
  }

  @override
  Future<String> organisationName() async {
    await _enter();
    return organisation;
  }

  @override
  Future<List<FormSummary>> listForms() async {
    await _enter();
    return forms;
  }

  @override
  Future<String> downloadXForm(FormVersion version) async {
    await _enter();
    final failure = xformFailure;
    if (failure != null) throw failure;
    final xml = xforms[version.id];
    if (xml == null) throw const AppProblem(ProblemKind.notFound);
    return xml;
  }

  @override
  Future<FormVersion> uploadDraft({
    required String formId,
    required String title,
    required String version,
    required Uint8List xmlBytes,
  }) async {
    await _enter();
    uploads.add((formId: formId, version: version, title: title));
    return FormVersion(
      id: 'new-version',
      formRecordId: 'new-form',
      version: version,
      published: false,
      created: DateTime.now(),
      xformFile: 'x.xml',
    );
  }

  @override
  Future<FormVersion> publish(FormVersion version) async {
    await _enter();
    published.add(version);
    return version;
  }

  @override
  Future<SubmissionPage> listSubmissions(SubmissionQuery query) async {
    await _enter();
    queries.add(query);
    final total = totalOverride ?? submissions.length;
    final first = (query.page - 1) * SubmissionQuery.perPage;
    final count = (total - first).clamp(0, SubmissionQuery.perPage);
    final items = <SubmissionRow>[
      for (var i = 0; i < count; i++)
        rowFor != null ? rowFor!(first + i) : submissions[first + i],
    ];
    return SubmissionPage(
      items: items,
      page: query.page,
      perPage: SubmissionQuery.perPage,
      totalItems: total,
      totalPages: (total / SubmissionQuery.perPage).ceil(),
    );
  }

  @override
  Future<Map<ReviewState, int>> countByState(SubmissionQuery query) async {
    await _enter();
    final total = totalOverride ?? submissions.length;
    return <ReviewState, int>{
      ReviewState.received: total - 3,
      ReviewState.edited: 0,
      ReviewState.hasIssues: 2,
      ReviewState.approved: 1,
      ReviewState.rejected: 0,
    };
  }

  @override
  Future<Map<String, String>> locationNames() async {
    await _enter();
    return locations;
  }

  @override
  Future<String> downloadInstance(String submissionId) async {
    await _enter();
    final xml = instances[submissionId];
    if (xml == null) throw const AppProblem(ProblemKind.notFound);
    return xml;
  }

  @override
  Future<SubmissionRow> setReview(
    SubmissionRow row,
    ReviewState state, {
    String? comment,
  }) async {
    await _enter();
    final failure = reviewFailure;
    if (failure != null) throw failure;
    reviews.add((row, state, comment));
    final updated = row.withReview(state, comment ?? '');
    submissions = <SubmissionRow>[
      for (final r in submissions) r.id == row.id ? updated : r,
    ];
    return updated;
  }

  // ------------------------------------------------------------- people

  /// Everyone, by kind, newest first.
  final Map<PersonKind, List<Person>> people = <PersonKind, List<Person>>{
    PersonKind.staff: <Person>[],
    PersonKind.field: <Person>[],
  };

  /// When set, [listPeople] makes up this many people with [personFor].
  int? peopleTotalOverride;
  Person Function(int index)? personFor;

  /// Every place.
  List<Place> places = <Place>[];

  /// Sign-in locks in force.
  List<SignInLock> locks = <SignInLock>[];

  /// What [countActiveOrgAdmins] answers.
  int activeOrgAdmins = 2;

  /// Set to make the next change to a person fail; it is then cleared.
  AppProblem? personFailure;

  final List<PeopleQuery> peopleQueries = <PeopleQuery>[];
  final List<
    ({PersonKind kind, PersonDraft draft, String password, bool oneTime})
  >
  created =
      <({PersonKind kind, PersonDraft draft, String password, bool oneTime})>[];
  final List<(Person, PersonDraft)> updates = <(Person, PersonDraft)>[];
  final List<(Person, bool)> activeChanges = <(Person, bool)>[];
  final List<(Person, String)> resets = <(Person, String)>[];
  final List<SignInLock> unlocked = <SignInLock>[];

  void _failPerson() {
    final failure = personFailure;
    if (failure != null) {
      personFailure = null;
      throw failure;
    }
  }

  void _store(Person person) {
    final list = people[person.kind]!;
    final index = list.indexWhere((p) => p.id == person.id);
    if (index < 0) {
      list.insert(0, person);
    } else {
      list[index] = person;
    }
  }

  Person _fromDraft(
    String id,
    PersonKind kind,
    PersonDraft draft, {
    bool active = true,
    bool mustChange = false,
  }) => Person(
    id: id,
    kind: kind,
    name: draft.name,
    email: draft.email,
    verified: draft.verified,
    phone: draft.phone,
    role: draft.role,
    locationId: draft.locationId,
    locationPath:
        places
            .where((place) => place.id == draft.locationId)
            .firstOrNull
            ?.path ??
        '',
    active: active,
    mustChangePassword: mustChange,
    created: DateTime(2026, 11, 6),
  );

  @override
  Future<PeoplePage> listPeople(PeopleQuery query) async {
    await _enter();
    peopleQueries.add(query);
    final total = peopleTotalOverride;
    if (total != null) {
      final first = (query.page - 1) * PeopleQuery.perPage;
      final count = (total - first).clamp(0, PeopleQuery.perPage);
      return PeoplePage(
        items: <Person>[for (var i = 0; i < count; i++) personFor!(first + i)],
        page: query.page,
        perPage: PeopleQuery.perPage,
        totalItems: total,
        totalPages: (total / PeopleQuery.perPage).ceil(),
      );
    }
    final search = query.search.toLowerCase();
    final digits = search.replaceAll(RegExp('[^0-9]'), '');
    final lockedIds = <String>{for (final lock in locks) lock.accountId};
    final matching = <Person>[
      for (final person in people[query.kind]!)
        if ((search.isEmpty ||
                person.name.toLowerCase().contains(search) ||
                person.email.toLowerCase().contains(search) ||
                (digits.length >= 3 && person.phone.contains(digits))) &&
            switch (query.status) {
              null => true,
              PeopleStatus.active => person.active,
              PeopleStatus.deactivated => !person.active,
              PeopleStatus.locked => lockedIds.contains(person.id),
            } &&
            (query.placePath == null ||
                person.locationPath.startsWith(query.placePath!)))
          person,
    ];
    if (query.sort == PeopleSort.name) {
      matching.sort((a, b) => a.name.compareTo(b.name));
    }
    final first = (query.page - 1) * PeopleQuery.perPage;
    return PeoplePage(
      items: matching.skip(first).take(PeopleQuery.perPage).toList(),
      page: query.page,
      perPage: PeopleQuery.perPage,
      totalItems: matching.length,
      totalPages: (matching.length / PeopleQuery.perPage).ceil(),
    );
  }

  @override
  Future<Person> getPerson(PersonKind kind, String id) async {
    await _enter();
    final person = people[kind]!.where((p) => p.id == id).firstOrNull;
    if (person == null) throw const AppProblem(ProblemKind.notFound);
    return person;
  }

  @override
  Future<Person> createPerson(
    PersonKind kind,
    PersonDraft draft, {
    required String password,
    required bool oneTimePassword,
  }) async {
    await _enter();
    _failPerson();
    created.add((
      kind: kind,
      draft: draft,
      password: password,
      oneTime: oneTimePassword,
    ));
    final person = _fromDraft(
      'new${created.length}',
      kind,
      draft,
      mustChange: oneTimePassword,
    );
    _store(person);
    return person;
  }

  @override
  Future<Person> updatePerson(Person person, PersonDraft draft) async {
    await _enter();
    _failPerson();
    updates.add((person, draft));
    final updated = _fromDraft(
      person.id,
      person.kind,
      draft,
      active: person.active,
      mustChange: person.mustChangePassword,
    );
    _store(updated);
    return updated;
  }

  @override
  Future<Person> setPersonActive(Person person, {required bool active}) async {
    await _enter();
    _failPerson();
    activeChanges.add((person, active));
    final updated = person.copyWith(active: active);
    _store(updated);
    return updated;
  }

  @override
  Future<Person> resetOneTimePassword(Person person, String password) async {
    await _enter();
    _failPerson();
    resets.add((person, password));
    final updated = person.copyWith(mustChangePassword: true);
    _store(updated);
    return updated;
  }

  @override
  Future<List<SignInLock>> activeLocks(
    PersonKind kind,
    Iterable<String> accountIds,
  ) async {
    await _enter();
    final ids = accountIds.toSet();
    return <SignInLock>[
      for (final lock in locks)
        if (lock.kind == kind && ids.contains(lock.accountId)) lock,
    ];
  }

  @override
  Future<void> unlockSignIn(SignInLock lock) async {
    await _enter();
    unlocked.add(lock);
    locks = <SignInLock>[
      for (final l in locks)
        if (l.id != lock.id) l,
    ];
  }

  @override
  Future<List<Place>> listPlaces() async {
    await _enter();
    return places;
  }

  @override
  Future<int> countActiveOrgAdmins() async {
    await _enter();
    return activeOrgAdmins;
  }

  // ------------------------------------------------- one-time password

  /// Every password change, as (current, new).
  final List<(String, String)> passwordChanges = <(String, String)>[];

  /// Set to make the next [chooseNewPassword] fail; it is then cleared.
  AppProblem? passwordChangeFailure;

  @override
  Future<StaffUser> chooseNewPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final failure = passwordChangeFailure;
    if (failure != null) {
      passwordChangeFailure = null;
      throw failure;
    }
    final me = user;
    if (me == null) throw const AppProblem(ProblemKind.signInRequired);
    passwordChanges.add((currentPassword, newPassword));
    // The real server ends every session; the app signs in again.
    signIns.add((me.email, newPassword));
    return user = me.copyWith(mustChangePassword: false);
  }
}
