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
  String get roleMe => 'M&E officer';

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
  String get problemGoogleUnmanaged =>
      'Google cannot vouch that this email address belongs to this Google account. Sign in with a Gmail address or your organisation\'s Google Workspace account, or use another way to sign in.';

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

  @override
  String get navPeople => 'People';

  @override
  String get roleFieldOfficer => 'Field officer';

  @override
  String get peopleTitle => 'People';

  @override
  String get peopleSummary =>
      'Add the people who use Obhijatra, choose what each can do, and help them sign in.';

  @override
  String get peopleAdd => 'Add person';

  @override
  String get peopleKindLabel => 'Kind of staff';

  @override
  String get kindStaff => 'Office staff';

  @override
  String get kindField => 'Field staff';

  @override
  String get peopleSearch => 'Search';

  @override
  String get peopleSearchHint => 'Name, email or mobile number';

  @override
  String get peopleSearchClear => 'Clear search';

  @override
  String get peopleStatus => 'Status';

  @override
  String get peopleStatusAll => 'Everyone';

  @override
  String get statusActive => 'Active';

  @override
  String get statusDeactivated => 'Deactivated';

  @override
  String get statusLocked => 'Locked';

  @override
  String get statusMustChoose => 'Must choose a password';

  @override
  String get personPlace => 'Place';

  @override
  String get placeAll => 'All places';

  @override
  String get peopleSort => 'Order';

  @override
  String get peopleSortNewest => 'Newest first';

  @override
  String get peopleSortName => 'Name, A to Z';

  @override
  String get emailConfirmed => 'Confirmed';

  @override
  String get peopleEmptyStaffTitle => 'No office staff yet';

  @override
  String get peopleEmptyFieldTitle => 'No field staff yet';

  @override
  String get peopleEmptyBody => 'Use ‘Add person’ to add the first one.';

  @override
  String get peopleNoMatchTitle => 'Nobody matches';

  @override
  String get peopleNoMatchBody => 'Try another search, status or place.';

  @override
  String get peopleNoLockedTitle => 'Nobody is locked out';

  @override
  String get peopleNoLockedBody =>
      'People appear here when their sign-in is locked after too many wrong passwords.';

  @override
  String get peopleBack => 'Back to People';

  @override
  String get personDetails => 'Details';

  @override
  String get personName => 'Name';

  @override
  String get personKind => 'Kind';

  @override
  String get personKindHelp =>
      'Office staff use this app. Field staff use the Obhijatra field app on a phone. This can’t be changed later.';

  @override
  String get personKindFixed => 'This can’t be changed.';

  @override
  String get personPlaceHelp => 'Where this person works.';

  @override
  String get personPlaceChoose => 'Choose a place';

  @override
  String get placeChange => 'Change';

  @override
  String get placeSearch => 'Search places';

  @override
  String get placeNoMatch => 'No place matches.';

  @override
  String get placeNone =>
      'There are no places yet. Ask whoever runs your server to add them.';

  @override
  String get personEmailHelp =>
      'Used to sign in with a password or with Google.';

  @override
  String get personVerified => 'Email address confirmed';

  @override
  String get personVerifiedHelp =>
      'Turn on when you are sure this address belongs to the person. Needed for Google sign-in.';

  @override
  String get personPhoneHelp =>
      'Needed for SMS-code sign-in. Not available to organisation admins.';

  @override
  String get personHowSignIn => 'How will they sign in?';

  @override
  String get personSignInOtp => 'Email and a one-time password';

  @override
  String get personSignInOtpHelp =>
      'You will see a password to give them. They choose their own the first time they sign in.';

  @override
  String get personSignInOtpNeedsEmail => 'Add an email address to use this.';

  @override
  String get personSignInOther => 'SMS code or Google only';

  @override
  String get personSignInOtherHelp =>
      'No password to give. They sign in with a code sent to their mobile, or with Google.';

  @override
  String get personCannotSignIn =>
      'With these details they can’t sign in yet. Google sign-in needs a confirmed email address. SMS-code sign-in needs a mobile number and is not available to organisation admins.';

  @override
  String get personAdding => 'Adding…';

  @override
  String personAdded(String name) {
    return '$name is added.';
  }

  @override
  String personAddedHeading(String name) {
    return '$name is added';
  }

  @override
  String get personSaved => 'Changes saved.';

  @override
  String get personSignOutNote =>
      'Changes to sign-in details, role or status sign this person out on their devices.';

  @override
  String get leavePersonBody => 'Your changes to this person will be lost.';

  @override
  String get personErrorName => 'Type the person’s name.';

  @override
  String get personErrorRole => 'Choose a role.';

  @override
  String get personErrorPlace => 'Choose a place.';

  @override
  String get personErrorEmailInvalid =>
      'This does not look like an email address.';

  @override
  String get personErrorEmailOrPhone =>
      'Give an email address or a mobile number, so this person can sign in.';

  @override
  String get personErrorAdminEmail =>
      'An organisation admin needs an email address. SMS-code sign-in is not available to organisation admins.';

  @override
  String get personErrorOtpEmail =>
      'A one-time password needs an email address to sign in with.';

  @override
  String get personErrorEmailTaken =>
      'Someone else already has this email address.';

  @override
  String get personErrorPhoneTaken =>
      'Someone else already has this mobile number.';

  @override
  String get personErrorLastAdmin =>
      'This is the only active organisation admin. Make someone else an organisation admin first.';

  @override
  String get problemDetailsInvalid =>
      'Some details need attention. Look for the messages under the fields.';

  @override
  String get problemPasswordChangeRequired =>
      'Choose your own password before you carry on.';

  @override
  String get problemPasswordSavedSignIn =>
      'Your new password is saved, but we could not sign you in again. Sign in with your new password.';

  @override
  String get personStatusTitle => 'Sign-in and status';

  @override
  String get personActiveHelp =>
      'People who are deactivated can’t sign in. Everything they did is kept.';

  @override
  String get personOnlyAdmin =>
      'You are the only active organisation admin, so you can’t change your own role or status. Make someone else an organisation admin first.';

  @override
  String deactivateTitle(String name) {
    return 'Deactivate $name?';
  }

  @override
  String get deactivateBody =>
      'They will be signed out and cannot sign in until you reactivate them.';

  @override
  String get deactivateSelfBody =>
      'You will be signed out and cannot sign in until another organisation admin reactivates you.';

  @override
  String get deactivateButton => 'Deactivate';

  @override
  String personDeactivated(String name) {
    return '$name is deactivated.';
  }

  @override
  String personReactivated(String name) {
    return '$name can sign in again.';
  }

  @override
  String personMustChooseNote(String name) {
    return '$name has a one-time password. They must choose their own password when they next sign in.';
  }

  @override
  String personLockedNote(String time) {
    return 'Sign-in is locked after too many wrong passwords. It unlocks by itself at $time.';
  }

  @override
  String get unlockButton => 'Unlock sign-in';

  @override
  String unlockDone(String name) {
    return 'Sign-in unlocked. $name can try again now.';
  }

  @override
  String get resetTitle => 'Forgotten password';

  @override
  String get resetHelp =>
      'Give a new one-time password when someone has forgotten theirs. Their old password stops working.';

  @override
  String get resetButton => 'Give a new one-time password';

  @override
  String get resetNeedsEmail =>
      'Add an email address and save first: a one-time password is used with an email address.';

  @override
  String resetConfirmTitle(String name) {
    return 'Give $name a new one-time password?';
  }

  @override
  String get resetConfirmBody =>
      'Their current password stops working, and they are signed out on all their devices. You will see the new one-time password once.';

  @override
  String get resetConfirmButton => 'Give a new password';

  @override
  String otpTitle(String name) {
    return 'One-time password for $name';
  }

  @override
  String otpGive(String name) {
    return 'Give this to $name in person or by phone. They must choose their own password when they first sign in. It will not be shown again.';
  }

  @override
  String otpSignInWith(String email) {
    return 'They sign in with $email.';
  }

  @override
  String otpSpoken(String characters) {
    return 'One-time password: $characters';
  }

  @override
  String get otpCopy => 'Copy password';

  @override
  String get otpCopied =>
      'Password copied. Paste it now: it is cleared from the clipboard when you close this.';

  @override
  String get otpDone => 'Done';

  @override
  String get otpAddAnother => 'Add another person';

  @override
  String get leaveOtpTitle => 'Leave without noting the password?';

  @override
  String get leaveOtpBody =>
      'The one-time password will not be shown again. If you leave now, you can give a new one from this person’s page.';

  @override
  String get leaveOtpLeave => 'Leave';

  @override
  String get choosePasswordTitle => 'Choose your own password';

  @override
  String get choosePasswordIntro =>
      'You signed in with a one-time password. Choose a password that only you know before you carry on.';

  @override
  String choosePasswordAccount(String name) {
    return 'Signed in as $name';
  }

  @override
  String get choosePasswordCurrent => 'One-time password';

  @override
  String get choosePasswordCurrentHelp =>
      'The password your organisation admin gave you.';

  @override
  String get choosePasswordNew => 'New password';

  @override
  String get choosePasswordHint =>
      'Use 3 or 4 words you will remember, at least 12 characters.';

  @override
  String get choosePasswordRepeat => 'Type the new password again';

  @override
  String get choosePasswordTooShort => 'Use at least 12 characters.';

  @override
  String get choosePasswordSame =>
      'Choose a password that is different from the one-time password.';

  @override
  String get choosePasswordMismatch => 'The two passwords are not the same.';

  @override
  String get choosePasswordWrongCurrent =>
      'This is not the one-time password you were given. Check it and try again.';

  @override
  String get choosePasswordSave => 'Save and continue';

  @override
  String get choosePasswordSaved => 'Your new password is saved.';

  @override
  String get problemPersonChanged =>
      'Someone changed this person a moment ago. Reload, then make your change again.';

  @override
  String get actionReload => 'Reload';

  @override
  String get navPlaces => 'Places';

  @override
  String get placesTitle => 'Places';

  @override
  String get placesSummary =>
      'Your organisation from the top down: head office, regions, areas and branches. Each person works at one place.';

  @override
  String get placesAdd => 'Add place';

  @override
  String get placesImport => 'Import from a spreadsheet';

  @override
  String get placesSearchHint => 'Name or code';

  @override
  String get placesShowClosed => 'Show closed places';

  @override
  String placesClosedHidden(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString closed places are hidden.',
      one: '1 closed place is hidden.',
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
      other: '$countString places match',
      one: '1 place matches',
      zero: 'No place matches',
    );
    return '$_temp0';
  }

  @override
  String get placesNoMatchBody => 'Try another name or code.';

  @override
  String get placesNoMatchClosedBody =>
      'Try another name or code, or turn on ‘Show closed places’.';

  @override
  String get placesEmptyTitle => 'Add your first places';

  @override
  String placesEmptyBody(String organisation) {
    return 'Add the regions, areas and branches inside $organisation: one at a time with ‘Add place’, or all at once from a spreadsheet.';
  }

  @override
  String get placesNoneTitle => 'No places yet';

  @override
  String get placesBack => 'Back to Places';

  @override
  String get placeRootNote => 'The whole organisation';

  @override
  String placeInsideCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString places inside',
      one: '1 place inside',
    );
    return '$_temp0';
  }

  @override
  String placeCodeShown(String code) {
    return 'Code $code';
  }

  @override
  String get placeClosed => 'Closed';

  @override
  String placeOpenInside(String name) {
    return 'Show the places inside $name';
  }

  @override
  String placeShutInside(String name) {
    return 'Hide the places inside $name';
  }

  @override
  String placeActions(String name) {
    return 'Actions for $name';
  }

  @override
  String get placeAddInside => 'Add a place inside';

  @override
  String get placeRename => 'Rename or change code';

  @override
  String get placeCloseAction => 'Close place';

  @override
  String get placeReopenAction => 'Reopen place';

  @override
  String get placeDeleteAction => 'Delete place';

  @override
  String get placeAddTitle => 'Add a place';

  @override
  String get placeParent => 'Goes inside';

  @override
  String get placeParentHelp =>
      'The place this one belongs to. It can’t be moved later.';

  @override
  String placeParentFixed(String parent) {
    return 'Inside $parent. A place can’t be moved.';
  }

  @override
  String get placeName => 'Name';

  @override
  String get placeNameHelp =>
      'For example ‘Mirpur branch’. Places inside the same place need different names.';

  @override
  String get placeCode => 'Code (optional)';

  @override
  String get placeCodeHelp =>
      'A short code your organisation uses, for example MRP10. No two places can have the same code.';

  @override
  String get placeErrorName => 'Give the place a name.';

  @override
  String placeErrorNameTaken(String parent) {
    return 'Another place inside $parent already has this name. Choose a different name.';
  }

  @override
  String get placeErrorCodeTaken =>
      'Another place already has this code. Choose a different code.';

  @override
  String get placeErrorParentClosed =>
      'The place above is closed. Reopen it first, or choose an open place.';

  @override
  String placeAdded(String name) {
    return '$name is added.';
  }

  @override
  String placeCloseTitle(String name) {
    return 'Close $name?';
  }

  @override
  String get placeCloseBody =>
      'A closed place can’t be chosen for people or for new places, and it is hidden where you choose a place. Everything recorded there is kept. You can reopen it at any time.';

  @override
  String get placeCloseButton => 'Close place';

  @override
  String placeClosedDone(String name) {
    return '$name is closed.';
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
          '$countString open places are still inside it. Close or delete them first.',
      one: '1 open place is still inside it. Close or delete that place first.',
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
          '$countString active people still work here. Move them to other places, or deactivate them, first.',
      one: '1 active person still works here. Move them to another place, or deactivate them, first.',
    );
    return '$_temp0';
  }

  @override
  String get placeSeePeople => 'See who works here';

  @override
  String get placeErrorRoot =>
      'The organisation itself can’t be closed or deleted.';

  @override
  String placeReopenTitle(String name) {
    return 'Reopen $name?';
  }

  @override
  String get placeReopenBody =>
      'It can be chosen again for people and for new places.';

  @override
  String get placeReopenButton => 'Reopen place';

  @override
  String placeReopenedDone(String name) {
    return '$name is open again.';
  }

  @override
  String get placeErrorAboveClosed =>
      'The place above it is closed. Reopen that place first.';

  @override
  String placeDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get placeDeleteBody =>
      'Delete a place only if it was added by mistake. This can’t be undone. A place that anyone or any record uses can’t be deleted: close it instead.';

  @override
  String get placeDeleteButton => 'Delete place';

  @override
  String placeDeletedDone(String name) {
    return '$name is deleted.';
  }

  @override
  String get placeErrorInUse =>
      'This place is in use, so it can’t be deleted. Close it instead: it will no longer be offered, and its records are kept.';

  @override
  String get placeCloseInstead => 'Close it instead';

  @override
  String get importTitle => 'Import from a spreadsheet';

  @override
  String get importSummary =>
      'Add many places at once from a spreadsheet. Places that are already there are kept, never doubled.';

  @override
  String importStep(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Step $numberString';
  }

  @override
  String get importStepFile => 'Get your spreadsheet ready';

  @override
  String get importRuleRows =>
      'One row for each place. Put the names in separate columns, from the top level down: for example Region, Area, Branch.';

  @override
  String get importRuleHeader => 'The first row holds the column names.';

  @override
  String get importRuleCode =>
      'To give a place a code, add a last column named ‘code’. The code goes on the last place in the row.';

  @override
  String get importRuleEmpty =>
      'Empty cells at the end of a row are fine: that row stops at a higher level.';

  @override
  String get importRuleReuse =>
      'Places that are already there (the same name at the same level) are reused, so you can import the same file again safely.';

  @override
  String get importRuleBangla => 'Bangla names are fine.';

  @override
  String get importRuleSave =>
      'Save the file as ‘CSV UTF-8’. In Excel: File › Save As › CSV UTF-8. In Google Sheets: File › Download › Comma-separated values (.csv).';

  @override
  String get importRuleLimits =>
      'Up to 5,000 rows, with up to 10 levels in a row.';

  @override
  String get importExample => 'Example';

  @override
  String get importExampleRegion => 'Region';

  @override
  String get importExampleArea => 'Area';

  @override
  String get importExampleBranch => 'Branch';

  @override
  String get importExampleRegion1 => 'Dhaka region';

  @override
  String get importExampleArea1 => 'Mirpur area';

  @override
  String get importExampleBranch1 => 'Mirpur-10 branch';

  @override
  String get importExampleBranch2 => 'Pallabi branch';

  @override
  String get importExampleRegion2 => 'Khulna region';

  @override
  String get importExampleArea2 => 'Sonadanga area';

  @override
  String get importStepParent => 'Choose where the new places go';

  @override
  String get importParent => 'New places go inside';

  @override
  String get importParentHelp =>
      'The places in the first column go directly inside this place.';

  @override
  String get importStepChoose => 'Choose the file';

  @override
  String get importChoose => 'Choose a CSV file';

  @override
  String get importChooseAnother => 'Choose another file';

  @override
  String importFileName(String name) {
    return 'File: $name';
  }

  @override
  String importRowCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString rows of places',
      one: '1 row of places',
    );
    return '$_temp0';
  }

  @override
  String get importHeader => 'The first row has column names';

  @override
  String get importHeaderHelp => 'Turn this off if the first row is a place.';

  @override
  String importColumns(String names) {
    return 'Column names: $names';
  }

  @override
  String importCodeColumn(String name) {
    return 'Codes are read from the column ‘$name’.';
  }

  @override
  String get importErrorTooBig =>
      'This file is too big. A list of places can be up to 5 MB.';

  @override
  String get importErrorExcel =>
      'This is an Excel file. Save it as ‘CSV UTF-8’ first, then choose the CSV file.';

  @override
  String get importErrorNotUtf8 =>
      'This file is not saved as CSV UTF-8, so Bangla and some other letters would be lost. Save it again as ‘CSV UTF-8’, then choose it again.';

  @override
  String importErrorQuote(int line) {
    final intl.NumberFormat lineNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String lineString = lineNumberFormat.format(line);

    return 'On line $lineString, a cell starts with a quotation mark (\") that is never closed. Check that line, save the file again, then choose it again.';
  }

  @override
  String get importErrorEmpty => 'This file has no places in it.';

  @override
  String get importErrorOnlyHeader =>
      'This file has column names but no places under them. If the first row is a place, turn off ‘The first row has column names’.';

  @override
  String importErrorTooMany(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'This file has $countString rows of places. A file can hold up to 5,000. Split it into smaller files and import them one after another.';
  }

  @override
  String get importRowNoName => 'This row has a code but no place name.';

  @override
  String importRowGap(String column) {
    return 'The cell in column $column is empty, but there is a name after it. Fill it in, or move the names to the left.';
  }

  @override
  String get importRowTooDeep => 'This row has more than 10 levels.';

  @override
  String get importRowNameTooLong =>
      'A name in this row is longer than 200 characters.';

  @override
  String get importRowCodeTooLong =>
      'The code in this row is longer than 50 characters.';

  @override
  String get importStepCheck => 'Check what will be added';

  @override
  String get importChecking => 'Checking the file…';

  @override
  String importNewCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString new places',
      one: '1 new place',
      zero: 'No new places',
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
      other: '$countString already there',
      one: '1 already there',
      zero: 'none already there',
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
      other: '$countString problems to fix',
      one: '1 problem to fix',
    );
    return '$_temp0';
  }

  @override
  String get importProblemsHelp =>
      'Nothing is added until every problem is fixed. Fix them in your spreadsheet, save it as ‘CSV UTF-8’ again, then choose it again.';

  @override
  String importLine(int line) {
    final intl.NumberFormat lineNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String lineString = lineNumberFormat.format(line);

    return 'Line $lineString';
  }

  @override
  String get importNothingNew =>
      'Every place in this file is already there, so there is nothing to add.';

  @override
  String get importPreview => 'How the places will look';

  @override
  String get importNew => 'New';

  @override
  String get importAlready => 'Already there';

  @override
  String importAdd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $countString places',
      one: 'Add 1 place',
    );
    return '$_temp0';
  }

  @override
  String get importAdding => 'Adding places…';

  @override
  String importDone(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString places are added.',
      one: '1 place is added.',
    );
    return '$_temp0';
  }

  @override
  String get importChanged =>
      'Something changed since the check, so nothing was added. Fix the problems below, then choose the file again.';

  @override
  String get leaveImportTitle => 'Leave without adding the places?';

  @override
  String get leaveImportBody =>
      'The places in the file you chose have not been added yet.';

  @override
  String get leaveImportLeave => 'Leave';

  @override
  String get personPlaceClosedHelp =>
      'This place is closed. Choose an open place if this person moves.';

  @override
  String importServerClosed(String name) {
    return '‘$name’ is closed. Reopen it first, or remove this row.';
  }

  @override
  String importServerCodeOther(String name, String code) {
    return '‘$name’ already has the code $code. Use the same code, or leave the cell empty.';
  }

  @override
  String importServerCodeTwice(String code) {
    return 'The code $code is used more than once in this file. Each place needs its own code.';
  }

  @override
  String importServerCodeTaken(String code) {
    return 'Another place already has the code $code. Choose a different code.';
  }

  @override
  String get importProblemNoName => 'This row has no place name.';

  @override
  String importProblemTooDeep(int limit) {
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'This row has more than $limitString levels.';
  }

  @override
  String get placeErrorNameUnsafe =>
      'The name has a line break or a hidden control character. Type it again.';

  @override
  String get placeErrorCodeUnsafe =>
      'The code has a line break or a hidden control character. Type it again.';

  @override
  String importServerUnsafeName(String name) {
    return 'The name ‘$name’ has a line break or a hidden control character.';
  }

  @override
  String importServerUnsafeCode(String code) {
    return 'The code $code has a line break or a hidden control character.';
  }

  @override
  String get navDevices => 'Devices';

  @override
  String get navMyDevices => 'My devices';

  @override
  String get problemSessionOtherDevice =>
      'This session belongs to another device. Sign in again on this one.';

  @override
  String get problemDeviceNotSetUp =>
      'This device is not set up for this server yet. Sign in again on this device.';

  @override
  String get problemDeviceCheckFailed =>
      'The server could not check this device. Try again. If it keeps happening, sign out and sign in again.';

  @override
  String get problemDeviceClock =>
      'This computer’s date or time is wrong. Set the correct date, time and time zone, then try again.';

  @override
  String get problemDeviceNotApproved => 'This device is waiting for approval.';

  @override
  String get problemDeviceRevoked =>
      'This device has been switched off for Obhijatra.';

  @override
  String get problemDeviceExpired =>
      'This device’s approval has run out. Ask an organisation admin to approve it again.';

  @override
  String get problemDeviceKeysUnavailable =>
      'This computer or browser could not keep the device’s security keys. If this is a private window, open a normal one, then try again.';

  @override
  String get problemDeviceKeyInUse =>
      'This device’s keys are already in use. Set this device up again.';

  @override
  String get problemTooManyWaitingDevices =>
      'Three of your devices are already waiting for approval. Ask an organisation admin to approve them or switch them off, then try again.';

  @override
  String get problemDeviceCodeMismatch =>
      'These numbers do not match this device. Check them with the person again.';

  @override
  String get problemDeviceNotWaiting =>
      'This device is no longer waiting for your approval. It may be approved already, or need a different organisation admin. Reload the list.';

  @override
  String get deviceChecking => 'Checking this device…';

  @override
  String deviceSignedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get deviceWaitingTitle => 'Waiting for approval';

  @override
  String get deviceWaitingIntro =>
      'Before you can use Obhijatra here, someone must check that this device is really yours.';

  @override
  String get deviceRenewTitle => 'Your approval has run out';

  @override
  String get deviceRenewIntro =>
      'Approvals last one year. To keep using Obhijatra here, someone must check this device again.';

  @override
  String get deviceCodeLabel => 'This device’s numbers';

  @override
  String deviceThisDevice(String label) {
    return 'This device: $label';
  }

  @override
  String get deviceWhoStaff =>
      'Show these numbers to an organisation admin, in person or on a phone call. They type them into their manager app to approve this device.';

  @override
  String get deviceWhoAdmin =>
      'You are an organisation admin, so two other organisation admins must each check these numbers and approve this device, in person or on a phone call.';

  @override
  String get deviceWhoAdminSecond =>
      'One organisation admin has approved it. A second, different organisation admin must approve it too.';

  @override
  String get deviceFirstAdminTitle => 'Are you the first organisation admin?';

  @override
  String get deviceFirstAdminBody =>
      'Then nobody can approve you in the app yet. Ask the person who runs the server to type this command on it:';

  @override
  String get deviceCommandCopied => 'Command copied.';

  @override
  String get deviceNoMessages =>
      'Your approver will not accept these numbers by text message, email or chat: read them out or show your screen.';

  @override
  String get deviceAutoCheck =>
      'This page checks every 15 seconds and opens Obhijatra as soon as the device is approved.';

  @override
  String get deviceCheckAgain => 'Check again';

  @override
  String get deviceCheckingNow => 'Checking…';

  @override
  String get deviceRevokedTitle => 'This device has been switched off';

  @override
  String get deviceRevokedBody =>
      'Someone switched off this device for Obhijatra, for example because it was reported lost. To use Obhijatra here again, set it up as a new device. Someone will then need to approve it.';

  @override
  String get deviceSetUpAgain => 'Set up this device again';

  @override
  String get deviceSetUpAgainTitle => 'Set up this device again?';

  @override
  String get deviceSetUpAgainBody =>
      'This makes new security keys for this device. You cannot use Obhijatra here until someone approves it.';

  @override
  String get deviceSetUpAgainConfirm => 'Set up again';

  @override
  String get deviceNotRecognisedTitle => 'This device could not be checked';

  @override
  String get deviceNotRecognisedBody =>
      'The server does not recognise this device’s keys. This can happen after the server was set up again. Check again; if that does not help, set this device up again.';

  @override
  String get deviceClockTitle => 'Check this computer’s date and time';

  @override
  String get deviceClockBody =>
      'This computer’s clock is more than 5 minutes away from the server’s. Set the correct date, time and time zone, then check again.';

  @override
  String get deviceUpdateBrowserTitle => 'Please update your browser';

  @override
  String get deviceUpdateBrowserBody =>
      'This browser cannot keep Obhijatra’s security keys safely. Use an up-to-date browser: Chrome or Edge 137 or later, Firefox 130 or later, or Safari 17 or later. You can also use the Obhijatra desktop app.';

  @override
  String get deviceSecureAddressTitle => 'Open the secure address';

  @override
  String get deviceSecureAddressBody =>
      'Browsers keep security keys only for pages opened at a secure address, which starts with https://. Ask your organisation admin for the manager’s https address.';

  @override
  String get devicesSummaryAdmin =>
      'Approve new computers, browsers and phones, and switch off lost ones.';

  @override
  String get devicesSummaryBranch =>
      'Approve the phones of field staff in your part of the organisation, and switch off lost ones.';

  @override
  String get devicesSummaryMine =>
      'The computers and browsers you use Obhijatra on. Switch one off if it is lost.';

  @override
  String get devicesTabOthers => 'Other people’s devices';

  @override
  String get devicesTabsLabel => 'Whose devices';

  @override
  String get devicesWaiting => 'Waiting for approval';

  @override
  String get devicesApproved => 'Approved';

  @override
  String get devicesSwitchedOff => 'Switched off';

  @override
  String get devicesWaitingNone => 'No devices are waiting for approval.';

  @override
  String get devicesEmptyTitle => 'No devices yet';

  @override
  String get devicesEmptyBody =>
      'When someone signs in on a new computer, browser or phone, it appears here for approval.';

  @override
  String get devicesMineEmptyBody => 'The devices you sign in on appear here.';

  @override
  String deviceAdded(String date) {
    return 'Added $date';
  }

  @override
  String deviceApprovedUntil(String date) {
    return 'Approved until $date';
  }

  @override
  String deviceApprovalRanOut(String date) {
    return 'Approval ran out $date';
  }

  @override
  String get deviceStatusWaiting => 'Waiting';

  @override
  String get deviceStatusApproved => 'Approved';

  @override
  String get deviceStatusOff => 'Switched off';

  @override
  String get deviceStatusRanOut => 'Approval ran out';

  @override
  String get deviceNeedsSecond => 'Needs a second approval';

  @override
  String get deviceThisOne => 'This device';

  @override
  String get deviceYouApprovedFirst =>
      'You approved it once. A different organisation admin must approve it too.';

  @override
  String get deviceSwitchOff => 'Switch off';

  @override
  String get platformWeb => 'Web browser';

  @override
  String get platformWindows => 'Windows computer';

  @override
  String get platformMac => 'Mac';

  @override
  String get platformLinux => 'Linux computer';

  @override
  String get platformAndroid => 'Android phone';

  @override
  String get platformIos => 'iPhone or iPad';

  @override
  String approveTitle(String name) {
    return 'Approve $name’s device';
  }

  @override
  String approveHow(String name) {
    return 'Ask $name to read out the 18 numbers on their own screen, in person or on a phone call with someone you know. Never accept numbers sent by text message, email or chat.';
  }

  @override
  String get approveCodeLabel => 'The 18 numbers';

  @override
  String get approveCodeHelp =>
      'Type them as you hear them. Bangla or English digits both work.';

  @override
  String get approveCodeIncomplete => 'Type all 18 numbers.';

  @override
  String approveMismatch(String name) {
    return 'These numbers do not match this device. Check them with $name again. If they still do not match, do not approve it: someone else may be trying to get in.';
  }

  @override
  String approveUnreadable(String name) {
    return 'This device’s details cannot be read, so it cannot be approved. Ask $name to set the device up again.';
  }

  @override
  String get approveAdminDevice =>
      'This is an organisation admin’s device. A second organisation admin must also approve it before it works.';

  @override
  String get approveAdminSecond =>
      'Another organisation admin has approved it once. Yours will be the second approval.';

  @override
  String get approveRenewal =>
      'This device’s approval has run out. Approving it again keeps it working for another year.';

  @override
  String get approveButton => 'Approve device';

  @override
  String get approveWorking => 'Approving…';

  @override
  String approveDone(String name) {
    return '$name can use Obhijatra on this device now.';
  }

  @override
  String approveDoneFirst(String name) {
    return 'You have approved it once. A second, different organisation admin must also check the 18 numbers with $name and approve it before it works.';
  }

  @override
  String get switchOffTitle => 'Switch off this device?';

  @override
  String switchOffBody(String name, String device) {
    return '$name’s $device will stop working for Obhijatra at once, and whoever uses it will be signed out straight away. To use it again, it must be set up again and approved.';
  }

  @override
  String switchOffMine(String device) {
    return 'Use this if your $device is lost or you no longer use it. It stops working for Obhijatra at once, and whoever uses it is signed out straight away.';
  }

  @override
  String get switchOffCurrent =>
      'This is the device you are using now. You will be signed out at once, and must set it up again and have it approved before you can carry on.';

  @override
  String get switchOffWorking => 'Switching off…';

  @override
  String get switchOffDone => 'Device switched off.';

  @override
  String get actionDone => 'Done';

  @override
  String get approveDoneTitle => 'Device approved';

  @override
  String approveDoneUntil(String date) {
    return 'Approved until $date';
  }

  @override
  String get approveDoneFirstTitle => 'Needs one more organisation admin';

  @override
  String deviceLastChecked(String time) {
    return 'Last checked at $time.';
  }

  @override
  String get problemDeviceUnknown =>
      'The server no longer knows this device. It is being set up again and will need approval again.';

  @override
  String get deviceServerForgot =>
      'The server no longer knew this device, so it needs approval again.';
}
