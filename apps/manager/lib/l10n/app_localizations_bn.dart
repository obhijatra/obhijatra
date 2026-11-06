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
      'এটি ওয়েব ঠিকানার মতো দেখাচ্ছে না। ঠিকানা এমন হয়: https://data.example.org';

  @override
  String get serverInsecure =>
      'https:// দিয়ে শুরু হওয়া ঠিকানা ব্যবহার করুন, যাতে পথে আপনার পাসওয়ার্ড ও তথ্য সুরক্ষিত থাকে।';

  @override
  String get serverTestingOnly =>
      'শুধু পরীক্ষার জন্য: এই ঠিকানাটি আপনার নিজের নেটওয়ার্কে এবং সুরক্ষিত নয়। আসল তথ্যের জন্য ব্যবহার করবেন না।';

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
  String get roleMe => 'পর্যবেক্ষণ ও মূল্যায়ন কর্মকর্তা';

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

  @override
  String get signInOr => 'অথবা';

  @override
  String get signInGoogle => 'গুগল দিয়ে চালিয়ে যান';

  @override
  String get signInSms => 'এসএমএস কোড দিয়ে সাইন ইন করুন';

  @override
  String get signInSmsAdminNote =>
      'সংস্থার অ্যাডমিনরা এসএমএস কোড ব্যবহার করতে পারেন না।';

  @override
  String get signInOtherWays => 'সাইন ইনের অন্য উপায়';

  @override
  String get smsNumberIntro =>
      'আপনার অ্যাকাউন্টে থাকা মোবাইল নম্বরে আমরা এসএমএস-এ ৬ অঙ্কের একটি কোড পাঠাব।';

  @override
  String get smsNumberLabel => 'মোবাইল নম্বর';

  @override
  String get smsNumberHelp =>
      'যেমন 01712345678। বাংলাদেশের বাইরের নম্বর হলে + ও দেশের কোড দিয়ে শুরু করুন।';

  @override
  String get smsNumberInvalid =>
      'এটি মোবাইল নম্বরের মতো দেখাচ্ছে না। 01712345678-এর মতো করে লিখুন, অথবা + ও দেশের কোড দিয়ে শুরু করুন।';

  @override
  String get smsSendCode => 'কোড পাঠান';

  @override
  String get actionSending => 'পাঠানো হচ্ছে…';

  @override
  String get smsCodeTitle => 'কোডটি লিখুন';

  @override
  String smsCodeSent(String phone) {
    return '$phone নম্বরটি দিয়ে এসএমএস কোডে সাইন ইন করা গেলে, ৬ অঙ্কের একটি কোড আসছে।';
  }

  @override
  String smsCodeLifetime(int minutes) {
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'কোডটি $minutesString মিনিট কাজ করবে।',
      one: 'কোডটি ১ মিনিট কাজ করবে।',
    );
    return '$_temp0';
  }

  @override
  String get smsCodeLabel => '৬ অঙ্কের কোড';

  @override
  String get smsCodeIncomplete => 'কোডের ৬টি অঙ্কই লিখুন।';

  @override
  String get smsCodeWrong =>
      'কোডটি ভুল অথবা এর মেয়াদ শেষ। এসএমএস দেখে আবার চেষ্টা করুন, অথবা নতুন কোড পাঠান।';

  @override
  String get smsCodeUsedUp =>
      'এই কোডটি ৩ বার চেষ্টা করা হয়েছে, তাই এটি আর কাজ করবে না। নতুন কোড পাঠান।';

  @override
  String get smsCodeExpired => 'এই কোডের মেয়াদ শেষ। নতুন কোড পাঠান।';

  @override
  String get smsCodeChecking => 'যাচাই করা হচ্ছে…';

  @override
  String smsResendIn(String time) {
    return '$time পরে নতুন কোড পাঠাতে পারবেন';
  }

  @override
  String get smsResend => 'নতুন কোড পাঠান';

  @override
  String get smsNewCodeSent => 'নতুন একটি কোড আসছে।';

  @override
  String get smsChangeNumber => 'নম্বর বদলান';

  @override
  String get googleWaitingTitle => 'গুগলের জন্য অপেক্ষা করা হচ্ছে…';

  @override
  String get googleWaitingBody =>
      'গুগলের সাইন-ইন পাতা আপনার ওয়েব ব্রাউজারে খুলবে। সেখানে আপনার গুগল অ্যাকাউন্ট বাছুন, তারপর এই উইন্ডোতে ফিরে আসুন।';

  @override
  String get googleOpenHelp => 'গুগলের পাতা না খুললে এই বোতামটি ব্যবহার করুন।';

  @override
  String get googleOpen => 'গুগল সাইন-ইন খুলুন';

  @override
  String get problemGoogleNoAccount =>
      'এই গুগল ইমেইল ঠিকানা দিয়ে এখানে কোনো অভিযাত্রা অ্যাকাউন্ট নেই। আপনার সংস্থার অ্যাডমিনকে এটি যোগ করতে বলুন, অথবা অন্যভাবে সাইন ইন করুন।';

  @override
  String get problemGoogleUnconfirmed =>
      'গুগল দিয়ে সাইন ইন করার আগে আপনার সংস্থার অ্যাডমিনকে আপনার ইমেইল ঠিকানা নিশ্চিত করতে হবে।';

  @override
  String get problemGoogleNotAllowed =>
      'এই অ্যাকাউন্ট দিয়ে সাইন ইন করা যাবে না। আপনার সংস্থার অ্যাডমিনকে জিজ্ঞেস করুন।';

  @override
  String get problemGoogleNoEmail =>
      'গুগল এই অ্যাকাউন্টের কোনো নিশ্চিত ইমেইল ঠিকানা জানায়নি। অন্য গুগল অ্যাকাউন্ট ব্যবহার করুন, অথবা অন্যভাবে সাইন ইন করুন।';

  @override
  String get problemGoogleUnmanaged =>
      'এই ইমেইল ঠিকানাটি যে এই গুগল অ্যাকাউন্টেরই, গুগল তা নিশ্চিত করতে পারে না। জিমেইল ঠিকানা বা আপনার প্রতিষ্ঠানের গুগল ওয়ার্কস্পেস অ্যাকাউন্ট দিয়ে সাইন ইন করুন, অথবা অন্যভাবে সাইন ইন করুন।';

  @override
  String get problemGoogleUnavailable =>
      'এই সার্ভারে গুগল দিয়ে সাইন ইন চালু নেই। অন্যভাবে সাইন ইন করুন।';

  @override
  String get problemGoogleFailed =>
      'গুগল দিয়ে সাইন ইন শেষ হয়নি। আবার চেষ্টা করুন, অথবা অন্যভাবে সাইন ইন করুন।';

  @override
  String get problemSmsOff =>
      'এই সার্ভারে এসএমএস কোড দিয়ে সাইন ইন বন্ধ আছে। অন্যভাবে সাইন ইন করুন।';

  @override
  String get problemPhoneInvalid =>
      'এটি মোবাইল নম্বরের মতো দেখাচ্ছে না। 01712345678-এর মতো করে লিখুন, অথবা + ও দেশের কোড দিয়ে শুরু করুন।';

  @override
  String get problemCodeWrong =>
      'কোডটি ভুল অথবা এর মেয়াদ শেষ। এসএমএস দেখে আবার চেষ্টা করুন, অথবা নতুন কোড পাঠান।';

  @override
  String get problemTooManyCodes =>
      'অনেকবার কোড চাওয়া হয়েছে। ১৫ মিনিট অপেক্ষা করুন, অথবা অন্যভাবে সাইন ইন করুন।';

  @override
  String get problemTooManyTries =>
      'এই সংযোগ থেকে অনেকবার চেষ্টা করা হয়েছে। ১৫ মিনিট অপেক্ষা করে নতুন কোড চান।';

  @override
  String get problemTooManyTests =>
      'অনেকগুলো পরীক্ষামূলক এসএমএস পাঠানো হয়েছে। ১৫ মিনিট অপেক্ষা করে আবার চেষ্টা করুন।';

  @override
  String get problemSettingsInvalid =>
      'কিছু সেটিং ঠিক করা দরকার। ঘরগুলোর নিচের বার্তা দেখুন।';

  @override
  String get accountPhone => 'মোবাইল নম্বর';

  @override
  String get signInMethodsTitle => 'সাইন ইনের উপায়';

  @override
  String get signInMethodsSummary =>
      'সবাই ইমেইল ঠিকানা ও পাসওয়ার্ড দিয়ে সাইন ইন করতে পারেন। চাইলে গুগল বা এসএমএস কোড দিয়েও সাইন ইনের সুযোগ দিতে পারেন।';

  @override
  String get signInMethodsOpen => 'সাইন ইনের উপায় ঠিক করুন';

  @override
  String get settingsBack => 'সেটিংসে ফিরে যান';

  @override
  String get methodOn => 'চালু';

  @override
  String get methodOff => 'বন্ধ';

  @override
  String get googleTitle => 'গুগল';

  @override
  String get googleDescription =>
      'লোকজন “গুগল দিয়ে চালিয়ে যান”-এ ক্লিক করে তাঁদের গুগল অ্যাকাউন্ট বাছেন। এটি শুধু তাঁদের জন্য কাজ করে, যাঁদের এখানকার অ্যাকাউন্টে একই ইমেইল ঠিকানা আছে এবং কোনো অ্যাডমিন তা নিশ্চিত করেছেন।';

  @override
  String get googleRedirectLabel => 'গুগলের জন্য রিডাইরেক্ট ঠিকানা';

  @override
  String get googleRedirectHelp =>
      'আপনার গুগল ক্লায়েন্টে Authorised redirect URIs-এর ঘরে এই ঠিকানাটি যোগ করুন।';

  @override
  String get googleRedirectWarning =>
      'গুগলের জন্য ডোমেইন নামসহ https:// ঠিকানা লাগে, যেমন https://data.example.org। আপনার সার্ভার যিনি চালান, তাঁকে এমন একটি ঠিকানা দিতে বলুন। এসএমএস কোড এটি ছাড়াই কাজ করে।';

  @override
  String get actionCopy => 'কপি করুন';

  @override
  String get copiedRedirect => 'রিডাইরেক্ট ঠিকানা কপি হয়েছে।';

  @override
  String get googleClientId => 'ক্লায়েন্ট আইডি';

  @override
  String get googleClientIdHelp =>
      'আপনার গুগল ক্লাউড প্রজেক্ট থেকে। এর শেষে থাকে .apps.googleusercontent.com।';

  @override
  String get googleClientSecret => 'ক্লায়েন্ট সিক্রেট';

  @override
  String get googleClientSecretHelp =>
      'ক্লায়েন্ট তৈরি করার সময় গুগল এটি একবারই দেখায়। এটি গোপন রাখুন।';

  @override
  String get secretSavedKeep => 'সংরক্ষিত আছে। আগেরটি রাখতে ফাঁকা রাখুন।';

  @override
  String get secretShow => 'সিক্রেট দেখান';

  @override
  String get secretHide => 'সিক্রেট লুকান';

  @override
  String get setupGuide => 'কীভাবে চালু করবেন';

  @override
  String get smsTitle => 'এসএমএস কোড';

  @override
  String get smsDescription =>
      'লোকজন তাঁদের মোবাইল নম্বর লেখেন এবং এসএমএস-এ ৬ অঙ্কের একটি কোড পান। প্রতিটি বার্তার জন্য আপনার সংস্থা এসএমএস সেবাদাতাকে টাকা দেয়। সংস্থার অ্যাডমিনরা এসএমএস কোড ব্যবহার করতে পারেন না।';

  @override
  String get smsProviderTitle => 'আপনার এসএমএস সেবাদাতা';

  @override
  String get smsProviderHelp =>
      'একটি বার্তা পাঠানোর জন্য আপনার এসএমএস সেবাদাতার নির্দেশিকা দেখে এগুলো পূরণ করুন।';

  @override
  String get smsMethod => 'পদ্ধতি';

  @override
  String get smsAddress => 'ঠিকানা';

  @override
  String get smsAddressHelp =>
      'বার্তা পাঠানোর জন্য সেবাদাতার ওয়েব ঠিকানা। এটি https:// দিয়ে শুরু হয়।';

  @override
  String get smsBodyFormat => 'বডির ধরন';

  @override
  String get smsFormatJson => 'JSON';

  @override
  String get smsFormatForm => 'ফর্ম';

  @override
  String get smsBody => 'বডি';

  @override
  String get smsBodyHelp =>
      'সেবাদাতার নির্দেশিকা থেকে উদাহরণটি কপি করুন, তারপর যেখানে যেখানে মান বসবে সেখানে প্লেসহোল্ডার দিন।';

  @override
  String get smsPlaceholders => 'প্লেসহোল্ডার';

  @override
  String get smsPlaceholdersHelp =>
      'ঠিকানা, বডি বা হেডারের মানে কার্সর যেখানে আছে সেখানে বসাতে একটিতে ক্লিক করুন। প্রতিটি বার্তার সময় সার্ভার এর জায়গায় আসল মান বসিয়ে দেয়।';

  @override
  String get smsPlaceholderPhone => 'প্লাস চিহ্নসহ নম্বর, যেমন +8801712345678';

  @override
  String get smsPlaceholderDigits =>
      'প্লাস চিহ্ন ছাড়া নম্বর, যেমন 8801712345678';

  @override
  String get smsPlaceholderMessage => 'এসএমএস-এর লেখা';

  @override
  String get smsPlaceholderSecret => 'আপনার সিক্রেট কী, যা লুকানো থাকে';

  @override
  String smsInsertPlaceholder(String placeholder) {
    return '$placeholder বসান';
  }

  @override
  String get smsHeaders => 'বাড়তি হেডার';

  @override
  String get smsHeadersHelp =>
      'শুধু সেবাদাতার নির্দেশিকায় চাওয়া থাকলে, যেমন Authorization।';

  @override
  String get smsHeaderName => 'নাম';

  @override
  String get smsHeaderValue => 'মান';

  @override
  String get smsHeaderAdd => 'হেডার যোগ করুন';

  @override
  String get smsHeaderRemove => 'এই হেডারটি সরান';

  @override
  String smsHeadersMax(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'সর্বোচ্চ $countStringটি হেডার যোগ করা যায়।';
  }

  @override
  String get smsSecret => 'সিক্রেট কী';

  @override
  String smsSecretHelp(String placeholder) {
    return 'আপনার সেবাদাতার এপিআই কী বা টোকেন। এটি এখানে লিখুন, আর নির্দেশিকায় যেখানে কী আছে সেখানে $placeholder দিন।';
  }

  @override
  String get smsSuccessText => 'সফলতার লেখা';

  @override
  String get smsSuccessTextHelp =>
      'ঐচ্ছিক। বার্তা গ্রহণ করলে সেবাদাতা যা উত্তর দেয়, যেমন SUCCESS। নিশ্চিত না হলে ফাঁকা রাখুন।';

  @override
  String get smsTestTitle => 'পরীক্ষামূলক এসএমএস পাঠান';

  @override
  String get smsTestHelp =>
      'ওপরের সেটিংস দিয়ে একটি পরীক্ষামূলক বার্তা পাঠায়, সংরক্ষণের আগেও।';

  @override
  String get smsTestNumber => 'পরীক্ষার জন্য মোবাইল নম্বর';

  @override
  String get smsTestButton => 'পরীক্ষামূলক এসএমএস পাঠান';

  @override
  String get smsResultTest => 'পরীক্ষার ফল';

  @override
  String get smsResultLast => 'সার্ভারের পাঠানো শেষ বার্তা';

  @override
  String get smsResultSent => 'পাঠানো হয়েছে। সেবাদাতা বার্তাটি গ্রহণ করেছে।';

  @override
  String get smsResultNotSent => 'পাঠানো হয়নি।';

  @override
  String smsResultStatus(String status) {
    return 'সেবাদাতার স্ট্যাটাস: $status';
  }

  @override
  String get smsResultNoAnswer => 'সেবাদাতা কোনো উত্তর দেয়নি।';

  @override
  String get smsResultReply => 'সেবাদাতার উত্তর';

  @override
  String smsResultAt(String time) {
    return 'সময়: $time';
  }

  @override
  String get smsResultNone =>
      'সার্ভার শেষবার চালু হওয়ার পর কোনো বার্তা পাঠানো হয়নি।';

  @override
  String get actionSave => 'সংরক্ষণ করুন';

  @override
  String get actionSaving => 'সংরক্ষণ হচ্ছে…';

  @override
  String get signInMethodsSaved => 'সাইন ইনের উপায় সংরক্ষিত হয়েছে।';

  @override
  String get unsavedChanges => 'আপনার কিছু পরিবর্তন এখনও সংরক্ষণ করা হয়নি।';

  @override
  String get leaveTitle => 'সংরক্ষণ না করেই চলে যাবেন?';

  @override
  String get leaveBody =>
      'সাইন ইনের উপায়ে করা আপনার পরিবর্তনগুলো হারিয়ে যাবে।';

  @override
  String get leaveStay => 'থাকুন';

  @override
  String get leaveDiscard => 'সংরক্ষণ না করে চলে যান';

  @override
  String get navPeople => 'লোকজন';

  @override
  String get roleFieldOfficer => 'মাঠ কর্মকর্তা';

  @override
  String get peopleTitle => 'লোকজন';

  @override
  String get peopleSummary =>
      'অভিযাত্রা যাঁরা ব্যবহার করেন তাঁদের যোগ করুন, কে কী করতে পারবেন তা বাছুন, এবং সাইন ইনে সাহায্য করুন।';

  @override
  String get peopleAdd => 'ব্যক্তি যোগ করুন';

  @override
  String get peopleKindLabel => 'কর্মীর ধরন';

  @override
  String get kindStaff => 'অফিসের কর্মী';

  @override
  String get kindField => 'মাঠকর্মী';

  @override
  String get peopleSearch => 'খুঁজুন';

  @override
  String get peopleSearchHint => 'নাম, ইমেইল বা মোবাইল নম্বর';

  @override
  String get peopleSearchClear => 'খোঁজা মুছুন';

  @override
  String get peopleStatus => 'অবস্থা';

  @override
  String get peopleStatusAll => 'সবাই';

  @override
  String get statusActive => 'সক্রিয়';

  @override
  String get statusDeactivated => 'নিষ্ক্রিয়';

  @override
  String get statusLocked => 'লক করা';

  @override
  String get statusMustChoose => 'পাসওয়ার্ড বাছতে হবে';

  @override
  String get personPlace => 'স্থান';

  @override
  String get placeAll => 'সব স্থান';

  @override
  String get peopleSort => 'ক্রম';

  @override
  String get peopleSortNewest => 'নতুনরা আগে';

  @override
  String get peopleSortName => 'নাম অনুযায়ী';

  @override
  String get emailConfirmed => 'নিশ্চিত';

  @override
  String get peopleEmptyStaffTitle => 'এখনও অফিসের কোনো কর্মী নেই';

  @override
  String get peopleEmptyFieldTitle => 'এখনও কোনো মাঠকর্মী নেই';

  @override
  String get peopleEmptyBody =>
      'প্রথম জনকে যোগ করতে ‘ব্যক্তি যোগ করুন’ ব্যবহার করুন।';

  @override
  String get peopleNoMatchTitle => 'কেউ মেলেনি';

  @override
  String get peopleNoMatchBody =>
      'অন্য কিছু লিখে খুঁজুন, অথবা অন্য অবস্থা বা স্থান বাছুন।';

  @override
  String get peopleNoLockedTitle => 'কারও সাইন ইন লক করা নেই';

  @override
  String get peopleNoLockedBody =>
      'অনেকবার ভুল পাসওয়ার্ড দেওয়ার পর কারও সাইন ইন লক হলে তিনি এখানে দেখা যাবেন।';

  @override
  String get peopleBack => 'লোকজনে ফিরে যান';

  @override
  String get personDetails => 'বিস্তারিত';

  @override
  String get personName => 'নাম';

  @override
  String get personKind => 'ধরন';

  @override
  String get personKindHelp =>
      'অফিসের কর্মীরা এই অ্যাপ ব্যবহার করেন। মাঠকর্মীরা ফোনে অভিযাত্রার মাঠের অ্যাপ ব্যবহার করেন। পরে এটি বদলানো যায় না।';

  @override
  String get personKindFixed => 'এটি বদলানো যায় না।';

  @override
  String get personPlaceHelp => 'এই ব্যক্তি যেখানে কাজ করেন।';

  @override
  String get personPlaceChoose => 'স্থান বাছুন';

  @override
  String get placeChange => 'বদলান';

  @override
  String get placeSearch => 'স্থান খুঁজুন';

  @override
  String get placeNoMatch => 'কোনো স্থান মেলেনি।';

  @override
  String get placeNone =>
      'এখনও কোনো স্থান নেই। আপনার সার্ভার যিনি চালান তাঁকে যোগ করতে বলুন।';

  @override
  String get personEmailHelp => 'পাসওয়ার্ড বা গুগল দিয়ে সাইন ইন করতে লাগে।';

  @override
  String get personVerified => 'ইমেইল ঠিকানা নিশ্চিত';

  @override
  String get personVerifiedHelp =>
      'ঠিকানাটি যে এই ব্যক্তিরই, সে বিষয়ে নিশ্চিত হলে চালু করুন। গুগল দিয়ে সাইন ইনের জন্য এটি লাগে।';

  @override
  String get personPhoneHelp =>
      'এসএমএস কোড দিয়ে সাইন ইনের জন্য লাগে। সংস্থার অ্যাডমিনদের জন্য এটি নেই।';

  @override
  String get personHowSignIn => 'তিনি কীভাবে সাইন ইন করবেন?';

  @override
  String get personSignInOtp => 'ইমেইল ও এককালীন পাসওয়ার্ড';

  @override
  String get personSignInOtpHelp =>
      'আপনি তাঁকে দেওয়ার জন্য একটি পাসওয়ার্ড দেখবেন। প্রথমবার সাইন ইনের সময় তিনি নিজের পাসওয়ার্ড বেছে নেবেন।';

  @override
  String get personSignInOtpNeedsEmail =>
      'এটি ব্যবহার করতে একটি ইমেইল ঠিকানা দিন।';

  @override
  String get personSignInOther => 'শুধু এসএমএস কোড বা গুগল';

  @override
  String get personSignInOtherHelp =>
      'দেওয়ার মতো কোনো পাসওয়ার্ড নেই। তিনি মোবাইলে পাঠানো কোড দিয়ে, অথবা গুগল দিয়ে সাইন ইন করবেন।';

  @override
  String get personCannotSignIn =>
      'এই তথ্য দিয়ে তিনি এখনও সাইন ইন করতে পারবেন না। গুগল দিয়ে সাইন ইনের জন্য নিশ্চিত ইমেইল ঠিকানা লাগে। এসএমএস কোডের জন্য মোবাইল নম্বর লাগে, আর এটি সংস্থার অ্যাডমিনদের জন্য নেই।';

  @override
  String get personAdding => 'যোগ হচ্ছে…';

  @override
  String personAdded(String name) {
    return '$name-কে যোগ করা হয়েছে।';
  }

  @override
  String personAddedHeading(String name) {
    return '$name-কে যোগ করা হয়েছে';
  }

  @override
  String get personSaved => 'পরিবর্তন সংরক্ষিত হয়েছে।';

  @override
  String get personSignOutNote =>
      'সাইন ইনের তথ্য, ভূমিকা বা অবস্থা বদলালে এই ব্যক্তি তাঁর সব ডিভাইস থেকে সাইন আউট হয়ে যাবেন।';

  @override
  String get leavePersonBody =>
      'এই ব্যক্তির তথ্যে করা আপনার পরিবর্তনগুলো হারিয়ে যাবে।';

  @override
  String get personErrorName => 'ব্যক্তির নাম লিখুন।';

  @override
  String get personErrorRole => 'একটি ভূমিকা বাছুন।';

  @override
  String get personErrorPlace => 'একটি স্থান বাছুন।';

  @override
  String get personErrorEmailInvalid => 'এটি ইমেইল ঠিকানার মতো দেখাচ্ছে না।';

  @override
  String get personErrorEmailOrPhone =>
      'এই ব্যক্তি যেন সাইন ইন করতে পারেন, সেজন্য একটি ইমেইল ঠিকানা বা মোবাইল নম্বর দিন।';

  @override
  String get personErrorAdminEmail =>
      'সংস্থার অ্যাডমিনের ইমেইল ঠিকানা লাগবে। সংস্থার অ্যাডমিনরা এসএমএস কোড দিয়ে সাইন ইন করতে পারেন না।';

  @override
  String get personErrorOtpEmail =>
      'এককালীন পাসওয়ার্ড দিয়ে সাইন ইন করতে একটি ইমেইল ঠিকানা লাগে।';

  @override
  String get personErrorEmailTaken =>
      'এই ইমেইল ঠিকানা আগে থেকেই অন্য একজনের আছে।';

  @override
  String get personErrorPhoneTaken =>
      'এই মোবাইল নম্বর আগে থেকেই অন্য একজনের আছে।';

  @override
  String get personErrorLastAdmin =>
      'ইনিই সংস্থার একমাত্র সক্রিয় অ্যাডমিন। আগে অন্য কাউকে সংস্থার অ্যাডমিন করুন।';

  @override
  String get problemDetailsInvalid =>
      'কিছু তথ্য ঠিক করা দরকার। ঘরগুলোর নিচের বার্তা দেখুন।';

  @override
  String get problemPasswordChangeRequired =>
      'চালিয়ে যাওয়ার আগে নিজের পাসওয়ার্ড বেছে নিন।';

  @override
  String get problemPasswordSavedSignIn =>
      'আপনার নতুন পাসওয়ার্ড সংরক্ষিত হয়েছে, কিন্তু আবার সাইন ইন করানো যায়নি। নতুন পাসওয়ার্ড দিয়ে সাইন ইন করুন।';

  @override
  String get personStatusTitle => 'সাইন ইন ও অবস্থা';

  @override
  String get personActiveHelp =>
      'নিষ্ক্রিয় ব্যক্তিরা সাইন ইন করতে পারেন না। তাঁদের করা সব কাজ রেখে দেওয়া হয়।';

  @override
  String get personOnlyAdmin =>
      'আপনিই সংস্থার একমাত্র সক্রিয় অ্যাডমিন, তাই নিজের ভূমিকা বা অবস্থা বদলাতে পারবেন না। আগে অন্য কাউকে সংস্থার অ্যাডমিন করুন।';

  @override
  String deactivateTitle(String name) {
    return '$name-কে নিষ্ক্রিয় করবেন?';
  }

  @override
  String get deactivateBody =>
      'তিনি সাইন আউট হয়ে যাবেন, এবং আপনি আবার সক্রিয় না করা পর্যন্ত সাইন ইন করতে পারবেন না।';

  @override
  String get deactivateSelfBody =>
      'আপনি সাইন আউট হয়ে যাবেন, এবং সংস্থার অন্য কোনো অ্যাডমিন আবার সক্রিয় না করা পর্যন্ত সাইন ইন করতে পারবেন না।';

  @override
  String get deactivateButton => 'নিষ্ক্রিয় করুন';

  @override
  String personDeactivated(String name) {
    return '$name-কে নিষ্ক্রিয় করা হয়েছে।';
  }

  @override
  String personReactivated(String name) {
    return '$name আবার সাইন ইন করতে পারবেন।';
  }

  @override
  String personMustChooseNote(String name) {
    return '$name-এর একটি এককালীন পাসওয়ার্ড আছে। পরের বার সাইন ইনের সময় তাঁকে নিজের পাসওয়ার্ড বেছে নিতে হবে।';
  }

  @override
  String personLockedNote(String time) {
    return 'অনেকবার ভুল পাসওয়ার্ড দেওয়ায় সাইন ইন লক হয়ে আছে। $time-এ এটি নিজে থেকেই খুলে যাবে।';
  }

  @override
  String get unlockButton => 'সাইন ইন খুলে দিন';

  @override
  String unlockDone(String name) {
    return 'সাইন ইন খুলে দেওয়া হয়েছে। $name এখন আবার চেষ্টা করতে পারবেন।';
  }

  @override
  String get resetTitle => 'পাসওয়ার্ড ভুলে গেলে';

  @override
  String get resetHelp =>
      'কেউ পাসওয়ার্ড ভুলে গেলে তাঁকে নতুন এককালীন পাসওয়ার্ড দিন। তাঁর পুরোনো পাসওয়ার্ড আর কাজ করবে না।';

  @override
  String get resetButton => 'নতুন এককালীন পাসওয়ার্ড দিন';

  @override
  String get resetNeedsEmail =>
      'আগে একটি ইমেইল ঠিকানা দিয়ে সংরক্ষণ করুন: এককালীন পাসওয়ার্ড ইমেইল ঠিকানার সাথে ব্যবহার করা হয়।';

  @override
  String resetConfirmTitle(String name) {
    return '$name-কে নতুন এককালীন পাসওয়ার্ড দেবেন?';
  }

  @override
  String get resetConfirmBody =>
      'তাঁর এখনকার পাসওয়ার্ড আর কাজ করবে না, এবং তিনি সব ডিভাইস থেকে সাইন আউট হয়ে যাবেন। নতুন এককালীন পাসওয়ার্ডটি আপনি একবারই দেখবেন।';

  @override
  String get resetConfirmButton => 'নতুন পাসওয়ার্ড দিন';

  @override
  String otpTitle(String name) {
    return '$name-এর এককালীন পাসওয়ার্ড';
  }

  @override
  String otpGive(String name) {
    return 'এটি $name-কে সামনাসামনি বা ফোনে জানিয়ে দিন। প্রথমবার সাইন ইনের সময় তাঁকে নিজের পাসওয়ার্ড বেছে নিতে হবে। এটি আর দেখানো হবে না।';
  }

  @override
  String otpSignInWith(String email) {
    return 'তিনি $email দিয়ে সাইন ইন করবেন।';
  }

  @override
  String otpSpoken(String characters) {
    return 'এককালীন পাসওয়ার্ড: $characters';
  }

  @override
  String get otpCopy => 'পাসওয়ার্ড কপি করুন';

  @override
  String get otpCopied =>
      'পাসওয়ার্ড কপি হয়েছে। এখনই পেস্ট করুন: এটি বন্ধ করলে ক্লিপবোর্ড থেকে পাসওয়ার্ডটি মুছে যাবে।';

  @override
  String get otpDone => 'হয়ে গেছে';

  @override
  String get otpAddAnother => 'আরেকজনকে যোগ করুন';

  @override
  String get leaveOtpTitle => 'পাসওয়ার্ড টুকে না রেখেই চলে যাবেন?';

  @override
  String get leaveOtpBody =>
      'এককালীন পাসওয়ার্ডটি আর দেখানো হবে না। এখন চলে গেলে এই ব্যক্তির পাতা থেকে নতুন একটি দিতে পারবেন।';

  @override
  String get leaveOtpLeave => 'চলে যান';

  @override
  String get choosePasswordTitle => 'নিজের পাসওয়ার্ড বেছে নিন';

  @override
  String get choosePasswordIntro =>
      'আপনি এককালীন পাসওয়ার্ড দিয়ে সাইন ইন করেছেন। চালিয়ে যাওয়ার আগে এমন একটি পাসওয়ার্ড বেছে নিন যা শুধু আপনিই জানেন।';

  @override
  String choosePasswordAccount(String name) {
    return '$name হিসেবে সাইন ইন করা আছে';
  }

  @override
  String get choosePasswordCurrent => 'এককালীন পাসওয়ার্ড';

  @override
  String get choosePasswordCurrentHelp =>
      'আপনার সংস্থার অ্যাডমিন যে পাসওয়ার্ড দিয়েছেন।';

  @override
  String get choosePasswordNew => 'নতুন পাসওয়ার্ড';

  @override
  String get choosePasswordHint =>
      'মনে থাকবে এমন ৩ বা ৪টি শব্দ ব্যবহার করুন, অন্তত ১২ অক্ষর।';

  @override
  String get choosePasswordRepeat => 'নতুন পাসওয়ার্ডটি আবার লিখুন';

  @override
  String get choosePasswordTooShort => 'অন্তত ১২ অক্ষর ব্যবহার করুন।';

  @override
  String get choosePasswordSame =>
      'এককালীন পাসওয়ার্ড থেকে আলাদা একটি পাসওয়ার্ড বেছে নিন।';

  @override
  String get choosePasswordMismatch => 'দুটি পাসওয়ার্ড এক নয়।';

  @override
  String get choosePasswordWrongCurrent =>
      'এটি আপনাকে দেওয়া এককালীন পাসওয়ার্ড নয়। দেখে নিয়ে আবার চেষ্টা করুন।';

  @override
  String get choosePasswordSave => 'সংরক্ষণ করে চালিয়ে যান';

  @override
  String get choosePasswordSaved => 'আপনার নতুন পাসওয়ার্ড সংরক্ষিত হয়েছে।';

  @override
  String get problemPersonChanged =>
      'কিছুক্ষণ আগে অন্য কেউ এই ব্যক্তির তথ্য বদলেছেন। আবার লোড করুন, তারপর আপনার পরিবর্তনটি আবার করুন।';

  @override
  String get actionReload => 'আবার লোড করুন';

  @override
  String get navPlaces => 'স্থান';

  @override
  String get placesTitle => 'স্থান';

  @override
  String get placesSummary =>
      'ওপর থেকে নিচে আপনার সংস্থা: প্রধান কার্যালয়, অঞ্চল, এলাকা ও শাখা। প্রত্যেক ব্যক্তি একটি স্থানে কাজ করেন।';

  @override
  String get placesAdd => 'স্থান যোগ করুন';

  @override
  String get placesImport => 'স্প্রেডশিট থেকে আনুন';

  @override
  String get placesSearchHint => 'নাম বা কোড';

  @override
  String get placesShowClosed => 'বন্ধ স্থানও দেখান';

  @override
  String placesClosedHidden(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি বন্ধ স্থান লুকানো আছে।',
      one: '১টি বন্ধ স্থান লুকানো আছে।',
    );
    return '$_temp0';
  }

  @override
  String placesMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি স্থান মিলেছে',
      one: '১টি স্থান মিলেছে',
      zero: 'কোনো স্থান মেলেনি',
    );
    return '$_temp0';
  }

  @override
  String get placesNoMatchBody => 'অন্য নাম বা কোড দিয়ে খুঁজুন।';

  @override
  String get placesNoMatchClosedBody =>
      'অন্য নাম বা কোড দিয়ে খুঁজুন, অথবা ‘বন্ধ স্থানও দেখান’ চালু করুন।';

  @override
  String get placesEmptyTitle => 'প্রথম স্থানগুলো যোগ করুন';

  @override
  String placesEmptyBody(String organisation) {
    return '$organisation-এর ভেতরের অঞ্চল, এলাকা ও শাখা যোগ করুন: ‘স্থান যোগ করুন’ দিয়ে একটি একটি করে, অথবা স্প্রেডশিট থেকে একসাথে সব।';
  }

  @override
  String get placesNoneTitle => 'এখনও কোনো স্থান নেই';

  @override
  String get placesBack => 'স্থানে ফিরে যান';

  @override
  String get placeRootNote => 'পুরো সংস্থা';

  @override
  String placeInsideCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ভেতরে $countStringটি স্থান',
      one: 'ভেতরে ১টি স্থান',
    );
    return '$_temp0';
  }

  @override
  String placeCodeShown(String code) {
    return 'কোড $code';
  }

  @override
  String get placeClosed => 'বন্ধ';

  @override
  String placeOpenInside(String name) {
    return '$name-এর ভেতরের স্থানগুলো দেখান';
  }

  @override
  String placeShutInside(String name) {
    return '$name-এর ভেতরের স্থানগুলো লুকান';
  }

  @override
  String placeActions(String name) {
    return '$name-এর বিকল্পগুলো';
  }

  @override
  String get placeAddInside => 'ভেতরে একটি স্থান যোগ করুন';

  @override
  String get placeRename => 'নাম বা কোড বদলান';

  @override
  String get placeCloseAction => 'স্থান বন্ধ করুন';

  @override
  String get placeReopenAction => 'স্থান আবার চালু করুন';

  @override
  String get placeDeleteAction => 'স্থান মুছে ফেলুন';

  @override
  String get placeAddTitle => 'একটি স্থান যোগ করুন';

  @override
  String get placeParent => 'যার ভেতরে থাকবে';

  @override
  String get placeParentHelp =>
      'এই স্থানটি যে স্থানের অংশ। পরে এটি সরানো যাবে না।';

  @override
  String placeParentFixed(String parent) {
    return '$parent-এর ভেতরে। কোনো স্থান সরানো যায় না।';
  }

  @override
  String get placeName => 'নাম';

  @override
  String get placeNameHelp =>
      'যেমন ‘মিরপুর শাখা’। একই স্থানের ভেতরের স্থানগুলোর নাম আলাদা হতে হবে।';

  @override
  String get placeCode => 'কোড (ঐচ্ছিক)';

  @override
  String get placeCodeHelp =>
      'আপনার সংস্থা যে ছোট কোড ব্যবহার করে, যেমন MRP10। দুটি স্থানের কোড এক হতে পারবে না।';

  @override
  String get placeErrorName => 'স্থানটির একটি নাম দিন।';

  @override
  String placeErrorNameTaken(String parent) {
    return '$parent-এর ভেতরে অন্য একটি স্থানের এই নাম আছে। অন্য একটি নাম বেছে নিন।';
  }

  @override
  String get placeErrorCodeTaken =>
      'অন্য একটি স্থানের এই কোড আছে। অন্য একটি কোড বেছে নিন।';

  @override
  String get placeErrorParentClosed =>
      'ওপরের স্থানটি বন্ধ। আগে সেটি আবার চালু করুন, অথবা একটি চালু স্থান বেছে নিন।';

  @override
  String placeAdded(String name) {
    return '$name যোগ হয়েছে।';
  }

  @override
  String placeCloseTitle(String name) {
    return '$name বন্ধ করবেন?';
  }

  @override
  String get placeCloseBody =>
      'বন্ধ স্থান কোনো ব্যক্তি বা নতুন স্থানের জন্য বাছা যায় না, আর স্থান বাছার সময় এটি লুকানো থাকে। সেখানে যা কিছু রেকর্ড করা হয়েছে সব রাখা থাকবে। যেকোনো সময় আপনি এটি আবার চালু করতে পারবেন।';

  @override
  String get placeCloseButton => 'স্থান বন্ধ করুন';

  @override
  String placeClosedDone(String name) {
    return '$name বন্ধ করা হয়েছে।';
  }

  @override
  String placeErrorOpenInside(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'এই স্থানের ভেতরে এখনও $countStringটি চালু স্থান আছে। আগে সেগুলো বন্ধ করুন বা মুছে ফেলুন।',
      one: 'এই স্থানের ভেতরে এখনও ১টি চালু স্থান আছে। আগে সেটি বন্ধ করুন বা মুছে ফেলুন।',
    );
    return '$_temp0';
  }

  @override
  String placeErrorPeople(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'এখানে এখনও $countString জন সক্রিয় ব্যক্তি কাজ করেন। আগে তাঁদের অন্য স্থানে সরান, অথবা নিষ্ক্রিয় করুন।',
      one: 'এখানে এখনও ১ জন সক্রিয় ব্যক্তি কাজ করেন। আগে তাঁকে অন্য স্থানে সরান, অথবা নিষ্ক্রিয় করুন।',
    );
    return '$_temp0';
  }

  @override
  String get placeSeePeople => 'এখানে কারা কাজ করেন দেখুন';

  @override
  String get placeErrorRoot => 'পুরো সংস্থাটি বন্ধ করা বা মুছে ফেলা যায় না।';

  @override
  String placeReopenTitle(String name) {
    return '$name আবার চালু করবেন?';
  }

  @override
  String get placeReopenBody =>
      'এটি আবার ব্যক্তি ও নতুন স্থানের জন্য বাছা যাবে।';

  @override
  String get placeReopenButton => 'আবার চালু করুন';

  @override
  String placeReopenedDone(String name) {
    return '$name আবার চালু হয়েছে।';
  }

  @override
  String get placeErrorAboveClosed =>
      'এর ওপরের স্থানটি বন্ধ। আগে সেটি আবার চালু করুন।';

  @override
  String placeDeleteTitle(String name) {
    return '$name মুছে ফেলবেন?';
  }

  @override
  String get placeDeleteBody =>
      'শুধু ভুল করে যোগ করা স্থানই মুছে ফেলুন। এটি আর ফেরানো যাবে না। কোনো ব্যক্তি বা রেকর্ড যে স্থান ব্যবহার করে তা মুছে ফেলা যায় না: সেটি বরং বন্ধ করুন।';

  @override
  String get placeDeleteButton => 'স্থান মুছে ফেলুন';

  @override
  String placeDeletedDone(String name) {
    return '$name মুছে ফেলা হয়েছে।';
  }

  @override
  String get placeErrorInUse =>
      'এই স্থানটি ব্যবহার হচ্ছে, তাই মুছে ফেলা যাবে না। বরং এটি বন্ধ করুন: তখন এটি আর বাছার জন্য দেখানো হবে না, আর এর রেকর্ড রাখা থাকবে।';

  @override
  String get placeCloseInstead => 'বরং বন্ধ করুন';

  @override
  String get importTitle => 'স্প্রেডশিট থেকে আনুন';

  @override
  String get importSummary =>
      'একটি স্প্রেডশিট থেকে একসাথে অনেক স্থান যোগ করুন। যে স্থানগুলো আগে থেকেই আছে সেগুলো রাখা হবে, কখনো দুবার যোগ হবে না।';

  @override
  String importStep(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'ধাপ $numberString';
  }

  @override
  String get importStepFile => 'আপনার স্প্রেডশিট তৈরি করুন';

  @override
  String get importRuleRows =>
      'প্রতিটি স্থানের জন্য একটি সারি। নামগুলো আলাদা আলাদা কলামে, ওপরের স্তর থেকে নিচে লিখুন: যেমন অঞ্চল, এলাকা, শাখা।';

  @override
  String get importRuleHeader => 'প্রথম সারিতে কলামের নাম থাকবে।';

  @override
  String get importRuleCode =>
      'কোনো স্থানকে কোড দিতে চাইলে শেষে ‘code’ নামে একটি কলাম যোগ করুন। কোডটি সারির শেষ স্থানের হবে।';

  @override
  String get importRuleEmpty =>
      'সারির শেষের দিকের ঘর খালি থাকলে অসুবিধা নেই: সেই সারি ওপরের কোনো স্তরেই শেষ হবে।';

  @override
  String get importRuleReuse =>
      'যে স্থানগুলো আগে থেকেই আছে (একই স্তরে একই নাম) সেগুলোই ব্যবহার হবে, তাই একই ফাইল আবার আনলেও সমস্যা নেই।';

  @override
  String get importRuleBangla => 'বাংলা নাম দিতে পারেন।';

  @override
  String get importRuleSave =>
      'ফাইলটি ‘CSV UTF-8’ হিসেবে সংরক্ষণ করুন। এক্সেলে: File › Save As › CSV UTF-8। গুগল শিটসে: File › Download › Comma-separated values (.csv)।';

  @override
  String get importRuleLimits =>
      'সর্বোচ্চ ৫,০০০ সারি, আর প্রতি সারিতে সর্বোচ্চ ১০টি স্তর।';

  @override
  String get importExample => 'উদাহরণ';

  @override
  String get importExampleRegion => 'অঞ্চল';

  @override
  String get importExampleArea => 'এলাকা';

  @override
  String get importExampleBranch => 'শাখা';

  @override
  String get importExampleRegion1 => 'ঢাকা অঞ্চল';

  @override
  String get importExampleArea1 => 'মিরপুর এলাকা';

  @override
  String get importExampleBranch1 => 'মিরপুর-১০ শাখা';

  @override
  String get importExampleBranch2 => 'পল্লবী শাখা';

  @override
  String get importExampleRegion2 => 'খুলনা অঞ্চল';

  @override
  String get importExampleArea2 => 'সোনাডাঙ্গা এলাকা';

  @override
  String get importStepParent => 'নতুন স্থানগুলো কোথায় যাবে তা বাছুন';

  @override
  String get importParent => 'নতুন স্থানগুলো যার ভেতরে যাবে';

  @override
  String get importParentHelp =>
      'প্রথম কলামের স্থানগুলো সরাসরি এই স্থানের ভেতরে যাবে।';

  @override
  String get importStepChoose => 'ফাইলটি বাছুন';

  @override
  String get importChoose => 'CSV ফাইল বাছুন';

  @override
  String get importChooseAnother => 'অন্য ফাইল বাছুন';

  @override
  String importFileName(String name) {
    return 'ফাইল: $name';
  }

  @override
  String importRowCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'স্থানের $countStringটি সারি',
      one: 'স্থানের ১টি সারি',
    );
    return '$_temp0';
  }

  @override
  String get importHeader => 'প্রথম সারিতে কলামের নাম আছে';

  @override
  String get importHeaderHelp =>
      'প্রথম সারিটি যদি একটি স্থান হয়, তাহলে এটি বন্ধ করুন।';

  @override
  String importColumns(String names) {
    return 'কলামের নাম: $names';
  }

  @override
  String importCodeColumn(String name) {
    return '‘$name’ কলাম থেকে কোড নেওয়া হচ্ছে।';
  }

  @override
  String get importErrorTooBig =>
      'ফাইলটি অনেক বড়। স্থানের তালিকা সর্বোচ্চ ৫ এমবি হতে পারে।';

  @override
  String get importErrorExcel =>
      'এটি একটি এক্সেল ফাইল। আগে এটি ‘CSV UTF-8’ হিসেবে সংরক্ষণ করুন, তারপর CSV ফাইলটি বাছুন।';

  @override
  String get importErrorNotUtf8 =>
      'ফাইলটি CSV UTF-8 হিসেবে সংরক্ষিত নয়, তাই বাংলা ও আরও কিছু অক্ষর হারিয়ে যেত। ফাইলটি আবার ‘CSV UTF-8’ হিসেবে সংরক্ষণ করে আবার বাছুন।';

  @override
  String importErrorQuote(int line) {
    final intl.NumberFormat lineNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String lineString = lineNumberFormat.format(line);

    return '$lineString নম্বর লাইনে একটি ঘর উদ্ধৃতিচিহ্ন (\") দিয়ে শুরু হয়েছে, কিন্তু তা আর শেষ হয়নি। লাইনটি দেখে ফাইলটি আবার সংরক্ষণ করুন, তারপর আবার বাছুন।';
  }

  @override
  String get importErrorEmpty => 'এই ফাইলে কোনো স্থান নেই।';

  @override
  String get importErrorOnlyHeader =>
      'এই ফাইলে কলামের নাম আছে, কিন্তু তার নিচে কোনো স্থান নেই। প্রথম সারিটি যদি একটি স্থান হয়, তাহলে ‘প্রথম সারিতে কলামের নাম আছে’ বন্ধ করুন।';

  @override
  String importErrorTooMany(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'এই ফাইলে স্থানের $countStringটি সারি আছে। একটি ফাইলে সর্বোচ্চ ৫,০০০টি থাকতে পারে। ফাইলটি ছোট ছোট ফাইলে ভাগ করে একটির পর একটি আনুন।';
  }

  @override
  String get importRowNoName => 'এই সারিতে কোড আছে, কিন্তু স্থানের নাম নেই।';

  @override
  String importRowGap(String column) {
    return '$column কলামের ঘরটি খালি, কিন্তু তার পরে একটি নাম আছে। ঘরটি পূরণ করুন, অথবা নামগুলো বাঁ দিকে সরান।';
  }

  @override
  String get importRowTooDeep => 'এই সারিতে ১০টির বেশি স্তর আছে।';

  @override
  String get importRowNameTooLong =>
      'এই সারির একটি নাম ২০০ অক্ষরের চেয়ে লম্বা।';

  @override
  String get importRowCodeTooLong => 'এই সারির কোড ৫০ অক্ষরের চেয়ে লম্বা।';

  @override
  String get importStepCheck => 'কী যোগ হবে তা দেখে নিন';

  @override
  String get importChecking => 'ফাইলটি যাচাই করা হচ্ছে…';

  @override
  String importNewCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি নতুন স্থান',
      one: '১টি নতুন স্থান',
      zero: 'কোনো নতুন স্থান নেই',
    );
    return '$_temp0';
  }

  @override
  String importExistingCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি আগে থেকেই আছে',
      one: '১টি আগে থেকেই আছে',
      zero: 'আগে থেকে কোনোটি নেই',
    );
    return '$_temp0';
  }

  @override
  String importProblems(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি সমস্যা ঠিক করতে হবে',
      one: '১টি সমস্যা ঠিক করতে হবে',
    );
    return '$_temp0';
  }

  @override
  String get importProblemsHelp =>
      'সব সমস্যা ঠিক না হওয়া পর্যন্ত কিছুই যোগ হবে না। আপনার স্প্রেডশিটে সেগুলো ঠিক করুন, আবার ‘CSV UTF-8’ হিসেবে সংরক্ষণ করুন, তারপর আবার বাছুন।';

  @override
  String importLine(int line) {
    final intl.NumberFormat lineNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String lineString = lineNumberFormat.format(line);

    return 'লাইন $lineString';
  }

  @override
  String get importNothingNew =>
      'এই ফাইলের সব স্থান আগে থেকেই আছে, তাই নতুন কিছু যোগ করার নেই।';

  @override
  String get importPreview => 'স্থানগুলো যেভাবে দেখাবে';

  @override
  String get importNew => 'নতুন';

  @override
  String get importAlready => 'আগে থেকেই আছে';

  @override
  String importAdd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি স্থান যোগ করুন',
      one: '১টি স্থান যোগ করুন',
    );
    return '$_temp0';
  }

  @override
  String get importAdding => 'স্থান যোগ হচ্ছে…';

  @override
  String importDone(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি স্থান যোগ হয়েছে।',
      one: '১টি স্থান যোগ হয়েছে।',
    );
    return '$_temp0';
  }

  @override
  String get importChanged =>
      'যাচাইয়ের পরে কিছু বদলেছে, তাই কিছুই যোগ হয়নি। নিচের সমস্যাগুলো ঠিক করুন, তারপর ফাইলটি আবার বাছুন।';

  @override
  String get leaveImportTitle => 'স্থান যোগ না করেই চলে যাবেন?';

  @override
  String get leaveImportBody => 'আপনার বাছা ফাইলের স্থানগুলো এখনও যোগ হয়নি।';

  @override
  String get leaveImportLeave => 'চলে যান';

  @override
  String get personPlaceClosedHelp =>
      'এই স্থানটি বন্ধ। এই ব্যক্তি অন্য কোথাও গেলে একটি চালু স্থান বাছুন।';

  @override
  String importServerClosed(String name) {
    return '‘$name’ বন্ধ। আগে এটি আবার চালু করুন, অথবা এই সারিটি মুছে দিন।';
  }

  @override
  String importServerCodeOther(String name, String code) {
    return '‘$name’-এর কোড আগে থেকেই $code। একই কোড দিন, অথবা ঘরটি খালি রাখুন।';
  }

  @override
  String importServerCodeTwice(String code) {
    return 'এই ফাইলে $code কোডটি একাধিকবার ব্যবহার হয়েছে। প্রতিটি স্থানের কোড আলাদা হতে হবে।';
  }

  @override
  String importServerCodeTaken(String code) {
    return 'অন্য একটি স্থানের কোড আগে থেকেই $code। অন্য একটি কোড বেছে নিন।';
  }

  @override
  String get importProblemNoName => 'এই সারিতে কোনো স্থানের নাম নেই।';

  @override
  String importProblemTooDeep(int limit) {
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'এই সারিতে $limitStringটির বেশি স্তর আছে।';
  }

  @override
  String get placeErrorNameUnsafe =>
      'নামে একটি লাইন ব্রেক বা লুকানো বিশেষ চিহ্ন আছে। নামটি আবার টাইপ করুন।';

  @override
  String get placeErrorCodeUnsafe =>
      'কোডে একটি লাইন ব্রেক বা লুকানো বিশেষ চিহ্ন আছে। কোডটি আবার টাইপ করুন।';

  @override
  String importServerUnsafeName(String name) {
    return '‘$name’ নামে একটি লাইন ব্রেক বা লুকানো বিশেষ চিহ্ন আছে।';
  }

  @override
  String importServerUnsafeCode(String code) {
    return '$code কোডে একটি লাইন ব্রেক বা লুকানো বিশেষ চিহ্ন আছে।';
  }

  @override
  String get navDevices => 'ডিভাইস';

  @override
  String get navMyDevices => 'আমার ডিভাইস';

  @override
  String get problemSessionOtherDevice =>
      'এই সেশনটি অন্য একটি ডিভাইসের। এই ডিভাইসে আবার সাইন ইন করুন।';

  @override
  String get problemDeviceNotSetUp =>
      'এই ডিভাইসটি এখনও এই সার্ভারের জন্য প্রস্তুত করা হয়নি। এই ডিভাইসে আবার সাইন ইন করুন।';

  @override
  String get problemDeviceCheckFailed =>
      'সার্ভার এই ডিভাইসটি যাচাই করতে পারেনি। আবার চেষ্টা করুন। বারবার হলে সাইন আউট করে আবার সাইন ইন করুন।';

  @override
  String get problemDeviceClock =>
      'এই কম্পিউটারের তারিখ বা সময় ভুল। সঠিক তারিখ, সময় ও টাইম জোন ঠিক করে আবার চেষ্টা করুন।';

  @override
  String get problemDeviceNotApproved => 'এই ডিভাইসটি অনুমোদনের অপেক্ষায় আছে।';

  @override
  String get problemDeviceRevoked =>
      'অভিযাত্রার জন্য এই ডিভাইসটি বন্ধ করে দেওয়া হয়েছে।';

  @override
  String get problemDeviceExpired =>
      'এই ডিভাইসের অনুমোদনের মেয়াদ শেষ হয়ে গেছে। আবার অনুমোদন দিতে সংস্থার একজন অ্যাডমিনকে বলুন।';

  @override
  String get problemDeviceKeysUnavailable =>
      'এই কম্পিউটার বা ব্রাউজার ডিভাইসের নিরাপত্তা চাবি রাখতে পারেনি। এটি প্রাইভেট উইন্ডো হলে একটি সাধারণ উইন্ডো খুলে আবার চেষ্টা করুন।';

  @override
  String get problemDeviceKeyInUse =>
      'এই ডিভাইসের চাবি আগে থেকেই ব্যবহৃত হচ্ছে। ডিভাইসটি আবার প্রস্তুত করুন।';

  @override
  String get problemTooManyWaitingDevices =>
      'আপনার তিনটি ডিভাইস আগে থেকেই অনুমোদনের অপেক্ষায় আছে। সেগুলো অনুমোদন করতে বা বন্ধ করতে সংস্থার একজন অ্যাডমিনকে বলুন, তারপর আবার চেষ্টা করুন।';

  @override
  String get problemDeviceCodeMismatch =>
      'এই নম্বরগুলো এই ডিভাইসের সাথে মেলে না। ব্যক্তির সাথে আবার মিলিয়ে দেখুন।';

  @override
  String get problemDeviceNotWaiting =>
      'এই ডিভাইসটি আর আপনার অনুমোদনের অপেক্ষায় নেই। এটি হয়তো আগেই অনুমোদিত হয়েছে, অথবা অন্য একজন অ্যাডমিনের অনুমোদন দরকার। তালিকাটি আবার লোড করুন।';

  @override
  String get deviceChecking => 'এই ডিভাইসটি যাচাই করা হচ্ছে…';

  @override
  String deviceSignedInAs(String name) {
    return '$name হিসেবে সাইন ইন করা আছে';
  }

  @override
  String get deviceWaitingTitle => 'অনুমোদনের অপেক্ষায়';

  @override
  String get deviceWaitingIntro =>
      'এখানে অভিযাত্রা ব্যবহারের আগে কাউকে যাচাই করতে হবে যে এই ডিভাইসটি সত্যিই আপনার।';

  @override
  String get deviceRenewTitle => 'আপনার অনুমোদনের মেয়াদ শেষ';

  @override
  String get deviceRenewIntro =>
      'অনুমোদন এক বছর থাকে। এখানে অভিযাত্রা ব্যবহার চালিয়ে যেতে কাউকে আবার এই ডিভাইসটি যাচাই করতে হবে।';

  @override
  String get deviceCodeLabel => 'এই ডিভাইসের নম্বর';

  @override
  String deviceThisDevice(String label) {
    return 'এই ডিভাইস: $label';
  }

  @override
  String get deviceWhoStaff =>
      'এই নম্বরগুলো সংস্থার একজন অ্যাডমিনকে দেখান, সামনাসামনি বা ফোনে। এই ডিভাইস অনুমোদন করতে তিনি নম্বরগুলো তাঁর ম্যানেজার অ্যাপে টাইপ করবেন।';

  @override
  String get deviceWhoAdmin =>
      'আপনি সংস্থার একজন অ্যাডমিন, তাই অন্য দুজন অ্যাডমিনকে আলাদাভাবে এই নম্বরগুলো যাচাই করে ডিভাইসটি অনুমোদন করতে হবে, সামনাসামনি বা ফোনে।';

  @override
  String get deviceWhoAdminSecond =>
      'সংস্থার একজন অ্যাডমিন এটি অনুমোদন করেছেন। আরেকজন, ভিন্ন একজন অ্যাডমিনকেও এটি অনুমোদন করতে হবে।';

  @override
  String get deviceFirstAdminTitle => 'আপনি কি সংস্থার প্রথম অ্যাডমিন?';

  @override
  String get deviceFirstAdminBody =>
      'তাহলে এখনও কেউ অ্যাপে আপনাকে অনুমোদন দিতে পারবেন না। যিনি সার্ভার চালান, তিনি সার্ভারে এই কমান্ডটি টাইপ করবেন, কোণ-বন্ধনীর লেখার জায়গায় এই ডিভাইসের ১৮টি নম্বর বসিয়ে। নম্বরগুলো তাঁকে নিজে এই স্ক্রিন থেকে পড়তে হবে, সামনাসামনি বা ফোনে। নম্বরগুলো কখনো মেসেজে পাঠাবেন না।';

  @override
  String get deviceNoMessages =>
      'আপনার অনুমোদনকারী টেক্সট মেসেজ, ইমেইল বা চ্যাটে পাঠানো নম্বর গ্রহণ করবেন না: নম্বরগুলো পড়ে শোনান বা স্ক্রিন দেখান।';

  @override
  String get deviceAutoCheck =>
      'এই পাতাটি প্রতি ১৫ সেকেন্ডে দেখে, এবং ডিভাইস অনুমোদিত হলেই অভিযাত্রা খুলে যায়।';

  @override
  String get deviceCheckAgain => 'আবার দেখুন';

  @override
  String get deviceCheckingNow => 'দেখা হচ্ছে…';

  @override
  String get deviceRevokedTitle => 'এই ডিভাইসটি বন্ধ করা হয়েছে';

  @override
  String get deviceRevokedBody =>
      'কেউ অভিযাত্রার জন্য এই ডিভাইসটি বন্ধ করেছেন, যেমন হারিয়ে গেছে বলে জানানো হলে। এখানে আবার অভিযাত্রা ব্যবহার করতে এটিকে নতুন ডিভাইস হিসেবে প্রস্তুত করুন। তারপর কাউকে এটি অনুমোদন করতে হবে।';

  @override
  String get deviceSetUpAgain => 'ডিভাইসটি আবার প্রস্তুত করুন';

  @override
  String get deviceSetUpAgainTitle => 'ডিভাইসটি আবার প্রস্তুত করবেন?';

  @override
  String get deviceSetUpAgainBody =>
      'এতে এই ডিভাইসের জন্য নতুন নিরাপত্তা চাবি তৈরি হবে। কেউ অনুমোদন না দেওয়া পর্যন্ত আপনি এখানে অভিযাত্রা ব্যবহার করতে পারবেন না।';

  @override
  String get deviceSetUpAgainConfirm => 'আবার প্রস্তুত করুন';

  @override
  String get deviceNotRecognisedTitle => 'এই ডিভাইসটি যাচাই করা যায়নি';

  @override
  String get deviceNotRecognisedBody =>
      'সার্ভার এই ডিভাইসের চাবি চিনতে পারছে না। সার্ভার নতুন করে প্রস্তুত করা হলে এমন হতে পারে। আবার দেখুন; তাতে কাজ না হলে ডিভাইসটি আবার প্রস্তুত করুন।';

  @override
  String get deviceClockTitle => 'এই কম্পিউটারের তারিখ ও সময় দেখুন';

  @override
  String get deviceClockBody =>
      'এই কম্পিউটারের ঘড়ি সার্ভারের ঘড়ি থেকে ৫ মিনিটের বেশি আলাদা। সঠিক তারিখ, সময় ও টাইম জোন ঠিক করে আবার দেখুন।';

  @override
  String get deviceUpdateBrowserTitle =>
      'অনুগ্রহ করে আপনার ব্রাউজার হালনাগাদ করুন';

  @override
  String get deviceUpdateBrowserBody =>
      'এই ব্রাউজার অভিযাত্রার নিরাপত্তা চাবি নিরাপদে রাখতে পারে না। একটি হালনাগাদ ব্রাউজার ব্যবহার করুন: ক্রোম বা এজ ১৩৭ বা পরের সংস্করণ, ফায়ারফক্স ১৩০ বা পরের সংস্করণ, অথবা সাফারি ১৭ বা পরের সংস্করণ। আপনি অভিযাত্রার ডেস্কটপ অ্যাপও ব্যবহার করতে পারেন।';

  @override
  String get deviceSecureAddressTitle => 'নিরাপদ ঠিকানাটি খুলুন';

  @override
  String get deviceSecureAddressBody =>
      'ব্রাউজার শুধু নিরাপদ ঠিকানায় (https:// দিয়ে শুরু) খোলা পাতার জন্য নিরাপত্তা চাবি রাখে। ম্যানেজারের https ঠিকানা আপনার সংস্থার অ্যাডমিনের কাছে চেয়ে নিন।';

  @override
  String get devicesSummaryAdmin =>
      'নতুন কম্পিউটার, ব্রাউজার ও ফোন অনুমোদন করুন, এবং হারানো ডিভাইস বন্ধ করুন।';

  @override
  String get devicesSummaryBranch =>
      'সংস্থায় আপনার অংশের মাঠকর্মীদের ফোন অনুমোদন করুন, এবং হারানো ফোন বন্ধ করুন।';

  @override
  String get devicesSummaryMine =>
      'যেসব কম্পিউটার ও ব্রাউজারে আপনি অভিযাত্রা ব্যবহার করেন। কোনোটি হারালে সেটি বন্ধ করুন।';

  @override
  String get devicesTabOthers => 'অন্যদের ডিভাইস';

  @override
  String get devicesTabsLabel => 'কার ডিভাইস';

  @override
  String get devicesWaiting => 'অনুমোদনের অপেক্ষায়';

  @override
  String get devicesApproved => 'অনুমোদিত';

  @override
  String get devicesSwitchedOff => 'বন্ধ';

  @override
  String get devicesWaitingNone => 'অনুমোদনের অপেক্ষায় কোনো ডিভাইস নেই।';

  @override
  String get devicesEmptyTitle => 'এখনও কোনো ডিভাইস নেই';

  @override
  String get devicesEmptyBody =>
      'কেউ নতুন কম্পিউটার, ব্রাউজার বা ফোনে সাইন ইন করলে সেটি অনুমোদনের জন্য এখানে দেখা যাবে।';

  @override
  String get devicesMineEmptyBody =>
      'আপনি যেসব ডিভাইসে সাইন ইন করেন সেগুলো এখানে দেখা যাবে।';

  @override
  String deviceAdded(String date) {
    return 'যোগ হয়েছে $date';
  }

  @override
  String deviceApprovedUntil(String date) {
    return '$date পর্যন্ত অনুমোদিত';
  }

  @override
  String deviceApprovalRanOut(String date) {
    return 'অনুমোদনের মেয়াদ শেষ হয়েছে $date';
  }

  @override
  String get deviceStatusWaiting => 'অপেক্ষায়';

  @override
  String get deviceStatusApproved => 'অনুমোদিত';

  @override
  String get deviceStatusOff => 'বন্ধ';

  @override
  String get deviceStatusRanOut => 'মেয়াদ শেষ';

  @override
  String get deviceNeedsSecond => 'দ্বিতীয় অনুমোদন দরকার';

  @override
  String get deviceThisOne => 'এই ডিভাইস';

  @override
  String get deviceYouApprovedFirst =>
      'আপনি একবার অনুমোদন করেছেন। ভিন্ন একজন অ্যাডমিনকেও এটি অনুমোদন করতে হবে।';

  @override
  String get deviceSwitchOff => 'বন্ধ করুন';

  @override
  String get platformWeb => 'ওয়েব ব্রাউজার';

  @override
  String get platformWindows => 'উইন্ডোজ কম্পিউটার';

  @override
  String get platformMac => 'ম্যাক';

  @override
  String get platformLinux => 'লিনাক্স কম্পিউটার';

  @override
  String get platformAndroid => 'অ্যান্ড্রয়েড ফোন';

  @override
  String get platformIos => 'আইফোন বা আইপ্যাড';

  @override
  String approveTitle(String name) {
    return '$name-এর ডিভাইস অনুমোদন';
  }

  @override
  String approveHow(String name) {
    return '$name-কে তাঁর নিজের স্ক্রিনে থাকা ১৮টি নম্বর পড়ে শোনাতে বলুন, সামনাসামনি বা আপনার চেনা কারও সাথে ফোনে। টেক্সট মেসেজ, ইমেইল বা চ্যাটে পাঠানো নম্বর কখনো গ্রহণ করবেন না।';
  }

  @override
  String get approveCodeLabel => '১৮টি নম্বর';

  @override
  String get approveCodeHelp =>
      'যেভাবে শুনছেন সেভাবে টাইপ করুন। বাংলা বা ইংরেজি, দুই ধরনের অঙ্কই চলবে।';

  @override
  String get approveCodeIncomplete => '১৮টি নম্বরই টাইপ করুন।';

  @override
  String approveMismatch(String name) {
    return 'এই নম্বরগুলো এই ডিভাইসের সাথে মেলে না। $name-এর সাথে আবার মিলিয়ে দেখুন। তারপরও না মিললে অনুমোদন করবেন না: অন্য কেউ ঢোকার চেষ্টা করতে পারে।';
  }

  @override
  String approveUnreadable(String name) {
    return 'এই ডিভাইসের তথ্য পড়া যাচ্ছে না, তাই এটি অনুমোদন করা যাবে না। $name-কে ডিভাইসটি আবার প্রস্তুত করতে বলুন।';
  }

  @override
  String get approveAdminDevice =>
      'এটি সংস্থার একজন অ্যাডমিনের ডিভাইস। কাজ শুরুর আগে আরেকজন অ্যাডমিনকেও এটি অনুমোদন করতে হবে।';

  @override
  String get approveAdminSecond =>
      'আরেকজন অ্যাডমিন এটি একবার অনুমোদন করেছেন। আপনারটি হবে দ্বিতীয় অনুমোদন।';

  @override
  String get approveRenewal =>
      'এই ডিভাইসের অনুমোদনের মেয়াদ শেষ। আবার অনুমোদন করলে এটি আরও এক বছর কাজ করবে।';

  @override
  String get approveButton => 'ডিভাইস অনুমোদন করুন';

  @override
  String get approveWorking => 'অনুমোদন করা হচ্ছে…';

  @override
  String approveDone(String name) {
    return '$name এখন এই ডিভাইসে অভিযাত্রা ব্যবহার করতে পারবেন।';
  }

  @override
  String approveDoneFirst(String name) {
    return 'আপনি একবার অনুমোদন করেছেন। কাজ শুরুর আগে ভিন্ন আরেকজন অ্যাডমিনকেও $name-এর সাথে ১৮টি নম্বর মিলিয়ে এটি অনুমোদন করতে হবে।';
  }

  @override
  String get switchOffTitle => 'ডিভাইসটি বন্ধ করবেন?';

  @override
  String switchOffBody(String name, String device) {
    return '$name-এর $device অভিযাত্রার জন্য সঙ্গে সঙ্গে কাজ করা বন্ধ করবে, আর যিনি এটি ব্যবহার করছেন তিনি তখনই সাইন আউট হয়ে যাবেন। আবার ব্যবহার করতে হলে এটি নতুন করে প্রস্তুত ও অনুমোদন করতে হবে।';
  }

  @override
  String switchOffMine(String device) {
    return 'আপনার $device হারিয়ে গেলে বা আর ব্যবহার না করলে এটি ব্যবহার করুন। এটি সঙ্গে সঙ্গে অভিযাত্রার জন্য কাজ করা বন্ধ করবে, আর যিনি এটি ব্যবহার করছেন তিনি তখনই সাইন আউট হবেন।';
  }

  @override
  String get switchOffCurrent =>
      'এটিই সেই ডিভাইস যা আপনি এখন ব্যবহার করছেন। আপনি সঙ্গে সঙ্গে সাইন আউট হবেন, এবং চালিয়ে যেতে ডিভাইসটি আবার প্রস্তুত ও অনুমোদন করাতে হবে।';

  @override
  String get switchOffWorking => 'বন্ধ করা হচ্ছে…';

  @override
  String get switchOffDone => 'ডিভাইস বন্ধ করা হয়েছে।';

  @override
  String get actionDone => 'হয়ে গেছে';

  @override
  String get approveDoneTitle => 'ডিভাইস অনুমোদিত';

  @override
  String approveDoneUntil(String date) {
    return '$date পর্যন্ত অনুমোদিত';
  }

  @override
  String get approveDoneFirstTitle => 'আরও একজন অ্যাডমিনের অনুমোদন দরকার';

  @override
  String deviceLastChecked(String time) {
    return 'শেষবার দেখা হয়েছে $time-এ।';
  }

  @override
  String get problemDeviceUnknown =>
      'সার্ভার এই ডিভাইসটি আর চেনে না। এটি আবার প্রস্তুত করা হচ্ছে, এবং আবার অনুমোদন লাগবে।';

  @override
  String get deviceServerForgot =>
      'সার্ভার এই ডিভাইসটি আর চিনত না, তাই এটির আবার অনুমোদন দরকার।';

  @override
  String get deviceCommandPlaceholder => 'এই স্ক্রিনের ১৮টি নম্বর';

  @override
  String deviceIdLine(String id) {
    return 'এই ডিভাইসের আইডি: $id';
  }

  @override
  String get deviceIdCopy => 'ডিভাইসের আইডি কপি করুন';

  @override
  String get deviceIdCopied => 'ডিভাইসের আইডি কপি হয়েছে।';

  @override
  String get actionDownload => 'ডাউনলোড';

  @override
  String get actionStop => 'থামান';

  @override
  String get downloadTitle => 'জমা পড়া তথ্য ডাউনলোড';

  @override
  String get downloadIntro =>
      'আপনি একটি জিপ ফাইল পাবেন: উত্তরগুলো স্প্রেডশিট (CSV) হিসেবে, প্রতিটি জমা যেমন এসেছিল তেমন, আর ফর্মটি।';

  @override
  String get downloadNoForms => 'ডাউনলোড করার মতো কোনো ফর্ম এখনও নেই।';

  @override
  String get downloadFirstDay => 'যেদিন থেকে';

  @override
  String get downloadLastDay => 'যেদিন পর্যন্ত (এই দিনসহ)';

  @override
  String get downloadAnyDay => 'যেকোনো দিন';

  @override
  String get downloadClearDay => 'তারিখ মুছুন';

  @override
  String get downloadDaysHelp =>
      'দিনগুলো এই কম্পিউটারের টাইম জোন অনুযায়ী। সব জমা ডাউনলোড করতে দুটোই “যেকোনো দিন” রাখুন।';

  @override
  String get downloadDaysWrong => 'শেষ দিনটি প্রথম দিনের সমান বা পরে হতে হবে।';

  @override
  String get downloadStates => 'পর্যালোচনার অবস্থা';

  @override
  String get downloadStatesNone => 'অন্তত একটি পর্যালোচনার অবস্থা বেছে নিন।';

  @override
  String get downloadMedia => 'ছবি ও অন্যান্য ফাইলও নিন';

  @override
  String get downloadMediaNote => 'এতে ডাউনলোড বড় হয়।';

  @override
  String get downloadPersonalData =>
      'এই ফাইলে ব্যক্তিগত তথ্য আছে। এটি নিরাপদ কম্পিউটারে রাখুন, শুধু যাঁদের দরকার তাঁদের সাথে শেয়ার করুন, আর দরকার শেষ হলে মুছে ফেলুন।';

  @override
  String get downloadBrowserMemory =>
      'ওয়েব ব্রাউজারে পুরো ফাইলটি সেভ হওয়া পর্যন্ত মেমোরিতে থাকে। ছবিসহ খুব বড় ডাউনলোডের জন্য ডেস্কটপ অ্যাপ ব্যবহার করুন, অথবা ছবি বাদ দিন।';

  @override
  String get downloadPreparing => 'সার্ভার ফাইলটি তৈরি করছে…';

  @override
  String downloadReceived(String size) {
    return '$size এসেছে';
  }

  @override
  String get downloadDoneTitle => 'ডাউনলোড শেষ';

  @override
  String downloadSaved(String name) {
    return '$name নামে সেভ হয়েছে।';
  }

  @override
  String downloadSavedBrowser(String name) {
    return 'আপনার ব্রাউজার $name তার ডাউনলোড ফোল্ডারে সেভ করছে।';
  }

  @override
  String get downloadDoneReminder =>
      'এতে ব্যক্তিগত তথ্য আছে: নিরাপদে রাখুন, আর দরকার শেষ হলে মুছে ফেলুন।';

  @override
  String get confirmTitle => 'নিশ্চিত করুন যে এটি আপনি';

  @override
  String get confirmIntro =>
      'তথ্য ডাউনলোড করতে গত ১৫ মিনিটের মধ্যে সাইন ইন থাকতে হয়। এটি আপনি তা নিশ্চিত করুন, তাহলে ডাউনলোড আবার শুরু হবে।';

  @override
  String get confirmPassword => 'আপনার পাসওয়ার্ড';

  @override
  String get confirmButton => 'নিশ্চিত করুন';

  @override
  String get confirmWorking => 'নিশ্চিত করা হচ্ছে…';

  @override
  String get confirmGoogle => 'গুগল দিয়ে নিশ্চিত করুন';

  @override
  String get confirmGoogleWaiting =>
      'যে ব্রাউজার ট্যাবটি খুলেছে সেখানে গুগল দিয়ে সাইন ইন শেষ করুন, তারপর এখানে ফিরে আসুন।';

  @override
  String confirmSms(String phone) {
    return '$phone নম্বরে কোড পাঠান';
  }

  @override
  String confirmSmsSent(String phone) {
    return '$phone নম্বরে কোড পাঠানো হয়েছে।';
  }

  @override
  String get confirmNoWay =>
      'নিশ্চিত করতে সাইন আউট করুন, আবার সাইন ইন করুন, তারপর আবার ডাউনলোড করুন।';

  @override
  String get problemRecentSignIn =>
      'তথ্য ডাউনলোড করতে নিশ্চিত করুন যে এটি আপনি: আপনার শেষ সাইন ইন ১৫ মিনিটের বেশি আগে হয়েছে।';

  @override
  String get problemExportNoVersion =>
      'এই ফর্মের এখনও কোনো সংস্করণ নেই, তাই ডাউনলোড করার কিছু নেই।';

  @override
  String get problemSaveFailed =>
      'ফাইলটি সেখানে সেভ করা যায়নি। আবার চেষ্টা করুন এবং অন্য একটি ফোল্ডার বেছে নিন।';

  @override
  String sizeKb(String size) {
    return '$size কেবি';
  }

  @override
  String sizeMb(String size) {
    return '$size এমবি';
  }

  @override
  String sizeGb(String size) {
    return '$size জিবি';
  }

  @override
  String get downloadChooseForm => 'একটি ফর্ম বেছে নিন।';

  @override
  String get problemDownloadIncomplete =>
      'ডাউনলোড পুরো হয়নি। আবার চেষ্টা করুন।';
}
