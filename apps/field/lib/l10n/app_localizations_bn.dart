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
  String get signInWithGoogle => 'Google দিয়ে চালিয়ে যান';

  @override
  String get signInUsePhone => 'মোবাইল নম্বর ব্যবহার করুন';

  @override
  String get signInUseEmail => 'ইমেইল ও পাসওয়ার্ড ব্যবহার করুন';

  @override
  String get signInOtherWays => 'সাইন ইন করার অন্য উপায়';

  @override
  String get signInCheckingMethods =>
      'কীভাবে সাইন ইন করতে পারবেন, তা দেখা হচ্ছে…';

  @override
  String get signInMethodsFailed =>
      'কীভাবে সাইন ইন করতে পারবেন, তার সব উপায় দেখা যায়নি।';

  @override
  String get signInPhone => 'মোবাইল নম্বর';

  @override
  String get signInPhoneHelp => 'এই নম্বরে SMS-এ ৬ অঙ্কের একটি কোড পাঠানো হবে।';

  @override
  String get signInPhoneEmpty => 'আপনার মোবাইল নম্বর লিখুন।';

  @override
  String get signInPhoneInvalid =>
      'নম্বরটি দেখে নিন। মোবাইল নম্বরে ১১টি অঙ্ক থাকে এবং শুরু হয় ০১ দিয়ে, যেমন ০১৭১২-৩৪৫৬৭৮।';

  @override
  String get signInSendCode => 'কোড পাঠান';

  @override
  String get signInSendingCode => 'কোড পাঠানো হচ্ছে…';

  @override
  String get signInCodeTitle => 'SMS-এ পাওয়া কোডটি লিখুন';

  @override
  String signInCodeSent(String phone) {
    return '$phone যদি আপনার অ্যাকাউন্টের মোবাইল নম্বর হয়, তাহলে ৬ অঙ্কের কোডসহ একটি SMS আসছে। আসতে এক মিনিট লাগতে পারে।';
  }

  @override
  String get signInCodeFrom =>
      'এই SMS আপনার প্রতিষ্ঠান পাঠায়। কোডটি কখনো কাউকে বলবেন না।';

  @override
  String get signInCodeNew =>
      'নতুন কোড পাঠানো হয়েছে। সবচেয়ে নতুন SMS-এর কোডটি লিখুন।';

  @override
  String get signInCode => '৬ অঙ্কের কোড';

  @override
  String get signInCodeIncomplete => 'কোডের ৬টি অঙ্কই লিখুন।';

  @override
  String signInNewCodeIn(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    return '$secondsString সেকেন্ড পরে নতুন কোড চাইতে পারবেন।';
  }

  @override
  String get signInNewCode => 'নতুন কোড পাঠান';

  @override
  String get signInChangeNumber => 'নম্বর বদলান';

  @override
  String get signInGoogleWaiting => 'Google-এর জন্য অপেক্ষা করা হচ্ছে…';

  @override
  String get signInGoogleWaitingHelp =>
      'Google-এর পেজ খুলেছে। সেখানে সাইন ইন করুন, তারপর এই অ্যাপে ফিরে আসুন।';

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
  String get passwordChangeBanner =>
      'আপনার প্রতিষ্ঠান আপনাকে একটি এককালীন পাসওয়ার্ড দিয়েছে। ফর্ম পাঠাতে নিজের পাসওয়ার্ড বেছে নিন। আপনার উত্তর এই ফোনেই থাকবে।';

  @override
  String get passwordChangeOpen => 'পাসওয়ার্ড বেছে নিন';

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
  String get lockTitle => 'আপনার তথ্য লক করা আছে';

  @override
  String get lockDeviceBody =>
      'অ্যাপ খুলতে ফোনের স্ক্রিন লক (পিন, প্যাটার্ন, পাসওয়ার্ড বা আঙুলের ছাপ) ব্যবহার করুন।';

  @override
  String get lockUnlock => 'আনলক করুন';

  @override
  String get lockPromptTitle => 'অভিযাত্রা আনলক করুন';

  @override
  String get lockDeviceReason =>
      'এই ফোনের ফর্মগুলো খুলতে নিশ্চিত করুন যে এটি আপনি।';

  @override
  String get lockDeviceCancelled =>
      'ফোন অ্যাপটি আনলক করেনি। আবার চেষ্টা করতে \"আনলক করুন\" চাপুন।';

  @override
  String get lockDeviceLockedOut =>
      'অনেকবার চেষ্টার পর ফোনের লক কিছুক্ষণের জন্য বন্ধ আছে। একটু অপেক্ষা করে আবার \"আনলক করুন\" চাপুন।';

  @override
  String get lockPinBody => 'আপনার ৬ সংখ্যার অ্যাপ পিন লিখুন।';

  @override
  String get pinLabel => 'অ্যাপ পিন';

  @override
  String pinWrong(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'পিন ভুল হয়েছে। অল্প সময় অপেক্ষা করার আগে আর $countString বার চেষ্টা করতে পারবেন।';
  }

  @override
  String pinWaitSeconds(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'অনেকবার ভুল চেষ্টা হয়েছে। $countString সেকেন্ড পরে আবার চেষ্টা করুন।';
  }

  @override
  String pinWaitMinutes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'অনেকবার ভুল চেষ্টা হয়েছে। $countString মিনিট পরে আবার চেষ্টা করুন।';
  }

  @override
  String get pinNeedsSixDigits => '৬টি সংখ্যা লিখুন।';

  @override
  String get pinForgot => 'পিন ভুলে গেছেন?';

  @override
  String get pinChecking => 'যাচাই করা হচ্ছে…';

  @override
  String get pinSetTitle => 'একটি অ্যাপ পিন বেছে নিন';

  @override
  String get pinSetBody =>
      'এই ফোনে কোনো স্ক্রিন লক নেই, তাই অ্যাপের নিজের একটি পিন দরকার। এমন ৬টি সংখ্যা বেছে নিন যা অন্যরা আন্দাজ করতে পারবে না। প্রতিবার অ্যাপ খোলার সময় এটি লিখতে হবে।';

  @override
  String get pinNew => 'নতুন পিন (৬ সংখ্যা)';

  @override
  String get pinConfirm => 'একই পিন আবার লিখুন';

  @override
  String get pinMismatch => 'দুটি পিন এক নয়। পিনটি আবার লিখুন।';

  @override
  String get pinSave => 'পিন সেভ করুন';

  @override
  String get pinSaving => 'সেভ করা হচ্ছে…';

  @override
  String get reSignInExpired =>
      'এই ফোনে শেষবার ইন্টারনেট দিয়ে সাইন ইন করার পর ৩০ দিনের বেশি পার হয়েছে, অথবা ফোনের তারিখ বদলে গেছে। তথ্য খুলতে ইন্টারনেটে যুক্ত হয়ে সাইন ইন করুন।';

  @override
  String get reSignInNoLock =>
      'এই ফোনে কোনো স্ক্রিন লক বা অ্যাপ পিন নেই। ইন্টারনেটে যুক্ত হয়ে সাইন ইন করুন, তারপর একটি অ্যাপ পিন বেছে নিন।';

  @override
  String get reSignInForgotPin =>
      'ইন্টারনেটে যুক্ত হয়ে আপনার অ্যাকাউন্ট দিয়ে সাইন ইন করুন। তারপর নতুন অ্যাপ পিন বেছে নিতে পারবেন।';

  @override
  String get reSignInWrongAccount =>
      'এই ফোনের তথ্য অন্য একটি অ্যাকাউন্টের। যে অ্যাকাউন্ট দিয়ে শেষবার এই ফোন ব্যবহার করা হয়েছে, সেটি দিয়ে সাইন ইন করুন।';

  @override
  String get reSignInBack => 'পিনে ফিরে যান';

  @override
  String get reSignInPasswordForPin =>
      'পিন নতুন করে ঠিক করতে আপনার ইমেইল ও পাসওয়ার্ড দিয়ে সাইন ইন করুন। আপনার অ্যাকাউন্টে পাসওয়ার্ড না থাকলে আপনার প্রতিষ্ঠানের অ্যাডমিনকে বলুন।';

  @override
  String get reSignInPasswordForLock =>
      'অ্যাপ পিন বেছে নিতে আপনার ইমেইল ও পাসওয়ার্ড দিয়ে সাইন ইন করুন। আপনার অ্যাকাউন্টে পাসওয়ার্ড না থাকলে আপনার প্রতিষ্ঠানের অ্যাডমিনকে বলুন।';

  @override
  String get passwordChangeTitle => 'নিজের পাসওয়ার্ড বেছে নিন';

  @override
  String get passwordChangeBody =>
      'আপনার প্রতিষ্ঠান আপনাকে একটি এককালীন পাসওয়ার্ড দিয়েছে। এখন নিজের একটি পাসওয়ার্ড বেছে নিন। এখন থেকে আপনি এটি দিয়েই সাইন ইন করবেন।';

  @override
  String get passwordChangeCurrent => 'এককালীন পাসওয়ার্ড';

  @override
  String get passwordChangeCurrentHelp =>
      'আপনার প্রতিষ্ঠান যে পাসওয়ার্ড দিয়েছে।';

  @override
  String get passwordChangeNew => 'নতুন পাসওয়ার্ড';

  @override
  String get passwordChangeHint =>
      'মনে রাখতে পারবেন এমন ৩ বা ৪টি শব্দ ব্যবহার করুন, কমপক্ষে ১২টি অক্ষর।';

  @override
  String get passwordChangeRepeat => 'নতুন পাসওয়ার্ডটি আবার লিখুন';

  @override
  String get passwordChangeCurrentEmpty =>
      'প্রতিষ্ঠানের দেওয়া এককালীন পাসওয়ার্ডটি লিখুন।';

  @override
  String get passwordChangeTooShort => 'কমপক্ষে ১২টি অক্ষর ব্যবহার করুন।';

  @override
  String get passwordChangeTooLong => '৭১টির বেশি অক্ষর ব্যবহার করবেন না।';

  @override
  String get passwordChangeSameAsOld =>
      'এককালীন পাসওয়ার্ডটি নয়, একটি নতুন পাসওয়ার্ড বেছে নিন।';

  @override
  String get passwordChangeMismatch =>
      'দুটি পাসওয়ার্ড এক নয়। নতুন পাসওয়ার্ডটি আবার লিখুন।';

  @override
  String get passwordChangeSave => 'পাসওয়ার্ড সেভ করুন';

  @override
  String get passwordChangeSaving => 'সেভ করা হচ্ছে…';

  @override
  String get passwordChangeSignOut => 'সাইন আউট করুন';

  @override
  String get passwordChangeSignInAgain => 'আবার সাইন ইন করুন';

  @override
  String get aboutSecurityHeading => 'তথ্য নিরাপদ রাখা';

  @override
  String get aboutSecurityBody =>
      'অ্যাপটি ৫ মিনিট ব্যাকগ্রাউন্ডে থাকলে নিজে থেকেই লক হয়ে যায়। ফোনের স্ক্রিন লক দিয়ে, অথবা ফোনে স্ক্রিন লক না থাকলে অ্যাপ পিন দিয়ে এটি খুলুন। ৩০ দিন ইন্টারনেট দিয়ে সাইন ইন না করলে আবার সাইন ইন না করা পর্যন্ত অ্যাপটি লক থাকবে। প্রতি জনের জন্য একটি করে ফোন ব্যবহার করুন: যতদিন অ্যাপটি প্রত্যেকের তথ্য আলাদা রাখতে পারছে না, ততদিন যে কেউ এই ফোনে অ্যাপটি খুলতে পারলে এতে থাকা ফর্মগুলো দেখতে পারবে।';

  @override
  String get actionSignInAgain => 'আবার সাইন ইন করুন';

  @override
  String get deviceSettingUpTitle => 'ফোনটি সেট আপ করা হচ্ছে';

  @override
  String get deviceSettingUpBody =>
      'ফর্ম পাওয়ার আগে আপনার প্রতিষ্ঠানের সার্ভারের সঙ্গে এই ফোনটি সেট আপ করতে হবে। এর জন্য ইন্টারনেট সংযোগ লাগবে।';

  @override
  String get deviceSettingUpWorking => 'সেট আপ করা হচ্ছে…';

  @override
  String get deviceWaitingTitle => 'অনুমোদনের অপেক্ষায়';

  @override
  String get deviceWaitingBody =>
      'এই ফোনে ফর্ম পাওয়া বা পাঠানোর আগে আপনার ব্রাঞ্চ ম্যানেজার বা প্রতিষ্ঠানের একজন অ্যাডমিনকে ফোনটি অনুমোদন করতে হবে।';

  @override
  String get deviceServerForgot =>
      'সার্ভার এই ফোনটিকে আর চিনতে পারেনি, তাই এটির আবার অনুমোদন লাগবে।';

  @override
  String get deviceRenewalTitle => 'অনুমোদনের মেয়াদ শেষ';

  @override
  String get deviceRenewalBody =>
      'প্রতিটি অনুমোদন এক বছর থাকে, আর এই ফোনের অনুমোদনের মেয়াদ শেষ হয়ে গেছে। আপনার ব্রাঞ্চ ম্যানেজার বা প্রতিষ্ঠানের একজন অ্যাডমিনকে আবার অনুমোদন করতে হবে। তাঁরা আগের নম্বরগুলোই মিলিয়ে দেখবেন।';

  @override
  String get deviceSwitchedOffTitle => 'এই ফোনটি বন্ধ করা হয়েছে';

  @override
  String get deviceSwitchedOffBody =>
      'আপনার প্রতিষ্ঠান অভিযাত্রার জন্য এই ফোনটি বন্ধ করে দিয়েছে, তাই এতে ফর্ম পাওয়া বা পাঠানো যাবে না। যেমন, কোনো ফোন হারিয়ে গেছে বলে জানালে এমন হয়।';

  @override
  String get deviceSwitchedOffKept =>
      'আপনার না-পাঠানো ফর্ম ও খসড়া এই ফোনেই থাকবে।';

  @override
  String get deviceSwitchedOffNext =>
      'এই ফোনটি আপনি ব্যবহার করবেন কি না, তা আপনার প্রতিষ্ঠানের অ্যাডমিনের কাছে জেনে নিন। করলে ফোনটি আবার সেট আপ করুন, তারপর আপনার ব্রাঞ্চ ম্যানেজার বা প্রতিষ্ঠানের একজন অ্যাডমিনকে অনুমোদন করতে বলুন।';

  @override
  String get deviceCodeHeading => 'এই ফোনের নম্বরগুলো';

  @override
  String deviceCodeSpoken(String numbers) {
    return 'এই ফোনের নম্বরগুলো: $numbers';
  }

  @override
  String get deviceShowInPerson =>
      'নম্বরগুলো তাঁদের সামনাসামনি দেখান, অথবা ফোন কলে পড়ে শোনান।';

  @override
  String get deviceNeverSend =>
      'নম্বরগুলো কখনো মেসেজে (এসএমএস, হোয়াটসঅ্যাপ বা ইমেইলে) পাঠাবেন না। অনুমোদনকারীকে নম্বরগুলো আপনার কাছ থেকেই দেখতে বা শুনতে হবে।';

  @override
  String get deviceAutoCheck =>
      'এই স্ক্রিনটি খোলা থাকলে প্রতি ১৫ সেকেন্ডে নিজে থেকেই আবার দেখে নেয়।';

  @override
  String deviceLastChecked(String when) {
    return 'শেষবার দেখা হয়েছে $when';
  }

  @override
  String get deviceCheckAgain => 'আবার দেখুন';

  @override
  String get deviceChecking => 'দেখা হচ্ছে…';

  @override
  String get deviceFillInForms => 'আপাতত এই ফোনে ফর্ম পূরণ করুন';

  @override
  String get deviceCheckOffline =>
      'ইন্টারনেট সংযোগ নেই, তাই এই ফোনটি আপনার প্রতিষ্ঠানের সার্ভারে পৌঁছাতে পারেনি। ইন্টারনেটে যুক্ত হয়ে আবার চেষ্টা করুন।';

  @override
  String get deviceSetUpAgain => 'ফোনটি আবার সেট আপ করুন';

  @override
  String get deviceSetUpAgainTitle => 'ফোনটি আবার সেট আপ করবেন?';

  @override
  String get deviceSetUpAgainBody =>
      'এই ফোনটি নতুন নম্বর পাবে, আর আপনি সাইন আউট হয়ে যাবেন। আপনার না-পাঠানো ফর্ম ও খসড়া এই ফোনেই থাকবে। তারপর আবার সাইন ইন করুন, এবং নতুন নম্বরগুলো অনুমোদন করতে আপনার ব্রাঞ্চ ম্যানেজার বা প্রতিষ্ঠানের একজন অ্যাডমিনকে বলুন।';

  @override
  String get deviceSetUpAgainConfirm => 'আবার সেট আপ করুন';

  @override
  String get deviceNoticeSettingUp =>
      'এই ফোনটি এখনো আপনার প্রতিষ্ঠানের সার্ভারের সঙ্গে সেট আপ করা হয়নি। সেট আপ ও অনুমোদন হলে শেষ করা ফর্মগুলো পাঠানো হবে।';

  @override
  String get deviceNoticeWaiting =>
      'এই ফোনটি অনুমোদনের অপেক্ষায় আছে। অনুমোদনের পরে শেষ করা ফর্মগুলো পাঠানো হবে।';

  @override
  String get deviceNoticeRenewal =>
      'এই ফোনের অনুমোদনের মেয়াদ শেষ হয়ে গেছে। আবার অনুমোদনের পরে শেষ করা ফর্মগুলো পাঠানো হবে।';

  @override
  String get deviceNoticeSwitchedOff =>
      'অভিযাত্রার জন্য এই ফোনটি বন্ধ করা হয়েছে। শেষ করা ফর্মগুলো এই ফোনেই থাকবে।';

  @override
  String get deviceShowCode => 'এই ফোনের নম্বরগুলো দেখুন';

  @override
  String get deviceSeeWhatToDo => 'কী করবেন দেখুন';

  @override
  String get settingsThisPhone => 'এই ফোন';

  @override
  String deviceStatusApproved(String date) {
    return '$date পর্যন্ত অনুমোদিত';
  }

  @override
  String get deviceStatusWaiting => 'অনুমোদনের অপেক্ষায়';

  @override
  String get deviceStatusRenewal => 'অনুমোদনের মেয়াদ শেষ';

  @override
  String get deviceStatusSwitchedOff => 'বন্ধ করা হয়েছে';

  @override
  String get deviceStatusSettingUp => 'এখনো সেট আপ করা হয়নি';

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
  String get problem_redirected =>
      'সার্ভারের ঠিকানা অ্যাপটিকে অন্য একটি ঠিকানায় পাঠিয়ে দিয়েছে, তাই কিছু পাঠানো হয়নি। পাবলিক ওয়াই-ফাই ব্যবহার করলে আগে তার সাইন-ইন পেজ খুলুন। না হলে আপনার প্রতিষ্ঠানের কাছ থেকে সার্ভারের ঠিকানা মিলিয়ে নিন। আমরা পরে আবার চেষ্টা করব।';

  @override
  String get problem_phoneNumberInvalid =>
      'মোবাইল নম্বরটি সঠিক আকারে নেই। দেখে আবার চেষ্টা করুন।';

  @override
  String get problem_tooManySignInCodes =>
      'অনেকবার কোড চাওয়া হয়েছে। ১৫ মিনিট অপেক্ষা করুন, অথবা অন্য উপায়ে সাইন ইন করুন।';

  @override
  String get problem_signInCodeWrong =>
      'কোডটি ভুল, অথবা এর মেয়াদ শেষ হয়ে গেছে। SMS দেখে নিন, অথবা নতুন কোড চান। ১০ বার ভুল হলে ১৫ মিনিটের জন্য সাইন ইন বন্ধ থাকবে।';

  @override
  String get problem_tooManyCodeTries =>
      'অনেকবার চেষ্টা করা হয়েছে। ১৫ মিনিট অপেক্ষা করুন, তারপর নতুন কোড চান।';

  @override
  String get problem_signInMethodOff =>
      'আপনার প্রতিষ্ঠানের সার্ভারে সাইন ইনের এই উপায়টি বন্ধ আছে। অন্য উপায়ে সাইন ইন করুন।';

  @override
  String get problem_googleSignInRefused =>
      'আপনার প্রতিষ্ঠানের অ্যাডমিনকে আপনার অ্যাকাউন্টে আপনার Google ইমেইল ঠিকানা যোগ করতে বলুন, অথবা অন্য উপায়ে সাইন ইন করুন।';

  @override
  String get problem_signInCancelled =>
      'সাইন ইন থামানো হয়েছে। আপনি আবার চেষ্টা করতে পারেন।';

  @override
  String get problem_browserUnavailable =>
      'সাইন ইনের জন্য এই ফোনে ওয়েব পেজ খোলা যায়নি। অন্য উপায়ে সাইন ইন করুন।';

  @override
  String get problem_passwordChangeRequired =>
      'এগিয়ে যাওয়ার আগে নিজের পাসওয়ার্ড বেছে নিন। আপনার প্রতিষ্ঠান আপনাকে একটি এককালীন পাসওয়ার্ড দিয়েছে। আপনার কাজ এই ফোনে নিরাপদ আছে।';

  @override
  String get problem_currentPasswordWrong =>
      'পাসওয়ার্ডটি ঠিক নয়। আপনার প্রতিষ্ঠান যেভাবে দিয়েছে, ঠিক সেভাবে এককালীন পাসওয়ার্ডটি লিখুন।';

  @override
  String get problem_newPasswordInvalid =>
      'এই নতুন পাসওয়ার্ডটি ব্যবহার করা যাবে না। কমপক্ষে ১২টি অক্ষর ব্যবহার করুন, যেমন ৩ বা ৪টি শব্দ।';

  @override
  String get problem_passwordChangedSignInAgain =>
      'আপনার নতুন পাসওয়ার্ড সেভ হয়েছে। নতুন পাসওয়ার্ড দিয়ে আবার সাইন ইন করুন।';

  @override
  String get problem_deviceNotEnrolled =>
      'এই ফোনটি এখনো আপনার প্রতিষ্ঠানের সার্ভারের সঙ্গে সেট আপ করা হয়নি। ইন্টারনেটে যুক্ত হয়ে অ্যাপটি খুলুন, এটি নিজে থেকেই সেট আপ হবে। আপনার কাজ এই ফোনে নিরাপদ আছে।';

  @override
  String get problem_deviceSignatureInvalid =>
      'সার্ভার এই ফোনের অনুরোধটি যাচাই করতে পারেনি। আমরা নিজে থেকেই আবার চেষ্টা করব। বারবার এমন হলে সাইন আউট করে আবার সাইন ইন করুন।';

  @override
  String get problem_deviceUnknown =>
      'আপনার প্রতিষ্ঠানের সার্ভার এই ফোনটিকে আর চিনতে পারেনি, তাই একই নম্বর দিয়ে ফোনটি আবার সেট আপ করা হচ্ছে, আর এটির আবার অনুমোদন লাগবে। আপনার ফর্মগুলো এই ফোনেই থাকবে।';

  @override
  String get problem_deviceClockWrong =>
      'এই ফোনের তারিখ বা সময় ভুল, তাই সার্ভার তা গ্রহণ করতে পারছে না। ফোনের সেটিংসে গিয়ে স্বয়ংক্রিয় তারিখ ও সময় চালু করুন, তারপর অ্যাপে ফিরে আবার চেষ্টা করুন। আপনার ফর্ম এই ফোনে রাখা আছে।';

  @override
  String get problem_deviceNotApproved =>
      'এই ফোনটি আপনার ব্রাঞ্চ ম্যানেজার বা প্রতিষ্ঠানের একজন অ্যাডমিনের অনুমোদনের অপেক্ষায় আছে। আপনার ফর্মগুলো রাখা আছে, অনুমোদনের পরে পাঠানো হবে।';

  @override
  String get problem_deviceApprovalExpired =>
      'এই ফোনের অনুমোদনের মেয়াদ শেষ হয়ে গেছে। আবার অনুমোদন করতে আপনার ব্রাঞ্চ ম্যানেজার বা প্রতিষ্ঠানের একজন অ্যাডমিনকে বলুন। আপনার ফর্মগুলো রাখা আছে।';

  @override
  String get problem_deviceRevoked =>
      'আপনার প্রতিষ্ঠান অভিযাত্রার জন্য এই ফোনটি বন্ধ করে দিয়েছে। আপনার ফর্মগুলো এই ফোনেই থাকবে। কী করতে হবে, তা আপনার প্রতিষ্ঠানের অ্যাডমিনের কাছে জেনে নিন।';

  @override
  String get problem_sessionEnded =>
      'আপনার সাইন-ইনের মেয়াদ শেষ হয়েছে। ফর্ম পাঠাতে আবার সাইন ইন করুন। আপনার উত্তরগুলো এই ফোনেই থাকবে।';

  @override
  String get problem_sessionOnOtherDevice =>
      'এই সাইন-ইনটি অন্য একটি ফোনের। এই ফোনে আবার সাইন ইন করুন। আপনার উত্তরগুলো এই ফোনেই থাকবে।';

  @override
  String get problem_deviceKeyInUse =>
      'এই ফোনের নম্বরগুলো আগে থেকেই ব্যবহার হচ্ছে, তাই ফোনটি সেট আপ করা যায়নি। আবার চেষ্টা করুন। আবারও এমন হলে আপনার প্রতিষ্ঠানের অ্যাডমিনকে জানান।';

  @override
  String get problem_tooManyDevicesWaiting =>
      'আপনার তিনটি ফোন আগে থেকেই অনুমোদনের অপেক্ষায় আছে। সেগুলো অনুমোদন বা বন্ধ করতে আপনার ব্রাঞ্চ ম্যানেজার বা প্রতিষ্ঠানের একজন অ্যাডমিনকে বলুন, তারপর আবার চেষ্টা করুন।';

  @override
  String get problem_unknown =>
      'কিছু একটা ভুল হয়েছে। আপনার কাজ এই ফোনে নিরাপদ আছে। আবার চেষ্টা করুন।';
}
