// Sign-in by SMS code and by Google, against the fake server (which follows
// the server's contract), and the realtime connection Google sign-in uses.
import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/src/server/realtime_channel.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:test/test.dart';

void main() {
  late FakeObhijatraServer fake;
  late ObhijatraServer server;

  ObhijatraServer connect({
    http.Client Function()? clients,
    Duration timeout = const Duration(seconds: 60),
    AuthStore? authStore,
  }) => ObhijatraServer(
    baseUrl: FakeObhijatraServer.baseUrl,
    appVersion: '0.1.0',
    authStore: authStore,
    httpClientFactory: clients ?? fake.client,
    timeout: timeout,
  );

  setUp(() {
    fake = FakeObhijatraServer();
    server = connect();
  });
  tearDown(() => server.close());

  Matcher problem(ProblemCode code) =>
      throwsA(isA<ObhijatraException>().having((e) => e.code, 'code', code));

  group('sign-in methods', () {
    test('lists what the server offers', () async {
      var methods = await server.fetchSignInMethods();
      expect(
        [methods.password, methods.google, methods.phone],
        [true, false, false],
      );
      fake
        ..offersGoogle = true
        ..offersPhone = true;
      methods = await server.fetchSignInMethods();
      expect(
        [methods.password, methods.google, methods.phone],
        [true, true, true],
      );
    });

    test('a server from before these methods offers the password', () async {
      fake.answersSignInMethods = false;
      final methods = await server.fetchSignInMethods();
      expect(
        [methods.password, methods.google, methods.phone],
        [true, false, false],
      );
    });

    test('reads missing fields safely', () {
      final methods = SignInMethods.fromJson(const {'phone': 'yes'});
      expect(methods.password, isTrue);
      expect(methods.google, isFalse);
      expect(methods.phone, isFalse);
    });

    test('failures keep their plain meaning', () async {
      fake.signInMethodsGlitches.addAll(const [
        NoConnection(),
        ErrorStatus(503),
        Redirect(),
      ]);
      await expectLater(
        server.fetchSignInMethods(),
        problem(ProblemCode.offline),
      );
      await expectLater(
        server.fetchSignInMethods(),
        problem(ProblemCode.serverError),
      );
      await expectLater(
        server.fetchSignInMethods(),
        problem(ProblemCode.redirected),
      );
      fake.isWebsite = true;
      await expectLater(
        server.fetchSignInMethods(),
        problem(ProblemCode.unexpectedResponse),
      );
    });
  });

  group('SMS code', () {
    setUp(() => fake.offersPhone = true);

    test('a code is sent and signs the field user in', () async {
      final request = await server.requestPhoneCode(fakePhone);
      expect(request.codeId, hasLength(15));
      expect(request.phone, fakePhone);
      expect(request.expiresIn, const Duration(minutes: 5));
      expect(request.resendAfter, const Duration(seconds: 60));
      expect(fake.sentSms.single.phone, fakePhone);
      expect(server.hasValidSession, isFalse);

      final user = await server.signInWithPhoneCode(
        codeId: request.codeId,
        code: fake.sentSms.single.code,
      );
      expect(user.id, 'fielduser1abcde');
      expect(user.name, 'Rahima Akter');
      expect(server.hasValidSession, isTrue);
      expect(server.currentUser!.id, 'fielduser1abcde');
    });

    test('the session is saved in the store the app gave', () async {
      String? saved;
      final store = AsyncAuthStore(save: (data) async => saved = data);
      final client = connect(authStore: store);
      addTearDown(client.close);
      final request = await client.requestPhoneCode(fakePhone);
      await client.signInWithPhoneCode(
        codeId: request.codeId,
        code: fake.sentSms.single.code,
      );
      await pumpEventQueue();
      final json = jsonDecode(saved!) as Map<String, Object?>;
      expect(json['token'], isNotEmpty);
      expect((json['model']! as Map)['collectionName'], 'field_users');
    });

    test('Bangla digits in the code work', () async {
      final request = await server.requestPhoneCode(fakePhone);
      const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
      final code = fake.sentSms.single.code
          .split('')
          .map((d) => bangla[int.parse(d)])
          .join();
      final user = await server.signInWithPhoneCode(
        codeId: request.codeId,
        code: ' $code ',
      );
      expect(user.id, 'fielduser1abcde');
    });

    test('the answer is the same for a number without an account', () async {
      final known = await server.requestPhoneCode(fakePhone);
      final unknown = await server.requestPhoneCode('+8801812345678');
      expect(unknown.codeId, hasLength(known.codeId.length));
      expect(unknown.expiresIn, known.expiresIn);
      expect(unknown.resendAfter, known.resendAfter);
      expect(fake.sentSms, hasLength(1)); // Only the account's number.
      // Any code for it is simply wrong.
      await expectLater(
        server.signInWithPhoneCode(codeId: unknown.codeId, code: '123456'),
        problem(ProblemCode.signInCodeWrong),
      );
    });

    test('a number not in international form is never sent', () async {
      await expectLater(
        server.requestPhoneCode('01712345678'),
        problem(ProblemCode.phoneNumberInvalid),
      );
      expect(
        fake.log,
        isNot(contains('POST /api/obhijatra/v1/signin/phone/code')),
      );
      // The server's own refusal means the same.
      fake.phoneCodeGlitches.add(const ErrorStatus(400));
      await expectLater(
        server.requestPhoneCode(fakePhone),
        problem(ProblemCode.phoneNumberInvalid),
      );
    });

    test('a wrong code is refused; after 3 wrong tries the code is '
        'discarded', () async {
      final request = await server.requestPhoneCode(fakePhone);
      final right = fake.sentSms.single.code;
      final wrong = right == '000000' ? '111111' : '000000';
      for (var i = 0; i < 3; i++) {
        await expectLater(
          server.signInWithPhoneCode(codeId: request.codeId, code: wrong),
          problem(ProblemCode.signInCodeWrong),
        );
      }
      // Discarded: even the right code no longer works.
      await expectLater(
        server.signInWithPhoneCode(codeId: request.codeId, code: right),
        problem(ProblemCode.signInCodeWrong),
      );
      expect(server.hasValidSession, isFalse);
    });

    test('a code works once and expires after 5 minutes', () async {
      final start = DateTime.utc(2026, 11, 5, 9);
      final first = await withClock(
        Clock.fixed(start),
        () => server.requestPhoneCode(fakePhone),
      );
      await withClock(
        Clock.fixed(start.add(const Duration(minutes: 6))),
        () => expectLater(
          server.signInWithPhoneCode(
            codeId: first.codeId,
            code: fake.sentSms.last.code,
          ),
          problem(ProblemCode.signInCodeWrong),
        ),
      );

      final second = await server.requestPhoneCode(fakePhone);
      final code = fake.sentSms.last.code;
      await server.signInWithPhoneCode(codeId: second.codeId, code: code);
      await expectLater(
        server.signInWithPhoneCode(codeId: second.codeId, code: code),
        problem(ProblemCode.signInCodeWrong),
      );
    });

    test('a code that is not 6 digits is never sent', () async {
      final request = await server.requestPhoneCode(fakePhone);
      for (final code in ['', '12345', '1234567', '12a456']) {
        await expectLater(
          server.signInWithPhoneCode(codeId: request.codeId, code: code),
          problem(ProblemCode.signInCodeWrong),
          reason: code,
        );
      }
      expect(
        fake.log,
        isNot(contains('POST /api/obhijatra/v1/signin/phone/verify')),
      );
    });

    test('too many codes for one number: 3 in 15 minutes', () async {
      for (var i = 0; i < 3; i++) {
        await server.requestPhoneCode(fakePhone);
      }
      await expectLater(
        server.requestPhoneCode(fakePhone),
        problem(ProblemCode.tooManySignInCodes),
      );
    });

    test('SMS sign-in switched off, too many checks, no connection', () async {
      final request = await server.requestPhoneCode(fakePhone);
      fake.signInGlitches.addAll(const [ErrorStatus(429), NoConnection()]);
      await expectLater(
        server.signInWithPhoneCode(codeId: request.codeId, code: '123456'),
        problem(ProblemCode.tooManyCodeTries),
      );
      await expectLater(
        server.signInWithPhoneCode(codeId: request.codeId, code: '123456'),
        problem(ProblemCode.offline),
      );
      fake.offersPhone = false;
      await expectLater(
        server.requestPhoneCode(fakePhone),
        problem(ProblemCode.signInMethodOff),
      );
      await expectLater(
        server.signInWithPhoneCode(codeId: request.codeId, code: '123456'),
        problem(ProblemCode.signInMethodOff),
      );
      fake.phoneCodeGlitches.add(const NoConnection());
      await expectLater(
        server.requestPhoneCode(fakePhone),
        problem(ProblemCode.offline),
      );
    });

    test('no session token is sent to the sign-in routes', () async {
      final seen = <http.BaseRequest>[];
      final client = connect(
        clients: () => _Spy(fake.client(), seen),
        authStore: AuthStore()
          ..save(
            fakeToken('someoneelse0000'),
            RecordModel({
              'id': 'someoneelse0000',
              'collectionName': 'field_users',
            }),
          ),
      );
      addTearDown(client.close);
      final request = await client.requestPhoneCode(fakePhone);
      await client.signInWithPhoneCode(
        codeId: request.codeId,
        code: fake.sentSms.single.code,
      );
      expect(seen, hasLength(2));
      expect(
        seen.every((r) => !r.headers.containsKey('Authorization')),
        isTrue,
      );
    });
  });

  group('Google', () {
    late List<Uri> opened;

    Future<void> openBrowser(Uri url) async => opened.add(url);

    setUp(() {
      fake.offersGoogle = true;
      opened = [];
    });

    /// Waits until the app has opened Google's page.
    Future<Uri> googlePage() async {
      for (var i = 0; i < 100 && opened.isEmpty; i++) {
        await pumpEventQueue();
      }
      return opened.single;
    }

    test('signs in through the browser and the realtime answer', () async {
      final signIn = server.signInWithGoogle(openBrowser);
      final page = await googlePage();
      expect(page.scheme, 'https');
      expect(page.host, 'accounts.google.example');
      expect(
        page.queryParameters['redirect_uri'],
        'https://data.example.org/api/oauth2-redirect',
      );
      expect(page.queryParameters['state'], startsWith('realtime'));
      expect(fake.openRealtimeConnections, 1);

      expect(fake.finishGoogleSignIn(page), isTrue);
      final user = await signIn;
      expect(user.id, 'fielduser1abcde');
      expect(server.hasValidSession, isTrue);
      // The realtime connection lives only as long as the sign-in.
      expect(fake.openRealtimeConnections, 0);
      expect(fake.log, [
        'GET /api/collections/field_users/auth-methods',
        'GET /api/realtime',
        'POST /api/realtime',
        'POST /api/collections/field_users/auth-with-oauth2',
      ]);
    });

    test('the Google email matches the account ignoring capitals', () async {
      final signIn = server.signInWithGoogle(openBrowser);
      fake.finishGoogleSignIn(
        await googlePage(),
        googleEmail: 'Field1@Example.org',
      );
      expect((await signIn).id, 'fielduser1abcde');
    });

    test('the server refuses Google accounts it does not know', () async {
      fake.users['new@example.org'] = const FakeFieldUser(
        id: 'unconfirmed0000',
        emailConfirmed: false,
      );
      fake.users['gone@example.org'] = const FakeFieldUser(
        id: 'deactivated0000',
        active: false,
      );
      for (final email in [
        'stranger@example.org', // no account
        'new@example.org', // the admin has not confirmed the email
        'gone@example.org', // deactivated
        '', // Google shared no confirmed email
      ]) {
        opened.clear();
        final signIn = server.signInWithGoogle(openBrowser);
        fake.finishGoogleSignIn(await googlePage(), googleEmail: email);
        await expectLater(
          signIn,
          problem(ProblemCode.googleSignInRefused),
          reason: email,
        );
        expect(server.hasValidSession, isFalse);
        expect(fake.openRealtimeConnections, 0);
      }
    });

    test('declining on Google\'s page is a cancelled sign-in', () async {
      final signIn = server.signInWithGoogle(openBrowser);
      fake.finishGoogleSignIn(await googlePage(), decline: true);
      await expectLater(signIn, problem(ProblemCode.signInCancelled));
      expect(fake.openRealtimeConnections, 0);
      expect(
        fake.log,
        isNot(contains('POST /api/collections/field_users/auth-with-oauth2')),
      );
    });

    test('Cancel stops waiting at once and closes the connection', () async {
      final cancel = SignInCancellation();
      final signIn = server.signInWithGoogle(openBrowser, cancellation: cancel);
      final page = await googlePage();
      expect(fake.openRealtimeConnections, 1);
      cancel.cancel();
      await expectLater(signIn, problem(ProblemCode.signInCancelled));
      await pumpEventQueue();
      expect(fake.openRealtimeConnections, 0);
      // Finishing on Google's page afterwards reaches nobody.
      expect(fake.finishGoogleSignIn(page), isFalse);
      expect(server.hasValidSession, isFalse);
      // Cancelling again does nothing.
      cancel.cancel();
    });

    test('a sign-in cancelled before it starts never connects', () async {
      final cancel = SignInCancellation()..cancel();
      await expectLater(
        server.signInWithGoogle(openBrowser, cancellation: cancel),
        problem(ProblemCode.signInCancelled),
      );
      await pumpEventQueue();
      expect(opened, isEmpty);
      expect(fake.openRealtimeConnections, 0);
    });

    test('a sign-in that finishes after Cancel is thrown away', () async {
      final exchange = Completer<void>();
      final client = connect(
        clients: () => _Holding(
          fake.client(),
          '/api/collections/field_users/auth-with-oauth2',
          exchange.future,
        ),
      );
      addTearDown(client.close);
      final cancel = SignInCancellation();
      final signIn = client.signInWithGoogle(openBrowser, cancellation: cancel);
      fake.finishGoogleSignIn(await googlePage());
      // The code exchange is under way when the person cancels.
      for (var i = 0; i < 20; i++) {
        await pumpEventQueue();
      }
      cancel.cancel();
      await expectLater(signIn, problem(ProblemCode.signInCancelled));
      exchange.complete();
      for (var i = 0; i < 20; i++) {
        await pumpEventQueue();
      }
      expect(
        fake.log,
        contains('POST /api/collections/field_users/auth-with-oauth2'),
      );
      expect(client.hasValidSession, isFalse);
      expect(client.currentUser, isNull);
    });

    test('closing the server while waiting ends the sign-in', () async {
      final client = connect();
      final signIn = client.signInWithGoogle(openBrowser);
      await googlePage();
      client.close();
      await expectLater(signIn, problem(ProblemCode.signInCancelled));
      await pumpEventQueue();
      expect(fake.openRealtimeConnections, 0);
    });

    test('Google sign-in switched off', () async {
      fake.offersGoogle = false;
      await expectLater(
        server.signInWithGoogle(openBrowser),
        problem(ProblemCode.signInMethodOff),
      );
      expect(opened, isEmpty);
      expect(fake.openRealtimeConnections, 0);
    });

    test('a phone without a browser', () async {
      await expectLater(
        server.signInWithGoogle((url) async => throw StateError('no browser')),
        problem(ProblemCode.browserUnavailable),
      );
      await expectLater(
        server.signInWithGoogle(
          (url) async =>
              throw const ObhijatraException(ProblemCode.browserUnavailable),
        ),
        problem(ProblemCode.browserUnavailable),
      );
      await pumpEventQueue();
      expect(fake.openRealtimeConnections, 0);
    });

    test('a lost realtime connection is offline; one the server ended '
        'took too long', () async {
      var signIn = server.signInWithGoogle(openBrowser);
      await googlePage();
      await fake.endRealtime(broken: true);
      await expectLater(signIn, problem(ProblemCode.offline));

      opened.clear();
      signIn = server.signInWithGoogle(openBrowser);
      await googlePage();
      await fake.endRealtime();
      await expectLater(signIn, problem(ProblemCode.timeout));
    });

    test('no realtime connection: offline, refused, redirected', () async {
      fake.realtimeGlitches.addAll(const [
        NoConnection(),
        ErrorStatus(503),
        Redirect(),
      ]);
      await expectLater(
        server.signInWithGoogle(openBrowser),
        problem(ProblemCode.offline),
      );
      await expectLater(
        server.signInWithGoogle(openBrowser),
        problem(ProblemCode.serverError),
      );
      await expectLater(
        server.signInWithGoogle(openBrowser),
        problem(ProblemCode.redirected),
      );
      expect(opened, isEmpty);
    });

    test('a refused code exchange and other failures', () async {
      fake.signInGlitches.addAll(const [ErrorStatus(403), NoConnection()]);
      var signIn = server.signInWithGoogle(openBrowser);
      fake.finishGoogleSignIn(await googlePage());
      await expectLater(signIn, problem(ProblemCode.signInMethodOff));
      opened.clear();
      signIn = server.signInWithGoogle(openBrowser);
      fake.finishGoogleSignIn(await googlePage());
      await expectLater(signIn, problem(ProblemCode.offline));
      expect(server.hasValidSession, isFalse);
      expect(fake.openRealtimeConnections, 0);
    });

    test('never opens anything but a secure web page', () async {
      final client = connect(
        clients: () => _Rewriting(
          fake.client(),
          '/api/collections/field_users/auth-methods',
          (body) => body.replaceAll(
            'https://accounts.google.example',
            'intent://accounts.google.example',
          ),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.signInWithGoogle(openBrowser),
        problem(ProblemCode.unexpectedResponse),
      );
      expect(opened, isEmpty);
      await pumpEventQueue();
      expect(fake.openRealtimeConnections, 0);
    });

    test(
      'the request time limit does not cut the realtime connection',
      () async {
        // Google's page takes far longer than the time limit for an answer.
        final client = connect(timeout: const Duration(milliseconds: 50));
        addTearDown(client.close);
        final signIn = client.signInWithGoogle(openBrowser);
        final page = await googlePage();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(fake.finishGoogleSignIn(page), isTrue);
        expect((await signIn).id, 'fielduser1abcde');
      },
    );
  });

  group('SigningHttpClient', () {
    test(
      'limits only the wait for the answer, not the stream after it',
      () async {
        final body = StreamController<List<int>>();
        final client = SigningHttpClient(
          MockClient.streaming(
            (request, _) async => http.StreamedResponse(body.stream, 200),
          ),
          timeout: const Duration(milliseconds: 20),
        );
        addTearDown(client.close);
        final response = await client.send(
          http.Request('GET', Uri.parse('https://a.example/api/realtime')),
        );
        final received = response.stream.toBytes();
        body.add(utf8.encode('first '));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        body.add(utf8.encode('second'));
        await body.close();
        expect(utf8.decode(await received), 'first second');
      },
    );
  });

  group('RealtimeChannel', () {
    late StreamController<List<int>> body;
    late List<http.BaseRequest> requests;

    http.Client stream({int status = 200}) =>
        MockClient.streaming((request, _) async {
          requests.add(request);
          return http.StreamedResponse(body.stream, status);
        });

    setUp(() {
      body = StreamController<List<int>>();
      requests = [];
    });
    tearDown(() => unawaited(body.close()));

    final url = Uri.parse('https://data.example.org/api/realtime');

    test('reads server-sent events as the standard writes them', () async {
      body.add(
        utf8.encode(
          ': a comment first\n'
          'id:client1\nevent:PB_CONNECT\ndata:{"clientId":"client1"}\n\n',
        ),
      );
      final channel = await RealtimeChannel.connect(stream(), url);
      expect(channel.clientId, 'client1');
      expect(requests.single.headers['accept'], 'text/event-stream');

      final next = channel.next('@oauth2');
      final other = channel.next('other');
      // Split across chunks, with a space after the colon, two data lines,
      // and an event nobody waits for in between.
      body
        ..add(utf8.encode('event: ignored\ndata: x\n\nid:client1\nev'))
        ..add(utf8.encode('ent:@oauth2\ndata: {"a":\ndata:1}\n\n'));
      final event = await next;
      expect(event.name, '@oauth2');
      expect(event.id, 'client1');
      expect(event.data, '{"a":\n1}');

      channel.close();
      expect(channel.isClosed, isTrue);
      await expectLater(
        other,
        throwsA(
          isA<RealtimeChannelException>().having(
            (e) => e.closedHere,
            'closedHere',
            isTrue,
          ),
        ),
      );
      await pumpEventQueue();
      expect(body.hasListener, isFalse);
      channel.close(); // Closing twice does nothing.
    });

    test(
      'takes the client id from the event id if the data has none',
      () async {
        body.add(utf8.encode('id:client2\nevent:PB_CONNECT\ndata:{}\n\n'));
        final channel = await RealtimeChannel.connect(stream(), url);
        expect(channel.clientId, 'client2');
        channel.close();
      },
    );

    test('a refused connection reports its status', () async {
      await expectLater(
        RealtimeChannel.connect(stream(status: 403), url),
        throwsA(
          isA<RealtimeChannelException>().having(
            (e) => e.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test('a connection that ends before PB_CONNECT fails', () async {
      final connecting = RealtimeChannel.connect(stream(), url);
      await pumpEventQueue();
      await body.close();
      await expectLater(
        connecting,
        throwsA(
          isA<RealtimeChannelException>()
              .having((e) => e.cause, 'cause', isNull)
              .having((e) => e.closedHere, 'closedHere', isFalse),
        ),
      );
    });

    test('a broken connection fails what waits on it', () async {
      body.add(
        utf8.encode('id:c\nevent:PB_CONNECT\ndata:{"clientId":"c"}\n\n'),
      );
      final channel = await RealtimeChannel.connect(stream(), url);
      final next = channel.next('@oauth2');
      body.addError(http.ClientException('reset'));
      await expectLater(
        next,
        throwsA(
          isA<RealtimeChannelException>().having(
            (e) => e.cause,
            'cause',
            isA<http.ClientException>(),
          ),
        ),
      );
      expect(channel.isClosed, isTrue);
      await expectLater(
        channel.next('@oauth2'),
        throwsA(isA<RealtimeChannelException>()),
      );
    });
  });
}

/// Records every request on its way to [_inner].
final class _Spy extends http.BaseClient {
  _Spy(this._inner, this._seen);

  final http.Client _inner;
  final List<http.BaseRequest> _seen;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    _seen.add(request);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Holds requests to [_path] until [_release] completes.
final class _Holding extends http.BaseClient {
  _Holding(this._inner, this._path, this._release);

  final http.Client _inner;
  final String _path;
  final Future<void> _release;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == _path) await _release;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Changes the body of answers from [_path].
final class _Rewriting extends http.BaseClient {
  _Rewriting(this._inner, this._path, this._change);

  final http.Client _inner;
  final String _path;
  final String Function(String body) _change;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (request.url.path != _path) return response;
    final body = _change(await response.stream.bytesToString());
    return http.StreamedResponse(
      http.ByteStream.fromBytes(utf8.encode(body)),
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close() => _inner.close();
}
