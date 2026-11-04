import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/app_info.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/widgets/labeled_field.dart';
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Why a typed server address is refused, before any network is used.
enum AddressIssue {
  /// Nothing was typed.
  empty,

  /// The text is not a web address.
  shape,

  /// The address would send data without protection.
  insecure,
}

/// The result of reading a typed server address.
typedef AddressResult = ({Uri? address, AddressIssue? issue});

/// Reads what the person typed as a server address.
///
/// "data.example.org" becomes `https://data.example.org`. Only the scheme,
/// host and port are kept. Plain `http` is accepted only for addresses on
/// the phone's own network (testing), never for the open internet.
AddressResult parseServerAddress(String input) {
  final text = input.trim();
  if (text.isEmpty) return (address: null, issue: AddressIssue.empty);
  if (RegExp(r'\s').hasMatch(text)) {
    return (address: null, issue: AddressIssue.shape);
  }
  final withScheme = text.contains('://') ? text : 'https://$text';
  final uri = Uri.tryParse(withScheme);
  if (uri == null ||
      !(uri.scheme == 'https' || uri.scheme == 'http') ||
      uri.host.isEmpty ||
      !(uri.host.contains('.') || uri.host == 'localhost')) {
    return (address: null, issue: AddressIssue.shape);
  }
  if (uri.scheme == 'http' && !_isLocalHost(uri.host)) {
    return (address: null, issue: AddressIssue.insecure);
  }
  final origin = Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );
  return (address: origin, issue: null);
}

bool _isLocalHost(String host) {
  if (host == 'localhost' || host.endsWith('.local')) return true;
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final nums = parts.map(int.tryParse).toList();
  if (nums.any((n) => n == null || n < 0 || n > 255)) return false;
  final a = nums[0]!;
  final b = nums[1]!;
  return a == 10 ||
      a == 127 ||
      (a == 192 && b == 168) ||
      (a == 172 && b >= 16 && b <= 31);
}

enum _Test { idle, testing, ok, failed }

/// "Connect to your organisation": the server address, a test, and a way on.
class ConnectScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final TextEditingController _controller = TextEditingController();
  _Test _test = _Test.idle;
  AddressIssue? _issue;
  String? _failure;
  Uri? _tested;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _issueText(AppLocalizations l, AddressIssue issue) => switch (issue) {
    AddressIssue.empty => l.connectErrorEmpty,
    AddressIssue.shape => l.connectErrorShape,
    AddressIssue.insecure => l.connectErrorInsecure,
  };

  Future<void> _runTest() async {
    final l = AppLocalizations.of(context);
    final parsed = parseServerAddress(_controller.text);
    if (parsed.address == null) {
      setState(() {
        _issue = parsed.issue;
        _test = _Test.idle;
      });
      return;
    }
    setState(() {
      _issue = null;
      _test = _Test.testing;
      _failure = null;
    });
    final server = ObhijatraServer(
      baseUrl: parsed.address!,
      appVersion: appReleaseVersion,
      httpClientFactory: ref.read(httpClientFactoryProvider),
      timeout: const Duration(seconds: 20),
    );
    String? failure;
    try {
      final meta = await server.fetchMeta();
      final blocker = meta.syncBlocker(appReleaseVersion);
      if (blocker != null) failure = problemText(l, blocker);
    } on ObhijatraException catch (e) {
      failure = switch (e.code) {
        ProblemCode.offline => l.connectOffline,
        ProblemCode.serverIncompatible ||
        ProblemCode.unexpectedResponse => l.connectWrongAddress,
        _ => problemText(l, e.code),
      };
    } on Object {
      failure = l.connectWrongAddress;
    } finally {
      server.close();
    }
    if (!mounted) return;
    setState(() {
      _failure = failure;
      _test = failure == null ? _Test.ok : _Test.failed;
      _tested = failure == null ? parsed.address : null;
    });
  }

  Future<void> _continue() async {
    final address = _tested;
    if (address == null) return;
    await ref.read(serverProvider.notifier).setAddress(address);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final ok = _test == _Test.ok;
    return ScreenFrame(
      topBar: TopBar(title: l.connectTitle),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          Text(l.connectIntro, style: text.bodyLarge),
          const SizedBox(height: Spacing.space5),
          LabeledField(
            fieldKey: const Key('server-address-field'),
            label: l.connectAddressLabel,
            help: l.connectAddressHelp,
            controller: _controller,
            errorText: _issue == null ? null : _issueText(l, _issue!),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            autofillHints: const <String>[AutofillHints.url],
            onSubmitted: (_) => _runTest(),
            onChanged: (_) {
              if (_test != _Test.idle || _issue != null) {
                setState(() {
                  _test = _Test.idle;
                  _issue = null;
                  _tested = null;
                });
              }
            },
          ),
          const SizedBox(height: Spacing.space4),
          if (ok)
            Panel(
              color: p.successSubtle,
              borderColor: p.success,
              child: Semantics(
                liveRegion: true,
                container: true,
                label: l.connectSuccess,
                child: ExcludeSemantics(
                  child: Row(
                    children: <Widget>[
                      Icon(LucideIcons.circleCheck, color: p.success),
                      const SizedBox(width: Spacing.space3),
                      Expanded(
                        child: Text(
                          l.connectSuccess,
                          style: text.bodyMedium!.copyWith(
                            color: p.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_test == _Test.failed && _failure != null)
            Panel(
              color: p.warningSubtle,
              borderColor: p.warning,
              child: Semantics(
                liveRegion: true,
                container: true,
                label: _failure,
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.space1),
                        child: Icon(
                          LucideIcons.triangleAlert,
                          color: p.warning,
                        ),
                      ),
                      const SizedBox(width: Spacing.space3),
                      Expanded(child: Text(_failure!, style: text.bodyMedium)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottom: BottomActions(
        children: <Widget>[
          if (ok)
            PrimaryButton(
              label: l.actionContinue,
              trailingIcon: LucideIcons.chevronRight,
              onPressed: _continue,
            ),
          PrimaryButton(
            label: _test == _Test.testing ? l.connectTesting : l.connectTest,
            icon: LucideIcons.server,
            variant: ok
                ? PrimaryButtonVariant.secondary
                : PrimaryButtonVariant.primary,
            busy: _test == _Test.testing,
            onPressed: _runTest,
          ),
        ],
      ),
    );
  }
}
