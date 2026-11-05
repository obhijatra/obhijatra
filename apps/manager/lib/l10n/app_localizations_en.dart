// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Obhijatra Manager';

  @override
  String get navMain => 'Main menu';

  @override
  String get navForms => 'Forms';

  @override
  String get navSubmissions => 'Submissions';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAbout => 'About';

  @override
  String get badgeWebApp => 'Web app';

  @override
  String get badgeDesktopApp => 'Desktop app';

  @override
  String get languageSwitch => 'Language';

  @override
  String get accountMenu => 'Account menu';

  @override
  String get menuSignOut => 'Sign out';

  @override
  String get loading => 'Loading';

  @override
  String get offlineTitle => 'You are offline';

  @override
  String get offlineBody =>
      'Check your internet connection. Your data will appear again when it is back.';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get actionSignInAgain => 'Sign in again';

  @override
  String get actionClose => 'Close';

  @override
  String get actionChooseFile => 'Choose another file';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get unknownValue => 'Unknown';

  @override
  String get problemOffline =>
      'We can’t reach the server. Check your internet connection and try again.';

  @override
  String get problemTimeout =>
      'The server took too long to answer. Try again in a moment.';

  @override
  String get problemServerBusy =>
      'The server is busy right now. Wait a minute, then try again.';

  @override
  String get problemServerError =>
      'The server had a problem. Try again. If it keeps happening, tell your organisation admin.';

  @override
  String get problemSignInRequired =>
      'Your session has ended. Sign in again to carry on.';

  @override
  String get problemSignInFailed =>
      'The email or password is not right, or this account is switched off. Check them and try again.';

  @override
  String get problemNotAllowed =>
      'Your account is not allowed to do this. Ask your organisation admin if you need access.';

  @override
  String get problemNotFound =>
      'We could not find this. It may have been removed, or your account may not have access to it.';

  @override
  String get problemTooLarge =>
      'This file is too big. Forms and submissions can be up to 10 MB.';

  @override
  String get problemRejected =>
      'The server did not accept this. Check what you entered and try again.';

  @override
  String get problemVersionExists =>
      'This version of the form was already uploaded. Change the version number in your form tool, then upload the file again.';

  @override
  String get problemCommentNotSaved =>
      'Your decision was saved, but this server can’t keep comments yet. Ask your organisation admin to update the server.';

  @override
  String get problemUnreadableFile =>
      'We could not read this file. Check that it is an XForm (.xml) file and try again.';

  @override
  String get problemFormUnavailable =>
      'We could not load this form’s definition, so the answers are hidden to keep protected answers safe.';

  @override
  String get problemUnknown =>
      'Something went wrong. Try again. If it keeps happening, tell your organisation admin.';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInIntro =>
      'Use the email and password your organisation admin gave you.';

  @override
  String get signInEmail => 'Email';

  @override
  String get signInPassword => 'Password';

  @override
  String get signInShowPassword => 'Show password';

  @override
  String get signInHidePassword => 'Hide password';

  @override
  String get signInServer => 'Server address';

  @override
  String get signInServerHelp =>
      'The web address of your organisation’s Obhijatra server, for example https://data.example.org';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signInWorking => 'Signing in…';

  @override
  String get fieldRequired => 'Please fill this in.';

  @override
  String get serverInvalid =>
      'This does not look like a web address. It should look like https://data.example.org';

  @override
  String get serverInsecure =>
      'Use an address that starts with https:// so that your password and data are protected on their way.';

  @override
  String get serverTestingOnly =>
      'Testing only: this address is on your own network and is not protected. Do not use it for real data.';

  @override
  String get formsTitle => 'Forms';

  @override
  String get formsUploadTitle => 'Upload a form';

  @override
  String get formsUploadHelp =>
      'Choose an XForm (.xml) file. Files made in Kobo or ODK work too.';

  @override
  String get formsChooseFile => 'Choose a file';

  @override
  String get formsYourForms => 'Your forms';

  @override
  String formsVersionCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString versions',
      one: '1 version',
    );
    return '$_temp0';
  }

  @override
  String formsPublishedSummary(String version) {
    return 'Version $version, published';
  }

  @override
  String get formsDraftSummary => 'Draft, not published yet';

  @override
  String get formsNoVersions => 'No versions yet';

  @override
  String get formsEmptyTitle => 'No forms yet';

  @override
  String get formsEmptyBodyAdmin => 'Upload your first form to get started.';

  @override
  String get formsEmptyBodyViewer =>
      'Your organisation admin has not published a form yet.';

  @override
  String get formsSelectPrompt =>
      'Choose a form on the left to see its versions.';

  @override
  String get formsSelectVersion => 'Choose a version to see its checks.';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String versionUploaded(String date) {
    return 'Uploaded $date';
  }

  @override
  String versionPublished(String date) {
    return 'Published $date';
  }

  @override
  String get badgePublished => 'Published';

  @override
  String get badgeDraft => 'Draft';

  @override
  String get badgeNeedsFix => 'Needs a fix';

  @override
  String versionHeading(String form, String version) {
    return '$form, version $version';
  }

  @override
  String get publishCheckTitle => 'Publish check';

  @override
  String get formCheckTitle => 'Form check';

  @override
  String publishCheckedQuestions(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'We checked $countString questions.',
      one: 'We checked 1 question.',
      zero: 'We found no questions.',
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
      other: 'Fix $countString things before you publish.',
      one: 'Fix 1 thing before you publish.',
    );
    return '$_temp0';
  }

  @override
  String get publishAllClear => 'Nothing to fix. You can publish this version.';

  @override
  String get checkKindFix => 'Fix before publishing';

  @override
  String get checkKindProtected => 'Protected';

  @override
  String get checkKindPassed => 'Passed';

  @override
  String get checkKindNote => 'Good to know';

  @override
  String get checkUnreadable =>
      'This file can’t be read as a form. It may be damaged. Export it again from your form tool and upload the new file.';

  @override
  String get checkNotXForm =>
      'This file is XML, but it is not an XForm. Upload the XForm (.xml) file exported from your form tool.';

  @override
  String get checkWellFormed => 'The file is a readable form.';

  @override
  String get checkVersionMissing =>
      'The form has no version number. Add a version in your form tool, export it again and upload the new file.';

  @override
  String checkVersionOk(String version) {
    return 'The form has a version number: $version.';
  }

  @override
  String get checkFormIdMissing =>
      'The form has no form id. Set a form id in your form tool, export it again and upload the new file.';

  @override
  String checkFormIdOk(String formId) {
    return 'The form has a form id: $formId.';
  }

  @override
  String checkVersionExists(String version) {
    return 'Version $version of this form was already uploaded. Change the version number in your form tool and upload the file again.';
  }

  @override
  String get checkKoboMatrix =>
      'Kobo ‘question matrix’ isn’t supported — use one ‘select one’ question per row instead.';

  @override
  String get checkKoboScore =>
      'Kobo ‘rating’ questions aren’t supported — use one ‘select one’ question per item instead.';

  @override
  String get checkKoboRank =>
      'Kobo ‘ranking’ questions aren’t supported — use ‘select one’ questions such as ‘first choice’ and ‘second choice’ instead.';

  @override
  String checkWhere(int count, String names) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Questions: $names',
      one: 'Question: $names',
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
      other: '$countString answers will be protected: $names.',
      one: '1 answer will be protected: $names.',
    );
    return '$_temp0';
  }

  @override
  String get checkLanguagesOk =>
      'Every question has a label in both languages.';

  @override
  String checkLanguagesPartial(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString questions are missing their label in one language.',
      one: '1 question is missing its label in one language.',
    );
    return '$_temp0';
  }

  @override
  String get checkSingleLanguage => 'The form is written in one language only.';

  @override
  String get uploadXlsNotice =>
      'Spreadsheet (.xlsx) forms can’t be uploaded yet. Converting them arrives in Phase 2. For now, upload the XForm (.xml) file. Kobo and ODK can export one.';

  @override
  String get uploadChoosePrompt =>
      'Choose the XForm (.xml) file from your computer. Spreadsheet (.xlsx) forms are not supported yet: converting them arrives in Phase 2.';

  @override
  String uploadFile(String name) {
    return 'File: $name';
  }

  @override
  String get uploadReady =>
      'This file passed every check. It is saved as a draft first, and you can publish it afterwards.';

  @override
  String get uploadBlocked =>
      'This file can’t be uploaded yet. Fix the things below, then choose the fixed file.';

  @override
  String get uploadButton => 'Upload as draft';

  @override
  String get uploadUploading => 'Uploading…';

  @override
  String get uploadDone =>
      'Uploaded as a draft. Check it over, then publish when you are ready.';

  @override
  String get publishButton => 'Publish';

  @override
  String get publishHint => 'You can publish when nothing is left to fix.';

  @override
  String publishConfirmTitle(String version) {
    return 'Publish version $version?';
  }

  @override
  String get publishConfirmBody =>
      'Once a version is published it can’t be changed. To change the form later, you will upload a new version.';

  @override
  String get publishConfirmNo => 'Not yet';

  @override
  String publishDone(String version) {
    return 'Version $version is published.';
  }

  @override
  String get publishedReadOnly =>
      'This version is published, so it can’t be changed. To change the form, upload a new version.';

  @override
  String get adminOnlyForms =>
      'Only an organisation admin can upload or publish forms.';

  @override
  String get subsTitle => 'Submissions';

  @override
  String subsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString submissions',
      one: '1 submission',
      zero: 'No submissions match',
    );
    return '$_temp0';
  }

  @override
  String get filterForm => 'Form';

  @override
  String get filterAllForms => 'All forms';

  @override
  String get filterDates => 'Dates';

  @override
  String get filterLast7 => 'Last 7 days';

  @override
  String get filterLast30 => 'Last 30 days';

  @override
  String get filterAllTime => 'All time';

  @override
  String get filterChoose => 'Choose dates…';

  @override
  String filterRange(String from, String to) {
    return '$from to $to';
  }

  @override
  String get filterReviewState => 'Review state';

  @override
  String get reviewAll => 'All';

  @override
  String get stateReceived => 'Received';

  @override
  String get stateEdited => 'Edited';

  @override
  String get stateHasIssues => 'Has issues';

  @override
  String get stateApproved => 'Approved';

  @override
  String get stateRejected => 'Rejected';

  @override
  String get colDate => 'Date';

  @override
  String get colForm => 'Form';

  @override
  String get colCollector => 'Collector';

  @override
  String get colLocation => 'Location';

  @override
  String get colReview => 'Review';

  @override
  String dateToday(String time) {
    return 'Today, $time';
  }

  @override
  String dateYesterday(String time) {
    return 'Yesterday, $time';
  }

  @override
  String dateOther(String date, String time) {
    return '$date, $time';
  }

  @override
  String get subsEmptyTitle => 'No submissions here';

  @override
  String get subsEmptyBody =>
      'Nothing matches these filters. Try a wider date range or another review state.';

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

    return 'Showing $fromString–$toString of $totalString';
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

    return 'Page $pageString of $pagesString';
  }

  @override
  String get pagingPrevious => 'Previous page';

  @override
  String get pagingNext => 'Next page';

  @override
  String get refresh => 'Refresh';

  @override
  String get detailClose => 'Close details';

  @override
  String detailMeta(String collector, String location, String date) {
    return '$collector · $location · $date';
  }

  @override
  String get detailProtectedNote =>
      'This app can’t show protected answers, so they stay safe even on a shared computer.';

  @override
  String get protectedAnswer =>
      'Protected — open in the Obhijatra desktop app to view';

  @override
  String get detailAnswers => 'Answers';

  @override
  String get detailNoAnswers => 'This submission has no answers to show.';

  @override
  String get detailComment => 'Review note';

  @override
  String get actionApprove => 'Approve';

  @override
  String get actionHasIssues => 'Has issues';

  @override
  String get actionReject => 'Reject';

  @override
  String get reviewReadOnly =>
      'Your role can read submissions but can’t review them.';

  @override
  String get reviewIssuesTitle => 'Mark as having issues';

  @override
  String get reviewIssuesLabel => 'What needs checking?';

  @override
  String get reviewRejectTitle => 'Reject this submission';

  @override
  String get reviewRejectLabel => 'Why are you rejecting it?';

  @override
  String get reviewConfirmIssues => 'Mark as having issues';

  @override
  String get reviewCommentHelp =>
      'Your note is saved with the submission and others can read it.';

  @override
  String get reviewCommentRequired => 'Please write a short note.';

  @override
  String reviewCommentTooLong(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'Keep it under $maxString characters.';
  }

  @override
  String reviewSaved(String state) {
    return 'Saved: $state.';
  }

  @override
  String get reviewSaving => 'Saving…';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHelp =>
      'This changes the language of the whole app. We remember your choice on this computer.';

  @override
  String get settingsAccount => 'Your account';

  @override
  String get accountName => 'Name';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountRole => 'Role';

  @override
  String get accountOrganisation => 'Organisation';

  @override
  String get accountServer => 'Server';

  @override
  String get settingsSignOutHelp =>
      'You will need your email and password to sign in again.';

  @override
  String get roleSupervisor => 'Supervisor';

  @override
  String get roleBranchManager => 'Branch manager';

  @override
  String get roleMe => 'Monitoring and evaluation';

  @override
  String get roleOrgAdmin => 'Organisation admin';

  @override
  String get roleDonorReadonly => 'Donor (read only)';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutPreAlpha => 'Pre-alpha. Not ready for real use yet.';

  @override
  String get aboutLicenceTitle => 'Licence';

  @override
  String get aboutLicenceBody =>
      'Obhijatra is free software. You can use it, study it, share it and change it under the GNU Affero General Public License, version 3 (AGPL-3.0). It comes with no warranty. If you run a changed version for other people over a network, you must offer them the source code of your changes.';

  @override
  String get aboutSourceTitle => 'Source code';

  @override
  String get aboutSourceOpen => 'Open the source code';

  @override
  String aboutSourceFailed(String url) {
    return 'We couldn’t open the link. The address is $url';
  }

  @override
  String get aboutLicencesTitle => 'Open-source licences';

  @override
  String get aboutLicencesHelp =>
      'The other free software Obhijatra is built with, and the licence of each.';

  @override
  String get aboutLicencesButton => 'See the licences';

  @override
  String get aboutMadeBy => 'Made by Aninda Studio';

  @override
  String get signInOr => 'or';

  @override
  String get signInGoogle => 'Continue with Google';

  @override
  String get signInSms => 'Sign in with an SMS code';

  @override
  String get signInSmsAdminNote =>
      'SMS codes are not available to organisation admins.';

  @override
  String get signInOtherWays => 'Other ways to sign in';

  @override
  String get smsNumberIntro =>
      'We will send a 6-digit code by SMS to the mobile number on your account.';

  @override
  String get smsNumberLabel => 'Mobile number';

  @override
  String get smsNumberHelp =>
      'For example 01712345678. For a number outside Bangladesh, start with + and the country code.';

  @override
  String get smsNumberInvalid =>
      'This does not look like a mobile number. Type it like 01712345678, or start with + and the country code.';

  @override
  String get smsSendCode => 'Send code';

  @override
  String get actionSending => 'Sending…';

  @override
  String get smsCodeTitle => 'Enter the code';

  @override
  String smsCodeSent(String phone) {
    return 'If $phone can sign in with an SMS code, a 6-digit code is on its way.';
  }

  @override
  String smsCodeLifetime(int minutes) {
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'The code works for $minutesString minutes.',
      one: 'The code works for 1 minute.',
    );
    return '$_temp0';
  }

  @override
  String get smsCodeLabel => '6-digit code';

  @override
  String get smsCodeIncomplete => 'Enter all 6 digits of the code.';

  @override
  String get smsCodeWrong =>
      'That code is wrong or has expired. Check the SMS and try again, or send a new code.';

  @override
  String get smsCodeUsedUp =>
      'That code was tried 3 times, so it no longer works. Send a new code.';

  @override
  String get smsCodeExpired => 'This code has expired. Send a new code.';

  @override
  String get smsCodeChecking => 'Checking…';

  @override
  String smsResendIn(String time) {
    return 'Send a new code in $time';
  }

  @override
  String get smsResend => 'Send a new code';

  @override
  String get smsNewCodeSent => 'A new code is on its way.';

  @override
  String get smsChangeNumber => 'Change number';

  @override
  String get googleWaitingTitle => 'Waiting for Google…';

  @override
  String get googleWaitingBody =>
      'Google’s sign-in page opens in your web browser. Choose your Google account there, then come back to this window.';

  @override
  String get googleOpenHelp =>
      'If Google’s page did not open, use this button.';

  @override
  String get googleOpen => 'Open Google sign-in';

  @override
  String get problemGoogleNoAccount =>
      'No Obhijatra account here uses this Google email address. Ask your organisation admin to add it, or use another way to sign in.';

  @override
  String get problemGoogleUnconfirmed =>
      'Your organisation admin must confirm your email address before you can sign in with Google.';

  @override
  String get problemGoogleNotAllowed =>
      'This account cannot sign in. Ask your organisation admin.';

  @override
  String get problemGoogleNoEmail =>
      'Google did not share a confirmed email address for this Google account. Use another Google account, or another way to sign in.';

  @override
  String get problemGoogleUnavailable =>
      'Google sign-in is not switched on for this server. Use another way to sign in.';

  @override
  String get problemGoogleFailed =>
      'Google sign-in did not finish. Try again, or use another way to sign in.';

  @override
  String get problemSmsOff =>
      'Sign-in by SMS code is switched off on this server. Use another way to sign in.';

  @override
  String get problemPhoneInvalid =>
      'This does not look like a mobile number. Type it like 01712345678, or start with + and the country code.';

  @override
  String get problemCodeWrong =>
      'That code is wrong or has expired. Check the SMS and try again, or send a new code.';

  @override
  String get problemTooManyCodes =>
      'Too many codes were asked for. Wait 15 minutes, or use another way to sign in.';

  @override
  String get problemTooManyTries =>
      'Too many tries from this connection. Wait 15 minutes, then ask for a new code.';

  @override
  String get problemTooManyTests =>
      'Too many test messages. Wait 15 minutes and try again.';

  @override
  String get problemSettingsInvalid =>
      'Some settings need attention. Look for the messages under the fields.';

  @override
  String get accountPhone => 'Mobile number';

  @override
  String get signInMethodsTitle => 'Sign-in methods';

  @override
  String get signInMethodsSummary =>
      'Everyone can sign in with an email address and password. You can also let people sign in with Google or with an SMS code.';

  @override
  String get signInMethodsOpen => 'Set up sign-in methods';

  @override
  String get settingsBack => 'Back to Settings';

  @override
  String get methodOn => 'On';

  @override
  String get methodOff => 'Off';

  @override
  String get googleTitle => 'Google';

  @override
  String get googleDescription =>
      'People click “Continue with Google” and choose their Google account. It works only for people whose account here has the same email address, confirmed by an admin.';

  @override
  String get googleRedirectLabel => 'Redirect address for Google';

  @override
  String get googleRedirectHelp =>
      'Add this address to your Google client under Authorised redirect URIs.';

  @override
  String get googleRedirectWarning =>
      'Google needs an https:// address with a domain name, such as https://data.example.org. Ask whoever runs your server to give it one. SMS codes work without it.';

  @override
  String get actionCopy => 'Copy';

  @override
  String get copiedRedirect => 'Redirect address copied.';

  @override
  String get googleClientId => 'Client ID';

  @override
  String get googleClientIdHelp =>
      'From your Google Cloud project. It ends with .apps.googleusercontent.com.';

  @override
  String get googleClientSecret => 'Client secret';

  @override
  String get googleClientSecretHelp =>
      'Google shows it once, when you create the client. Keep it private.';

  @override
  String get secretSavedKeep => 'Saved. Leave empty to keep it.';

  @override
  String get secretShow => 'Show secret';

  @override
  String get secretHide => 'Hide secret';

  @override
  String get setupGuide => 'How to set this up';

  @override
  String get smsTitle => 'SMS codes';

  @override
  String get smsDescription =>
      'People type their mobile number and receive a 6-digit code by SMS. Your organisation pays your SMS provider for each message. SMS codes are not available to organisation admins.';

  @override
  String get smsProviderTitle => 'Your SMS provider';

  @override
  String get smsProviderHelp =>
      'Fill these in from your SMS provider’s guide for sending one message.';

  @override
  String get smsMethod => 'Method';

  @override
  String get smsAddress => 'Address';

  @override
  String get smsAddressHelp =>
      'The provider’s web address for sending a message. It starts with https://';

  @override
  String get smsBodyFormat => 'Body format';

  @override
  String get smsFormatJson => 'JSON';

  @override
  String get smsFormatForm => 'Form';

  @override
  String get smsBody => 'Body';

  @override
  String get smsBodyHelp =>
      'Copy the example from your provider’s guide, then put placeholders where the values go.';

  @override
  String get smsPlaceholders => 'Placeholders';

  @override
  String get smsPlaceholdersHelp =>
      'Click one to put it where the cursor is in the Address, the Body or a header value. The server fills it in for each message.';

  @override
  String get smsPlaceholderPhone =>
      'the number with a plus sign, for example +8801712345678';

  @override
  String get smsPlaceholderDigits =>
      'the number without a plus sign, for example 8801712345678';

  @override
  String get smsPlaceholderMessage => 'the text of the SMS';

  @override
  String get smsPlaceholderSecret => 'your secret key, kept hidden';

  @override
  String smsInsertPlaceholder(String placeholder) {
    return 'Insert $placeholder';
  }

  @override
  String get smsHeaders => 'Extra headers';

  @override
  String get smsHeadersHelp =>
      'Only if your provider’s guide asks for them, for example Authorization.';

  @override
  String get smsHeaderName => 'Name';

  @override
  String get smsHeaderValue => 'Value';

  @override
  String get smsHeaderAdd => 'Add a header';

  @override
  String get smsHeaderRemove => 'Remove this header';

  @override
  String smsHeadersMax(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'You can add up to $countString headers.';
  }

  @override
  String get smsSecret => 'Secret key';

  @override
  String smsSecretHelp(String placeholder) {
    return 'Your provider’s API key or token. Type it here, and put $placeholder where the guide shows the key.';
  }

  @override
  String get smsSuccessText => 'Success text';

  @override
  String get smsSuccessTextHelp =>
      'Optional. What the provider replies when it accepts a message, for example SUCCESS. Leave empty if you are not sure.';

  @override
  String get smsTestTitle => 'Send test SMS';

  @override
  String get smsTestHelp =>
      'Sends a test message with the settings above, even before you save them.';

  @override
  String get smsTestNumber => 'Mobile number for the test';

  @override
  String get smsTestButton => 'Send test SMS';

  @override
  String get smsResultTest => 'Test result';

  @override
  String get smsResultLast => 'Last message sent by the server';

  @override
  String get smsResultSent => 'Sent. The provider accepted the message.';

  @override
  String get smsResultNotSent => 'Not sent.';

  @override
  String smsResultStatus(String status) {
    return 'Provider status: $status';
  }

  @override
  String get smsResultNoAnswer => 'The provider did not answer.';

  @override
  String get smsResultReply => 'Provider reply';

  @override
  String smsResultAt(String time) {
    return 'Time: $time';
  }

  @override
  String get smsResultNone =>
      'No message has been sent since the server last started.';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSaving => 'Saving…';

  @override
  String get signInMethodsSaved => 'Sign-in methods saved.';

  @override
  String get unsavedChanges => 'You have unsaved changes.';

  @override
  String get leaveTitle => 'Leave without saving?';

  @override
  String get leaveBody => 'Your changes to the sign-in methods will be lost.';

  @override
  String get leaveStay => 'Stay';

  @override
  String get leaveDiscard => 'Leave without saving';
}
