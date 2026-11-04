// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Obhijatra';

  @override
  String get splashLoading => 'Opening the app';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionBack => 'Go back';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionRetryStartup => 'Try again';

  @override
  String get startupProblemTitle => 'The app could not start';

  @override
  String get connectTitle => 'Connect to your organisation';

  @override
  String get connectIntro =>
      'Type the server address that your organisation gave you.';

  @override
  String get connectAddressLabel => 'Server address';

  @override
  String get connectAddressHelp => 'For example: data.example.org';

  @override
  String get connectErrorEmpty => 'Type the server address.';

  @override
  String get connectErrorShape =>
      'This does not look like an address. It should look like data.example.org.';

  @override
  String get connectErrorInsecure =>
      'Use an address that starts with https:// so that your data is protected on its way.';

  @override
  String get connectTest => 'Test connection';

  @override
  String get connectTesting => 'Testing the connection…';

  @override
  String get connectSuccess => 'Connected. This server is ready.';

  @override
  String get connectWrongAddress =>
      'We could not find Obhijatra at this address. Check the address with your organisation.';

  @override
  String get connectOffline =>
      'We could not reach this address. Check your phone\'s internet, and check the address.';

  @override
  String get signInTitle => 'Sign in';

  @override
  String signInServer(String server) {
    return 'Connected to $server';
  }

  @override
  String get signInEmail => 'Email';

  @override
  String get signInPassword => 'Password';

  @override
  String get signInShowPassword => 'Show password';

  @override
  String get signInHidePassword => 'Hide password';

  @override
  String get signInEmptyEmail => 'Type your email.';

  @override
  String get signInEmptyPassword => 'Type your password.';

  @override
  String get signInNeedsInternet =>
      'You need internet for this first sign in. After that, the app works offline too.';

  @override
  String get signInWorking => 'Signing in…';

  @override
  String get signInChangeServer => 'Use a different server';

  @override
  String get navToday => 'Today';

  @override
  String get navForms => 'Forms';

  @override
  String get navSending => 'Sending';

  @override
  String get navMore => 'More';

  @override
  String get navMainMenu => 'Main menu';

  @override
  String get todayTitle => 'Today';

  @override
  String get offlineTitle => 'You\'re offline.';

  @override
  String get offlineMessage =>
      'Keep working: everything is being saved on this phone.';

  @override
  String get statWaiting => 'Waiting to send';

  @override
  String get statDrafts => 'Drafts saved';

  @override
  String lastSyncedAt(String when) {
    return 'Last synced $when. Waiting forms send by themselves when there is signal.';
  }

  @override
  String get lastSyncedNever =>
      'Not synced yet. Connect to the internet once to get your forms and send your work.';

  @override
  String get formsToFill => 'Forms to fill';

  @override
  String get formsEmptyTitle => 'No forms yet';

  @override
  String get formsEmptyBody =>
      'Your forms appear here after the first sync. Connect to the internet, then press \"Update forms\".';

  @override
  String get formsUpdate => 'Update forms';

  @override
  String get formsUpdating => 'Updating forms…';

  @override
  String formsUpdateFailed(String reason) {
    return 'The forms could not be updated. $reason';
  }

  @override
  String get formMetaNew => 'Start a new one';

  @override
  String formMetaDrafts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString drafts saved',
      one: '1 draft saved',
    );
    return '$_temp0';
  }

  @override
  String get draftsHeading => 'Drafts';

  @override
  String draftSavedAt(String when) {
    return 'Saved $when';
  }

  @override
  String get draftContinue => 'Continue this draft';

  @override
  String get signInAgainBanner =>
      'Please sign in again to send your forms. Your answers stay on this phone.';

  @override
  String get syncBlockedUpdate =>
      'Please update the app to send your forms. Your answers are kept.';

  @override
  String get syncSendingNow => 'Sending…';

  @override
  String get sendingTitle => 'Sending';

  @override
  String get sendingEmpty =>
      'Nothing here yet. Forms you finish will show here.';

  @override
  String get sendingNow => 'Send now';

  @override
  String get stateQueued => 'Waiting to send';

  @override
  String get stateSending => 'Sending…';

  @override
  String stateSent(String when) {
    return 'Sent $when';
  }

  @override
  String get stateProblem => 'Could not send';

  @override
  String get stateOnPhone => 'Saved on this phone';

  @override
  String sendingFinishedAt(String when) {
    return 'Finished $when';
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

    return 'Question $nString of $totalString';
  }

  @override
  String get savedBadge => 'Saved';

  @override
  String get closeForm => 'Close form';

  @override
  String get requiredMark => 'Required';

  @override
  String get entryBack => 'Back';

  @override
  String get entryNext => 'Next';

  @override
  String get entryFinish => 'Finish';

  @override
  String get helpChooseOne => 'Choose one.';

  @override
  String get helpChooseMany => 'Choose all that apply.';

  @override
  String get pickDate => 'Choose a date';

  @override
  String get issueRequired => 'Please answer this question.';

  @override
  String get issueConstraint =>
      'This answer does not look right. Please check it.';

  @override
  String get issueInvalidInteger => 'Type a whole number, for example 5.';

  @override
  String get issueInvalidDecimal => 'Type a number, for example 2.5.';

  @override
  String get issueInvalidDate => 'Choose a date.';

  @override
  String get issueInvalidChoice => 'Choose from the list.';

  @override
  String get issueInvalidText =>
      'This answer could not be read. Please check it.';

  @override
  String get unsupportedTitle => 'This question type is not supported yet';

  @override
  String get unsupportedBody =>
      'This version of the app cannot show it. Your organisation can update the form or the app. You can go on to the next question.';

  @override
  String get unsupportedRequiredBody =>
      'This question must be answered, so this form cannot be finished yet. Your answers so far are saved. Please tell your organisation.';

  @override
  String repeatPromptTitle(String label) {
    return 'Add another $label?';
  }

  @override
  String get repeatPromptTitleNoLabel => 'Add another one?';

  @override
  String get repeatAdd => 'Add another';

  @override
  String get repeatNoMore => 'No more';

  @override
  String get formOpenFailedTitle => 'This form could not be opened';

  @override
  String get formNotOnPhone =>
      'This form is not on the phone. Press \"Update forms\" on the home screen when you have internet.';

  @override
  String get entryBackToToday => 'Back to the list';

  @override
  String get finishTitle => 'Finish and send';

  @override
  String get finishBackToQuestions => 'Back to the questions';

  @override
  String get summaryTitle => 'Summary';

  @override
  String get summaryAnswered => 'Answered';

  @override
  String summaryAnsweredValue(int answered, int total) {
    final intl.NumberFormat answeredNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String answeredString = answeredNumberFormat.format(answered);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$answeredString of $totalString';
  }

  @override
  String get summaryStarted => 'Started';

  @override
  String get summaryReady => 'Everything is answered. You can send this form.';

  @override
  String validationTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString answers need fixing',
      one: 'One answer needs fixing',
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
      other: 'Fix each one, then send again.',
      one: 'Fix it, then send again.',
    );
    return '$_temp0';
  }

  @override
  String validationItem(String question, String reason) {
    return '$question: $reason';
  }

  @override
  String get finishSend => 'Send';

  @override
  String get finishSending => 'Sending…';

  @override
  String get finishKeepDraft => 'Keep as a draft';

  @override
  String get finishDraftKept => 'Saved as a draft.';

  @override
  String get outcomeSentTitle => 'Sent';

  @override
  String get outcomeSentBody => 'Your answers have reached your organisation.';

  @override
  String outcomeSentChip(String when) {
    return 'Sent $when';
  }

  @override
  String get outcomeWaitingTitle => 'Waiting for signal';

  @override
  String get outcomeWaitingBody =>
      'Your answers are safely saved on this phone. They will be sent by themselves when there is signal. You do not need to do anything.';

  @override
  String outcomeWaitingCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString forms are waiting to be sent.',
      one: '1 form is waiting to be sent.',
    );
    return '$_temp0';
  }

  @override
  String get outcomeProblemTitle => 'Could not send';

  @override
  String get outcomeProblemSafe =>
      'Your answers are not lost. They are saved on this phone.';

  @override
  String get outcomeNext => 'Start the next one';

  @override
  String get outcomeBackToToday => 'Back to today\'s list';

  @override
  String get outcomeSignIn => 'Sign in again';

  @override
  String get moreTitle => 'More';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageBangla => 'বাংলা';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsAccount => 'Account';

  @override
  String settingsSignedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutNothingWaiting =>
      'You will need to sign in again to send forms. Your drafts stay on this phone.';

  @override
  String signOutOutboxWarning(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString forms have not been sent yet.',
      one: '1 form has not been sent yet.',
    );
    return '$_temp0 They stay safe on this phone, but they can only be sent from your account. Sign in again with the same account when you have signal.';
  }

  @override
  String get settingsAbout => 'About Obhijatra';

  @override
  String get settingsSection => 'Settings';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutMadeBy => 'Made by Aninda Studio';

  @override
  String get aboutLicenceHeading => 'Free software';

  @override
  String get aboutLicenceBody =>
      'Obhijatra is free software, shared under the GNU Affero General Public License, version 3 (AGPL-3.0). You may use it, study it, change it and share it. If you run a changed version for other people, you must share your changes under the same licence. There is no warranty.';

  @override
  String get aboutSourceLink => 'Get the source code';

  @override
  String aboutLinkFailed(String url) {
    return 'The link could not be opened. The address is $url';
  }

  @override
  String get aboutLicences => 'Open-source licences';

  @override
  String get problem_offline =>
      'There is no internet connection right now. Your work is safe on this phone and will be sent when the signal returns.';

  @override
  String get problem_timeout =>
      'The connection is too slow. We will try again by ourselves.';

  @override
  String get problem_serverError =>
      'The server has a problem. This is not your fault. We will try again by ourselves.';

  @override
  String get problem_serverBusy =>
      'The server is busy. We will try again in a little while.';

  @override
  String get problem_signInRequired =>
      'Please sign in again to send your forms. Your answers stay on this phone.';

  @override
  String get problem_signInFailed =>
      'The email or password is not right, or this account is not active. Check them and try again.';

  @override
  String get problem_accountNotPermitted =>
      'This account is not allowed to do this. Please contact your organisation.';

  @override
  String get problem_differentUser =>
      'Forms from another person are still waiting on this phone. Sign in as that person to send them first.';

  @override
  String get problem_appUpdateRequired =>
      'This app is too old to send forms. Please update the app. Your answers are kept.';

  @override
  String get problem_serverIncompatible =>
      'This app and the server do not match. Please update the app or ask your organisation.';

  @override
  String get problem_serverNotSetUp =>
      'The server is not ready yet. Please ask your organisation\'s administrator.';

  @override
  String get problem_clockSkew =>
      'The date or time on this phone is wrong, so forms cannot be sent. Open the phone\'s Settings, set the right date and time (turn on automatic date and time if you can), then come back to the app. Your forms are kept on this phone.';

  @override
  String get problem_duplicateInstance =>
      'The server already has a different form with the same code. Your answers are kept. Please tell your organisation.';

  @override
  String get problem_formNotOnServer =>
      'The server does not have this version of the form. Please tell your organisation.';

  @override
  String get problem_submissionInvalid =>
      'The server could not accept this form. Your answers are kept. Please tell your organisation.';

  @override
  String get problem_submissionTooLarge =>
      'This form, with its files, is too big to send. Please tell your organisation.';

  @override
  String get problem_attachmentMissing =>
      'A photo or file of this form is missing on this phone. Please tell your organisation.';

  @override
  String get problem_formInvalid =>
      'This form could not be opened. Get the forms again when you have internet, or tell your organisation.';

  @override
  String get problem_databaseKeyMissing =>
      'The key to the saved data on this phone is missing, so the data cannot be opened. Please contact your organisation before you do anything else.';

  @override
  String get problem_databaseKeyRejected =>
      'The saved data on this phone could not be unlocked. Do not delete the app. Please contact your organisation.';

  @override
  String get problem_databaseFromNewerApp =>
      'The saved data was made by a newer version of the app. Please update the app.';

  @override
  String get problem_databaseUnavailable =>
      'The saved data on this phone could not be opened. Please restart the phone. If it happens again, contact your organisation.';

  @override
  String get problem_unexpectedResponse =>
      'The server answered in a way the app does not understand. We will try again later.';

  @override
  String get problem_unknown =>
      'Something went wrong. Your work is safe on this phone. Please try again.';
}
