import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/one_time_password.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/phone_number.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/navigation.dart';
import 'package:obhijatra_manager/src/state/people.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/format.dart';
import 'package:obhijatra_manager/src/ui/leave_guard.dart';
import 'package:obhijatra_manager/src/ui/one_time_password_reveal.dart';
import 'package:obhijatra_manager/src/ui/page_scaffold.dart';
import 'package:obhijatra_manager/src/ui/people_words.dart';
import 'package:obhijatra_manager/src/ui/place_picker.dart';
import 'package:obhijatra_manager/widgets/loading_block.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/phone_number_field.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

// The server's names for the fields it can refuse.
const String _kName = 'name';
const String _kRole = 'role';
const String _kLocation = 'location';
const String _kEmail = 'email';
const String _kVerified = 'verified';
const String _kPhone = 'phone';

/// The fields shown on the form, in the order of the screen.
const List<String> _placedKeys = <String>[
  _kName,
  _kRole,
  _kLocation,
  _kEmail,
  _kVerified,
  _kPhone,
];

/// Width of the sign-in and status panel beside the details.
const double _statusWidth = 340;

/// Content width from which that panel sits beside the details.
const double _sideBySideFrom = 900;

/// Enough of an email address to catch a typing slip; the server checks
/// the rest.
final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// How a new person will sign in.
enum _SignInWay {
  /// With their email address and a one-time password shown to the admin.
  oneTimePassword,

  /// With an SMS code or Google; nobody is shown a password.
  smsOrGoogle,
}

/// The form to add a person ([id] null) or one person's page.
class PersonEditor extends ConsumerStatefulWidget {
  /// Creates the form for a person of [kind]; [id] opens that person.
  const PersonEditor({required this.kind, this.id, super.key});

  /// The kind of person.
  final PersonKind kind;

  /// The person shown, or null to add one.
  final String? id;

  @override
  ConsumerState<PersonEditor> createState() => _PersonEditorState();
}

class _PersonEditorState extends ConsumerState<PersonEditor> {
  late final LeaveGuard _guard;

  bool get _adding => widget.id == null;

  // Loading (a person's page only).
  bool _loading = false;
  AppProblem? _loadProblem;
  Person? _saved;
  List<SignInLock> _locks = const <SignInLock>[];
  int? _activeAdmins;

  // The form.
  late PersonKind _kind = widget.kind;
  final _name = TextEditingController();
  String? _role;
  String? _locationId;
  final _email = TextEditingController();
  bool _verified = false;
  bool _verifiedTouched = false;
  final _phone = TextEditingController();
  _SignInWay? _way;
  Map<String, String> _errors = <String, String>{};
  final Map<String, GlobalKey> _anchors = <String, GlobalKey>{};
  bool _saving = false;
  AppProblem? _saveProblem;

  // After adding a person with a one-time password, shown once.
  Person? _added;
  String? _addedPassword;

  // Status actions (a person's page only).
  bool _statusBusy = false;
  AppProblem? _statusProblem;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    _guard = ref.read(leaveGuardProvider)
      ..attach(this, () => _addedPassword != null || _dirty, prompt: _prompt);
    if (_kind == PersonKind.field) _role = fieldOfficerRole;
    if (!_adding) {
      _loading = true;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _guard.detach(this);
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  LeavePrompt _prompt(AppLocalizations l10n) => _addedPassword != null
      ? LeavePrompt(
          title: l10n.leaveOtpTitle,
          body: l10n.leaveOtpBody,
          leave: l10n.leaveOtpLeave,
        )
      : LeavePrompt(
          title: l10n.leaveTitle,
          body: l10n.leavePersonBody,
          leave: l10n.leaveDiscard,
        );

  // ------------------------------------------------------------- state

  String get _emailText => _email.text.trim();

  /// The mobile number as the server keeps it; what was typed when it is
  /// not a usable number, so that a typing slip still counts as a change.
  String get _phoneValue {
    final typed = _phone.text.trim();
    if (typed.isEmpty) return '';
    return normalisePhone(typed) ?? typed;
  }

  PersonDraft get _draft => PersonDraft(
    name: _name.text.trim(),
    role: _role ?? '',
    locationId: _locationId ?? '',
    email: _emailText,
    verified: _emailText.isNotEmpty && _verified,
    phone: _phoneValue,
  );

  /// Whether anything typed would be lost by leaving.
  bool get _dirty {
    if (_adding) {
      final draft = _draft;
      return draft.name.isNotEmpty ||
          draft.email.isNotEmpty ||
          draft.phone.isNotEmpty ||
          draft.locationId.isNotEmpty ||
          (_kind == PersonKind.staff && draft.role.isNotEmpty);
    }
    final saved = _saved;
    return saved != null && _draft != PersonDraft.of(saved);
  }

  /// How the new person will sign in: a one-time password needs an email
  /// address, and is the default once there is one.
  _SignInWay get _signInWay => _emailText.isEmpty
      ? _SignInWay.smsOrGoogle
      : (_way ?? _SignInWay.oneTimePassword);

  bool get _isSelf {
    final saved = _saved;
    final me = ref.read(sessionProvider);
    return saved != null &&
        me != null &&
        saved.kind == PersonKind.staff &&
        saved.id == me.id;
  }

  /// You may not demote or deactivate yourself as the only active admin.
  bool get _onlyAdminIsMe {
    final saved = _saved;
    return saved != null &&
        _isSelf &&
        saved.role == orgAdminRole &&
        saved.active &&
        (_activeAdmins ?? 2) <= 1;
  }

  /// Shows [person] as the server has them, keeping nothing typed.
  void _apply(Person person) {
    _saved = person;
    _kind = person.kind;
    _name.text = person.name;
    _role = person.role;
    _locationId = person.locationId.isEmpty ? null : person.locationId;
    _email.text = person.email;
    _verified = person.verified;
    _verifiedTouched = false;
    _phone.text = person.phone.isEmpty ? '' : displayPhone(person.phone);
    _errors = <String, String>{};
  }

  Future<void> _load() async {
    final api = ref.read(apiProvider);
    try {
      final (person, locks) = await trackedUi(ref, () async {
        final person = await api.getPerson(widget.kind, widget.id!);
        final locks = await api.activeLocks(widget.kind, <String>[person.id]);
        return (person, locks);
      });
      if (!mounted) return;
      setState(() {
        _apply(person);
        _locks = locks;
        _loading = false;
        _loadProblem = null;
      });
      if (_isSelf && person.role == orgAdminRole) {
        try {
          final count = await trackedUi(ref, api.countActiveOrgAdmins);
          if (mounted) setState(() => _activeAdmins = count);
        } on AppProblem {
          // The server refuses the change anyway; its message is shown.
        }
      }
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        _loadProblem = problem;
        _loading = false;
      });
    }
  }

  void _onLoadProblem() {
    final problem = _loadProblem;
    if (problem == null) return;
    switch (problem.action) {
      case ProblemAction.signInAgain:
        ref.read(sessionProvider.notifier).signOut();
      case ProblemAction.tryAgain || ProblemAction.reload:
        unawaited(_reload());
      case ProblemAction.close || ProblemAction.chooseFile:
        _toList();
    }
  }

  /// Loads the person again as the server has them now: after someone else
  /// changed them, the admin starts again from the saved record.
  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadProblem = null;
      _saveProblem = null;
      _statusProblem = null;
      _statusError = null;
    });
    await _load();
  }

  /// Records an edit: the field's old problem no longer applies.
  void _edited(String key, [String? alsoKey]) {
    setState(() {
      _errors.remove(key);
      if (alsoKey != null) _errors.remove(alsoKey);
    });
  }

  void _onEmailChanged() {
    final saved = _saved;
    setState(() {
      _errors
        ..remove(_kEmail)
        ..remove(_kVerified);
      // A different address has not been confirmed yet.
      if (saved != null && !_verifiedTouched) {
        _verified = _emailText.toLowerCase() == saved.email.toLowerCase()
            ? saved.verified
            : false;
      }
    });
  }

  GlobalKey _anchor(String key) => _anchors.putIfAbsent(key, GlobalKey.new);

  /// Scrolls to the first field with a problem.
  void _revealFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final key in _placedKeys) {
        if (!_errors.containsKey(key)) continue;
        final context = _anchors[key]?.currentContext;
        if (context == null) continue;
        unawaited(
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 250),
            alignment: 0.1,
          ),
        );
        return;
      }
    });
  }

  /// The problems the admin can fix before anything is sent.
  Map<String, String> _check(AppLocalizations l10n) {
    final errors = <String, String>{};
    final draft = _draft;
    if (draft.name.isEmpty) errors[_kName] = l10n.personErrorName;
    if (draft.role.isEmpty) errors[_kRole] = l10n.personErrorRole;
    if (draft.locationId.isEmpty) errors[_kLocation] = l10n.personErrorPlace;
    if (draft.email.isNotEmpty && !_emailShape.hasMatch(draft.email)) {
      errors[_kEmail] = l10n.personErrorEmailInvalid;
    }
    final typedPhone = _phone.text.trim();
    if (typedPhone.isNotEmpty && normalisePhone(typedPhone) == null) {
      errors[_kPhone] = l10n.smsNumberInvalid;
    }
    if (draft.email.isEmpty && typedPhone.isEmpty) {
      errors[_kEmail] = l10n.personErrorEmailOrPhone;
    } else if (draft.email.isEmpty && draft.role == orgAdminRole) {
      errors[_kEmail] = l10n.personErrorAdminEmail;
    }
    return errors;
  }

  /// The server's refusals, under the right fields and in the app's own
  /// words for the reasons it knows.
  Map<String, String> _serverErrors(AppLocalizations l10n, AppProblem p) => {
    for (final entry in p.fields.entries)
      entry.key: switch (p.codes[entry.key]) {
        'validation_email_or_phone_required' => l10n.personErrorEmailOrPhone,
        'validation_org_admin_email_required' => l10n.personErrorAdminEmail,
        'validation_one_time_password_needs_email' => l10n.personErrorOtpEmail,
        'validation_last_org_admin' => l10n.personErrorLastAdmin,
        'validation_not_unique' when entry.key == _kEmail =>
          l10n.personErrorEmailTaken,
        'validation_not_unique' when entry.key == _kPhone =>
          l10n.personErrorPhoneTaken,
        'validation_is_email' ||
        'validation_invalid_email' => l10n.personErrorEmailInvalid,
        'validation_invalid_format' when entry.key == _kPhone =>
          l10n.smsNumberInvalid,
        _ when entry.value.isNotEmpty => entry.value,
        _ => l10n.problemRejected,
      },
  };

  /// Problems the server reported for fields this form does not show.
  List<String> get _unplacedErrors => <String>[
    for (final entry in _errors.entries)
      if (!_placedKeys.contains(entry.key)) entry.value,
  ];

  // ----------------------------------------------------------- actions

  void _toList() =>
      ref.read(peopleViewProvider.notifier).open(const PeopleView.list());

  Future<void> _back() async {
    if (!await confirmLeave(context, ref) || !mounted) return;
    _toList();
  }

  void _setKind(PersonKind kind) {
    setState(() {
      _kind = kind;
      _role = kind == PersonKind.field ? fieldOfficerRole : null;
      _errors.remove(_kRole);
    });
  }

  Future<void> _choosePlace() async {
    final choice = await showPlacePicker(context, selectedId: _locationId);
    final place = choice?.place;
    if (place == null || !mounted) return;
    setState(() {
      _locationId = place.id;
      _errors.remove(_kLocation);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errors = _check(l10n);
    setState(() {
      _errors = errors;
      _saveProblem = null;
    });
    if (errors.isNotEmpty) {
      _revealFirstError();
      return;
    }
    final draft = _draft;
    final api = ref.read(apiProvider);
    setState(() => _saving = true);
    try {
      if (_adding) {
        final oneTime = _signInWay == _SignInWay.oneTimePassword;
        final random = ref.read(secureRandomProvider);
        final password = oneTime
            ? newOneTimePassword(random)
            : newHiddenPassword(random);
        final person = await trackedUi(
          ref,
          () => api.createPerson(
            _kind,
            draft,
            password: password,
            oneTimePassword: oneTime,
          ),
        );
        ref.invalidate(peopleListProvider);
        if (!mounted) return;
        if (oneTime) {
          setState(() {
            _added = person;
            _addedPassword = password;
          });
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.personAdded(person.displayName))),
          );
          _toList();
        }
      } else {
        final person = await trackedUi(
          ref,
          () => api.updatePerson(_saved!, draft),
        );
        ref.invalidate(peopleListProvider);
        if (!mounted) return;
        setState(() => _apply(person));
        messenger.showSnackBar(SnackBar(content: Text(l10n.personSaved)));
      }
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        _saveProblem = problem;
        _errors = _serverErrors(l10n, problem);
      });
      _revealFirstError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onSaveProblem() {
    final problem = _saveProblem;
    if (problem == null) return;
    switch (problem.action) {
      case ProblemAction.signInAgain:
        ref.read(sessionProvider.notifier).signOut();
      case ProblemAction.tryAgain:
        unawaited(_save());
      case ProblemAction.reload when !_adding:
        unawaited(_reload());
      case ProblemAction.close ||
          ProblemAction.chooseFile ||
          ProblemAction.reload:
        setState(() => _saveProblem = null);
    }
  }

  /// Starts again with an empty form, for the next person.
  void _addAnother() {
    setState(() {
      _added = null;
      _addedPassword = null;
      _name.clear();
      _email.clear();
      _phone.clear();
      _verified = false;
      _verifiedTouched = false;
      _way = null;
      _locationId = null;
      _role = _kind == PersonKind.field ? fieldOfficerRole : null;
      _errors = <String, String>{};
    });
  }

  /// Runs a status action, showing its problem in the status panel.
  Future<void> _statusAction(Future<void> Function() action) async {
    if (_statusBusy) return;
    setState(() {
      _statusBusy = true;
      _statusProblem = null;
      _statusError = null;
    });
    try {
      await action();
    } on AppProblem catch (problem) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        if (problem.codes[_kRole] == 'validation_last_org_admin') {
          _statusError = l10n.personErrorLastAdmin;
        } else if (problem.fields.isNotEmpty) {
          _statusError = _serverErrors(l10n, problem).values.join('\n');
        } else {
          _statusProblem = problem;
        }
      });
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _setActive(bool active) async {
    final saved = _saved;
    if (saved == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!active) {
      final palette = context.palette;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.deactivateTitle(saved.displayName)),
          content: Text(
            _isSelf ? l10n.deactivateSelfBody : l10n.deactivateBody,
          ),
          actions: <Widget>[
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.danger,
                foregroundColor: palette.onAction,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.deactivateButton),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _statusAction(() async {
      final person = await trackedUi(
        ref,
        () => ref.read(apiProvider).setPersonActive(saved, active: active),
      );
      ref.invalidate(peopleListProvider);
      if (!mounted) return;
      // Only the status changed; anything typed in the form stays.
      setState(() => _saved = saved.copyWith(active: person.active));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            active
                ? l10n.personReactivated(saved.displayName)
                : l10n.personDeactivated(saved.displayName),
          ),
        ),
      );
    });
  }

  Future<void> _giveNewPassword() async {
    final saved = _saved;
    if (saved == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetConfirmTitle(saved.displayName)),
        content: Text(l10n.resetConfirmBody),
        actions: <Widget>[
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.resetConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final password = newOneTimePassword(ref.read(secureRandomProvider));
    await _statusAction(() async {
      final person = await trackedUi(
        ref,
        () => ref.read(apiProvider).resetOneTimePassword(saved, password),
      );
      ref.invalidate(peopleListProvider);
      if (!mounted) return;
      setState(
        () => _saved = saved.copyWith(
          mustChangePassword: person.mustChangePassword,
        ),
      );
      await showOneTimePasswordDialog(
        context,
        name: saved.displayName,
        email: saved.email,
        password: password,
      );
    });
  }

  Future<void> _unlock() async {
    final saved = _saved;
    if (saved == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(apiProvider);
    final locks = _locks;
    await _statusAction(() async {
      final left = await trackedUi(ref, () async {
        for (final lock in locks) {
          await api.unlockSignIn(lock);
        }
        return api.activeLocks(saved.kind, <String>[saved.id]);
      });
      ref.invalidate(peopleListProvider);
      if (!mounted) return;
      setState(() => _locks = left);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.unlockDone(saved.displayName))),
      );
    });
  }

  // ------------------------------------------------------------ layout

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saved = _saved;
    final Widget body;
    if (_loading) {
      body = const LoadingBlock();
    } else if (_loadProblem != null) {
      body = ProblemView(problem: _loadProblem!, onAction: _onLoadProblem);
    } else if (_added != null && _addedPassword != null) {
      body = _addedView(context, _added!, _addedPassword!);
    } else {
      body = _form(context);
    }
    return PageScaffold(
      leading: TextButton.icon(
        onPressed: () => unawaited(_back()),
        icon: const Icon(Icons.arrow_back),
        label: Text(l10n.peopleBack),
      ),
      title: _adding || saved == null ? l10n.peopleAdd : saved.displayName,
      subtitle: saved == null
          ? null
          : '${kindName(l10n, saved.kind)} · ${roleName(l10n, saved.role)}',
      child: body,
    );
  }

  Widget _limited(Widget child) => Align(
    alignment: AlignmentDirectional.topStart,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Sizes.content),
      child: child,
    ),
  );

  Widget _form(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: Spacing.space8),
          child: LayoutBuilder(
            builder: (context, box) {
              if (_adding) {
                return _limited(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _detailsPanel(context),
                      const SizedBox(height: Spacing.space5),
                      _signInPanel(context),
                    ],
                  ),
                );
              }
              // Wide enough: sign-in and status beside the details, so
              // both are seen at once. Otherwise status first, since it
              // holds what people most often come for (unlocking, a new
              // one-time password).
              if (box.maxWidth >= _sideBySideFrom) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Sizes.content,
                        ),
                        child: _detailsPanel(context),
                      ),
                    ),
                    const SizedBox(width: Spacing.space5),
                    SizedBox(width: _statusWidth, child: _statusPanel(context)),
                  ],
                );
              }
              return _limited(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _statusPanel(context),
                    const SizedBox(height: Spacing.space5),
                    _detailsPanel(context),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      _limited(_saveBar(context)),
    ],
  );

  Widget _heading(BuildContext context, String title) => Semantics(
    header: true,
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _detailsPanel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final places = ref.watch(placesProvider).asData?.value;
    final place = _locationId == null ? null : places?.byId(_locationId!);
    final roleLocked = _onlyAdminIsMe;
    final hasEmail = _emailText.isNotEmpty;
    return ObPanel(
      padding: const EdgeInsets.all(Spacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _heading(context, l10n.personDetails),
          const SizedBox(height: Spacing.space5),
          KeyedSubtree(
            key: _anchor(_kName),
            child: TextField(
              key: const ValueKey<String>('person-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(200),
              ],
              decoration: InputDecoration(
                labelText: l10n.personName,
                errorText: _errors[_kName],
                errorMaxLines: 3,
              ),
              onChanged: (_) => _edited(_kName),
            ),
          ),
          const SizedBox(height: Spacing.space5),
          if (_adding)
            _Labelled(
              label: l10n.personKind,
              helper: l10n.personKindHelp,
              child: SegmentedButton<PersonKind>(
                key: const ValueKey<String>('person-kind'),
                segments: <ButtonSegment<PersonKind>>[
                  ButtonSegment<PersonKind>(
                    value: PersonKind.staff,
                    label: Text(l10n.kindStaff),
                  ),
                  ButtonSegment<PersonKind>(
                    value: PersonKind.field,
                    label: Text(l10n.kindField),
                  ),
                ],
                selected: <PersonKind>{_kind},
                onSelectionChanged: (choice) => _setKind(choice.first),
              ),
            )
          else
            _ReadOnly(
              label: l10n.personKind,
              value: kindName(l10n, _kind),
              helper: l10n.personKindFixed,
            ),
          const SizedBox(height: Spacing.space5),
          KeyedSubtree(
            key: _anchor(_kRole),
            child: _kind == PersonKind.field
                ? _ReadOnly(
                    label: l10n.accountRole,
                    value: roleName(l10n, fieldOfficerRole),
                  )
                : DropdownMenu<String>(
                    key: ValueKey<String>('person-role-$_role-$roleLocked'),
                    label: Text(l10n.accountRole),
                    expandedInsets: EdgeInsets.zero,
                    requestFocusOnTap: false,
                    enabled: !roleLocked,
                    initialSelection: _role,
                    helperText: roleLocked ? l10n.personOnlyAdmin : null,
                    errorText: _errors[_kRole],
                    onSelected: (value) => setState(() {
                      _role = value;
                      _errors
                        ..remove(_kRole)
                        ..remove(_kEmail);
                    }),
                    dropdownMenuEntries: <DropdownMenuEntry<String>>[
                      for (final role in PersonKind.staff.roles)
                        DropdownMenuEntry<String>(
                          value: role,
                          label: roleName(l10n, role),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: Spacing.space5),
          KeyedSubtree(
            key: _anchor(_kLocation),
            child: PickerField(
              key: const ValueKey<String>('person-place'),
              label: l10n.personPlace,
              value: place == null ? '' : places!.trail(place).join(' › '),
              placeholder: l10n.personPlaceChoose,
              helper: l10n.personPlaceHelp,
              error: _errors[_kLocation],
              onTap: () => unawaited(_choosePlace()),
            ),
          ),
          const SizedBox(height: Spacing.space5),
          KeyedSubtree(
            key: _anchor(_kEmail),
            child: TextField(
              key: const ValueKey<String>('person-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.accountEmail,
                helperText: l10n.personEmailHelp,
                helperMaxLines: 3,
                errorText: _errors[_kEmail],
                errorMaxLines: 4,
              ),
              onChanged: (_) => _onEmailChanged(),
            ),
          ),
          const SizedBox(height: Spacing.space3),
          KeyedSubtree(
            key: _anchor(_kVerified),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ExcludeSemantics(
                        child: Text(
                          l10n.personVerified,
                          style: text.labelLarge!.copyWith(
                            color: hasEmail ? palette.text : palette.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.space1),
                      Text(
                        l10n.personVerifiedHelp,
                        style: text.bodySmall!.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                      if (_errors[_kVerified] != null)
                        _ErrorText(_errors[_kVerified]!),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.space3),
                Semantics(
                  label: l10n.personVerified,
                  child: Switch(
                    key: const ValueKey<String>('person-verified'),
                    value: hasEmail && _verified,
                    onChanged: hasEmail
                        ? (on) => setState(() {
                            _verified = on;
                            _verifiedTouched = true;
                            _errors.remove(_kVerified);
                          })
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.space5),
          KeyedSubtree(
            key: _anchor(_kPhone),
            child: PhoneNumberField(
              key: const ValueKey<String>('person-phone'),
              controller: _phone,
              label: l10n.accountPhone,
              helper: l10n.personPhoneHelp,
              errorText: _errors[_kPhone],
              onChanged: (_) => _edited(_kPhone, _kEmail),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signInPanel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final hasEmail = _emailText.isNotEmpty;
    final way = _signInWay;
    final draft = _draft;
    final cannotSignIn =
        way == _SignInWay.smsOrGoogle &&
        !draft.verified &&
        (draft.phone.isEmpty || draft.role == orgAdminRole);
    return ObPanel(
      padding: const EdgeInsets.all(Spacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _heading(context, l10n.personHowSignIn),
          const SizedBox(height: Spacing.space3),
          RadioGroup<_SignInWay>(
            groupValue: way,
            onChanged: (value) => setState(() => _way = value),
            // The tiles' own surface, so their ink shows on the panel.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: <Widget>[
                  RadioListTile<_SignInWay>(
                    key: const ValueKey<String>('signin-otp'),
                    value: _SignInWay.oneTimePassword,
                    enabled: hasEmail,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.personSignInOtp),
                    subtitle: Text(
                      hasEmail
                          ? l10n.personSignInOtpHelp
                          : l10n.personSignInOtpNeedsEmail,
                    ),
                  ),
                  RadioListTile<_SignInWay>(
                    key: const ValueKey<String>('signin-other'),
                    value: _SignInWay.smsOrGoogle,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.personSignInOther),
                    subtitle: Text(l10n.personSignInOtherHelp),
                  ),
                ],
              ),
            ),
          ),
          if (cannotSignIn) ...<Widget>[
            const SizedBox(height: Spacing.space3),
            Container(
              padding: const EdgeInsets.all(Spacing.space3),
              decoration: BoxDecoration(
                color: Tone.warning.background(palette),
                borderRadius: Radii.smAll,
                border: Border.all(color: Tone.warning.foreground(palette)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: Sizes.icon,
                    color: Tone.warning.foreground(palette),
                  ),
                  const SizedBox(width: Spacing.space2),
                  Expanded(
                    child: Text(
                      l10n.personCannotSignIn,
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPanel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final saved = _saved!;
    final muted = text.bodySmall!.copyWith(color: palette.textMuted);
    final locked = _locks.isNotEmpty;
    final until = _locks.isEmpty
        ? null
        : _locks
              .map((lock) => lock.lockedUntil)
              .reduce((a, b) => a.isAfter(b) ? a : b);
    final statusLocked = _onlyAdminIsMe || _statusBusy;
    return ObPanel(
      padding: const EdgeInsets.all(Spacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _heading(context, l10n.personStatusTitle),
          const SizedBox(height: Spacing.space3),
          PersonStatusChips(person: saved, locked: locked),
          const SizedBox(height: Spacing.space4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ExcludeSemantics(
                      child: Text(l10n.statusActive, style: text.labelLarge),
                    ),
                    const SizedBox(height: Spacing.space1),
                    Text(
                      _onlyAdminIsMe
                          ? l10n.personOnlyAdmin
                          : l10n.personActiveHelp,
                      style: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.space3),
              Semantics(
                label: l10n.statusActive,
                child: Switch(
                  key: const ValueKey<String>('person-active'),
                  value: saved.active,
                  onChanged: statusLocked
                      ? null
                      : (on) => unawaited(_setActive(on)),
                ),
              ),
            ],
          ),
          if (_statusError != null) _ErrorText(_statusError!),
          if (locked) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            const Divider(),
            const SizedBox(height: Spacing.space4),
            Text(
              l10n.personLockedNote(Format.clock(context, until!)),
              style: text.bodyMedium,
            ),
            const SizedBox(height: Spacing.space3),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _statusBusy ? null : () => unawaited(_unlock()),
                icon: const Icon(Icons.lock_open_outlined),
                label: Text(l10n.unlockButton),
              ),
            ),
          ],
          // Nobody gives themselves a one-time password (the server refuses
          // it too): it would hand their own account to whoever saw it.
          if (!_isSelf) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            const Divider(),
            const SizedBox(height: Spacing.space4),
            Text(l10n.resetTitle, style: text.labelLarge),
            const SizedBox(height: Spacing.space1),
            if (saved.mustChangePassword) ...<Widget>[
              Text(
                l10n.personMustChooseNote(saved.displayName),
                style: text.bodyMedium,
              ),
              const SizedBox(height: Spacing.space2),
            ],
            Text(
              saved.email.isEmpty ? l10n.resetNeedsEmail : l10n.resetHelp,
              style: muted,
            ),
            const SizedBox(height: Spacing.space3),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _statusBusy || saved.email.isEmpty
                    ? null
                    : () => unawaited(_giveNewPassword()),
                icon: const Icon(Icons.key_outlined),
                label: Text(l10n.resetButton),
              ),
            ),
          ],
          if (_statusProblem != null) ...<Widget>[
            const SizedBox(height: Spacing.space3),
            ProblemBanner(
              problem: _statusProblem!,
              onAction: () => switch (_statusProblem!.action) {
                ProblemAction.signInAgain =>
                  ref.read(sessionProvider.notifier).signOut(),
                ProblemAction.reload => unawaited(_reload()),
                _ => setState(() => _statusProblem = null),
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _saveBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final muted = text.bodyMedium!.copyWith(color: palette.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Spacing.space3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_saveProblem != null) ...<Widget>[
            ProblemBanner(problem: _saveProblem!, onAction: _onSaveProblem),
            for (final message in _unplacedErrors) _ErrorText(message),
            const SizedBox(height: Spacing.space3),
          ],
          if (!_adding) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline, size: Sizes.icon, color: palette.info),
                const SizedBox(width: Spacing.space2),
                Expanded(
                  child: Text(l10n.personSignOutNote, style: text.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: Spacing.space2),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    !_adding && _dirty ? l10n.unsavedChanges : '',
                    style: muted,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.space3),
              FilledButton(
                key: const ValueKey<String>('person-save'),
                onPressed: _saving ? null : _save,
                child: Text(switch ((_adding, _saving)) {
                  (true, true) => l10n.personAdding,
                  (true, false) => l10n.peopleAdd,
                  (false, true) => l10n.actionSaving,
                  (false, false) => l10n.actionSave,
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addedView(BuildContext context, Person person, String password) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Spacing.space8),
      child: _limited(
        ObPanel(
          padding: const EdgeInsets.all(Spacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                liveRegion: true,
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline,
                      color: palette.success,
                      size: Sizes.iconLg,
                    ),
                    const SizedBox(width: Spacing.space2),
                    Expanded(
                      child: Text(
                        l10n.personAddedHeading(person.displayName),
                        style: text.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.space5),
              OneTimePasswordReveal(
                name: person.displayName,
                email: person.email,
                password: password,
              ),
              const SizedBox(height: Spacing.space6),
              Wrap(
                spacing: Spacing.space3,
                runSpacing: Spacing.space2,
                children: <Widget>[
                  FilledButton(onPressed: _toList, child: Text(l10n.otpDone)),
                  OutlinedButton.icon(
                    onPressed: _addAnother,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(l10n.otpAddAnother),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label above a control that is not a text field, with help under it.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child, this.helper});

  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(child: Text(label, style: text.labelLarge)),
          const SizedBox(height: Spacing.space2),
          child,
          if (helper != null) ...<Widget>[
            const SizedBox(height: Spacing.space1),
            Text(
              helper!,
              style: text.bodySmall!.copyWith(color: context.palette.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// A value that cannot be changed here, laid out like a field.
class _ReadOnly extends StatelessWidget {
  const _ReadOnly({required this.label, required this.value, this.helper});

  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: text.bodySmall!.copyWith(color: palette.textMuted)),
        const SizedBox(height: Spacing.space1),
        Text(value, style: text.bodyLarge),
        if (helper != null)
          Text(
            helper!,
            style: text.bodySmall!.copyWith(color: palette.textMuted),
          ),
      ],
    );
  }
}

/// A problem with a field, in words and with an icon.
class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: Sizes.iconSm, color: palette.danger),
          const SizedBox(width: Spacing.space1),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelSmall!
                  .copyWith(color: palette.danger),
            ),
          ),
        ],
      ),
    );
  }
}
