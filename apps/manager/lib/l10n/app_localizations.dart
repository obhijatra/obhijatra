import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// The app name shown in the browser tab and the app switcher.
  ///
  /// In en, this message translates to:
  /// **'Obhijatra Manager'**
  String get appTitle;

  /// Spoken name of the navigation menu, for screen readers.
  ///
  /// In en, this message translates to:
  /// **'Main menu'**
  String get navMain;

  /// Menu item: forms.
  ///
  /// In en, this message translates to:
  /// **'Forms'**
  String get navForms;

  /// Menu item: submissions (answers sent in from the field).
  ///
  /// In en, this message translates to:
  /// **'Submissions'**
  String get navSubmissions;

  /// Menu item: settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Menu item: about this app.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get navAbout;

  /// Small label in the top bar when the app runs in a web browser.
  ///
  /// In en, this message translates to:
  /// **'Web app'**
  String get badgeWebApp;

  /// Small label in the top bar when the app runs on Windows or macOS.
  ///
  /// In en, this message translates to:
  /// **'Desktop app'**
  String get badgeDesktopApp;

  /// Spoken name of the English/Bangla switch.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSwitch;

  /// Spoken name of the button that opens the account menu.
  ///
  /// In en, this message translates to:
  /// **'Account menu'**
  String get accountMenu;

  /// Menu item and button: sign out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get menuSignOut;

  /// Spoken and visible label while data loads.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// Banner title when the internet is not reachable.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get offlineTitle;

  /// Banner text when the internet is not reachable.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection. Your data will appear again when it is back.'**
  String get offlineBody;

  /// Button: try the same thing again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// Button: go back to the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get actionSignInAgain;

  /// Button: close a message or dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Button: pick a different file.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get actionChooseFile;

  /// Button: cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Shown when a name (collector, location) is not available.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownValue;

  /// Plain sentence for a network failure.
  ///
  /// In en, this message translates to:
  /// **'We can’t reach the server. Check your internet connection and try again.'**
  String get problemOffline;

  /// Plain sentence for a time-out.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to answer. Try again in a moment.'**
  String get problemTimeout;

  /// Plain sentence for HTTP 429.
  ///
  /// In en, this message translates to:
  /// **'The server is busy right now. Wait a minute, then try again.'**
  String get problemServerBusy;

  /// Plain sentence for HTTP 5xx.
  ///
  /// In en, this message translates to:
  /// **'The server had a problem. Try again. If it keeps happening, tell your organisation admin.'**
  String get problemServerError;

  /// Plain sentence for HTTP 401.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Sign in again to carry on.'**
  String get problemSignInRequired;

  /// Plain sentence for a failed sign-in.
  ///
  /// In en, this message translates to:
  /// **'The email or password is not right, or this account is switched off. Check them and try again.'**
  String get problemSignInFailed;

  /// Plain sentence for HTTP 403.
  ///
  /// In en, this message translates to:
  /// **'Your account is not allowed to do this. Ask your organisation admin if you need access.'**
  String get problemNotAllowed;

  /// Plain sentence for HTTP 404.
  ///
  /// In en, this message translates to:
  /// **'We could not find this. It may have been removed, or your account may not have access to it.'**
  String get problemNotFound;

  /// Plain sentence for HTTP 413 or a file over the limit.
  ///
  /// In en, this message translates to:
  /// **'This file is too big. Forms and submissions can be up to 10 MB.'**
  String get problemTooLarge;

  /// Plain sentence for HTTP 400.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept this. Check what you entered and try again.'**
  String get problemRejected;

  /// Plain sentence when a form version already exists.
  ///
  /// In en, this message translates to:
  /// **'This version of the form was already uploaded. Change the version number in your form tool, then upload the file again.'**
  String get problemVersionExists;

  /// Plain sentence when the server has no review comment field.
  ///
  /// In en, this message translates to:
  /// **'Your decision was saved, but this server can’t keep comments yet. Ask your organisation admin to update the server.'**
  String get problemCommentNotSaved;

  /// Plain sentence for a file that cannot be read.
  ///
  /// In en, this message translates to:
  /// **'We could not read this file. Check that it is an XForm (.xml) file and try again.'**
  String get problemUnreadableFile;

  /// Plain sentence when answers cannot be shown safely.
  ///
  /// In en, this message translates to:
  /// **'We could not load this form’s definition, so the answers are hidden to keep protected answers safe.'**
  String get problemFormUnavailable;

  /// Plain sentence for any other problem.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again. If it keeps happening, tell your organisation admin.'**
  String get problemUnknown;

  /// Heading of the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Intro under the sign-in heading.
  ///
  /// In en, this message translates to:
  /// **'Use the email and password your organisation admin gave you.'**
  String get signInIntro;

  /// Label of the email field.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get signInEmail;

  /// Label of the password field.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signInPassword;

  /// Spoken name of the button that shows the password.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get signInShowPassword;

  /// Spoken name of the button that hides the password.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get signInHidePassword;

  /// Label of the server address field (desktop app only).
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get signInServer;

  /// Help text under the server address field.
  ///
  /// In en, this message translates to:
  /// **'The web address of your organisation’s Obhijatra server, for example https://data.example.org'**
  String get signInServerHelp;

  /// Button: sign in.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// Button text while signing in.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signInWorking;

  /// Error under an empty required field.
  ///
  /// In en, this message translates to:
  /// **'Please fill this in.'**
  String get fieldRequired;

  /// Error under a wrong server address.
  ///
  /// In en, this message translates to:
  /// **'Enter a full web address that starts with http:// or https://'**
  String get serverInvalid;

  /// Page heading.
  ///
  /// In en, this message translates to:
  /// **'Forms'**
  String get formsTitle;

  /// Heading of the upload card and dialog.
  ///
  /// In en, this message translates to:
  /// **'Upload a form'**
  String get formsUploadTitle;

  /// Help text on the upload card.
  ///
  /// In en, this message translates to:
  /// **'Choose an XForm (.xml) file. Files made in Kobo or ODK work too.'**
  String get formsUploadHelp;

  /// Button: choose a file.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get formsChooseFile;

  /// Heading above the list of forms.
  ///
  /// In en, this message translates to:
  /// **'Your forms'**
  String get formsYourForms;

  /// Number of versions of a form.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 version} other{{count} versions}}'**
  String formsVersionCount(int count);

  /// Summary under a form that has a published version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}, published'**
  String formsPublishedSummary(String version);

  /// Summary under a form with no published version.
  ///
  /// In en, this message translates to:
  /// **'Draft, not published yet'**
  String get formsDraftSummary;

  /// Summary under a form with no versions you can see.
  ///
  /// In en, this message translates to:
  /// **'No versions yet'**
  String get formsNoVersions;

  /// Title when there are no forms.
  ///
  /// In en, this message translates to:
  /// **'No forms yet'**
  String get formsEmptyTitle;

  /// Text when there are no forms and you can upload.
  ///
  /// In en, this message translates to:
  /// **'Upload your first form to get started.'**
  String get formsEmptyBodyAdmin;

  /// Text when there are no forms and you cannot upload.
  ///
  /// In en, this message translates to:
  /// **'Your organisation admin has not published a form yet.'**
  String get formsEmptyBodyViewer;

  /// Text in the right panel when no form is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a form on the left to see its versions.'**
  String get formsSelectPrompt;

  /// Text in the right panel when a form but no version is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a version to see its checks.'**
  String get formsSelectVersion;

  /// Name of a version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// When a version was uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {date}'**
  String versionUploaded(String date);

  /// When a version was published.
  ///
  /// In en, this message translates to:
  /// **'Published {date}'**
  String versionPublished(String date);

  /// Badge on a published version.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get badgePublished;

  /// Badge on a version that is not published.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get badgeDraft;

  /// Badge on a draft that fails a check.
  ///
  /// In en, this message translates to:
  /// **'Needs a fix'**
  String get badgeNeedsFix;

  /// Heading of the version panel.
  ///
  /// In en, this message translates to:
  /// **'{form}, version {version}'**
  String versionHeading(String form, String version);

  /// Heading of the checks list for a draft.
  ///
  /// In en, this message translates to:
  /// **'Publish check'**
  String get publishCheckTitle;

  /// Heading of the checks list for a published version.
  ///
  /// In en, this message translates to:
  /// **'Form check'**
  String get formCheckTitle;

  /// Sentence about how many questions were checked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{We found no questions.} =1{We checked 1 question.} other{We checked {count} questions.}}'**
  String publishCheckedQuestions(int count);

  /// Sentence about how many problems must be fixed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Fix 1 thing before you publish.} other{Fix {count} things before you publish.}}'**
  String publishFixCount(int count);

  /// Sentence when all checks pass.
  ///
  /// In en, this message translates to:
  /// **'Nothing to fix. You can publish this version.'**
  String get publishAllClear;

  /// Label above a check that must be fixed.
  ///
  /// In en, this message translates to:
  /// **'Fix before publishing'**
  String get checkKindFix;

  /// Label above the list of protected answers.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get checkKindProtected;

  /// Label above a check that passed.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get checkKindPassed;

  /// Label above a note that does not block publishing.
  ///
  /// In en, this message translates to:
  /// **'Good to know'**
  String get checkKindNote;

  /// Check: the XML is not well formed.
  ///
  /// In en, this message translates to:
  /// **'This file can’t be read as a form. It may be damaged. Export it again from your form tool and upload the new file.'**
  String get checkUnreadable;

  /// Check: the XML is not an XForm.
  ///
  /// In en, this message translates to:
  /// **'This file is XML, but it is not an XForm. Upload the XForm (.xml) file exported from your form tool.'**
  String get checkNotXForm;

  /// Check passed: the XML is well formed.
  ///
  /// In en, this message translates to:
  /// **'The file is a readable form.'**
  String get checkWellFormed;

  /// Check: no version.
  ///
  /// In en, this message translates to:
  /// **'The form has no version number. Add a version in your form tool, export it again and upload the new file.'**
  String get checkVersionMissing;

  /// Check passed: version present.
  ///
  /// In en, this message translates to:
  /// **'The form has a version number: {version}.'**
  String checkVersionOk(String version);

  /// Check: no form id.
  ///
  /// In en, this message translates to:
  /// **'The form has no form id. Set a form id in your form tool, export it again and upload the new file.'**
  String get checkFormIdMissing;

  /// Check passed: form id present.
  ///
  /// In en, this message translates to:
  /// **'The form has a form id: {formId}.'**
  String checkFormIdOk(String formId);

  /// Check: this version already exists.
  ///
  /// In en, this message translates to:
  /// **'Version {version} of this form was already uploaded. Change the version number in your form tool and upload the file again.'**
  String checkVersionExists(String version);

  /// Check: Kobo question matrix is not supported.
  ///
  /// In en, this message translates to:
  /// **'Kobo ‘question matrix’ isn’t supported — use one ‘select one’ question per row instead.'**
  String get checkKoboMatrix;

  /// Check: Kobo rating questions are not supported.
  ///
  /// In en, this message translates to:
  /// **'Kobo ‘rating’ questions aren’t supported — use one ‘select one’ question per item instead.'**
  String get checkKoboScore;

  /// Check: Kobo ranking questions are not supported.
  ///
  /// In en, this message translates to:
  /// **'Kobo ‘ranking’ questions aren’t supported — use ‘select one’ questions such as ‘first choice’ and ‘second choice’ instead.'**
  String get checkKoboRank;

  /// Where a problem was found.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Question: {names}} other{Questions: {names}}}'**
  String checkWhere(int count, String names);

  /// Check: the answers marked as protected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 answer will be protected: {names}.} other{{count} answers will be protected: {names}.}}'**
  String checkProtectedList(int count, String names);

  /// Check passed: labels in two languages.
  ///
  /// In en, this message translates to:
  /// **'Every question has a label in both languages.'**
  String get checkLanguagesOk;

  /// Note: some questions lack a label in one language.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question is missing its label in one language.} other{{count} questions are missing their label in one language.}}'**
  String checkLanguagesPartial(int count);

  /// Note: the form has one language.
  ///
  /// In en, this message translates to:
  /// **'The form is written in one language only.'**
  String get checkSingleLanguage;

  /// Said plainly in the upload dialog: spreadsheet forms are not supported yet.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet (.xlsx) forms can’t be uploaded yet. Converting them arrives in Phase 2. For now, upload the XForm (.xml) file. Kobo and ODK can export one.'**
  String get uploadXlsNotice;

  /// Prompt in the upload dialog before a file is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose the XForm (.xml) file from your computer. Spreadsheet (.xlsx) forms are not supported yet: converting them arrives in Phase 2.'**
  String get uploadChoosePrompt;

  /// Shows the name of the chosen file.
  ///
  /// In en, this message translates to:
  /// **'File: {name}'**
  String uploadFile(String name);

  /// Sentence when the chosen file passes all checks.
  ///
  /// In en, this message translates to:
  /// **'This file passed every check. It is saved as a draft first, and you can publish it afterwards.'**
  String get uploadReady;

  /// Sentence when the chosen file fails a check.
  ///
  /// In en, this message translates to:
  /// **'This file can’t be uploaded yet. Fix the things below, then choose the fixed file.'**
  String get uploadBlocked;

  /// Button: upload the chosen file.
  ///
  /// In en, this message translates to:
  /// **'Upload as draft'**
  String get uploadButton;

  /// Button text while uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploadUploading;

  /// Message after a successful upload.
  ///
  /// In en, this message translates to:
  /// **'Uploaded as a draft. Check it over, then publish when you are ready.'**
  String get uploadDone;

  /// Button: publish a version.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publishButton;

  /// Help text beside the Publish button when it is switched off.
  ///
  /// In en, this message translates to:
  /// **'You can publish when nothing is left to fix.'**
  String get publishHint;

  /// Title of the publish confirmation.
  ///
  /// In en, this message translates to:
  /// **'Publish version {version}?'**
  String publishConfirmTitle(String version);

  /// Body of the publish confirmation.
  ///
  /// In en, this message translates to:
  /// **'Once a version is published it can’t be changed. To change the form later, you will upload a new version.'**
  String get publishConfirmBody;

  /// Button: do not publish yet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get publishConfirmNo;

  /// Message after publishing.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is published.'**
  String publishDone(String version);

  /// Note on a published version.
  ///
  /// In en, this message translates to:
  /// **'This version is published, so it can’t be changed. To change the form, upload a new version.'**
  String get publishedReadOnly;

  /// Note shown to people who cannot upload forms.
  ///
  /// In en, this message translates to:
  /// **'Only an organisation admin can upload or publish forms.'**
  String get adminOnlyForms;

  /// Page heading.
  ///
  /// In en, this message translates to:
  /// **'Submissions'**
  String get subsTitle;

  /// How many submissions match the filters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No submissions match} =1{1 submission} other{{count} submissions}}'**
  String subsCount(int count);

  /// Label of the form filter.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get filterForm;

  /// Filter choice: every form.
  ///
  /// In en, this message translates to:
  /// **'All forms'**
  String get filterAllForms;

  /// Label of the date filter.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get filterDates;

  /// Date filter choice.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get filterLast7;

  /// Date filter choice.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get filterLast30;

  /// Date filter choice.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get filterAllTime;

  /// Date filter choice that opens a calendar.
  ///
  /// In en, this message translates to:
  /// **'Choose dates…'**
  String get filterChoose;

  /// Text of a custom date range.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String filterRange(String from, String to);

  /// Spoken name of the review state tabs.
  ///
  /// In en, this message translates to:
  /// **'Review state'**
  String get filterReviewState;

  /// Review state tab: everything.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reviewAll;

  /// Review state word.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get stateReceived;

  /// Review state word.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get stateEdited;

  /// Review state word.
  ///
  /// In en, this message translates to:
  /// **'Has issues'**
  String get stateHasIssues;

  /// Review state word.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get stateApproved;

  /// Review state word.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get stateRejected;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get colDate;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get colForm;

  /// Table column: the field officer who collected the answers.
  ///
  /// In en, this message translates to:
  /// **'Collector'**
  String get colCollector;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get colLocation;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get colReview;

  /// A time today.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String dateToday(String time);

  /// A time yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String dateYesterday(String time);

  /// A date and time.
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String dateOther(String date, String time);

  /// Title when no submission matches.
  ///
  /// In en, this message translates to:
  /// **'No submissions here'**
  String get subsEmptyTitle;

  /// Text when no submission matches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters. Try a wider date range or another review state.'**
  String get subsEmptyBody;

  /// Which rows are on the page.
  ///
  /// In en, this message translates to:
  /// **'Showing {from}–{to} of {total}'**
  String pagingRange(int from, int to, int total);

  /// Current page.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String pagingPage(int page, int pages);

  /// Button: previous page.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get pagingPrevious;

  /// Button: next page.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get pagingNext;

  /// Button: reload the list.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Spoken name of the button that closes the details panel.
  ///
  /// In en, this message translates to:
  /// **'Close details'**
  String get detailClose;

  /// Line under the heading of the details panel.
  ///
  /// In en, this message translates to:
  /// **'{collector} · {location} · {date}'**
  String detailMeta(String collector, String location, String date);

  /// Note in the details panel about protected answers.
  ///
  /// In en, this message translates to:
  /// **'This app can’t show protected answers, so they stay safe even on a shared computer.'**
  String get detailProtectedNote;

  /// Shown instead of a protected answer. Never replaced by the answer on this app.
  ///
  /// In en, this message translates to:
  /// **'Protected — open in the Obhijatra desktop app to view'**
  String get protectedAnswer;

  /// Heading above the answers.
  ///
  /// In en, this message translates to:
  /// **'Answers'**
  String get detailAnswers;

  /// Text when a submission has no answers.
  ///
  /// In en, this message translates to:
  /// **'This submission has no answers to show.'**
  String get detailNoAnswers;

  /// Heading above the review note.
  ///
  /// In en, this message translates to:
  /// **'Review note'**
  String get detailComment;

  /// Button: approve a submission.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get actionApprove;

  /// Button: mark a submission as having issues.
  ///
  /// In en, this message translates to:
  /// **'Has issues'**
  String get actionHasIssues;

  /// Button: reject a submission.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get actionReject;

  /// Note shown to people who cannot review.
  ///
  /// In en, this message translates to:
  /// **'Your role can read submissions but can’t review them.'**
  String get reviewReadOnly;

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Mark as having issues'**
  String get reviewIssuesTitle;

  /// Dialog field label.
  ///
  /// In en, this message translates to:
  /// **'What needs checking?'**
  String get reviewIssuesLabel;

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Reject this submission'**
  String get reviewRejectTitle;

  /// Dialog field label.
  ///
  /// In en, this message translates to:
  /// **'Why are you rejecting it?'**
  String get reviewRejectLabel;

  /// Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Mark as having issues'**
  String get reviewConfirmIssues;

  /// Dialog help text.
  ///
  /// In en, this message translates to:
  /// **'Your note is saved with the submission and others can read it.'**
  String get reviewCommentHelp;

  /// Error when the note is empty.
  ///
  /// In en, this message translates to:
  /// **'Please write a short note.'**
  String get reviewCommentRequired;

  /// Error when the note is too long.
  ///
  /// In en, this message translates to:
  /// **'Keep it under {max} characters.'**
  String reviewCommentTooLong(int max);

  /// Message after saving a review decision.
  ///
  /// In en, this message translates to:
  /// **'Saved: {state}.'**
  String reviewSaved(String state);

  /// Button text while saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get reviewSaving;

  /// Page heading.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Heading of the language card.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Help text under the language switch.
  ///
  /// In en, this message translates to:
  /// **'This changes the language of the whole app. We remember your choice on this computer.'**
  String get settingsLanguageHelp;

  /// Heading of the account card.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get settingsAccount;

  /// Account detail label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountName;

  /// Account detail label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmail;

  /// Account detail label.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get accountRole;

  /// Account detail label.
  ///
  /// In en, this message translates to:
  /// **'Organisation'**
  String get accountOrganisation;

  /// Account detail label.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get accountServer;

  /// Help text beside the sign-out button.
  ///
  /// In en, this message translates to:
  /// **'You will need your email and password to sign in again.'**
  String get settingsSignOutHelp;

  /// Role name.
  ///
  /// In en, this message translates to:
  /// **'Supervisor'**
  String get roleSupervisor;

  /// Role name.
  ///
  /// In en, this message translates to:
  /// **'Branch manager'**
  String get roleBranchManager;

  /// Role name.
  ///
  /// In en, this message translates to:
  /// **'Monitoring and evaluation'**
  String get roleMe;

  /// Role name.
  ///
  /// In en, this message translates to:
  /// **'Organisation admin'**
  String get roleOrgAdmin;

  /// Role name.
  ///
  /// In en, this message translates to:
  /// **'Donor (read only)'**
  String get roleDonorReadonly;

  /// Page heading.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// App version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// Status note.
  ///
  /// In en, this message translates to:
  /// **'Pre-alpha. Not ready for real use yet.'**
  String get aboutPreAlpha;

  /// Heading.
  ///
  /// In en, this message translates to:
  /// **'Licence'**
  String get aboutLicenceTitle;

  /// AGPL-3.0 notice.
  ///
  /// In en, this message translates to:
  /// **'Obhijatra is free software. You can use it, study it, share it and change it under the GNU Affero General Public License, version 3 (AGPL-3.0). It comes with no warranty. If you run a changed version for other people over a network, you must offer them the source code of your changes.'**
  String get aboutLicenceBody;

  /// Heading.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get aboutSourceTitle;

  /// Link text.
  ///
  /// In en, this message translates to:
  /// **'Open the source code'**
  String get aboutSourceOpen;

  /// Message when the link cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t open the link. The address is {url}'**
  String aboutSourceFailed(String url);

  /// Heading.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutLicencesTitle;

  /// Help text.
  ///
  /// In en, this message translates to:
  /// **'The other free software Obhijatra is built with, and the licence of each.'**
  String get aboutLicencesHelp;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'See the licences'**
  String get aboutLicencesButton;

  /// Credit line, plain text.
  ///
  /// In en, this message translates to:
  /// **'Made by Aninda Studio'**
  String get aboutMadeBy;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
