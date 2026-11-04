// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'অভিযাত্রা ম্যানেজার';

  @override
  String get navMain => 'প্রধান মেনু';

  @override
  String get navForms => 'ফর্ম';

  @override
  String get navSubmissions => 'জমা';

  @override
  String get navSettings => 'সেটিংস';

  @override
  String get navAbout => 'পরিচিতি';

  @override
  String get badgeWebApp => 'ওয়েব অ্যাপ';

  @override
  String get badgeDesktopApp => 'ডেস্কটপ অ্যাপ';

  @override
  String get languageSwitch => 'ভাষা';

  @override
  String get accountMenu => 'অ্যাকাউন্ট মেনু';

  @override
  String get menuSignOut => 'সাইন আউট';

  @override
  String get loading => 'লোড হচ্ছে';

  @override
  String get offlineTitle => 'আপনি অফলাইনে আছেন';

  @override
  String get offlineBody =>
      'ইন্টারনেট সংযোগ দেখুন। সংযোগ ফিরলে আপনার তথ্য আবার দেখা যাবে।';

  @override
  String get actionTryAgain => 'আবার চেষ্টা করুন';

  @override
  String get actionSignInAgain => 'আবার সাইন ইন করুন';

  @override
  String get actionClose => 'বন্ধ করুন';

  @override
  String get actionChooseFile => 'অন্য ফাইল বাছুন';

  @override
  String get actionCancel => 'বাতিল';

  @override
  String get unknownValue => 'অজানা';

  @override
  String get problemOffline =>
      'সার্ভারের সাথে যোগাযোগ করা যাচ্ছে না। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।';

  @override
  String get problemTimeout =>
      'সার্ভার উত্তর দিতে অনেক সময় নিচ্ছে। কিছুক্ষণ পরে আবার চেষ্টা করুন।';

  @override
  String get problemServerBusy =>
      'সার্ভার এখন ব্যস্ত। এক মিনিট অপেক্ষা করে আবার চেষ্টা করুন।';

  @override
  String get problemServerError =>
      'সার্ভারে একটি সমস্যা হয়েছে। আবার চেষ্টা করুন। বারবার হলে আপনার সংস্থার অ্যাডমিনকে জানান।';

  @override
  String get problemSignInRequired =>
      'আপনার সেশন শেষ হয়ে গেছে। চালিয়ে যেতে আবার সাইন ইন করুন।';

  @override
  String get problemSignInFailed =>
      'ইমেইল বা পাসওয়ার্ড ঠিক নয়, অথবা এই অ্যাকাউন্টটি বন্ধ আছে। যাচাই করে আবার চেষ্টা করুন।';

  @override
  String get problemNotAllowed =>
      'আপনার অ্যাকাউন্টের এটি করার অনুমতি নেই। অনুমতি দরকার হলে আপনার সংস্থার অ্যাডমিনকে বলুন।';

  @override
  String get problemNotFound =>
      'এটি খুঁজে পাওয়া যায়নি। এটি সরানো হয়ে থাকতে পারে, অথবা আপনার অ্যাকাউন্টের এতে প্রবেশাধিকার নেই।';

  @override
  String get problemTooLarge =>
      'ফাইলটি অনেক বড়। ফর্ম ও জমা সর্বোচ্চ ১০ এমবি পর্যন্ত হতে পারে।';

  @override
  String get problemRejected =>
      'সার্ভার এটি গ্রহণ করেনি। যা দিয়েছেন তা দেখে আবার চেষ্টা করুন।';

  @override
  String get problemVersionExists =>
      'ফর্মের এই সংস্করণটি আগেই আপলোড করা হয়েছে। আপনার ফর্ম টুলে সংস্করণ নম্বর বদলে ফাইলটি আবার আপলোড করুন।';

  @override
  String get problemCommentNotSaved =>
      'আপনার সিদ্ধান্ত সংরক্ষিত হয়েছে, কিন্তু এই সার্ভার এখনও মন্তব্য রাখতে পারে না। সার্ভার হালনাগাদ করতে আপনার সংস্থার অ্যাডমিনকে বলুন।';

  @override
  String get problemUnreadableFile =>
      'ফাইলটি পড়া যায়নি। এটি এক্সফর্ম (.xml) ফাইল কি না দেখে আবার চেষ্টা করুন।';

  @override
  String get problemFormUnavailable =>
      'এই ফর্মের গঠন লোড করা যায়নি, তাই সুরক্ষিত উত্তর নিরাপদ রাখতে সব উত্তর লুকানো আছে।';

  @override
  String get problemUnknown =>
      'কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন। বারবার হলে আপনার সংস্থার অ্যাডমিনকে জানান।';

  @override
  String get signInTitle => 'সাইন ইন';

  @override
  String get signInIntro =>
      'আপনার সংস্থার অ্যাডমিনের দেওয়া ইমেইল ও পাসওয়ার্ড ব্যবহার করুন।';

  @override
  String get signInEmail => 'ইমেইল';

  @override
  String get signInPassword => 'পাসওয়ার্ড';

  @override
  String get signInShowPassword => 'পাসওয়ার্ড দেখান';

  @override
  String get signInHidePassword => 'পাসওয়ার্ড লুকান';

  @override
  String get signInServer => 'সার্ভারের ঠিকানা';

  @override
  String get signInServerHelp =>
      'আপনার সংস্থার অভিযাত্রা সার্ভারের ওয়েব ঠিকানা, যেমন https://data.example.org';

  @override
  String get signInButton => 'সাইন ইন';

  @override
  String get signInWorking => 'সাইন ইন হচ্ছে…';

  @override
  String get fieldRequired => 'এটি পূরণ করুন।';

  @override
  String get serverInvalid =>
      'http:// বা https:// দিয়ে শুরু হওয়া পূর্ণ ওয়েব ঠিকানা লিখুন।';

  @override
  String get formsTitle => 'ফর্ম';

  @override
  String get formsUploadTitle => 'ফর্ম আপলোড করুন';

  @override
  String get formsUploadHelp =>
      'একটি এক্সফর্ম (.xml) ফাইল বাছুন। কোবো বা ওডিকে-তে তৈরি ফাইলও চলবে।';

  @override
  String get formsChooseFile => 'ফাইল বাছুন';

  @override
  String get formsYourForms => 'আপনার ফর্ম';

  @override
  String formsVersionCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি সংস্করণ',
      one: '১টি সংস্করণ',
    );
    return '$_temp0';
  }

  @override
  String formsPublishedSummary(String version) {
    return 'সংস্করণ $version, প্রকাশিত';
  }

  @override
  String get formsDraftSummary => 'খসড়া, এখনও প্রকাশিত হয়নি';

  @override
  String get formsNoVersions => 'এখনও কোনো সংস্করণ নেই';

  @override
  String get formsEmptyTitle => 'এখনও কোনো ফর্ম নেই';

  @override
  String get formsEmptyBodyAdmin => 'শুরু করতে আপনার প্রথম ফর্মটি আপলোড করুন।';

  @override
  String get formsEmptyBodyViewer =>
      'আপনার সংস্থার অ্যাডমিন এখনও কোনো ফর্ম প্রকাশ করেননি।';

  @override
  String get formsSelectPrompt => 'সংস্করণ দেখতে বাঁ দিক থেকে একটি ফর্ম বাছুন।';

  @override
  String get formsSelectVersion => 'পরীক্ষার ফল দেখতে একটি সংস্করণ বাছুন।';

  @override
  String versionLabel(String version) {
    return 'সংস্করণ $version';
  }

  @override
  String versionUploaded(String date) {
    return 'আপলোড: $date';
  }

  @override
  String versionPublished(String date) {
    return 'প্রকাশিত: $date';
  }

  @override
  String get badgePublished => 'প্রকাশিত';

  @override
  String get badgeDraft => 'খসড়া';

  @override
  String get badgeNeedsFix => 'ঠিক করা দরকার';

  @override
  String versionHeading(String form, String version) {
    return '$form, সংস্করণ $version';
  }

  @override
  String get publishCheckTitle => 'প্রকাশের আগের পরীক্ষা';

  @override
  String get formCheckTitle => 'ফর্মের পরীক্ষা';

  @override
  String publishCheckedQuestions(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি প্রশ্ন পরীক্ষা করা হয়েছে।',
      one: '১টি প্রশ্ন পরীক্ষা করা হয়েছে।',
      zero: 'কোনো প্রশ্ন পাওয়া যায়নি।',
    );
    return '$_temp0';
  }

  @override
  String publishFixCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'প্রকাশের আগে $countStringটি বিষয় ঠিক করুন।',
      one: 'প্রকাশের আগে ১টি বিষয় ঠিক করুন।',
    );
    return '$_temp0';
  }

  @override
  String get publishAllClear =>
      'ঠিক করার কিছু নেই। আপনি এই সংস্করণ প্রকাশ করতে পারেন।';

  @override
  String get checkKindFix => 'প্রকাশের আগে ঠিক করুন';

  @override
  String get checkKindProtected => 'সুরক্ষিত';

  @override
  String get checkKindPassed => 'ঠিক আছে';

  @override
  String get checkKindNote => 'জেনে রাখুন';

  @override
  String get checkUnreadable =>
      'এই ফাইলটি ফর্ম হিসেবে পড়া যাচ্ছে না। এটি নষ্ট হতে পারে। আপনার ফর্ম টুল থেকে আবার এক্সপোর্ট করে নতুন ফাইল আপলোড করুন।';

  @override
  String get checkNotXForm =>
      'ফাইলটি এক্সএমএল, কিন্তু এক্সফর্ম নয়। আপনার ফর্ম টুল থেকে এক্সপোর্ট করা এক্সফর্ম (.xml) ফাইল আপলোড করুন।';

  @override
  String get checkWellFormed => 'ফাইলটি পড়ার মতো একটি ফর্ম।';

  @override
  String get checkVersionMissing =>
      'ফর্মে কোনো সংস্করণ নম্বর নেই। আপনার ফর্ম টুলে সংস্করণ যোগ করে আবার এক্সপোর্ট করুন এবং নতুন ফাইল আপলোড করুন।';

  @override
  String checkVersionOk(String version) {
    return 'ফর্মে সংস্করণ নম্বর আছে: $version।';
  }

  @override
  String get checkFormIdMissing =>
      'ফর্মে কোনো ফর্ম আইডি নেই। আপনার ফর্ম টুলে ফর্ম আইডি দিয়ে আবার এক্সপোর্ট করুন এবং নতুন ফাইল আপলোড করুন।';

  @override
  String checkFormIdOk(String formId) {
    return 'ফর্মে ফর্ম আইডি আছে: $formId।';
  }

  @override
  String checkVersionExists(String version) {
    return 'এই ফর্মের সংস্করণ $version আগেই আপলোড করা হয়েছে। আপনার ফর্ম টুলে সংস্করণ নম্বর বদলে ফাইলটি আবার আপলোড করুন।';
  }

  @override
  String get checkKoboMatrix =>
      'কোবো ‘প্রশ্ন ম্যাট্রিক্স’ চলে না — তার বদলে প্রতিটি সারির জন্য একটি করে ‘একটি বাছুন’ প্রশ্ন ব্যবহার করুন।';

  @override
  String get checkKoboScore =>
      'কোবো ‘রেটিং’ প্রশ্ন চলে না — তার বদলে প্রতিটি বিষয়ের জন্য একটি করে ‘একটি বাছুন’ প্রশ্ন ব্যবহার করুন।';

  @override
  String get checkKoboRank =>
      'কোবো ‘ক্রম’ প্রশ্ন চলে না — তার বদলে ‘প্রথম পছন্দ’ ও ‘দ্বিতীয় পছন্দ’-এর মতো ‘একটি বাছুন’ প্রশ্ন ব্যবহার করুন।';

  @override
  String checkWhere(int count, String names) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'প্রশ্নগুলি: $names',
      one: 'প্রশ্ন: $names',
    );
    return '$_temp0';
  }

  @override
  String checkProtectedList(int count, String names) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি উত্তর সুরক্ষিত থাকবে: $names।',
      one: '১টি উত্তর সুরক্ষিত থাকবে: $names।',
    );
    return '$_temp0';
  }

  @override
  String get checkLanguagesOk => 'প্রতিটি প্রশ্নের দুই ভাষাতেই লেখা আছে।';

  @override
  String checkLanguagesPartial(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি প্রশ্নের এক ভাষার লেখা নেই।',
      one: '১টি প্রশ্নের এক ভাষার লেখা নেই।',
    );
    return '$_temp0';
  }

  @override
  String get checkSingleLanguage => 'ফর্মটি শুধু এক ভাষায় লেখা।';

  @override
  String get uploadXlsNotice =>
      'স্প্রেডশিট (.xlsx) ফর্ম এখনও আপলোড করা যায় না। এগুলো রূপান্তরের সুবিধা দ্বিতীয় পর্যায়ে (Phase 2) আসছে। আপাতত এক্সফর্ম (.xml) ফাইল আপলোড করুন। কোবো ও ওডিকে থেকে এটি এক্সপোর্ট করা যায়।';

  @override
  String get uploadChoosePrompt =>
      'আপনার কম্পিউটার থেকে এক্সফর্ম (.xml) ফাইল বাছুন। স্প্রেডশিট (.xlsx) ফর্ম এখনও চলে না: রূপান্তরের সুবিধা দ্বিতীয় পর্যায়ে (Phase 2) আসছে।';

  @override
  String uploadFile(String name) {
    return 'ফাইল: $name';
  }

  @override
  String get uploadReady =>
      'ফাইলটি সব পরীক্ষায় উত্তীর্ণ। এটি প্রথমে খসড়া হিসেবে সংরক্ষিত হবে, পরে আপনি প্রকাশ করতে পারবেন।';

  @override
  String get uploadBlocked =>
      'ফাইলটি এখনও আপলোড করা যাবে না। নিচের বিষয়গুলো ঠিক করে ঠিক করা ফাইলটি বাছুন।';

  @override
  String get uploadButton => 'খসড়া হিসেবে আপলোড';

  @override
  String get uploadUploading => 'আপলোড হচ্ছে…';

  @override
  String get uploadDone =>
      'খসড়া হিসেবে আপলোড হয়েছে। দেখে নিন, তারপর প্রস্তুত হলে প্রকাশ করুন।';

  @override
  String get publishButton => 'প্রকাশ করুন';

  @override
  String get publishHint =>
      'ঠিক করার কিছু বাকি না থাকলে আপনি প্রকাশ করতে পারবেন।';

  @override
  String publishConfirmTitle(String version) {
    return 'সংস্করণ $version প্রকাশ করবেন?';
  }

  @override
  String get publishConfirmBody =>
      'একবার প্রকাশ করলে সংস্করণটি আর বদলানো যায় না। পরে ফর্ম বদলাতে হলে আপনাকে নতুন সংস্করণ আপলোড করতে হবে।';

  @override
  String get publishConfirmNo => 'এখনই নয়';

  @override
  String publishDone(String version) {
    return 'সংস্করণ $version প্রকাশিত হয়েছে।';
  }

  @override
  String get publishedReadOnly =>
      'এই সংস্করণটি প্রকাশিত, তাই বদলানো যায় না। ফর্ম বদলাতে নতুন সংস্করণ আপলোড করুন।';

  @override
  String get adminOnlyForms =>
      'শুধু সংস্থার অ্যাডমিন ফর্ম আপলোড বা প্রকাশ করতে পারেন।';

  @override
  String get subsTitle => 'জমা';

  @override
  String subsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি জমা',
      one: '১টি জমা',
      zero: 'কোনো জমা মেলেনি',
    );
    return '$_temp0';
  }

  @override
  String get filterForm => 'ফর্ম';

  @override
  String get filterAllForms => 'সব ফর্ম';

  @override
  String get filterDates => 'তারিখ';

  @override
  String get filterLast7 => 'গত ৭ দিন';

  @override
  String get filterLast30 => 'গত ৩০ দিন';

  @override
  String get filterAllTime => 'সব সময়';

  @override
  String get filterChoose => 'তারিখ বাছুন…';

  @override
  String filterRange(String from, String to) {
    return '$from থেকে $to';
  }

  @override
  String get filterReviewState => 'পর্যালোচনার অবস্থা';

  @override
  String get reviewAll => 'সব';

  @override
  String get stateReceived => 'গৃহীত';

  @override
  String get stateEdited => 'সম্পাদিত';

  @override
  String get stateHasIssues => 'সমস্যা আছে';

  @override
  String get stateApproved => 'অনুমোদিত';

  @override
  String get stateRejected => 'বাতিল';

  @override
  String get colDate => 'তারিখ';

  @override
  String get colForm => 'ফর্ম';

  @override
  String get colCollector => 'সংগ্রহকারী';

  @override
  String get colLocation => 'এলাকা';

  @override
  String get colReview => 'পর্যালোচনা';

  @override
  String dateToday(String time) {
    return 'আজ, $time';
  }

  @override
  String dateYesterday(String time) {
    return 'গতকাল, $time';
  }

  @override
  String dateOther(String date, String time) {
    return '$date, $time';
  }

  @override
  String get subsEmptyTitle => 'এখানে কোনো জমা নেই';

  @override
  String get subsEmptyBody =>
      'এই ফিল্টারে কিছু মেলেনি। আরও বড় তারিখের পরিসর বা অন্য পর্যালোচনার অবস্থা দিয়ে দেখুন।';

  @override
  String pagingRange(int from, int to, int total) {
    final intl.NumberFormat fromNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String fromString = fromNumberFormat.format(from);
    final intl.NumberFormat toNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String toString = toNumberFormat.format(to);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString-এর মধ্যে $fromString–$toString দেখানো হচ্ছে';
  }

  @override
  String pagingPage(int page, int pages) {
    final intl.NumberFormat pageNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String pageString = pageNumberFormat.format(page);
    final intl.NumberFormat pagesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pagesString = pagesNumberFormat.format(pages);

    return 'পৃষ্ঠা $pageString / $pagesString';
  }

  @override
  String get pagingPrevious => 'আগের পৃষ্ঠা';

  @override
  String get pagingNext => 'পরের পৃষ্ঠা';

  @override
  String get refresh => 'নতুন করে আনুন';

  @override
  String get detailClose => 'বিবরণ বন্ধ করুন';

  @override
  String detailMeta(String collector, String location, String date) {
    return '$collector · $location · $date';
  }

  @override
  String get detailProtectedNote =>
      'এই অ্যাপ সুরক্ষিত উত্তর দেখাতে পারে না, তাই ভাগাভাগি করা কম্পিউটারেও সেগুলো নিরাপদ থাকে।';

  @override
  String get protectedAnswer =>
      'সুরক্ষিত — দেখতে অভিযাত্রা ডেস্কটপ অ্যাপ খুলুন';

  @override
  String get detailAnswers => 'উত্তর';

  @override
  String get detailNoAnswers => 'এই জমায় দেখানোর মতো কোনো উত্তর নেই।';

  @override
  String get detailComment => 'পর্যালোচনার নোট';

  @override
  String get actionApprove => 'অনুমোদন';

  @override
  String get actionHasIssues => 'সমস্যা আছে';

  @override
  String get actionReject => 'বাতিল করুন';

  @override
  String get reviewReadOnly =>
      'আপনার ভূমিকায় জমা দেখা যায়, কিন্তু পর্যালোচনা করা যায় না।';

  @override
  String get reviewIssuesTitle => 'সমস্যা আছে বলে চিহ্নিত করুন';

  @override
  String get reviewIssuesLabel => 'কী দেখা দরকার?';

  @override
  String get reviewRejectTitle => 'এই জমাটি বাতিল করুন';

  @override
  String get reviewRejectLabel => 'কেন বাতিল করছেন?';

  @override
  String get reviewConfirmIssues => 'সমস্যা আছে বলে চিহ্নিত করুন';

  @override
  String get reviewCommentHelp =>
      'আপনার লেখা জমার সাথে সংরক্ষিত হবে এবং অন্যরা পড়তে পারবেন।';

  @override
  String get reviewCommentRequired => 'অনুগ্রহ করে একটি ছোট নোট লিখুন।';

  @override
  String reviewCommentTooLong(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$maxString অক্ষরের মধ্যে রাখুন।';
  }

  @override
  String reviewSaved(String state) {
    return 'সংরক্ষিত: $state।';
  }

  @override
  String get reviewSaving => 'সংরক্ষণ হচ্ছে…';

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get settingsLanguage => 'ভাষা';

  @override
  String get settingsLanguageHelp =>
      'এটি পুরো অ্যাপের ভাষা বদলায়। আপনার পছন্দ এই কম্পিউটারে মনে রাখা হবে।';

  @override
  String get settingsAccount => 'আপনার অ্যাকাউন্ট';

  @override
  String get accountName => 'নাম';

  @override
  String get accountEmail => 'ইমেইল';

  @override
  String get accountRole => 'ভূমিকা';

  @override
  String get accountOrganisation => 'সংস্থা';

  @override
  String get accountServer => 'সার্ভার';

  @override
  String get settingsSignOutHelp =>
      'আবার সাইন ইন করতে আপনার ইমেইল ও পাসওয়ার্ড লাগবে।';

  @override
  String get roleSupervisor => 'সুপারভাইজার';

  @override
  String get roleBranchManager => 'শাখা ব্যবস্থাপক';

  @override
  String get roleMe => 'পর্যবেক্ষণ ও মূল্যায়ন';

  @override
  String get roleOrgAdmin => 'সংস্থার অ্যাডমিন';

  @override
  String get roleDonorReadonly => 'দাতা (শুধু দেখা)';

  @override
  String get aboutTitle => 'পরিচিতি';

  @override
  String aboutVersion(String version) {
    return 'সংস্করণ $version';
  }

  @override
  String get aboutPreAlpha =>
      'প্রাথমিক পরীক্ষামূলক সংস্করণ। এখনও বাস্তব কাজে ব্যবহারের উপযুক্ত নয়।';

  @override
  String get aboutLicenceTitle => 'লাইসেন্স';

  @override
  String get aboutLicenceBody =>
      'অভিযাত্রা মুক্ত সফটওয়্যার। আপনি জিএনইউ অ্যাফেরো জেনারেল পাবলিক লাইসেন্স, সংস্করণ ৩ (AGPL-3.0) অনুযায়ী এটি ব্যবহার, অধ্যয়ন, ভাগ ও পরিবর্তন করতে পারেন। এর কোনো ওয়ারেন্টি নেই। বদলানো সংস্করণ নেটওয়ার্কে অন্যদের জন্য চালালে তাদের কাছে আপনার পরিবর্তনের সোর্স কোড দিতে হবে।';

  @override
  String get aboutSourceTitle => 'সোর্স কোড';

  @override
  String get aboutSourceOpen => 'সোর্স কোড খুলুন';

  @override
  String aboutSourceFailed(String url) {
    return 'লিংকটি খোলা গেল না। ঠিকানাটি হলো $url';
  }

  @override
  String get aboutLicencesTitle => 'ওপেন-সোর্স লাইসেন্স';

  @override
  String get aboutLicencesHelp =>
      'অভিযাত্রা যে অন্য মুক্ত সফটওয়্যার দিয়ে তৈরি এবং প্রতিটির লাইসেন্স।';

  @override
  String get aboutLicencesButton => 'লাইসেন্সগুলো দেখুন';

  @override
  String get aboutMadeBy => 'অনিন্দ স্টুডিও-র তৈরি';
}
