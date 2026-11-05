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

  /// Error under a server address that is not a web address.
  ///
  /// In en, this message translates to:
  /// **'This does not look like a web address. It should look like https://data.example.org'**
  String get serverInvalid;

  /// Error under a server address that would send data without protection.
  ///
  /// In en, this message translates to:
  /// **'Use an address that starts with https:// so that your password and data are protected on their way.'**
  String get serverInsecure;

  /// Note under an http:// server address on a private network.
  ///
  /// In en, this message translates to:
  /// **'Testing only: this address is on your own network and is not protected. Do not use it for real data.'**
  String get serverTestingOnly;

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

  /// Role name: monitoring and evaluation (M&E) officer.
  ///
  /// In en, this message translates to:
  /// **'M&E officer'**
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

  /// Small word between email sign-in and the other ways to sign in.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get signInOr;

  /// Button that opens Google's sign-in page in the browser. Plain text only: no Google logo.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInGoogle;

  /// Button and heading: sign in with a code sent by SMS.
  ///
  /// In en, this message translates to:
  /// **'Sign in with an SMS code'**
  String get signInSms;

  /// Note beside the SMS sign-in option.
  ///
  /// In en, this message translates to:
  /// **'SMS codes are not available to organisation admins.'**
  String get signInSmsAdminNote;

  /// Link back from the SMS steps to the main sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Other ways to sign in'**
  String get signInOtherWays;

  /// Text on the SMS number step.
  ///
  /// In en, this message translates to:
  /// **'We will send a 6-digit code by SMS to the mobile number on your account.'**
  String get smsNumberIntro;

  /// Label of the mobile number field.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get smsNumberLabel;

  /// Help under the mobile number field.
  ///
  /// In en, this message translates to:
  /// **'For example 01712345678. For a number outside Bangladesh, start with + and the country code.'**
  String get smsNumberHelp;

  /// Error under the mobile number field.
  ///
  /// In en, this message translates to:
  /// **'This does not look like a mobile number. Type it like 01712345678, or start with + and the country code.'**
  String get smsNumberInvalid;

  /// Button: send the sign-in code by SMS.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get smsSendCode;

  /// Button text while something is being sent.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get actionSending;

  /// Heading of the SMS code step.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get smsCodeTitle;

  /// Text on the code step. It must not say whether the number has an account.
  ///
  /// In en, this message translates to:
  /// **'If {phone} can sign in with an SMS code, a 6-digit code is on its way.'**
  String smsCodeSent(String phone);

  /// How long the SMS code works.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{The code works for 1 minute.} other{The code works for {minutes} minutes.}}'**
  String smsCodeLifetime(int minutes);

  /// Label of the code field.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get smsCodeLabel;

  /// Error under the code field when fewer than 6 digits were typed.
  ///
  /// In en, this message translates to:
  /// **'Enter all 6 digits of the code.'**
  String get smsCodeIncomplete;

  /// Error under the code field.
  ///
  /// In en, this message translates to:
  /// **'That code is wrong or has expired. Check the SMS and try again, or send a new code.'**
  String get smsCodeWrong;

  /// Error under the code field after the third wrong try.
  ///
  /// In en, this message translates to:
  /// **'That code was tried 3 times, so it no longer works. Send a new code.'**
  String get smsCodeUsedUp;

  /// Error under the code field when the code is too old.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Send a new code.'**
  String get smsCodeExpired;

  /// Button text while the code is checked.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get smsCodeChecking;

  /// Disabled button with a countdown, for example 0:42.
  ///
  /// In en, this message translates to:
  /// **'Send a new code in {time}'**
  String smsResendIn(String time);

  /// Button: send another code.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get smsResend;

  /// Note after a new code was asked for.
  ///
  /// In en, this message translates to:
  /// **'A new code is on its way.'**
  String get smsNewCodeSent;

  /// Button: go back and type another number.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get smsChangeNumber;

  /// Heading while the person signs in on Google's page.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Google…'**
  String get googleWaitingTitle;

  /// Text while waiting for Google.
  ///
  /// In en, this message translates to:
  /// **'Google’s sign-in page opens in your web browser. Choose your Google account there, then come back to this window.'**
  String get googleWaitingBody;

  /// Help above the button that opens Google's page again.
  ///
  /// In en, this message translates to:
  /// **'If Google’s page did not open, use this button.'**
  String get googleOpenHelp;

  /// Button that opens Google's sign-in page (for when the browser blocked it).
  ///
  /// In en, this message translates to:
  /// **'Open Google sign-in'**
  String get googleOpen;

  /// Google sign-in refused: no account with that email.
  ///
  /// In en, this message translates to:
  /// **'No Obhijatra account here uses this Google email address. Ask your organisation admin to add it, or use another way to sign in.'**
  String get problemGoogleNoAccount;

  /// Google sign-in refused: email not confirmed by an admin.
  ///
  /// In en, this message translates to:
  /// **'Your organisation admin must confirm your email address before you can sign in with Google.'**
  String get problemGoogleUnconfirmed;

  /// Google sign-in refused: account switched off.
  ///
  /// In en, this message translates to:
  /// **'This account cannot sign in. Ask your organisation admin.'**
  String get problemGoogleNotAllowed;

  /// Google sign-in refused: Google gave no confirmed email.
  ///
  /// In en, this message translates to:
  /// **'Google did not share a confirmed email address for this Google account. Use another Google account, or another way to sign in.'**
  String get problemGoogleNoEmail;

  /// Google sign-in refused: the address is neither Gmail nor Google Workspace.
  ///
  /// In en, this message translates to:
  /// **'Google cannot vouch that this email address belongs to this Google account. Sign in with a Gmail address or your organisation\'s Google Workspace account, or use another way to sign in.'**
  String get problemGoogleUnmanaged;

  /// Google sign-in is off.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not switched on for this server. Use another way to sign in.'**
  String get problemGoogleUnavailable;

  /// Google sign-in failed for another reason.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in did not finish. Try again, or use another way to sign in.'**
  String get problemGoogleFailed;

  /// SMS sign-in is off.
  ///
  /// In en, this message translates to:
  /// **'Sign-in by SMS code is switched off on this server. Use another way to sign in.'**
  String get problemSmsOff;

  /// The server refused the mobile number.
  ///
  /// In en, this message translates to:
  /// **'This does not look like a mobile number. Type it like 01712345678, or start with + and the country code.'**
  String get problemPhoneInvalid;

  /// The SMS code was refused.
  ///
  /// In en, this message translates to:
  /// **'That code is wrong or has expired. Check the SMS and try again, or send a new code.'**
  String get problemCodeWrong;

  /// Too many SMS codes asked for.
  ///
  /// In en, this message translates to:
  /// **'Too many codes were asked for. Wait 15 minutes, or use another way to sign in.'**
  String get problemTooManyCodes;

  /// Too many code checks.
  ///
  /// In en, this message translates to:
  /// **'Too many tries from this connection. Wait 15 minutes, then ask for a new code.'**
  String get problemTooManyTries;

  /// Too many test SMS.
  ///
  /// In en, this message translates to:
  /// **'Too many test messages. Wait 15 minutes and try again.'**
  String get problemTooManyTests;

  /// The server refused some sign-in settings.
  ///
  /// In en, this message translates to:
  /// **'Some settings need attention. Look for the messages under the fields.'**
  String get problemSettingsInvalid;

  /// Label in the account details.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get accountPhone;

  /// Heading of the sign-in methods settings (organisation admins).
  ///
  /// In en, this message translates to:
  /// **'Sign-in methods'**
  String get signInMethodsTitle;

  /// Text about the sign-in methods.
  ///
  /// In en, this message translates to:
  /// **'Everyone can sign in with an email address and password. You can also let people sign in with Google or with an SMS code.'**
  String get signInMethodsSummary;

  /// Button that opens the sign-in methods settings.
  ///
  /// In en, this message translates to:
  /// **'Set up sign-in methods'**
  String get signInMethodsOpen;

  /// Link back to the main settings page.
  ///
  /// In en, this message translates to:
  /// **'Back to Settings'**
  String get settingsBack;

  /// State beside a switch.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get methodOn;

  /// State beside a switch.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get methodOff;

  /// Card heading and switch: Google sign-in.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get googleTitle;

  /// Text in the Google card.
  ///
  /// In en, this message translates to:
  /// **'People click “Continue with Google” and choose their Google account. It works only for people whose account here has the same email address, confirmed by an admin.'**
  String get googleDescription;

  /// Label of the read-only address to register with Google.
  ///
  /// In en, this message translates to:
  /// **'Redirect address for Google'**
  String get googleRedirectLabel;

  /// Help under the redirect address.
  ///
  /// In en, this message translates to:
  /// **'Add this address to your Google client under Authorised redirect URIs.'**
  String get googleRedirectHelp;

  /// Warning when the server's address will not work with Google.
  ///
  /// In en, this message translates to:
  /// **'Google needs an https:// address with a domain name, such as https://data.example.org. Ask whoever runs your server to give it one. SMS codes work without it.'**
  String get googleRedirectWarning;

  /// Button: copy to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// Message after copying.
  ///
  /// In en, this message translates to:
  /// **'Redirect address copied.'**
  String get copiedRedirect;

  /// Field label: the Google client ID.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get googleClientId;

  /// Help under the client ID.
  ///
  /// In en, this message translates to:
  /// **'From your Google Cloud project. It ends with .apps.googleusercontent.com.'**
  String get googleClientIdHelp;

  /// Field label: the Google client secret.
  ///
  /// In en, this message translates to:
  /// **'Client secret'**
  String get googleClientSecret;

  /// Help under the client secret when none is saved.
  ///
  /// In en, this message translates to:
  /// **'Google shows it once, when you create the client. Keep it private.'**
  String get googleClientSecretHelp;

  /// Help under a secret field when a secret is already saved.
  ///
  /// In en, this message translates to:
  /// **'Saved. Leave empty to keep it.'**
  String get secretSavedKeep;

  /// Button that shows a hidden secret.
  ///
  /// In en, this message translates to:
  /// **'Show secret'**
  String get secretShow;

  /// Button that hides a secret.
  ///
  /// In en, this message translates to:
  /// **'Hide secret'**
  String get secretHide;

  /// Link to the written set-up guide.
  ///
  /// In en, this message translates to:
  /// **'How to set this up'**
  String get setupGuide;

  /// Card heading and switch: SMS-code sign-in.
  ///
  /// In en, this message translates to:
  /// **'SMS codes'**
  String get smsTitle;

  /// Text in the SMS card.
  ///
  /// In en, this message translates to:
  /// **'People type their mobile number and receive a 6-digit code by SMS. Your organisation pays your SMS provider for each message. SMS codes are not available to organisation admins.'**
  String get smsDescription;

  /// Sub-heading in the SMS card.
  ///
  /// In en, this message translates to:
  /// **'Your SMS provider'**
  String get smsProviderTitle;

  /// Help under the SMS provider sub-heading.
  ///
  /// In en, this message translates to:
  /// **'Fill these in from your SMS provider’s guide for sending one message.'**
  String get smsProviderHelp;

  /// Label: GET or POST.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get smsMethod;

  /// Field label: the provider's web address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get smsAddress;

  /// Help under the address.
  ///
  /// In en, this message translates to:
  /// **'The provider’s web address for sending a message. It starts with https://'**
  String get smsAddressHelp;

  /// Label: JSON or form.
  ///
  /// In en, this message translates to:
  /// **'Body format'**
  String get smsBodyFormat;

  /// Body format choice.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get smsFormatJson;

  /// Body format choice.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get smsFormatForm;

  /// Field label: the message body template.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get smsBody;

  /// Help under the body.
  ///
  /// In en, this message translates to:
  /// **'Copy the example from your provider’s guide, then put placeholders where the values go.'**
  String get smsBodyHelp;

  /// Heading of the placeholder buttons.
  ///
  /// In en, this message translates to:
  /// **'Placeholders'**
  String get smsPlaceholders;

  /// Help about the placeholder buttons.
  ///
  /// In en, this message translates to:
  /// **'Click one to put it where the cursor is in the Address, the Body or a header value. The server fills it in for each message.'**
  String get smsPlaceholdersHelp;

  /// What the phone placeholder becomes.
  ///
  /// In en, this message translates to:
  /// **'the number with a plus sign, for example +8801712345678'**
  String get smsPlaceholderPhone;

  /// What the digits placeholder becomes.
  ///
  /// In en, this message translates to:
  /// **'the number without a plus sign, for example 8801712345678'**
  String get smsPlaceholderDigits;

  /// What the message placeholder becomes.
  ///
  /// In en, this message translates to:
  /// **'the text of the SMS'**
  String get smsPlaceholderMessage;

  /// What the secret placeholder becomes.
  ///
  /// In en, this message translates to:
  /// **'your secret key, kept hidden'**
  String get smsPlaceholderSecret;

  /// Tooltip of a placeholder button.
  ///
  /// In en, this message translates to:
  /// **'Insert {placeholder}'**
  String smsInsertPlaceholder(String placeholder);

  /// Heading of the extra headers.
  ///
  /// In en, this message translates to:
  /// **'Extra headers'**
  String get smsHeaders;

  /// Help about extra headers.
  ///
  /// In en, this message translates to:
  /// **'Only if your provider’s guide asks for them, for example Authorization.'**
  String get smsHeadersHelp;

  /// Field label: header name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get smsHeaderName;

  /// Field label: header value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get smsHeaderValue;

  /// Button: add a header row.
  ///
  /// In en, this message translates to:
  /// **'Add a header'**
  String get smsHeaderAdd;

  /// Tooltip: remove a header row.
  ///
  /// In en, this message translates to:
  /// **'Remove this header'**
  String get smsHeaderRemove;

  /// Note when the header limit is reached.
  ///
  /// In en, this message translates to:
  /// **'You can add up to {count} headers.'**
  String smsHeadersMax(int count);

  /// Field label: the provider's API key.
  ///
  /// In en, this message translates to:
  /// **'Secret key'**
  String get smsSecret;

  /// Help under the secret key when none is saved.
  ///
  /// In en, this message translates to:
  /// **'Your provider’s API key or token. Type it here, and put {placeholder} where the guide shows the key.'**
  String smsSecretHelp(String placeholder);

  /// Field label: text the provider replies on success.
  ///
  /// In en, this message translates to:
  /// **'Success text'**
  String get smsSuccessText;

  /// Help under the success text.
  ///
  /// In en, this message translates to:
  /// **'Optional. What the provider replies when it accepts a message, for example SUCCESS. Leave empty if you are not sure.'**
  String get smsSuccessTextHelp;

  /// Sub-heading.
  ///
  /// In en, this message translates to:
  /// **'Send test SMS'**
  String get smsTestTitle;

  /// Help about the test SMS.
  ///
  /// In en, this message translates to:
  /// **'Sends a test message with the settings above, even before you save them.'**
  String get smsTestHelp;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Mobile number for the test'**
  String get smsTestNumber;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Send test SMS'**
  String get smsTestButton;

  /// Heading of the test result.
  ///
  /// In en, this message translates to:
  /// **'Test result'**
  String get smsResultTest;

  /// Heading of the last send status.
  ///
  /// In en, this message translates to:
  /// **'Last message sent by the server'**
  String get smsResultLast;

  /// Result: sent.
  ///
  /// In en, this message translates to:
  /// **'Sent. The provider accepted the message.'**
  String get smsResultSent;

  /// Result: not sent.
  ///
  /// In en, this message translates to:
  /// **'Not sent.'**
  String get smsResultNotSent;

  /// The provider's HTTP status number.
  ///
  /// In en, this message translates to:
  /// **'Provider status: {status}'**
  String smsResultStatus(String status);

  /// Result when the provider could not be reached.
  ///
  /// In en, this message translates to:
  /// **'The provider did not answer.'**
  String get smsResultNoAnswer;

  /// Label above the provider's reply text.
  ///
  /// In en, this message translates to:
  /// **'Provider reply'**
  String get smsResultReply;

  /// When the message was sent.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String smsResultAt(String time);

  /// Shown when there is no last send.
  ///
  /// In en, this message translates to:
  /// **'No message has been sent since the server last started.'**
  String get smsResultNone;

  /// Button: save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Button text while saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get actionSaving;

  /// Message after saving.
  ///
  /// In en, this message translates to:
  /// **'Sign-in methods saved.'**
  String get signInMethodsSaved;

  /// Note beside the Save button.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes.'**
  String get unsavedChanges;

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get leaveTitle;

  /// Dialog text.
  ///
  /// In en, this message translates to:
  /// **'Your changes to the sign-in methods will be lost.'**
  String get leaveBody;

  /// Dialog button: stay on the page.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get leaveStay;

  /// Dialog button: leave and lose changes.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving'**
  String get leaveDiscard;

  /// Menu item: the people who use Obhijatra (organisation admins only).
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get navPeople;

  /// Role name: a field officer, who uses the field app.
  ///
  /// In en, this message translates to:
  /// **'Field officer'**
  String get roleFieldOfficer;

  /// Heading of the People screen.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get peopleTitle;

  /// Line under the People heading.
  ///
  /// In en, this message translates to:
  /// **'Add the people who use Obhijatra, choose what each can do, and help them sign in.'**
  String get peopleSummary;

  /// Primary button and page heading: add a person.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get peopleAdd;

  /// Spoken name of the Office staff / Field staff tabs.
  ///
  /// In en, this message translates to:
  /// **'Kind of staff'**
  String get peopleKindLabel;

  /// Tab and choice: people who use this manager app.
  ///
  /// In en, this message translates to:
  /// **'Office staff'**
  String get kindStaff;

  /// Tab and choice: people who use the field app on a phone.
  ///
  /// In en, this message translates to:
  /// **'Field staff'**
  String get kindField;

  /// Label of the search box on the People screen.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get peopleSearch;

  /// Hint inside the search box.
  ///
  /// In en, this message translates to:
  /// **'Name, email or mobile number'**
  String get peopleSearchHint;

  /// Spoken name of the button that empties the search box.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get peopleSearchClear;

  /// Filter label: status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get peopleStatus;

  /// Status filter choice: no status filter.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get peopleStatusAll;

  /// Status chip, filter choice and switch label: the person can sign in.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// Status chip and filter choice: the person cannot sign in.
  ///
  /// In en, this message translates to:
  /// **'Deactivated'**
  String get statusDeactivated;

  /// Status chip and filter choice: sign-in locked after too many wrong passwords.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get statusLocked;

  /// Status chip: the person has a one-time password.
  ///
  /// In en, this message translates to:
  /// **'Must choose a password'**
  String get statusMustChoose;

  /// Field label and filter label: the place where a person works.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get personPlace;

  /// Place filter choice: every place.
  ///
  /// In en, this message translates to:
  /// **'All places'**
  String get placeAll;

  /// Label of the list order menu.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get peopleSort;

  /// List order: most recently added first.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get peopleSortNewest;

  /// List order: by name.
  ///
  /// In en, this message translates to:
  /// **'Name, A to Z'**
  String get peopleSortName;

  /// Small mark next to an email address an admin has confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get emailConfirmed;

  /// Empty list title (office staff).
  ///
  /// In en, this message translates to:
  /// **'No office staff yet'**
  String get peopleEmptyStaffTitle;

  /// Empty list title (field staff).
  ///
  /// In en, this message translates to:
  /// **'No field staff yet'**
  String get peopleEmptyFieldTitle;

  /// Empty list text.
  ///
  /// In en, this message translates to:
  /// **'Use ‘Add person’ to add the first one.'**
  String get peopleEmptyBody;

  /// Title when the search or filters find nobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody matches'**
  String get peopleNoMatchTitle;

  /// Text when the search or filters find nobody.
  ///
  /// In en, this message translates to:
  /// **'Try another search, status or place.'**
  String get peopleNoMatchBody;

  /// Title when the Locked filter finds nobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody is locked out'**
  String get peopleNoLockedTitle;

  /// Text when the Locked filter finds nobody.
  ///
  /// In en, this message translates to:
  /// **'People appear here when their sign-in is locked after too many wrong passwords.'**
  String get peopleNoLockedBody;

  /// Link back from a person's page to the list.
  ///
  /// In en, this message translates to:
  /// **'Back to People'**
  String get peopleBack;

  /// Heading of the person's details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get personDetails;

  /// Field label: the person's full name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get personName;

  /// Field label: office staff or field staff.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get personKind;

  /// Help under the Kind choice when adding a person.
  ///
  /// In en, this message translates to:
  /// **'Office staff use this app. Field staff use the Obhijatra field app on a phone. This can’t be changed later.'**
  String get personKindHelp;

  /// Help under the Kind on a person's page.
  ///
  /// In en, this message translates to:
  /// **'This can’t be changed.'**
  String get personKindFixed;

  /// Help under the Place field.
  ///
  /// In en, this message translates to:
  /// **'Where this person works.'**
  String get personPlaceHelp;

  /// Button and dialog title: choose a place.
  ///
  /// In en, this message translates to:
  /// **'Choose a place'**
  String get personPlaceChoose;

  /// Button: choose a different place.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get placeChange;

  /// Search box in the place chooser.
  ///
  /// In en, this message translates to:
  /// **'Search places'**
  String get placeSearch;

  /// Place chooser: the search finds nothing.
  ///
  /// In en, this message translates to:
  /// **'No place matches.'**
  String get placeNoMatch;

  /// Place chooser: the organisation has no places.
  ///
  /// In en, this message translates to:
  /// **'There are no places yet. Ask whoever runs your server to add them.'**
  String get placeNone;

  /// Help under the Email field.
  ///
  /// In en, this message translates to:
  /// **'Used to sign in with a password or with Google.'**
  String get personEmailHelp;

  /// Switch label: the admin confirmed the email address belongs to the person.
  ///
  /// In en, this message translates to:
  /// **'Email address confirmed'**
  String get personVerified;

  /// Help under the Email address confirmed switch.
  ///
  /// In en, this message translates to:
  /// **'Turn on when you are sure this address belongs to the person. Needed for Google sign-in.'**
  String get personVerifiedHelp;

  /// Help under the Mobile number field.
  ///
  /// In en, this message translates to:
  /// **'Needed for SMS-code sign-in. Not available to organisation admins.'**
  String get personPhoneHelp;

  /// Heading of the sign-in choice when adding a person.
  ///
  /// In en, this message translates to:
  /// **'How will they sign in?'**
  String get personHowSignIn;

  /// Sign-in choice: email with a one-time password.
  ///
  /// In en, this message translates to:
  /// **'Email and a one-time password'**
  String get personSignInOtp;

  /// Help for the one-time password choice.
  ///
  /// In en, this message translates to:
  /// **'You will see a password to give them. They choose their own the first time they sign in.'**
  String get personSignInOtpHelp;

  /// Help for the one-time password choice when no email is typed.
  ///
  /// In en, this message translates to:
  /// **'Add an email address to use this.'**
  String get personSignInOtpNeedsEmail;

  /// Sign-in choice: no password from the admin.
  ///
  /// In en, this message translates to:
  /// **'SMS code or Google only'**
  String get personSignInOther;

  /// Help for the SMS code or Google choice.
  ///
  /// In en, this message translates to:
  /// **'No password to give. They sign in with a code sent to their mobile, or with Google.'**
  String get personSignInOtherHelp;

  /// Warning when the details chosen give the person no way to sign in.
  ///
  /// In en, this message translates to:
  /// **'With these details they can’t sign in yet. Google sign-in needs a confirmed email address. SMS-code sign-in needs a mobile number and is not available to organisation admins.'**
  String get personCannotSignIn;

  /// Button label while a person is being added.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get personAdding;

  /// Message after adding a person.
  ///
  /// In en, this message translates to:
  /// **'{name} is added.'**
  String personAdded(String name);

  /// Heading above the one-time password after adding a person.
  ///
  /// In en, this message translates to:
  /// **'{name} is added'**
  String personAddedHeading(String name);

  /// Message after saving a person's details.
  ///
  /// In en, this message translates to:
  /// **'Changes saved.'**
  String get personSaved;

  /// Note next to Save on a person's page.
  ///
  /// In en, this message translates to:
  /// **'Changes to sign-in details, role or status sign this person out on their devices.'**
  String get personSignOutNote;

  /// Leave dialog text on a person's page.
  ///
  /// In en, this message translates to:
  /// **'Your changes to this person will be lost.'**
  String get leavePersonBody;

  /// Field error: no name.
  ///
  /// In en, this message translates to:
  /// **'Type the person’s name.'**
  String get personErrorName;

  /// Field error: no role.
  ///
  /// In en, this message translates to:
  /// **'Choose a role.'**
  String get personErrorRole;

  /// Field error: no place.
  ///
  /// In en, this message translates to:
  /// **'Choose a place.'**
  String get personErrorPlace;

  /// Field error: the email address is not in a usable form.
  ///
  /// In en, this message translates to:
  /// **'This does not look like an email address.'**
  String get personErrorEmailInvalid;

  /// Field error: neither an email address nor a mobile number.
  ///
  /// In en, this message translates to:
  /// **'Give an email address or a mobile number, so this person can sign in.'**
  String get personErrorEmailOrPhone;

  /// Field error: an organisation admin without an email address.
  ///
  /// In en, this message translates to:
  /// **'An organisation admin needs an email address. SMS-code sign-in is not available to organisation admins.'**
  String get personErrorAdminEmail;

  /// Field error: a one-time password without an email address.
  ///
  /// In en, this message translates to:
  /// **'A one-time password needs an email address to sign in with.'**
  String get personErrorOtpEmail;

  /// Field error: the email address is used by another person.
  ///
  /// In en, this message translates to:
  /// **'Someone else already has this email address.'**
  String get personErrorEmailTaken;

  /// Field error: the mobile number is used by another person.
  ///
  /// In en, this message translates to:
  /// **'Someone else already has this mobile number.'**
  String get personErrorPhoneTaken;

  /// Field error: the change would leave no active organisation admin.
  ///
  /// In en, this message translates to:
  /// **'This is the only active organisation admin. Make someone else an organisation admin first.'**
  String get personErrorLastAdmin;

  /// Problem: the server refused some details.
  ///
  /// In en, this message translates to:
  /// **'Some details need attention. Look for the messages under the fields.'**
  String get problemDetailsInvalid;

  /// Problem: the person must replace their one-time password first.
  ///
  /// In en, this message translates to:
  /// **'Choose your own password before you carry on.'**
  String get problemPasswordChangeRequired;

  /// Problem: the new password was saved but signing in again failed.
  ///
  /// In en, this message translates to:
  /// **'Your new password is saved, but we could not sign you in again. Sign in with your new password.'**
  String get problemPasswordSavedSignIn;

  /// Heading of the sign-in and status panel on a person's page.
  ///
  /// In en, this message translates to:
  /// **'Sign-in and status'**
  String get personStatusTitle;

  /// Help under the Active switch.
  ///
  /// In en, this message translates to:
  /// **'People who are deactivated can’t sign in. Everything they did is kept.'**
  String get personActiveHelp;

  /// Shown on your own page when you are the only active organisation admin.
  ///
  /// In en, this message translates to:
  /// **'You are the only active organisation admin, so you can’t change your own role or status. Make someone else an organisation admin first.'**
  String get personOnlyAdmin;

  /// Dialog title before deactivating a person.
  ///
  /// In en, this message translates to:
  /// **'Deactivate {name}?'**
  String deactivateTitle(String name);

  /// Dialog text before deactivating a person.
  ///
  /// In en, this message translates to:
  /// **'They will be signed out and cannot sign in until you reactivate them.'**
  String get deactivateBody;

  /// Dialog text before deactivating yourself.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out and cannot sign in until another organisation admin reactivates you.'**
  String get deactivateSelfBody;

  /// Dialog button: deactivate the person.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivateButton;

  /// Message after deactivating a person.
  ///
  /// In en, this message translates to:
  /// **'{name} is deactivated.'**
  String personDeactivated(String name);

  /// Message after reactivating a person.
  ///
  /// In en, this message translates to:
  /// **'{name} can sign in again.'**
  String personReactivated(String name);

  /// Note on a person's page while they have a one-time password.
  ///
  /// In en, this message translates to:
  /// **'{name} has a one-time password. They must choose their own password when they next sign in.'**
  String personMustChooseNote(String name);

  /// Note on a person's page while their sign-in is locked.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is locked after too many wrong passwords. It unlocks by itself at {time}.'**
  String personLockedNote(String time);

  /// Button: lift a sign-in lock early.
  ///
  /// In en, this message translates to:
  /// **'Unlock sign-in'**
  String get unlockButton;

  /// Message after unlocking sign-in.
  ///
  /// In en, this message translates to:
  /// **'Sign-in unlocked. {name} can try again now.'**
  String unlockDone(String name);

  /// Heading: give a new one-time password.
  ///
  /// In en, this message translates to:
  /// **'Forgotten password'**
  String get resetTitle;

  /// Help next to the new one-time password button.
  ///
  /// In en, this message translates to:
  /// **'Give a new one-time password when someone has forgotten theirs. Their old password stops working.'**
  String get resetHelp;

  /// Button: give a new one-time password.
  ///
  /// In en, this message translates to:
  /// **'Give a new one-time password'**
  String get resetButton;

  /// Shown when a person without an email address cannot get a one-time password.
  ///
  /// In en, this message translates to:
  /// **'Add an email address and save first: a one-time password is used with an email address.'**
  String get resetNeedsEmail;

  /// Dialog title before giving a new one-time password.
  ///
  /// In en, this message translates to:
  /// **'Give {name} a new one-time password?'**
  String resetConfirmTitle(String name);

  /// Dialog text before giving a new one-time password.
  ///
  /// In en, this message translates to:
  /// **'Their current password stops working, and they are signed out on all their devices. You will see the new one-time password once.'**
  String get resetConfirmBody;

  /// Dialog button: give a new one-time password.
  ///
  /// In en, this message translates to:
  /// **'Give a new password'**
  String get resetConfirmButton;

  /// Heading above a one-time password.
  ///
  /// In en, this message translates to:
  /// **'One-time password for {name}'**
  String otpTitle(String name);

  /// Instructions under a one-time password.
  ///
  /// In en, this message translates to:
  /// **'Give this to {name} in person or by phone. They must choose their own password when they first sign in. It will not be shown again.'**
  String otpGive(String name);

  /// The email address the person signs in with.
  ///
  /// In en, this message translates to:
  /// **'They sign in with {email}.'**
  String otpSignInWith(String email);

  /// Screen-reader text for a one-time password, read letter by letter.
  ///
  /// In en, this message translates to:
  /// **'One-time password: {characters}'**
  String otpSpoken(String characters);

  /// Button: copy the one-time password.
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get otpCopy;

  /// Shown after copying the one-time password, which is cleared from the clipboard when the reveal closes.
  ///
  /// In en, this message translates to:
  /// **'Password copied. Paste it now: it is cleared from the clipboard when you close this.'**
  String get otpCopied;

  /// Button: close the one-time password.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get otpDone;

  /// Button: add another person after adding one.
  ///
  /// In en, this message translates to:
  /// **'Add another person'**
  String get otpAddAnother;

  /// Leave dialog title while a one-time password is shown.
  ///
  /// In en, this message translates to:
  /// **'Leave without noting the password?'**
  String get leaveOtpTitle;

  /// Leave dialog text while a one-time password is shown.
  ///
  /// In en, this message translates to:
  /// **'The one-time password will not be shown again. If you leave now, you can give a new one from this person’s page.'**
  String get leaveOtpBody;

  /// Leave dialog button while a one-time password is shown.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveOtpLeave;

  /// Heading of the step after signing in with a one-time password.
  ///
  /// In en, this message translates to:
  /// **'Choose your own password'**
  String get choosePasswordTitle;

  /// Text under the heading.
  ///
  /// In en, this message translates to:
  /// **'You signed in with a one-time password. Choose a password that only you know before you carry on.'**
  String get choosePasswordIntro;

  /// Who is signed in.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String choosePasswordAccount(String name);

  /// Field label: the one-time password from the admin.
  ///
  /// In en, this message translates to:
  /// **'One-time password'**
  String get choosePasswordCurrent;

  /// Help under the one-time password field.
  ///
  /// In en, this message translates to:
  /// **'The password your organisation admin gave you.'**
  String get choosePasswordCurrentHelp;

  /// Field label: the new password.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get choosePasswordNew;

  /// Help under the new password field.
  ///
  /// In en, this message translates to:
  /// **'Use 3 or 4 words you will remember, at least 12 characters.'**
  String get choosePasswordHint;

  /// Field label: repeat the new password.
  ///
  /// In en, this message translates to:
  /// **'Type the new password again'**
  String get choosePasswordRepeat;

  /// Field error: the new password is too short.
  ///
  /// In en, this message translates to:
  /// **'Use at least 12 characters.'**
  String get choosePasswordTooShort;

  /// Field error: the new password is the one-time password.
  ///
  /// In en, this message translates to:
  /// **'Choose a password that is different from the one-time password.'**
  String get choosePasswordSame;

  /// Field error: the repeated password differs.
  ///
  /// In en, this message translates to:
  /// **'The two passwords are not the same.'**
  String get choosePasswordMismatch;

  /// Field error: the one-time password is wrong.
  ///
  /// In en, this message translates to:
  /// **'This is not the one-time password you were given. Check it and try again.'**
  String get choosePasswordWrongCurrent;

  /// Button: save the new password and carry on.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get choosePasswordSave;

  /// Message after choosing a new password.
  ///
  /// In en, this message translates to:
  /// **'Your new password is saved.'**
  String get choosePasswordSaved;

  /// Problem: another admin changed the person between loading and saving.
  ///
  /// In en, this message translates to:
  /// **'Someone changed this person a moment ago. Reload, then make your change again.'**
  String get problemPersonChanged;

  /// Button: load the record again from the server.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get actionReload;

  /// Menu item: the organisation tree of places (organisation admins only).
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get navPlaces;

  /// Heading of the Places screen.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get placesTitle;

  /// Line under the Places heading.
  ///
  /// In en, this message translates to:
  /// **'Your organisation from the top down: head office, regions, areas and branches. Each person works at one place.'**
  String get placesSummary;

  /// Primary button: add a place.
  ///
  /// In en, this message translates to:
  /// **'Add place'**
  String get placesAdd;

  /// Button: add many places from a CSV file.
  ///
  /// In en, this message translates to:
  /// **'Import from a spreadsheet'**
  String get placesImport;

  /// Hint inside the search box on the Places screen.
  ///
  /// In en, this message translates to:
  /// **'Name or code'**
  String get placesSearchHint;

  /// Switch: also show places that are closed.
  ///
  /// In en, this message translates to:
  /// **'Show closed places'**
  String get placesShowClosed;

  /// Help under the Show closed places switch while it is off.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 closed place is hidden.} other{{count} closed places are hidden.}}'**
  String placesClosedHidden(int count);

  /// How many places the search finds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No place matches} =1{1 place matches} other{{count} places match}}'**
  String placesMatches(int count);

  /// Text when the search finds no place.
  ///
  /// In en, this message translates to:
  /// **'Try another name or code.'**
  String get placesNoMatchBody;

  /// Text when the search finds no open place but closed places are hidden.
  ///
  /// In en, this message translates to:
  /// **'Try another name or code, or turn on ‘Show closed places’.'**
  String get placesNoMatchClosedBody;

  /// Title when the organisation has no places inside it yet.
  ///
  /// In en, this message translates to:
  /// **'Add your first places'**
  String get placesEmptyTitle;

  /// Text when the organisation has no places inside it yet.
  ///
  /// In en, this message translates to:
  /// **'Add the regions, areas and branches inside {organisation}: one at a time with ‘Add place’, or all at once from a spreadsheet.'**
  String placesEmptyBody(String organisation);

  /// Title when the server has no organisation set up.
  ///
  /// In en, this message translates to:
  /// **'No places yet'**
  String get placesNoneTitle;

  /// Link back from the import to the tree.
  ///
  /// In en, this message translates to:
  /// **'Back to Places'**
  String get placesBack;

  /// Line under the organisation at the top of the tree.
  ///
  /// In en, this message translates to:
  /// **'The whole organisation'**
  String get placeRootNote;

  /// How many places are directly inside a place.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place inside} other{{count} places inside}}'**
  String placeInsideCount(int count);

  /// A place code shown in the tree.
  ///
  /// In en, this message translates to:
  /// **'Code {code}'**
  String placeCodeShown(String code);

  /// Badge: the place is closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get placeClosed;

  /// Button tooltip: open a place in the tree.
  ///
  /// In en, this message translates to:
  /// **'Show the places inside {name}'**
  String placeOpenInside(String name);

  /// Button tooltip: shut a place in the tree.
  ///
  /// In en, this message translates to:
  /// **'Hide the places inside {name}'**
  String placeShutInside(String name);

  /// Tooltip of the menu of actions for one place.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String placeActions(String name);

  /// Menu item: add a place inside this one.
  ///
  /// In en, this message translates to:
  /// **'Add a place inside'**
  String get placeAddInside;

  /// Menu item and dialog title: change a place name or code.
  ///
  /// In en, this message translates to:
  /// **'Rename or change code'**
  String get placeRename;

  /// Menu item: close a place.
  ///
  /// In en, this message translates to:
  /// **'Close place'**
  String get placeCloseAction;

  /// Menu item: reopen a closed place.
  ///
  /// In en, this message translates to:
  /// **'Reopen place'**
  String get placeReopenAction;

  /// Menu item: delete a place.
  ///
  /// In en, this message translates to:
  /// **'Delete place'**
  String get placeDeleteAction;

  /// Dialog title: add a place.
  ///
  /// In en, this message translates to:
  /// **'Add a place'**
  String get placeAddTitle;

  /// Field label: the place a new place belongs to.
  ///
  /// In en, this message translates to:
  /// **'Goes inside'**
  String get placeParent;

  /// Help under the Goes inside field.
  ///
  /// In en, this message translates to:
  /// **'The place this one belongs to. It can’t be moved later.'**
  String get placeParentHelp;

  /// Note in the rename dialog: where the place is.
  ///
  /// In en, this message translates to:
  /// **'Inside {parent}. A place can’t be moved.'**
  String placeParentFixed(String parent);

  /// Field label: the name of a place.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get placeName;

  /// Help under the place name field.
  ///
  /// In en, this message translates to:
  /// **'For example ‘Mirpur branch’. Places inside the same place need different names.'**
  String get placeNameHelp;

  /// Field label: the short code of a place.
  ///
  /// In en, this message translates to:
  /// **'Code (optional)'**
  String get placeCode;

  /// Help under the place code field.
  ///
  /// In en, this message translates to:
  /// **'A short code your organisation uses, for example MRP10. No two places can have the same code.'**
  String get placeCodeHelp;

  /// Problem: the name is empty.
  ///
  /// In en, this message translates to:
  /// **'Give the place a name.'**
  String get placeErrorName;

  /// Problem: a neighbouring place has the same name.
  ///
  /// In en, this message translates to:
  /// **'Another place inside {parent} already has this name. Choose a different name.'**
  String placeErrorNameTaken(String parent);

  /// Problem: another place has the same code.
  ///
  /// In en, this message translates to:
  /// **'Another place already has this code. Choose a different code.'**
  String get placeErrorCodeTaken;

  /// Problem: the place chosen to hold new places is closed.
  ///
  /// In en, this message translates to:
  /// **'The place above is closed. Reopen it first, or choose an open place.'**
  String get placeErrorParentClosed;

  /// Message after adding a place.
  ///
  /// In en, this message translates to:
  /// **'{name} is added.'**
  String placeAdded(String name);

  /// Dialog title: close a place.
  ///
  /// In en, this message translates to:
  /// **'Close {name}?'**
  String placeCloseTitle(String name);

  /// Dialog text: what closing a place does.
  ///
  /// In en, this message translates to:
  /// **'A closed place can’t be chosen for people or for new places, and it is hidden where you choose a place. Everything recorded there is kept. You can reopen it at any time.'**
  String get placeCloseBody;

  /// Dialog button: close the place.
  ///
  /// In en, this message translates to:
  /// **'Close place'**
  String get placeCloseButton;

  /// Message after closing a place.
  ///
  /// In en, this message translates to:
  /// **'{name} is closed.'**
  String placeClosedDone(String name);

  /// Problem: a place cannot close while open places are inside it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 open place is still inside it. Close or delete that place first.} other{{count} open places are still inside it. Close or delete them first.}}'**
  String placeErrorOpenInside(int count);

  /// Problem: a place cannot close while active people work there.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active person still works here. Move them to another place, or deactivate them, first.} other{{count} active people still work here. Move them to other places, or deactivate them, first.}}'**
  String placeErrorPeople(int count);

  /// Button: open People, showing the active people at this place.
  ///
  /// In en, this message translates to:
  /// **'See who works here'**
  String get placeSeePeople;

  /// Problem: the place at the top cannot be closed or deleted.
  ///
  /// In en, this message translates to:
  /// **'The organisation itself can’t be closed or deleted.'**
  String get placeErrorRoot;

  /// Dialog title: reopen a place.
  ///
  /// In en, this message translates to:
  /// **'Reopen {name}?'**
  String placeReopenTitle(String name);

  /// Dialog text: what reopening a place does.
  ///
  /// In en, this message translates to:
  /// **'It can be chosen again for people and for new places.'**
  String get placeReopenBody;

  /// Dialog button: reopen the place.
  ///
  /// In en, this message translates to:
  /// **'Reopen place'**
  String get placeReopenButton;

  /// Message after reopening a place.
  ///
  /// In en, this message translates to:
  /// **'{name} is open again.'**
  String placeReopenedDone(String name);

  /// Problem: a place cannot reopen inside a closed place.
  ///
  /// In en, this message translates to:
  /// **'The place above it is closed. Reopen that place first.'**
  String get placeErrorAboveClosed;

  /// Dialog title: delete a place.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String placeDeleteTitle(String name);

  /// Dialog text: when to delete a place.
  ///
  /// In en, this message translates to:
  /// **'Delete a place only if it was added by mistake. This can’t be undone. A place that anyone or any record uses can’t be deleted: close it instead.'**
  String get placeDeleteBody;

  /// Dialog button: delete the place.
  ///
  /// In en, this message translates to:
  /// **'Delete place'**
  String get placeDeleteButton;

  /// Message after deleting a place.
  ///
  /// In en, this message translates to:
  /// **'{name} is deleted.'**
  String placeDeletedDone(String name);

  /// Problem: a place in use cannot be deleted.
  ///
  /// In en, this message translates to:
  /// **'This place is in use, so it can’t be deleted. Close it instead: it will no longer be offered, and its records are kept.'**
  String get placeErrorInUse;

  /// Button: close the place that cannot be deleted.
  ///
  /// In en, this message translates to:
  /// **'Close it instead'**
  String get placeCloseInstead;

  /// Heading of the spreadsheet import page.
  ///
  /// In en, this message translates to:
  /// **'Import from a spreadsheet'**
  String get importTitle;

  /// Line under the import heading.
  ///
  /// In en, this message translates to:
  /// **'Add many places at once from a spreadsheet. Places that are already there are kept, never doubled.'**
  String get importSummary;

  /// Spoken label of a step number.
  ///
  /// In en, this message translates to:
  /// **'Step {number}'**
  String importStep(int number);

  /// Import step heading.
  ///
  /// In en, this message translates to:
  /// **'Get your spreadsheet ready'**
  String get importStepFile;

  /// Import rule.
  ///
  /// In en, this message translates to:
  /// **'One row for each place. Put the names in separate columns, from the top level down: for example Region, Area, Branch.'**
  String get importRuleRows;

  /// Import rule.
  ///
  /// In en, this message translates to:
  /// **'The first row holds the column names.'**
  String get importRuleHeader;

  /// Import rule. Keep the column name code in English: the app looks for it.
  ///
  /// In en, this message translates to:
  /// **'To give a place a code, add a last column named ‘code’. The code goes on the last place in the row.'**
  String get importRuleCode;

  /// Import rule.
  ///
  /// In en, this message translates to:
  /// **'Empty cells at the end of a row are fine: that row stops at a higher level.'**
  String get importRuleEmpty;

  /// Import rule.
  ///
  /// In en, this message translates to:
  /// **'Places that are already there (the same name at the same level) are reused, so you can import the same file again safely.'**
  String get importRuleReuse;

  /// Import rule.
  ///
  /// In en, this message translates to:
  /// **'Bangla names are fine.'**
  String get importRuleBangla;

  /// Import rule. Menu names stay in English, as the programs show them.
  ///
  /// In en, this message translates to:
  /// **'Save the file as ‘CSV UTF-8’. In Excel: File › Save As › CSV UTF-8. In Google Sheets: File › Download › Comma-separated values (.csv).'**
  String get importRuleSave;

  /// Import rule: the limits.
  ///
  /// In en, this message translates to:
  /// **'Up to 5,000 rows, with up to 10 levels in a row.'**
  String get importRuleLimits;

  /// Caption of the example table.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get importExample;

  /// Example column name.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get importExampleRegion;

  /// Example column name.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get importExampleArea;

  /// Example column name.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get importExampleBranch;

  /// Example place name.
  ///
  /// In en, this message translates to:
  /// **'Dhaka region'**
  String get importExampleRegion1;

  /// Example place name.
  ///
  /// In en, this message translates to:
  /// **'Mirpur area'**
  String get importExampleArea1;

  /// Example place name.
  ///
  /// In en, this message translates to:
  /// **'Mirpur-10 branch'**
  String get importExampleBranch1;

  /// Example place name.
  ///
  /// In en, this message translates to:
  /// **'Pallabi branch'**
  String get importExampleBranch2;

  /// Example place name.
  ///
  /// In en, this message translates to:
  /// **'Khulna region'**
  String get importExampleRegion2;

  /// Example place name.
  ///
  /// In en, this message translates to:
  /// **'Sonadanga area'**
  String get importExampleArea2;

  /// Import step heading.
  ///
  /// In en, this message translates to:
  /// **'Choose where the new places go'**
  String get importStepParent;

  /// Field label: the place the imported places go inside.
  ///
  /// In en, this message translates to:
  /// **'New places go inside'**
  String get importParent;

  /// Help under the New places go inside field.
  ///
  /// In en, this message translates to:
  /// **'The places in the first column go directly inside this place.'**
  String get importParentHelp;

  /// Import step heading.
  ///
  /// In en, this message translates to:
  /// **'Choose the file'**
  String get importStepChoose;

  /// Button: choose the spreadsheet file.
  ///
  /// In en, this message translates to:
  /// **'Choose a CSV file'**
  String get importChoose;

  /// Button: choose a different file.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get importChooseAnother;

  /// The chosen file.
  ///
  /// In en, this message translates to:
  /// **'File: {name}'**
  String importFileName(String name);

  /// How many rows of places the file has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row of places} other{{count} rows of places}}'**
  String importRowCount(int count);

  /// Switch: read the first row as column names.
  ///
  /// In en, this message translates to:
  /// **'The first row has column names'**
  String get importHeader;

  /// Help under the first row switch.
  ///
  /// In en, this message translates to:
  /// **'Turn this off if the first row is a place.'**
  String get importHeaderHelp;

  /// The first row, read as column names.
  ///
  /// In en, this message translates to:
  /// **'Column names: {names}'**
  String importColumns(String names);

  /// Which column holds the codes.
  ///
  /// In en, this message translates to:
  /// **'Codes are read from the column ‘{name}’.'**
  String importCodeColumn(String name);

  /// File problem.
  ///
  /// In en, this message translates to:
  /// **'This file is too big. A list of places can be up to 5 MB.'**
  String get importErrorTooBig;

  /// File problem.
  ///
  /// In en, this message translates to:
  /// **'This is an Excel file. Save it as ‘CSV UTF-8’ first, then choose the CSV file.'**
  String get importErrorExcel;

  /// File problem.
  ///
  /// In en, this message translates to:
  /// **'This file is not saved as CSV UTF-8, so Bangla and some other letters would be lost. Save it again as ‘CSV UTF-8’, then choose it again.'**
  String get importErrorNotUtf8;

  /// File problem.
  ///
  /// In en, this message translates to:
  /// **'On line {line}, a cell starts with a quotation mark (\") that is never closed. Check that line, save the file again, then choose it again.'**
  String importErrorQuote(int line);

  /// File problem.
  ///
  /// In en, this message translates to:
  /// **'This file has no places in it.'**
  String get importErrorEmpty;

  /// File problem.
  ///
  /// In en, this message translates to:
  /// **'This file has column names but no places under them. If the first row is a place, turn off ‘The first row has column names’.'**
  String get importErrorOnlyHeader;

  /// File problem.
  ///
  /// In en, this message translates to:
  /// **'This file has {count} rows of places. A file can hold up to 5,000. Split it into smaller files and import them one after another.'**
  String importErrorTooMany(int count);

  /// Row problem.
  ///
  /// In en, this message translates to:
  /// **'This row has a code but no place name.'**
  String get importRowNoName;

  /// Row problem. The column is a spreadsheet letter such as B.
  ///
  /// In en, this message translates to:
  /// **'The cell in column {column} is empty, but there is a name after it. Fill it in, or move the names to the left.'**
  String importRowGap(String column);

  /// Row problem.
  ///
  /// In en, this message translates to:
  /// **'This row has more than 10 levels.'**
  String get importRowTooDeep;

  /// Row problem.
  ///
  /// In en, this message translates to:
  /// **'A name in this row is longer than 200 characters.'**
  String get importRowNameTooLong;

  /// Row problem.
  ///
  /// In en, this message translates to:
  /// **'The code in this row is longer than 50 characters.'**
  String get importRowCodeTooLong;

  /// Import step heading.
  ///
  /// In en, this message translates to:
  /// **'Check what will be added'**
  String get importStepCheck;

  /// While the server checks the file.
  ///
  /// In en, this message translates to:
  /// **'Checking the file…'**
  String get importChecking;

  /// How many places the import adds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No new places} =1{1 new place} other{{count} new places}}'**
  String importNewCount(int count);

  /// How many places in the file are already there.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{none already there} =1{1 already there} other{{count} already there}}'**
  String importExistingCount(int count);

  /// Heading of the list of problems in the file.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 problem to fix} other{{count} problems to fix}}'**
  String importProblems(int count);

  /// Help above the list of problems.
  ///
  /// In en, this message translates to:
  /// **'Nothing is added until every problem is fixed. Fix them in your spreadsheet, save it as ‘CSV UTF-8’ again, then choose it again.'**
  String get importProblemsHelp;

  /// The line of the file a problem is on.
  ///
  /// In en, this message translates to:
  /// **'Line {line}'**
  String importLine(int line);

  /// When the file adds no place.
  ///
  /// In en, this message translates to:
  /// **'Every place in this file is already there, so there is nothing to add.'**
  String get importNothingNew;

  /// Heading of the preview tree.
  ///
  /// In en, this message translates to:
  /// **'How the places will look'**
  String get importPreview;

  /// Badge in the preview: the import adds this place.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get importNew;

  /// Note in the preview: this place is already there.
  ///
  /// In en, this message translates to:
  /// **'Already there'**
  String get importAlready;

  /// Button: run the import.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 place} other{Add {count} places}}'**
  String importAdd(int count);

  /// Button label while the import runs.
  ///
  /// In en, this message translates to:
  /// **'Adding places…'**
  String get importAdding;

  /// Message after the import.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place is added.} other{{count} places are added.}}'**
  String importDone(int count);

  /// When the real import finds problems the check did not.
  ///
  /// In en, this message translates to:
  /// **'Something changed since the check, so nothing was added. Fix the problems below, then choose the file again.'**
  String get importChanged;

  /// Dialog title: leaving the import before adding.
  ///
  /// In en, this message translates to:
  /// **'Leave without adding the places?'**
  String get leaveImportTitle;

  /// Dialog text: leaving the import before adding.
  ///
  /// In en, this message translates to:
  /// **'The places in the file you chose have not been added yet.'**
  String get leaveImportBody;

  /// Dialog button: leave the import.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveImportLeave;

  /// Help under a person’s place when that place is closed.
  ///
  /// In en, this message translates to:
  /// **'This place is closed. Choose an open place if this person moves.'**
  String get personPlaceClosedHelp;

  /// Row problem from the server: the row names a closed place.
  ///
  /// In en, this message translates to:
  /// **'‘{name}’ is closed. Reopen it first, or remove this row.'**
  String importServerClosed(String name);

  /// Row problem from the server: the place already has another code.
  ///
  /// In en, this message translates to:
  /// **'‘{name}’ already has the code {code}. Use the same code, or leave the cell empty.'**
  String importServerCodeOther(String name, String code);

  /// Row problem from the server: a code repeats in the file.
  ///
  /// In en, this message translates to:
  /// **'The code {code} is used more than once in this file. Each place needs its own code.'**
  String importServerCodeTwice(String code);

  /// Row problem from the server: another place has the code.
  ///
  /// In en, this message translates to:
  /// **'Another place already has the code {code}. Choose a different code.'**
  String importServerCodeTaken(String code);

  /// Row problem from the server: the row has no place name.
  ///
  /// In en, this message translates to:
  /// **'This row has no place name.'**
  String get importProblemNoName;

  /// Row problem from the server: the row has too many levels.
  ///
  /// In en, this message translates to:
  /// **'This row has more than {limit} levels.'**
  String importProblemTooDeep(int limit);
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
