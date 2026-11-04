import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_field/src/app_info.dart';
import 'package:obhijatra_field/src/forms/form_entry_controller.dart';
import 'package:obhijatra_field/src/screens/connect_screen.dart';
import 'package:obhijatra_field/src/util/bangla.dart';

void main() {
  group('Bangla numbers, dates and times', () {
    test('digits', () {
      expect(toBanglaDigits('Question 4/12'), 'Question ৪/১২');
      expect(digits(2026, bangla: true), '২০২৬');
      expect(digits(2026, bangla: false), '2026');
    });

    test('full dates match the approved design', () {
      final day = DateTime(2026, 11, 4);
      expect(fullDate(day, bangla: true), 'বুধবার, ৪ নভেম্বর ২০২৬');
      expect(fullDate(day, bangla: false), 'Wednesday, 4 November 2026');
    });

    test('times of day', () {
      expect(
        timeOfDay(DateTime(2026, 11, 4, 9, 15), bangla: true),
        'সকাল ৯:১৫',
      );
      expect(
        timeOfDay(DateTime(2026, 11, 4, 13, 5), bangla: true),
        'দুপুর ১:০৫',
      );
      expect(
        timeOfDay(DateTime(2026, 11, 4, 17, 0), bangla: true),
        'বিকাল ৫:০০',
      );
      expect(
        timeOfDay(DateTime(2026, 11, 4, 19, 0), bangla: true),
        'সন্ধ্যা ৭:০০',
      );
      expect(
        timeOfDay(DateTime(2026, 11, 4, 23, 30), bangla: true),
        'রাত ১১:৩০',
      );
      expect(timeOfDay(DateTime(2026, 11, 4, 0, 5), bangla: true), 'রাত ১২:০৫');
      expect(timeOfDay(DateTime(2026, 11, 4, 9, 15), bangla: false), '9:15 am');
      expect(
        timeOfDay(DateTime(2026, 11, 4, 12, 0), bangla: false),
        '12:00 pm',
      );
    });

    test('a moment in a sentence', () {
      final now = DateTime(2026, 11, 4, 10, 30);
      expect(
        when(DateTime(2026, 11, 4, 9, 15), bangla: true, now: now),
        'আজ সকাল ৯:১৫',
      );
      expect(
        when(DateTime(2026, 11, 3, 9, 15), bangla: true, now: now),
        'গতকাল সকাল ৯:১৫',
      );
      expect(
        when(DateTime(2026, 10, 30, 9, 15), bangla: true, now: now),
        '৩০ অক্টোবর, সকাল ৯:১৫',
      );
      expect(
        when(DateTime(2026, 11, 4, 9, 15), bangla: false, now: now),
        'today at 9:15 am',
      );
      expect(
        when(DateTime(2026, 11, 3, 21, 0), bangla: false, now: now),
        'yesterday at 9:00 pm',
      );
      expect(
        when(DateTime(2025, 12, 30, 9, 15), bangla: false, now: now),
        '30 December 2025 at 9:15 am',
      );
    });
  });

  group('server address', () {
    test('adds https and keeps only the origin', () {
      expect(
        parseServerAddress('data.example.org').address,
        Uri.parse('https://data.example.org'),
      );
      expect(
        parseServerAddress('  https://data.example.org/app/#x ').address,
        Uri.parse('https://data.example.org'),
      );
      expect(
        parseServerAddress('https://data.example.org:8443').address?.port,
        8443,
      );
    });

    test('refuses an empty or malformed address in plain terms', () {
      expect(parseServerAddress('').issue, AddressIssue.empty);
      expect(parseServerAddress('   ').issue, AddressIssue.empty);
      expect(parseServerAddress('my server').issue, AddressIssue.shape);
      expect(
        parseServerAddress('ftp://data.example.org').issue,
        AddressIssue.shape,
      );
      expect(parseServerAddress('localserver').issue, AddressIssue.shape);
    });

    test('plain http only on the local network', () {
      expect(
        parseServerAddress('http://data.example.org').issue,
        AddressIssue.insecure,
      );
      expect(parseServerAddress('http://192.168.1.20:8090').address, isNotNull);
      expect(parseServerAddress('http://10.0.2.2:8090').address, isNotNull);
      expect(parseServerAddress('http://localhost:8090').address, isNotNull);
      expect(parseServerAddress('http://172.20.0.5').address, isNotNull);
      expect(
        parseServerAddress('http://172.40.0.5').issue,
        AddressIssue.insecure,
      );
    });
  });

  group('form language', () {
    test('matches the ODK language names', () {
      const languages = ['English (en)', 'Bangla (bn)'];
      expect(pickFormLanguage(languages, const Locale('bn')), 'Bangla (bn)');
      expect(pickFormLanguage(languages, const Locale('en')), 'English (en)');
      expect(pickFormLanguage(['default'], const Locale('bn')), isNull);
      expect(pickFormLanguage(const [], const Locale('bn')), isNull);
      expect(pickFormLanguage(['bn', 'en'], const Locale('bn')), 'bn');
    });
  });

  test('the release version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(
        r'^version: (\S+)\+(\S+)$',
        multiLine: true,
      ).firstMatch(pubspec)!.groups([1, 2]),
      [appReleaseVersion, appBuildNumber],
    );
  });
}
