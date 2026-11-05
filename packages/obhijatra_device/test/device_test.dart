import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_device/obhijatra_device.dart';
import 'package:test/test.dart';

// The test vectors in docs/decisions/0008-device-trust.md, which the
// server's tests check too.
const _vectorCode = '225142753699752889';
const _vectorSignature =
    'jd5i3Nw3804mIJ7v6JiJZiZL0-fApy9xIFWavKqJpDe7ZsVhMVdXvkYfyBnm2GlRzO-fV95bdXGvCeL1YG9PAg';

void main() {
  group('check code', () {
    test('matches the published vector', () {
      final sign = List<int>.generate(32, (i) => i);
      final enc = List<int>.generate(32, (i) => 32 + i);
      expect(deviceCheckCode(sign, enc), _vectorCode);
      expect(groupCheckCode(_vectorCode), '225 142 753 699 752 889');
    });

    test('keeps leading zeros and has 18 digits for any keys', () {
      final random = Random(7);
      for (var i = 0; i < 200; i++) {
        final code = deviceCheckCode(
          List<int>.generate(32, (_) => random.nextInt(256)),
          List<int>.generate(32, (_) => random.nextInt(256)),
        );
        expect(code, matches(RegExp(r'^\d{18}$')));
      }
    });

    test('reads Bangla digits, spaces and dashes', () {
      final bangla = toBanglaDigits(groupCheckCode(_vectorCode));
      expect(bangla, '২২৫ ১৪২ ৭৫৩ ৬৯৯ ৭৫২ ৮৮৯');
      expect(normaliseCheckCode(bangla), _vectorCode);
      expect(normaliseCheckCode('225-142 753\t699৭৫২৮৮৯'), _vectorCode);
    });

    test('refuses keys of the wrong length', () {
      expect(
        () => deviceCheckCode(List<int>.filled(31, 0), List<int>.filled(32, 0)),
        throwsArgumentError,
      );
    });
  });

  group('signed message', () {
    test('matches the published signature vector', () async {
      final keys = await SoftwareDeviceKeys.fromSeeds(
        List<int>.filled(32, 0),
        List<int>.filled(32, 1),
      );
      final message = requestMessage(
        method: 'post',
        target: '/api/x?a=1',
        unixTime: '1793836800',
        nonce: 'AAAAAAAAAAAAAAAAAAAAAA',
        body: utf8.encode('{}'),
      );
      expect(
        utf8.decode(message),
        'OBHIJATRA-REQUEST-V1\nPOST\n/api/x?a=1\n1793836800\nAAAAAAAAAAAAAAAAAAAAAA\n'
        '44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a',
      );
      expect(base64UrlNoPadding(await keys.sign(message)), _vectorSignature);
    });
  });

  group('canonical URL', () {
    test('escapes what a browser would, and keeps the query structure', () {
      final url = Uri.parse(
        'https://obhijatra.example.org/api/collections/devices/records'
        "?filter=status%3D'pending'&sort=-created&q=a+b&x=%e0%a6%95",
      );
      final canonical = canonicalUrl(url);
      expect(
        requestTarget(canonical),
        '/api/collections/devices/records'
        '?filter=status%3D%27pending%27&sort=-created&q=a+b&x=%E0%A6%95',
      );
      // Canonical is a fixed point: sending it again changes nothing.
      expect(canonicalUrl(canonical), canonical);
      expect(canonical.queryParameters['filter'], "status='pending'");
      expect(canonical.queryParameters['q'], 'a b');
    });

    test('escapes non-ASCII and spaces built by Uri itself', () {
      final url = Uri.https('server.example', '/api/a b', {
        'name': 'রহিমা খাতুন',
        'f': "x='1'",
      });
      final target = requestTarget(canonicalUrl(url));
      expect(target, isNot(contains("'")));
      expect(target, isNot(contains(' ')));
      expect(RegExp(r'^[A-Za-z0-9\-._~%/?&=+]+$').hasMatch(target), isTrue);
      expect(canonicalUrl(url).queryParameters['name'], 'রহিমা খাতুন');
    });

    test('drops the fragment and gives an empty path a slash', () {
      expect(
        requestTarget(canonicalUrl(Uri.parse('https://s.example#x'))),
        '/',
      );
    });
  });

  group('signing client', () {
    test(
      'signs the exact bytes and target it sends, as the server checks them',
      () async {
        final keys = await SoftwareDeviceKeys.generate();
        final signer = DeviceRequestSigner(
          keys,
          deviceId: 'abcdefghijklmno',
          now: () => DateTime.utc(2026, 11, 6, 9),
        );
        late http.Request seen;
        final client = SigningHttpClient(
          MockClient((request) async {
            seen = request;
            return http.Response('{}', 200);
          }),
          signer: signer,
        );
        final multipart =
            http.MultipartRequest(
                'POST',
                Uri.parse(
                  "https://s.example/api/collections/submissions/records?expand=a&f='x'",
                ),
              )
              ..fields['note'] = 'রহিমা'
              ..files.add(
                http.MultipartFile.fromBytes(
                  'xml',
                  utf8.encode('<data/>'),
                  filename: 'a.xml',
                ),
              );
        await client.send(multipart);

        expect(seen.headers[DeviceHeaders.device], 'abcdefghijklmno');
        expect(
          seen.headers[DeviceHeaders.time],
          '${DateTime.utc(2026, 11, 6, 9).millisecondsSinceEpoch ~/ 1000}',
        );
        expect(
          base64Url.decode('${seen.headers[DeviceHeaders.nonce]}=='),
          hasLength(16),
        );
        expect(
          seen.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        expect(seen.url.query, 'expand=a&f=%27x%27');

        final message = requestMessage(
          method: seen.method,
          target: requestTarget(seen.url),
          unixTime: seen.headers[DeviceHeaders.time]!,
          nonce: seen.headers[DeviceHeaders.nonce]!,
          body: seen.bodyBytes,
        );
        final signature = base64Url.decode(
          '${seen.headers[DeviceHeaders.signature]!}==',
        );
        final ok = await Ed25519().verify(
          message,
          signature: Signature(
            signature,
            publicKey: SimplePublicKey(
              keys.signPublicKey,
              type: KeyPairType.ed25519,
            ),
          ),
        );
        expect(ok, isTrue);
      },
    );

    test('signs enrolment as "enrol", and nothing before enrolment', () async {
      final signer = DeviceRequestSigner(await SoftwareDeviceKeys.generate());
      final enrol = await signer.signatureHeaders(
        SignableRequest(
          method: 'POST',
          url: Uri.parse('https://s.example$deviceEnrolPath'),
          body: Uint8List(0),
        ),
      );
      expect(enrol[DeviceHeaders.device], enrolDeviceId);
      final other = await signer.signatureHeaders(
        SignableRequest(
          method: 'GET',
          url: Uri.parse('https://s.example/api/x'),
          body: Uint8List(0),
        ),
      );
      expect(other, isEmpty);
    });

    test('never follows a redirect', () async {
      final client = SigningHttpClient(
        MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'https://elsewhere.example'},
          ),
        ),
      );
      expect(
        client.get(Uri.parse('https://s.example/api/x')),
        throwsA(
          isA<RedirectNotFollowed>().having((e) => e.statusCode, 'status', 302),
        ),
      );
    });
  });

  test('keys round-trip through their seeds', () async {
    final keys = await SoftwareDeviceKeys.generate();
    final again = await SoftwareDeviceKeys.fromSeeds(
      keys.signSeed,
      keys.encSeed,
    );
    expect(again.signPublicKey, keys.signPublicKey);
    expect(again.encPublicKey, keys.encPublicKey);
    expect(
      keys.toString(),
      isNot(contains(keys.signSeed.first.toString() * 3)),
    );
  });
}
