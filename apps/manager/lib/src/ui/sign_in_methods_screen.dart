import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/phone_number.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/navigation.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/state/url_opener.dart';
import 'package:obhijatra_manager/src/ui/format.dart';
import 'package:obhijatra_manager/src/ui/leave_guard.dart';
import 'package:obhijatra_manager/src/ui/page_scaffold.dart';
import 'package:obhijatra_manager/widgets/code_text.dart';
import 'package:obhijatra_manager/widgets/loading_block.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/phone_number_field.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The written set-up guide for Google and SMS-code sign-in.
const String signInGuideUrl =
    'https://github.com/obhijatra/obhijatra/blob/main/docs/setup/sign-in.md';

/// The placeholders the server fills in for each SMS (its own names).
const List<String> smsPlaceholders = <String>[
  '{phone}',
  '{phone_digits}',
  '{message}',
  '{secret}',
];

/// The most extra headers the server accepts.
const int maxSmsHeaders = 10;

// The server's names for the fields it can refuse (dotted paths).
const String _kClientId = 'google.client_id';
const String _kClientSecret = 'google.client_secret';
const String _kMethod = 'phone.sms.method';
const String _kUrl = 'phone.sms.url';
const String _kFormat = 'phone.sms.content_type';
const String _kBody = 'phone.sms.body';
const String _kHeaders = 'phone.sms.headers';
const String _kSecret = 'phone.sms.secret';
const String _kSuccess = 'phone.sms.success_text';
const String _kTestPhone = 'test.phone';

/// Google and SMS-code sign-in, for organisation admins: everything is
/// changed on screen and saved together with one Save button.
class SignInMethodsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SignInMethodsScreen({super.key});

  @override
  ConsumerState<SignInMethodsScreen> createState() =>
      _SignInMethodsScreenState();
}

/// One extra header: two fields and an id that outlives reordering.
class _HeaderRow {
  _HeaderRow(this.id, [SmsHeader? header])
    : name = TextEditingController(text: header?.name ?? ''),
      value = TextEditingController(text: header?.value ?? '');

  final int id;
  final TextEditingController name;
  final TextEditingController value;
  final FocusNode nameFocus = FocusNode();
  final FocusNode valueFocus = FocusNode();

  String get errorKey => 'header:$id';

  bool get isEmpty => name.text.trim().isEmpty && value.text.trim().isEmpty;

  SmsHeader get header =>
      SmsHeader(name: name.text.trim(), value: value.text.trim());

  void dispose() {
    name.dispose();
    value.dispose();
    nameFocus.dispose();
    valueFocus.dispose();
  }
}

/// A field a placeholder can be put into.
class _Target {
  const _Target(this.controller, this.focus, this.errorKey);

  final TextEditingController controller;
  final FocusNode focus;
  final String errorKey;
}

class _SignInMethodsScreenState extends ConsumerState<SignInMethodsScreen> {
  late final LeaveGuard _guard;

  bool _loading = true;
  AppProblem? _loadProblem;
  SignInSettings? _saved;

  bool _googleOn = false;
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();

  bool _smsOn = false;
  SmsMethod _method = SmsMethod.post;
  SmsBodyFormat _format = SmsBodyFormat.json;
  final _url = TextEditingController();
  final _urlFocus = FocusNode();
  final _body = TextEditingController();
  final _bodyFocus = FocusNode();
  final List<_HeaderRow> _headers = <_HeaderRow>[];
  int _nextHeaderId = 0;
  final _secret = TextEditingController();
  final _successText = TextEditingController();
  final _testPhone = TextEditingController();

  _Target? _target;
  List<int> _sentHeaderIds = <int>[];
  Map<String, String> _errors = <String, String>{};
  final Map<String, GlobalKey> _anchors = <String, GlobalKey>{};

  bool _saving = false;
  AppProblem? _saveProblem;
  bool _testing = false;
  AppProblem? _testProblem;
  SmsSendResult? _testResult;
  SmsSendResult? _lastSend;

  @override
  void initState() {
    super.initState();
    _guard = ref.read(leaveGuardProvider)..attach(this, () => _dirty);
    _watchFocus(_urlFocus, () => _Target(_url, _urlFocus, _kUrl));
    _watchFocus(_bodyFocus, () => _Target(_body, _bodyFocus, _kBody));
    unawaited(_load());
  }

  @override
  void dispose() {
    _guard.detach(this);
    for (final controller in <TextEditingController>[
      _clientId,
      _clientSecret,
      _url,
      _body,
      _secret,
      _successText,
      _testPhone,
    ]) {
      controller.dispose();
    }
    _urlFocus.dispose();
    _bodyFocus.dispose();
    for (final row in _headers) {
      row.dispose();
    }
    super.dispose();
  }

  void _watchFocus(FocusNode node, _Target Function() target) {
    node.addListener(() {
      if (node.hasFocus) _target = target();
    });
  }

  // ------------------------------------------------------------- state

  List<SmsHeader> get _typedHeaders => <SmsHeader>[
    for (final row in _headers)
      if (!row.isEmpty) row.header,
  ];

  /// Whether anything differs from what the server has.
  bool get _dirty {
    final saved = _saved;
    if (saved == null) return false;
    final sms = saved.phone.sms;
    return _googleOn != saved.google.enabled ||
        _clientId.text.trim() != saved.google.clientId ||
        _clientSecret.text.trim().isNotEmpty ||
        _smsOn != saved.phone.enabled ||
        _method != sms.method ||
        _url.text.trim() != sms.url ||
        (_method == SmsMethod.post &&
            (_format != sms.bodyFormat || _body.text.trim() != sms.body)) ||
        !listEquals(_typedHeaders, sms.headers) ||
        _secret.text.trim().isNotEmpty ||
        _successText.text.trim() != sms.successText;
  }

  _HeaderRow _newRow([SmsHeader? header]) {
    final row = _HeaderRow(_nextHeaderId++, header);
    _watchFocus(
      row.valueFocus,
      () => _Target(row.value, row.valueFocus, row.errorKey),
    );
    return row;
  }

  /// Shows [settings] as the server has them.
  void _apply(SignInSettings settings) {
    _saved = settings;
    _googleOn = settings.google.enabled;
    _clientId.text = settings.google.clientId;
    _clientSecret.clear();
    _smsOn = settings.phone.enabled;
    final sms = settings.phone.sms;
    _method = sms.method;
    _format = sms.bodyFormat;
    _url.text = sms.url;
    _body.text = sms.body;
    final old = List<_HeaderRow>.of(_headers);
    _headers
      ..clear()
      ..addAll(sms.headers.map(_newRow));
    if (old.isNotEmpty) {
      // The old fields are still on screen until the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final row in old) {
          row.dispose();
        }
      });
    }
    _secret.clear();
    _successText.text = sms.successText;
    _lastSend = settings.phone.lastSend;
    _errors = <String, String>{};
    if (_target?.errorKey.startsWith('header:') ?? false) _target = null;
  }

  Future<void> _load() async {
    try {
      final settings = await trackedUi(
        ref,
        () => ref.read(apiProvider).loadSignInSettings(),
      );
      if (!mounted) return;
      setState(() {
        _apply(settings);
        _loading = false;
      });
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        _loadProblem = problem;
        _loading = false;
      });
    }
  }

  void _retryLoad() {
    final problem = _loadProblem;
    if (problem?.action == ProblemAction.signInAgain) {
      ref.read(sessionProvider.notifier).signOut();
      return;
    }
    setState(() {
      _loading = true;
      _loadProblem = null;
    });
    unawaited(_load());
  }

  /// Records an edit: the field's old problem no longer applies.
  void _edited([String? errorKey, String? alsoKey]) {
    setState(() {
      if (errorKey != null) _errors.remove(errorKey);
      if (alsoKey != null) _errors.remove(alsoKey);
    });
  }

  /// The settings as typed. Empty header rows are left out, as the server
  /// would leave them out; [_sentHeaderIds] remembers which row is which.
  SmsProviderDraft _draft() {
    final headers = <SmsHeader>[];
    final ids = <int>[];
    for (final row in _headers) {
      if (row.isEmpty) continue;
      headers.add(row.header);
      ids.add(row.id);
    }
    _sentHeaderIds = ids;
    return SmsProviderDraft(
      method: _method,
      url: _url.text.trim(),
      bodyFormat: _format,
      body: _body.text.trim(),
      headers: headers,
      secret: _secret.text.trim(),
      successText: _successText.text.trim(),
    );
  }

  /// The server's field names, turned into the names used on this screen.
  Map<String, String> _errorsFrom(
    Map<String, String> fields, {
    required bool test,
  }) {
    final headerPattern = RegExp(r'^phone\.sms\.headers\.(\d+)$');
    final out = <String, String>{};
    for (final entry in fields.entries) {
      var key = entry.key;
      if (test) {
        key = key == 'phone' ? _kTestPhone : 'phone.$key';
      }
      final match = headerPattern.firstMatch(key);
      if (match != null) {
        final index = int.parse(match.group(1)!);
        if (index < _sentHeaderIds.length) {
          key = 'header:${_sentHeaderIds[index]}';
        }
      }
      out[key] = entry.value;
    }
    return out;
  }

  /// Every key shown beside a field, in the order of the screen.
  List<String> get _placedKeys => <String>[
    _kClientId,
    _kClientSecret,
    _kMethod,
    _kUrl,
    _kFormat,
    _kBody,
    _kHeaders,
    for (final row in _headers) row.errorKey,
    _kSecret,
    _kSuccess,
    _kTestPhone,
  ];

  /// Problems the server reported for fields this screen does not show.
  List<String> get _unplacedErrors {
    final placed = _placedKeys.toSet();
    return <String>[
      for (final entry in _errors.entries)
        if (!placed.contains(entry.key) && entry.value.isNotEmpty) entry.value,
    ];
  }

  GlobalKey _anchor(String key) => _anchors.putIfAbsent(key, GlobalKey.new);

  /// Scrolls to the first field with a problem.
  void _revealFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final key in _placedKeys) {
        if (!_errors.containsKey(key)) continue;
        final anchor = (key == _kBody && _method == SmsMethod.get)
            ? _anchors[_kUrl]
            : _anchors[key];
        final context = anchor?.currentContext;
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

  // ----------------------------------------------------------- actions

  Future<void> _save() async {
    if (_saving) return;
    final update = SignInSettingsUpdate(
      googleEnabled: _googleOn,
      googleClientId: _clientId.text.trim(),
      googleClientSecret: _clientSecret.text.trim(),
      phoneEnabled: _smsOn,
      sms: _draft(),
    );
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _saveProblem = null;
      _errors = <String, String>{};
    });
    try {
      final saved = await trackedUi(
        ref,
        () => ref.read(apiProvider).saveSignInSettings(update),
      );
      if (!mounted) return;
      setState(() => _apply(saved));
      messenger.showSnackBar(SnackBar(content: Text(l10n.signInMethodsSaved)));
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        _saveProblem = problem;
        _errors = _errorsFrom(problem.fields, test: false);
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
      case ProblemAction.close ||
          ProblemAction.chooseFile ||
          ProblemAction.reload:
        setState(() => _saveProblem = null);
    }
  }

  Future<void> _sendTest() async {
    if (_testing) return;
    final l10n = AppLocalizations.of(context);
    final phone = normalisePhone(_testPhone.text);
    if (phone == null) {
      setState(() => _errors[_kTestPhone] = l10n.smsNumberInvalid);
      return;
    }
    final draft = _draft();
    setState(() {
      _testing = true;
      _testProblem = null;
      _errors.removeWhere(
        (key, _) =>
            key.startsWith('phone.sms.') ||
            key.startsWith('header:') ||
            key == _kTestPhone,
      );
    });
    try {
      final result = await trackedUi(
        ref,
        () => ref.read(apiProvider).sendTestSms(phone, draft),
      );
      if (!mounted) return;
      setState(() {
        _testResult = result;
        _lastSend = result;
      });
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        _testProblem = problem;
        _errors.addAll(_errorsFrom(problem.fields, test: true));
      });
      if (problem.fields.isNotEmpty) _revealFirstError();
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _onTestProblem() {
    final problem = _testProblem;
    if (problem == null) return;
    switch (problem.action) {
      case ProblemAction.signInAgain:
        ref.read(sessionProvider.notifier).signOut();
      case ProblemAction.tryAgain:
        unawaited(_sendTest());
      case ProblemAction.close ||
          ProblemAction.chooseFile ||
          ProblemAction.reload:
        setState(() => _testProblem = null);
    }
  }

  Future<void> _back() async {
    if (!await confirmLeave(context, ref) || !mounted) return;
    ref.read(settingsPageProvider.notifier).open(SettingsPage.overview);
  }

  Future<void> _copy(String text) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(l10n.copiedRedirect)));
  }

  Future<void> _openGuide(String section) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final address = '$signInGuideUrl$section';
    final opened = await ref.read(urlOpenerProvider)(Uri.parse(address));
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.aboutSourceFailed(address))),
      );
    }
  }

  void _setMethod(SmsMethod method) {
    setState(() {
      _method = method;
      _errors.remove(_kMethod);
      if (method == SmsMethod.get && identical(_target?.controller, _body)) {
        _target = null;
      }
    });
  }

  void _addHeader() {
    if (_headers.length >= maxSmsHeaders) return;
    final row = _newRow();
    setState(() {
      _headers.add(row);
      _errors.remove(_kHeaders);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.nameFocus.requestFocus();
    });
  }

  void _removeHeader(_HeaderRow row) {
    setState(() {
      _headers.remove(row);
      _errors
        ..remove(row.errorKey)
        ..remove(_kHeaders);
      if (identical(_target?.controller, row.value)) _target = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  /// Puts [placeholder] where the cursor is in the field last used (the
  /// body, or the address for GET, when none was used yet).
  void _insertPlaceholder(String placeholder) {
    final target =
        _target ??
        (_method == SmsMethod.post
            ? _Target(_body, _bodyFocus, _kBody)
            : _Target(_url, _urlFocus, _kUrl));
    final value = target.controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    target.controller.value = TextEditingValue(
      text: text.replaceRange(start, end, placeholder),
      selection: TextSelection.collapsed(offset: start + placeholder.length),
    );
    target.focus.requestFocus();
    _target = target;
    _edited(target.errorKey);
  }

  // ------------------------------------------------------------ layout

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Widget body;
    if (_loading) {
      body = const LoadingBlock();
    } else if (_loadProblem != null) {
      body = ProblemView(problem: _loadProblem!, onAction: _retryLoad);
    } else {
      body = _form(context);
    }
    return PageScaffold(
      leading: TextButton.icon(
        onPressed: () => unawaited(_back()),
        icon: const Icon(Icons.arrow_back),
        label: Text(l10n.settingsBack),
      ),
      title: l10n.signInMethodsTitle,
      subtitle: l10n.signInMethodsSummary,
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
          child: _limited(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _googleCard(context),
                const SizedBox(height: Spacing.space5),
                _smsCard(context),
              ],
            ),
          ),
        ),
      ),
      _limited(_saveBar(context)),
    ],
  );

  Widget _googleCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final google = _saved!.google;
    return ObPanel(
      padding: const EdgeInsets.all(Spacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MethodHeader(
            title: l10n.googleTitle,
            description: l10n.googleDescription,
            value: _googleOn,
            switchKey: const ValueKey<String>('google-switch'),
            onChanged: (on) => setState(() => _googleOn = on),
          ),
          _GuideLink(onOpen: () => _openGuide('#part-1-google-sign-in')),
          const SizedBox(height: Spacing.space4),
          _ReadOnlyAddress(
            label: l10n.googleRedirectLabel,
            value: google.redirectUrl,
            help: l10n.googleRedirectHelp,
            onCopy: () => _copy(google.redirectUrl),
          ),
          if (!google.redirectUrlUsable) ...<Widget>[
            const SizedBox(height: Spacing.space3),
            _Notice(
              tone: Tone.warning,
              icon: Icons.warning_amber_rounded,
              message: l10n.googleRedirectWarning,
            ),
          ],
          const SizedBox(height: Spacing.space5),
          KeyedSubtree(
            key: _anchor(_kClientId),
            child: TextField(
              controller: _clientId,
              autocorrect: false,
              enableSuggestions: false,
              style: codeStyle(Theme.of(context).textTheme.bodyLarge!),
              decoration: InputDecoration(
                labelText: l10n.googleClientId,
                helperText: l10n.googleClientIdHelp,
                helperMaxLines: 3,
                errorText: _errors[_kClientId],
                errorMaxLines: 4,
              ),
              onChanged: (_) => _edited(_kClientId),
            ),
          ),
          const SizedBox(height: Spacing.space4),
          KeyedSubtree(
            key: _anchor(_kClientSecret),
            child: _SecretField(
              fieldKey: const ValueKey<String>('google-secret'),
              controller: _clientSecret,
              label: l10n.googleClientSecret,
              helper: google.clientSecretSet
                  ? l10n.secretSavedKeep
                  : l10n.googleClientSecretHelp,
              errorText: _errors[_kClientSecret],
              onChanged: () => _edited(_kClientSecret),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final sms = _saved!.phone.sms;
    final post = _method == SmsMethod.post;
    final code = codeStyle(text.bodyLarge!);
    final urlErrors = <String?>[
      _errors[_kUrl],
      if (!post) _errors[_kBody],
    ].whereType<String>().join('\n');
    return ObPanel(
      padding: const EdgeInsets.all(Spacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MethodHeader(
            title: l10n.smsTitle,
            description: l10n.smsDescription,
            value: _smsOn,
            switchKey: const ValueKey<String>('sms-switch'),
            onChanged: (on) => setState(() => _smsOn = on),
          ),
          _GuideLink(onOpen: () => _openGuide('#part-2-sms-codes')),
          const SizedBox(height: Spacing.space4),
          const Divider(),
          const SizedBox(height: Spacing.space4),
          Semantics(
            header: true,
            child: Text(l10n.smsProviderTitle, style: text.titleMedium),
          ),
          const SizedBox(height: Spacing.space1),
          Text(
            l10n.smsProviderHelp,
            style: text.bodyMedium!.copyWith(color: palette.textMuted),
          ),
          const SizedBox(height: Spacing.space4),
          KeyedSubtree(
            key: _anchor(_kMethod),
            child: _Labelled(
              label: l10n.smsMethod,
              error: _errors[_kMethod],
              child: SegmentedButton<SmsMethod>(
                segments: const <ButtonSegment<SmsMethod>>[
                  ButtonSegment<SmsMethod>(
                    value: SmsMethod.post,
                    label: Text('POST'),
                  ),
                  ButtonSegment<SmsMethod>(
                    value: SmsMethod.get,
                    label: Text('GET'),
                  ),
                ],
                selected: <SmsMethod>{_method},
                onSelectionChanged: (choice) => _setMethod(choice.first),
              ),
            ),
          ),
          const SizedBox(height: Spacing.space4),
          KeyedSubtree(
            key: _anchor(_kUrl),
            child: TextField(
              key: const ValueKey<String>('sms-address'),
              controller: _url,
              focusNode: _urlFocus,
              selectAllOnFocus: false,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              style: code,
              decoration: InputDecoration(
                labelText: l10n.smsAddress,
                hintText: 'https://',
                helperText: l10n.smsAddressHelp,
                helperMaxLines: 3,
                errorText: urlErrors.isEmpty ? null : urlErrors,
                errorMaxLines: 6,
              ),
              onChanged: (_) => _edited(_kUrl, post ? null : _kBody),
            ),
          ),
          if (post) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            KeyedSubtree(
              key: _anchor(_kFormat),
              child: _Labelled(
                label: l10n.smsBodyFormat,
                error: _errors[_kFormat],
                child: SegmentedButton<SmsBodyFormat>(
                  segments: <ButtonSegment<SmsBodyFormat>>[
                    ButtonSegment<SmsBodyFormat>(
                      value: SmsBodyFormat.json,
                      label: Text(l10n.smsFormatJson),
                    ),
                    ButtonSegment<SmsBodyFormat>(
                      value: SmsBodyFormat.form,
                      label: Text(l10n.smsFormatForm),
                    ),
                  ],
                  selected: <SmsBodyFormat>{_format},
                  onSelectionChanged: (choice) => setState(() {
                    _format = choice.first;
                    _errors
                      ..remove(_kFormat)
                      ..remove(_kBody);
                  }),
                ),
              ),
            ),
            const SizedBox(height: Spacing.space4),
            KeyedSubtree(
              key: _anchor(_kBody),
              child: TextField(
                key: const ValueKey<String>('sms-body'),
                controller: _body,
                focusNode: _bodyFocus,
                selectAllOnFocus: false,
                keyboardType: TextInputType.multiline,
                minLines: 4,
                maxLines: 10,
                autocorrect: false,
                enableSuggestions: false,
                style: code,
                decoration: InputDecoration(
                  labelText: l10n.smsBody,
                  alignLabelWithHint: true,
                  helperText: l10n.smsBodyHelp,
                  helperMaxLines: 3,
                  errorText: _errors[_kBody],
                  errorMaxLines: 6,
                ),
                onChanged: (_) => _edited(_kBody),
              ),
            ),
          ],
          const SizedBox(height: Spacing.space4),
          _placeholders(context),
          const SizedBox(height: Spacing.space5),
          KeyedSubtree(key: _anchor(_kHeaders), child: _headerList(context)),
          const SizedBox(height: Spacing.space5),
          KeyedSubtree(
            key: _anchor(_kSecret),
            child: _SecretField(
              fieldKey: const ValueKey<String>('sms-secret'),
              controller: _secret,
              label: l10n.smsSecret,
              helper: sms.secretSet
                  ? l10n.secretSavedKeep
                  : l10n.smsSecretHelp(smsPlaceholders[3]),
              errorText: _errors[_kSecret],
              onChanged: () => _edited(_kSecret),
            ),
          ),
          const SizedBox(height: Spacing.space4),
          KeyedSubtree(
            key: _anchor(_kSuccess),
            child: TextField(
              key: const ValueKey<String>('sms-success'),
              controller: _successText,
              autocorrect: false,
              enableSuggestions: false,
              style: code,
              decoration: InputDecoration(
                labelText: l10n.smsSuccessText,
                helperText: l10n.smsSuccessTextHelp,
                helperMaxLines: 3,
                errorText: _errors[_kSuccess],
                errorMaxLines: 4,
              ),
              onChanged: (_) => _edited(_kSuccess),
            ),
          ),
          const SizedBox(height: Spacing.space5),
          const Divider(),
          const SizedBox(height: Spacing.space5),
          _testSection(context),
        ],
      ),
    );
  }

  Widget _placeholders(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final meanings = <String>[
      l10n.smsPlaceholderPhone,
      l10n.smsPlaceholderDigits,
      l10n.smsPlaceholderMessage,
      l10n.smsPlaceholderSecret,
    ];
    final small = text.bodySmall!.copyWith(color: palette.textMuted);
    // Inside a text-field tap region, so clicking a placeholder does not
    // take the cursor out of the field it goes into.
    return TextFieldTapRegion(
      child: Container(
        padding: const EdgeInsets.all(Spacing.space4),
        decoration: BoxDecoration(
          color: palette.bgSubtle,
          borderRadius: Radii.smAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.smsPlaceholders, style: text.labelLarge),
            const SizedBox(height: Spacing.space1),
            Text(l10n.smsPlaceholdersHelp, style: small),
            const SizedBox(height: Spacing.space3),
            Wrap(
              spacing: Spacing.space2,
              runSpacing: Spacing.space2,
              children: <Widget>[
                for (final placeholder in smsPlaceholders)
                  Tooltip(
                    message: l10n.smsInsertPlaceholder(placeholder),
                    child: ActionChip(
                      key: ValueKey<String>('insert-$placeholder'),
                      label: Text(
                        placeholder,
                        style: codeStyle(text.labelLarge!),
                      ),
                      avatar: const Icon(Icons.add, size: Sizes.iconSm),
                      onPressed: () => _insertPlaceholder(placeholder),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.space3),
            for (var i = 0; i < smsPlaceholders.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.space1),
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: smsPlaceholders[i],
                        style: codeStyle(
                          small.copyWith(
                            color: palette.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextSpan(text: ': ${meanings[i]}'),
                    ],
                  ),
                  style: small,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _headerList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final code = codeStyle(text.bodyLarge!);
    final full = _headers.length >= maxSmsHeaders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.smsHeaders, style: text.labelLarge),
        const SizedBox(height: Spacing.space1),
        Text(
          l10n.smsHeadersHelp,
          style: text.bodySmall!.copyWith(color: palette.textMuted),
        ),
        if (_errors[_kHeaders] != null) _ErrorText(_errors[_kHeaders]!),
        for (final row in _headers)
          Padding(
            key: ValueKey<int>(row.id),
            padding: const EdgeInsets.only(top: Spacing.space3),
            child: KeyedSubtree(
              key: _anchor(row.errorKey),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.name,
                          focusNode: row.nameFocus,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: code,
                          decoration: InputDecoration(
                            labelText: l10n.smsHeaderName,
                            error: _errors[row.errorKey] == null
                                ? null
                                : const SizedBox.shrink(),
                          ),
                          onChanged: (_) => _edited(row.errorKey),
                        ),
                      ),
                      const SizedBox(width: Spacing.space2),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: row.value,
                          focusNode: row.valueFocus,
                          selectAllOnFocus: false,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: code,
                          decoration: InputDecoration(
                            labelText: l10n.smsHeaderValue,
                            error: _errors[row.errorKey] == null
                                ? null
                                : const SizedBox.shrink(),
                          ),
                          onChanged: (_) => _edited(row.errorKey),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.smsHeaderRemove,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeHeader(row),
                      ),
                    ],
                  ),
                  if (_errors[row.errorKey] != null)
                    _ErrorText(_errors[row.errorKey]!),
                ],
              ),
            ),
          ),
        const SizedBox(height: Spacing.space2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Spacing.space3,
          children: <Widget>[
            TextButton.icon(
              onPressed: full ? null : _addHeader,
              icon: const Icon(Icons.add),
              label: Text(l10n.smsHeaderAdd),
            ),
            if (full)
              Text(
                l10n.smsHeadersMax(maxSmsHeaders),
                style: text.bodySmall!.copyWith(color: palette.textMuted),
              ),
          ],
        ),
      ],
    );
  }

  Widget _testSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final result = _testResult ?? _lastSend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(l10n.smsTestTitle, style: text.titleMedium),
        ),
        const SizedBox(height: Spacing.space1),
        Text(
          l10n.smsTestHelp,
          style: text.bodyMedium!.copyWith(color: palette.textMuted),
        ),
        const SizedBox(height: Spacing.space4),
        KeyedSubtree(
          key: _anchor(_kTestPhone),
          child: PhoneNumberField(
            key: const ValueKey<String>('sms-test-phone'),
            controller: _testPhone,
            label: l10n.smsTestNumber,
            errorText: _errors[_kTestPhone],
            onChanged: (_) {
              if (_errors.containsKey(_kTestPhone)) _edited(_kTestPhone);
            },
            onSubmitted: (_) => _sendTest(),
          ),
        ),
        const SizedBox(height: Spacing.space3),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: _testing ? null : _sendTest,
            icon: const Icon(Icons.send_outlined),
            label: Text(_testing ? l10n.actionSending : l10n.smsTestButton),
          ),
        ),
        if (_testProblem != null) ...<Widget>[
          const SizedBox(height: Spacing.space3),
          ProblemBanner(problem: _testProblem!, onAction: _onTestProblem),
          if (_saveProblem == null)
            for (final message in _unplacedErrors) _ErrorText(message),
        ],
        const SizedBox(height: Spacing.space5),
        _SendResultPanel(
          title: _testResult != null ? l10n.smsResultTest : l10n.smsResultLast,
          result: result,
        ),
      ],
    );
  }

  Widget _saveBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
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
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _dirty ? l10n.unsavedChanges : '',
                    style: text.bodyMedium!.copyWith(color: palette.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.space3),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? l10n.actionSaving : l10n.actionSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A card heading with an on/off switch named after it.
class _MethodHeader extends StatelessWidget {
  const _MethodHeader({
    required this.title,
    required this.description,
    required this.value,
    required this.switchKey,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final Key switchKey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: text.titleLarge),
              ),
            ),
            const SizedBox(width: Spacing.space3),
            // The switch announces its own state; the word is for the eye.
            ExcludeSemantics(
              child: Text(
                value ? l10n.methodOn : l10n.methodOff,
                style: text.labelLarge!.copyWith(
                  color: value ? palette.text : palette.textMuted,
                ),
              ),
            ),
            const SizedBox(width: Spacing.space2),
            Semantics(
              label: title,
              child: Switch(key: switchKey, value: value, onChanged: onChanged),
            ),
          ],
        ),
        const SizedBox(height: Spacing.space2),
        Text(
          description,
          style: text.bodyMedium!.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}

/// "How to set this up", opening the written guide.
class _GuideLink extends StatelessWidget {
  const _GuideLink({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      onPressed: onOpen,
      icon: const Icon(Icons.open_in_new),
      label: Text(AppLocalizations.of(context).setupGuide),
    ),
  );
}

/// A label above a control that is not a text field.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child, this.error});

  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(height: Spacing.space2),
        child,
        if (error != null) _ErrorText(error!),
      ],
    ),
  );
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

/// A coloured message with an icon.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.tone,
    required this.icon,
    required this.message,
  });

  final Tone tone;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(Spacing.space3),
      decoration: BoxDecoration(
        color: tone.background(palette),
        borderRadius: Radii.smAll,
        border: Border.all(color: tone.foreground(palette)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: Sizes.icon, color: tone.foreground(palette)),
          const SizedBox(width: Spacing.space2),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// An address to copy, which cannot be changed here.
class _ReadOnlyAddress extends StatelessWidget {
  const _ReadOnlyAddress({
    required this.label,
    required this.value,
    required this.help,
    required this.onCopy,
  });

  final String label;
  final String value;
  final String help;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: text.labelLarge),
        const SizedBox(height: Spacing.space2),
        Container(
          constraints: const BoxConstraints(minHeight: Sizes.control),
          padding: const EdgeInsetsDirectional.only(
            start: Spacing.space4,
            end: Spacing.space1,
          ),
          decoration: BoxDecoration(
            color: palette.surfaceSunken,
            borderRadius: Radii.smAll,
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  label: label,
                  child: SelectableText(
                    value,
                    style: codeStyle(text.bodyMedium!),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.space2),
              TextButton.icon(
                onPressed: value.isEmpty ? null : onCopy,
                icon: const Icon(Icons.copy_outlined),
                label: Text(l10n.actionCopy),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.space1),
        Text(help, style: text.bodySmall!.copyWith(color: palette.textMuted)),
      ],
    );
  }
}

/// A secret field: hidden, with a button to show it while typing.
class _SecretField extends StatefulWidget {
  const _SecretField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.helper,
    required this.errorText,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String helper;
  final String? errorText;
  final VoidCallback onChanged;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 3,
        errorText: widget.errorText,
        errorMaxLines: 4,
        suffixIcon: IconButton(
          tooltip: _hidden ? l10n.secretShow : l10n.secretHide,
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
      onChanged: (_) => widget.onChanged(),
    );
  }
}

/// What happened to a test SMS, or to the server's last SMS.
class _SendResultPanel extends StatelessWidget {
  const _SendResultPanel({required this.title, required this.result});

  final String title;
  final SmsSendResult? result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final outcome = result;
    final muted = text.bodySmall!.copyWith(color: palette.textMuted);
    if (outcome == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: text.labelLarge),
          const SizedBox(height: Spacing.space1),
          Text(l10n.smsResultNone, style: muted),
        ],
      );
    }
    final tone = outcome.ok ? Tone.success : Tone.danger;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: text.labelLarge),
          const SizedBox(height: Spacing.space2),
          Container(
            padding: const EdgeInsets.all(Spacing.space3),
            decoration: BoxDecoration(
              color: tone.background(palette),
              borderRadius: Radii.smAll,
              border: Border.all(color: tone.foreground(palette)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      outcome.ok
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: Sizes.icon,
                      color: tone.foreground(palette),
                    ),
                    const SizedBox(width: Spacing.space2),
                    Expanded(
                      child: Text(
                        outcome.ok ? l10n.smsResultSent : l10n.smsResultNotSent,
                        style: text.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.space2),
                Text(
                  outcome.status == 0
                      ? l10n.smsResultNoAnswer
                      : l10n.smsResultStatus('${outcome.status}'),
                  style: text.bodyMedium,
                ),
                if (outcome.reply.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Spacing.space2),
                  Text(l10n.smsResultReply, style: text.labelMedium),
                  const SizedBox(height: Spacing.space1),
                  SelectableText(
                    outcome.reply,
                    style: codeStyle(text.bodySmall!),
                  ),
                ],
                const SizedBox(height: Spacing.space2),
                Text(
                  l10n.smsResultAt(Format.when(context, outcome.at)),
                  style: muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
