// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'অভিযাত্রা';

  @override
  String get splashLoading => 'অ্যাপ খোলা হচ্ছে';

  @override
  String get actionCancel => 'বাতিল করুন';

  @override
  String get actionClose => 'বন্ধ করুন';

  @override
  String get actionBack => 'ফিরে যান';

  @override
  String get actionTryAgain => 'আবার চেষ্টা করুন';

  @override
  String get actionContinue => 'এগিয়ে যান';

  @override
  String get actionRetryStartup => 'আবার চেষ্টা করুন';

  @override
  String get startupProblemTitle => 'অ্যাপটি চালু করা যায়নি';

  @override
  String get connectTitle => 'আপনার প্রতিষ্ঠানের সাথে যুক্ত হন';

  @override
  String get connectIntro =>
      'আপনার প্রতিষ্ঠান যে সার্ভারের ঠিকানা দিয়েছে, সেটি লিখুন।';

  @override
  String get connectAddressLabel => 'সার্ভারের ঠিকানা';

  @override
  String get connectAddressHelp => 'যেমন: data.example.org';

  @override
  String get connectErrorEmpty => 'সার্ভারের ঠিকানা লিখুন।';

  @override
  String get connectErrorShape =>
      'এটি ঠিকানার মতো দেখাচ্ছে না। ঠিকানা এমন হয়: data.example.org।';

  @override
  String get connectErrorInsecure =>
      'https:// দিয়ে শুরু হওয়া ঠিকানা ব্যবহার করুন, যাতে পথে আপনার তথ্য সুরক্ষিত থাকে।';

  @override
  String get connectTest => 'সংযোগ পরীক্ষা করুন';

  @override
  String get connectTesting => 'সংযোগ পরীক্ষা করা হচ্ছে…';

  @override
  String get connectSuccess => 'সংযোগ হয়েছে। সার্ভারটি প্রস্তুত।';

  @override
  String get connectWrongAddress =>
      'এই ঠিকানায় অভিযাত্রা সার্ভার পাওয়া যায়নি। ঠিকানাটি আপনার প্রতিষ্ঠানের কাছ থেকে আবার দেখে নিন।';

  @override
  String get connectOffline =>
      'এই ঠিকানায় পৌঁছানো যায়নি। ফোনের ইন্টারনেট এবং ঠিকানাটি দেখে নিন।';

  @override
  String get signInTitle => 'সাইন ইন';

  @override
  String signInServer(String server) {
    return '$server-এর সাথে যুক্ত';
  }

  @override
  String get signInEmail => 'ইমেইল';

  @override
  String get signInPassword => 'পাসওয়ার্ড';

  @override
  String get signInShowPassword => 'পাসওয়ার্ড দেখান';

  @override
  String get signInHidePassword => 'পাসওয়ার্ড লুকান';

  @override
  String get signInEmptyEmail => 'আপনার ইমেইল লিখুন।';

  @override
  String get signInEmptyPassword => 'আপনার পাসওয়ার্ড লিখুন।';

  @override
  String get signInNeedsInternet =>
      'প্রথমবার সাইন ইন করতে ইন্টারনেট লাগবে। এরপর অ্যাপ অফলাইনেও কাজ করবে।';

  @override
  String get signInWorking => 'সাইন ইন হচ্ছে…';

  @override
  String get signInChangeServer => 'অন্য সার্ভার ব্যবহার করুন';

  @override
  String get navToday => 'আজ';

  @override
  String get navForms => 'ফর্ম';

  @override
  String get navSending => 'পাঠানো';

  @override
  String get navMore => 'আরও';

  @override
  String get navMainMenu => 'প্রধান মেনু';

  @override
  String get todayTitle => 'আজ';

  @override
  String get offlineTitle => 'আপনি অফলাইনে আছেন।';

  @override
  String get offlineMessage => 'কাজ চালিয়ে যান, সবকিছু এই ফোনে সেভ হচ্ছে।';

  @override
  String get statWaiting => 'পাঠানোর অপেক্ষায়';

  @override
  String get statDrafts => 'খসড়া সেভ করা আছে';

  @override
  String lastSyncedAt(String when) {
    return 'শেষ সিঙ্ক $when-এ। সিগন্যাল পেলে ফর্মগুলো নিজে থেকেই চলে যাবে।';
  }

  @override
  String get lastSyncedNever =>
      'এখনও সিঙ্ক হয়নি। ফর্ম পেতে ও কাজ পাঠাতে একবার ইন্টারনেটে যুক্ত হন।';

  @override
  String get formsToFill => 'পূরণ করার ফর্ম';

  @override
  String get formsEmptyTitle => 'এখনও কোনো ফর্ম নেই';

  @override
  String get formsEmptyBody =>
      'প্রথম সিঙ্কের পর আপনার ফর্ম এখানে দেখা যাবে। ইন্টারনেটে যুক্ত হয়ে \"ফর্ম হালনাগাদ করুন\" চাপুন।';

  @override
  String get formsUpdate => 'ফর্ম হালনাগাদ করুন';

  @override
  String get formsUpdating => 'ফর্ম হালনাগাদ হচ্ছে…';

  @override
  String formsUpdateFailed(String reason) {
    return 'ফর্ম হালনাগাদ করা যায়নি। $reason';
  }

  @override
  String get formMetaNew => 'নতুন পূরণ শুরু করুন';

  @override
  String formMetaDrafts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countStringটি খসড়া সেভ করা আছে';
  }

  @override
  String get draftsHeading => 'খসড়া';

  @override
  String draftSavedAt(String when) {
    return '$when সেভ হয়েছে';
  }

  @override
  String get draftContinue => 'এই খসড়া চালিয়ে যান';

  @override
  String get signInAgainBanner =>
      'ফর্ম পাঠাতে আবার সাইন ইন করুন। আপনার উত্তর এই ফোনেই থাকবে।';

  @override
  String get syncBlockedUpdate =>
      'ফর্ম পাঠাতে অ্যাপটি আপডেট করুন। আপনার উত্তর রাখা আছে।';

  @override
  String get syncSendingNow => 'পাঠানো হচ্ছে…';

  @override
  String get sendingTitle => 'পাঠানো';

  @override
  String get sendingEmpty =>
      'এখানে এখনও কিছু নেই। আপনি যে ফর্ম শেষ করবেন, তা এখানে দেখা যাবে।';

  @override
  String get sendingNow => 'এখনই পাঠান';

  @override
  String get stateQueued => 'পাঠানোর অপেক্ষায়';

  @override
  String get stateSending => 'পাঠানো হচ্ছে…';

  @override
  String stateSent(String when) {
    return '$when-এ পাঠানো হয়েছে';
  }

  @override
  String get stateProblem => 'পাঠানো যায়নি';

  @override
  String get stateOnPhone => 'এই ফোনে সেভ আছে';

  @override
  String sendingFinishedAt(String when) {
    return '$when শেষ করা হয়েছে';
  }

  @override
  String questionProgress(int n, int total) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'প্রশ্ন $nString/$totalString';
  }

  @override
  String get savedBadge => 'সেভ হয়েছে';

  @override
  String get closeForm => 'ফর্ম বন্ধ করুন';

  @override
  String get requiredMark => 'আবশ্যক';

  @override
  String get entryBack => 'পেছনে যান';

  @override
  String get entryNext => 'পরের প্রশ্ন';

  @override
  String get entryFinish => 'শেষ করুন';

  @override
  String get helpChooseOne => 'একটি বেছে নিন।';

  @override
  String get helpChooseMany => 'যেগুলো প্রযোজ্য সবগুলো বেছে নিন।';

  @override
  String get pickDate => 'তারিখ বেছে নিন';

  @override
  String get issueRequired => 'এই প্রশ্নের উত্তর দিন।';

  @override
  String get issueConstraint => 'এই উত্তরটি ঠিক মনে হচ্ছে না। আবার দেখে লিখুন।';

  @override
  String get issueInvalidInteger => 'একটি পূর্ণসংখ্যা লিখুন, যেমন ৫।';

  @override
  String get issueInvalidDecimal => 'একটি সংখ্যা লিখুন, যেমন ২.৫।';

  @override
  String get issueInvalidDate => 'একটি তারিখ বেছে নিন।';

  @override
  String get issueInvalidChoice => 'তালিকা থেকে বেছে নিন।';

  @override
  String get issueInvalidText => 'এই উত্তরটি পড়া যায়নি। আবার দেখে লিখুন।';

  @override
  String get unsupportedTitle => 'এই ধরনের প্রশ্ন এখনও সমর্থিত নয়';

  @override
  String get unsupportedBody =>
      'অ্যাপের এই সংস্করণে এটি দেখানো যায় না। আপনার প্রতিষ্ঠান ফর্ম বা অ্যাপ হালনাগাদ করতে পারবে। আপনি পরের প্রশ্নে যেতে পারেন।';

  @override
  String get unsupportedRequiredBody =>
      'এই প্রশ্নের উত্তর দেওয়া আবশ্যক, তাই এখন ফর্মটি শেষ করা যাবে না। এ পর্যন্ত আপনার উত্তর সেভ আছে। আপনার প্রতিষ্ঠানকে জানান।';

  @override
  String repeatPromptTitle(String label) {
    return 'আরও একটি $label যোগ করবেন?';
  }

  @override
  String get repeatPromptTitleNoLabel => 'আরও একটি যোগ করবেন?';

  @override
  String get repeatAdd => 'আরও যোগ করুন';

  @override
  String get repeatNoMore => 'আর নয়';

  @override
  String get formOpenFailedTitle => 'ফর্মটি খোলা যায়নি';

  @override
  String get formNotOnPhone =>
      'ফর্মটি ফোনে নেই। ইন্টারনেট থাকলে হোম স্ক্রিনে \"ফর্ম হালনাগাদ করুন\" চাপুন।';

  @override
  String get entryBackToToday => 'তালিকায় ফিরুন';

  @override
  String get finishTitle => 'শেষ করে পাঠান';

  @override
  String get finishBackToQuestions => 'প্রশ্নে ফিরে যান';

  @override
  String get summaryTitle => 'সারসংক্ষেপ';

  @override
  String get summaryAnswered => 'উত্তর দেওয়া হয়েছে';

  @override
  String summaryAnsweredValue(int answered, int total) {
    final intl.NumberFormat answeredNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String answeredString = answeredNumberFormat.format(answered);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalStringটির মধ্যে $answeredStringটি';
  }

  @override
  String get summaryStarted => 'শুরু করেছেন';

  @override
  String get summaryReady =>
      'সব উত্তর দেওয়া হয়েছে। আপনি ফর্মটি পাঠাতে পারেন।';

  @override
  String validationTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি উত্তর ঠিক করতে হবে',
      one: 'একটি উত্তর ঠিক করতে হবে',
    );
    return '$_temp0';
  }

  @override
  String validationMessage(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'প্রতিটি ঠিক করুন, তারপর আবার পাঠান।',
      one: 'এটি ঠিক করুন, তারপর আবার পাঠান।',
    );
    return '$_temp0';
  }

  @override
  String validationItem(String question, String reason) {
    return '$question: $reason';
  }

  @override
  String get finishSend => 'পাঠান';

  @override
  String get finishSending => 'পাঠানো হচ্ছে…';

  @override
  String get finishKeepDraft => 'খসড়া হিসেবে রাখুন';

  @override
  String get finishDraftKept => 'খসড়া হিসেবে সেভ হয়েছে।';

  @override
  String get outcomeSentTitle => 'পাঠানো হয়েছে';

  @override
  String get outcomeSentBody =>
      'আপনার উত্তরগুলো আপনার প্রতিষ্ঠানের কাছে পৌঁছেছে।';

  @override
  String outcomeSentChip(String when) {
    return '$when-এ পাঠানো';
  }

  @override
  String get outcomeWaitingTitle => 'সিগন্যালের অপেক্ষায়';

  @override
  String get outcomeWaitingBody =>
      'আপনার উত্তর এই ফোনে নিরাপদে সেভ আছে। সিগন্যাল পেলেই নিজে থেকে পাঠানো হবে, আপনাকে কিছু করতে হবে না।';

  @override
  String outcomeWaitingCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'পাঠানোর অপেক্ষায় মোট $countStringটি ফর্ম।';
  }

  @override
  String get outcomeProblemTitle => 'পাঠানো যায়নি';

  @override
  String get outcomeProblemSafe => 'আপনার উত্তর হারায়নি, এই ফোনে সেভ আছে।';

  @override
  String get outcomeNext => 'পরেরটি শুরু করুন';

  @override
  String get outcomeBackToToday => 'আজকের তালিকায় ফিরুন';

  @override
  String get outcomeSignIn => 'আবার সাইন ইন করুন';

  @override
  String get moreTitle => 'আরও';

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get settingsLanguage => 'ভাষা';

  @override
  String get languageBangla => 'বাংলা';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsAccount => 'অ্যাকাউন্ট';

  @override
  String settingsSignedInAs(String name) {
    return '$name হিসেবে সাইন ইন করা আছে';
  }

  @override
  String get settingsSignOut => 'সাইন আউট';

  @override
  String get signOutConfirmTitle => 'সাইন আউট করবেন?';

  @override
  String get signOutNothingWaiting =>
      'ফর্ম পাঠাতে আপনাকে আবার সাইন ইন করতে হবে। আপনার খসড়াগুলো এই ফোনেই থাকবে।';

  @override
  String signOutOutboxWarning(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countStringটি ফর্ম এখনও পাঠানো হয়নি। সেগুলো এই ফোনে নিরাপদে থাকবে, কিন্তু শুধু আপনার অ্যাকাউন্ট থেকেই পাঠানো যাবে। সিগন্যাল পেলে একই অ্যাকাউন্টে আবার সাইন ইন করুন।';
  }

  @override
  String get settingsAbout => 'অভিযাত্রা সম্পর্কে';

  @override
  String get settingsSection => 'সেটিংস';

  @override
  String get aboutTitle => 'সম্পর্কে';

  @override
  String aboutVersion(String version) {
    return 'সংস্করণ $version';
  }

  @override
  String get aboutMadeBy => 'Made by Aninda Studio';

  @override
  String get aboutLicenceHeading => 'মুক্ত সফটওয়্যার';

  @override
  String get aboutLicenceBody =>
      'অভিযাত্রা একটি মুক্ত সফটওয়্যার, যা GNU Affero General Public License, সংস্করণ ৩ (AGPL-3.0) অনুযায়ী দেওয়া হয়েছে। আপনি এটি ব্যবহার করতে, বুঝতে, বদলাতে ও অন্যকে দিতে পারেন। বদলানো সংস্করণ অন্যদের জন্য চালালে আপনার বদলগুলোও একই লাইসেন্সে সবার সাথে ভাগ করতে হবে। এর কোনো ওয়ারেন্টি নেই।';

  @override
  String get aboutSourceLink => 'সোর্স কোড দেখুন';

  @override
  String aboutLinkFailed(String url) {
    return 'লিংকটি খোলা যায়নি। ঠিকানাটি হলো $url';
  }

  @override
  String get aboutLicences => 'ওপেন-সোর্স লাইসেন্স';

  @override
  String get problem_offline =>
      'এখন ইন্টারনেট সংযোগ নেই। আপনার কাজ এই ফোনে নিরাপদ আছে, সিগন্যাল ফিরলে পাঠানো হবে।';

  @override
  String get problem_timeout =>
      'সংযোগ খুব ধীর। আমরা নিজে থেকেই আবার চেষ্টা করব।';

  @override
  String get problem_serverError =>
      'সার্ভারে সমস্যা হয়েছে। এটি আপনার ভুল নয়। আমরা নিজে থেকেই আবার চেষ্টা করব।';

  @override
  String get problem_serverBusy =>
      'সার্ভার এখন ব্যস্ত। কিছুক্ষণ পর আবার চেষ্টা করা হবে।';

  @override
  String get problem_signInRequired =>
      'ফর্ম পাঠাতে আবার সাইন ইন করুন। আপনার উত্তর এই ফোনেই থাকবে।';

  @override
  String get problem_signInFailed =>
      'ইমেইল বা পাসওয়ার্ড ঠিক নয়, অথবা অ্যাকাউন্টটি চালু নেই। দেখে আবার চেষ্টা করুন।';

  @override
  String get problem_accountNotPermitted =>
      'এই অ্যাকাউন্ট দিয়ে এটি করা যাবে না। আপনার প্রতিষ্ঠানের সাথে যোগাযোগ করুন।';

  @override
  String get problem_differentUser =>
      'এই ফোনে অন্য একজনের ফর্ম এখনও পাঠানো বাকি আছে। আগে সেই ব্যক্তির অ্যাকাউন্টে সাইন ইন করে সেগুলো পাঠান।';

  @override
  String get problem_appUpdateRequired =>
      'ফর্ম পাঠানোর জন্য এই অ্যাপ খুব পুরনো। অ্যাপটি আপডেট করুন। আপনার উত্তর রাখা আছে।';

  @override
  String get problem_serverIncompatible =>
      'অ্যাপ ও সার্ভার মিলছে না। অ্যাপটি আপডেট করুন অথবা আপনার প্রতিষ্ঠানকে জানান।';

  @override
  String get problem_serverNotSetUp =>
      'সার্ভার এখনও প্রস্তুত নয়। আপনার প্রতিষ্ঠানের অ্যাডমিনকে জানান।';

  @override
  String get problem_clockSkew =>
      'এই ফোনের তারিখ বা সময় ভুল, তাই ফর্ম পাঠানো যাচ্ছে না। ফোনের সেটিংস খুলে তারিখ ও সময় ঠিক করুন (পারলে স্বয়ংক্রিয় তারিখ ও সময় চালু করুন), তারপর অ্যাপে ফিরে আসুন। আপনার ফর্ম এই ফোনে রাখা আছে।';

  @override
  String get problem_duplicateInstance =>
      'সার্ভারে একই কোডের আরেকটি ভিন্ন ফর্ম আগে থেকেই আছে। আপনার উত্তর রাখা আছে। আপনার প্রতিষ্ঠানকে জানান।';

  @override
  String get problem_formNotOnServer =>
      'সার্ভারে ফর্মটির এই সংস্করণ নেই। আপনার প্রতিষ্ঠানকে জানান।';

  @override
  String get problem_submissionInvalid =>
      'সার্ভার এই ফর্মটি নিতে পারেনি। আপনার উত্তর রাখা আছে। আপনার প্রতিষ্ঠানকে জানান।';

  @override
  String get problem_submissionTooLarge =>
      'ফাইলসহ এই ফর্মটি পাঠানোর জন্য খুব বড়। আপনার প্রতিষ্ঠানকে জানান।';

  @override
  String get problem_attachmentMissing =>
      'এই ফর্মের একটি ছবি বা ফাইল ফোনে পাওয়া যাচ্ছে না। আপনার প্রতিষ্ঠানকে জানান।';

  @override
  String get problem_formInvalid =>
      'ফর্মটি খোলা যায়নি। ইন্টারনেট থাকলে ফর্মগুলো আবার নিন, অথবা আপনার প্রতিষ্ঠানকে জানান।';

  @override
  String get problem_databaseKeyMissing =>
      'এই ফোনের সেভ করা তথ্যের চাবি পাওয়া যাচ্ছে না, তাই তথ্য খোলা যাচ্ছে না। অন্য কিছু করার আগে আপনার প্রতিষ্ঠানের সাথে যোগাযোগ করুন।';

  @override
  String get problem_databaseKeyRejected =>
      'এই ফোনের সেভ করা তথ্য খোলা যায়নি। অ্যাপটি মুছবেন না। আপনার প্রতিষ্ঠানের সাথে যোগাযোগ করুন।';

  @override
  String get problem_databaseFromNewerApp =>
      'সেভ করা তথ্য অ্যাপের নতুন সংস্করণে তৈরি। অ্যাপটি আপডেট করুন।';

  @override
  String get problem_databaseUnavailable =>
      'এই ফোনের সেভ করা তথ্য খোলা যায়নি। ফোনটি বন্ধ করে আবার চালু করুন। আবার হলে আপনার প্রতিষ্ঠানের সাথে যোগাযোগ করুন।';

  @override
  String get problem_unexpectedResponse =>
      'সার্ভার এমনভাবে উত্তর দিয়েছে যা অ্যাপ বুঝতে পারছে না। আমরা পরে আবার চেষ্টা করব।';

  @override
  String get problem_unknown =>
      'কিছু একটা ভুল হয়েছে। আপনার কাজ এই ফোনে নিরাপদ আছে। আবার চেষ্টা করুন।';
}
