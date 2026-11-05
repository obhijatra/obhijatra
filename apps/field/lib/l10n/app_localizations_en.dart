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
  String get signInWithGoogle => 'Continue with Google';

  @override
  String get signInUsePhone => 'Use mobile number';

  @override
  String get signInUseEmail => 'Use email and password';

  @override
  String get signInOtherWays => 'Other ways to sign in';

  @override
  String get signInCheckingMethods => 'Checking how you can sign in…';

  @override
  String get signInMethodsFailed =>
      'We could not check all the ways you can sign in.';

  @override
  String get signInPhone => 'Mobile number';

  @override
  String get signInPhoneHelp =>
      'We will send a 6-digit code to this number by SMS.';

  @override
  String get signInPhoneEmpty => 'Type your mobile number.';

  @override
  String get signInPhoneInvalid =>
      'Check the number. A mobile number has 11 digits and starts with 01, for example 01712-345678.';

  @override
  String get signInSendCode => 'Send code';

  @override
  String get signInSendingCode => 'Sending the code…';

  @override
  String get signInCodeTitle => 'Enter the code from the SMS';

  @override
  String signInCodeSent(String phone) {
    return 'If $phone is the mobile number on your account, an SMS with a 6-digit code is on its way. It can take a minute.';
  }

  @override
  String get signInCodeFrom =>
      'Your organisation sends this SMS. Never share the code with anyone.';

  @override
  String get signInCodeNew =>
      'We sent a new code. Use the code in the newest SMS.';

  @override
  String get signInCode => '6-digit code';

  @override
  String get signInCodeIncomplete => 'Type all 6 digits of the code.';

  @override
  String signInNewCodeIn(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'You can ask for a new code in $secondsString seconds.',
      one: 'You can ask for a new code in 1 second.',
    );
    return '$_temp0';
  }

  @override
  String get signInNewCode => 'Send a new code';

  @override
  String get signInChangeNumber => 'Change number';

  @override
  String get signInGoogleWaiting => 'Waiting for Google…';

  @override
  String get signInGoogleWaitingHelp =>
      'Google\'s page has opened. Sign in there, then come back to this app.';

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
  String get lockTitle => 'Your data is locked';

  @override
  String get lockDeviceBody =>
      'Use your phone\'s screen lock (PIN, pattern, password or fingerprint) to open the app.';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get lockPromptTitle => 'Unlock Obhijatra';

  @override
  String get lockDeviceReason =>
      'Confirm it is you to open the forms on this phone.';

  @override
  String get lockDeviceCancelled =>
      'The phone did not unlock the app. Press Unlock to try again.';

  @override
  String get lockDeviceLockedOut =>
      'The phone\'s lock is paused after too many tries. Wait a little, then press Unlock again.';

  @override
  String get lockPinBody => 'Type your 6-digit app PIN.';

  @override
  String get pinLabel => 'App PIN';

  @override
  String pinWrong(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Wrong PIN. You can try $countString more times before a short wait.',
      one: 'Wrong PIN. You can try 1 more time before a short wait.',
    );
    return '$_temp0';
  }

  @override
  String pinWaitSeconds(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString seconds',
      one: '1 second',
    );
    return 'Too many wrong tries. Try again in $_temp0.';
  }

  @override
  String pinWaitMinutes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString minutes',
      one: '1 minute',
    );
    return 'Too many wrong tries. Try again in $_temp0.';
  }

  @override
  String get pinNeedsSixDigits => 'Type 6 digits.';

  @override
  String get pinForgot => 'Forgot your PIN?';

  @override
  String get pinChecking => 'Checking…';

  @override
  String get pinSetTitle => 'Choose an app PIN';

  @override
  String get pinSetBody =>
      'This phone has no screen lock, so the app needs its own PIN. Choose 6 digits that others cannot guess. You will type them each time you open the app.';

  @override
  String get pinNew => 'New PIN (6 digits)';

  @override
  String get pinConfirm => 'Type the same PIN again';

  @override
  String get pinMismatch =>
      'The two PINs are not the same. Type the PIN again.';

  @override
  String get pinSave => 'Save PIN';

  @override
  String get pinSaving => 'Saving…';

  @override
  String get reSignInExpired =>
      'It is more than 30 days since you last signed in with the internet on this phone, or the phone\'s date has changed. Connect to the internet and sign in to open your data.';

  @override
  String get reSignInNoLock =>
      'This phone has no screen lock and no app PIN. Connect to the internet and sign in, then choose an app PIN.';

  @override
  String get reSignInForgotPin =>
      'Connect to the internet and sign in with your account. Then you can choose a new app PIN.';

  @override
  String get reSignInWrongAccount =>
      'The data on this phone belongs to another account. Sign in with the account that last used this phone.';

  @override
  String get reSignInBack => 'Back to the PIN';

  @override
  String get reSignInPasswordForPin =>
      'To reset your PIN, sign in with your email and password. If your account has no password, ask your organisation admin.';

  @override
  String get reSignInPasswordForLock =>
      'To choose an app PIN, sign in with your email and password. If your account has no password, ask your organisation admin.';

  @override
  String get aboutSecurityHeading => 'Keeping the data safe';

  @override
  String get aboutSecurityBody =>
      'The app locks when it has been in the background for 5 minutes. Open it with your phone\'s screen lock, or with the app PIN if the phone has no screen lock. If you have not signed in with the internet for 30 days, the app stays locked until you sign in again. Use one phone per person: until the app can keep each person\'s data apart, anyone who can open the app on this phone can see the forms on it.';

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
  String get problem_redirected =>
      'The server address sent the app to a different address, so nothing was sent. If you use public Wi-Fi, open its sign-in page first. Otherwise, check the server address with your organisation. We will try again later.';

  @override
  String get problem_phoneNumberInvalid =>
      'This mobile number is not in the right form. Check it and try again.';

  @override
  String get problem_tooManySignInCodes =>
      'Too many codes were asked for. Wait 15 minutes, or use another way to sign in.';

  @override
  String get problem_signInCodeWrong =>
      'That code is wrong or has expired. Check the SMS, or ask for a new code. After 10 wrong tries, sign-in is locked for 15 minutes.';

  @override
  String get problem_tooManyCodeTries =>
      'Too many tries. Wait 15 minutes, then ask for a new code.';

  @override
  String get problem_signInMethodOff =>
      'This way to sign in is switched off on your organisation\'s server. Use another way to sign in.';

  @override
  String get problem_googleSignInRefused =>
      'Ask your organisation admin to add your Google email address to your account, or use another way to sign in.';

  @override
  String get problem_signInCancelled =>
      'Sign-in was stopped. You can try again.';

  @override
  String get problem_browserUnavailable =>
      'This phone could not open a web page to sign in. Use another way to sign in.';

  @override
  String get problem_unknown =>
      'Something went wrong. Your work is safe on this phone. Please try again.';
}
