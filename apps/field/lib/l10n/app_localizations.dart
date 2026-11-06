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

  /// The app name, shown in the top bar and the app switcher.
  ///
  /// In en, this message translates to:
  /// **'Obhijatra'**
  String get appTitle;

  /// Spoken by a screen reader while the splash screen is shown.
  ///
  /// In en, this message translates to:
  /// **'Opening the app'**
  String get splashLoading;

  /// Button that cancels an action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Button or icon that closes a screen.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Icon button that goes to the previous screen.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get actionBack;

  /// Button that repeats an action that failed.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// Button that goes to the next step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// Button on the start-up problem screen.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetryStartup;

  /// Title of the screen shown when the saved data on the phone cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'The app could not start'**
  String get startupProblemTitle;

  /// Title of the screen where the server address is typed.
  ///
  /// In en, this message translates to:
  /// **'Connect to your organisation'**
  String get connectTitle;

  /// Short explanation under the title of the connect screen.
  ///
  /// In en, this message translates to:
  /// **'Type the server address that your organisation gave you.'**
  String get connectIntro;

  /// Label of the server address field.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get connectAddressLabel;

  /// Help text under the server address field. The example address stays in English letters.
  ///
  /// In en, this message translates to:
  /// **'For example: data.example.org'**
  String get connectAddressHelp;

  /// Shown when the server address field is empty.
  ///
  /// In en, this message translates to:
  /// **'Type the server address.'**
  String get connectErrorEmpty;

  /// Shown when the typed server address is not a web address.
  ///
  /// In en, this message translates to:
  /// **'This does not look like an address. It should look like data.example.org.'**
  String get connectErrorShape;

  /// Shown when the address would send data without protection.
  ///
  /// In en, this message translates to:
  /// **'Use an address that starts with https:// so that your data is protected on its way.'**
  String get connectErrorInsecure;

  /// Button that checks the server address.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get connectTest;

  /// Shown on the test button while it works.
  ///
  /// In en, this message translates to:
  /// **'Testing the connection…'**
  String get connectTesting;

  /// Shown when the test connection worked.
  ///
  /// In en, this message translates to:
  /// **'Connected. This server is ready.'**
  String get connectSuccess;

  /// Shown when the address answers but is not an Obhijatra server.
  ///
  /// In en, this message translates to:
  /// **'We could not find Obhijatra at this address. Check the address with your organisation.'**
  String get connectWrongAddress;

  /// Shown when the server could not be reached.
  ///
  /// In en, this message translates to:
  /// **'We could not reach this address. Check your phone\'s internet, and check the address.'**
  String get connectOffline;

  /// Title of the sign-in screen and the sign-in button.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Shows which server the phone is connected to.
  ///
  /// In en, this message translates to:
  /// **'Connected to {server}'**
  String signInServer(String server);

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

  /// Button that shows the typed password.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get signInShowPassword;

  /// Button that hides the typed password.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get signInHidePassword;

  /// Shown when the email field is empty.
  ///
  /// In en, this message translates to:
  /// **'Type your email.'**
  String get signInEmptyEmail;

  /// Shown when the password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Type your password.'**
  String get signInEmptyPassword;

  /// Reassurance on the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'You need internet for this first sign in. After that, the app works offline too.'**
  String get signInNeedsInternet;

  /// Shown on the sign-in button while it works.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signInWorking;

  /// Link that goes back to the connect screen.
  ///
  /// In en, this message translates to:
  /// **'Use a different server'**
  String get signInChangeServer;

  /// Button that opens Google's sign-in page in a secure browser tab. Plain text only: never Google's logo.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInWithGoogle;

  /// Button that switches the sign-in screen to signing in with a code sent by SMS.
  ///
  /// In en, this message translates to:
  /// **'Use mobile number'**
  String get signInUsePhone;

  /// Button that switches the sign-in screen to email and password.
  ///
  /// In en, this message translates to:
  /// **'Use email and password'**
  String get signInUseEmail;

  /// Small heading above the other ways to sign in.
  ///
  /// In en, this message translates to:
  /// **'Other ways to sign in'**
  String get signInOtherWays;

  /// Shown while the app asks the server which ways to sign in it offers.
  ///
  /// In en, this message translates to:
  /// **'Checking how you can sign in…'**
  String get signInCheckingMethods;

  /// Shown above the reason when the app could not ask the server which ways to sign in it offers; a Try again button follows.
  ///
  /// In en, this message translates to:
  /// **'We could not check all the ways you can sign in.'**
  String get signInMethodsFailed;

  /// Label of the mobile number field (the country code +880 is shown in the field).
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get signInPhone;

  /// Help under the mobile number label.
  ///
  /// In en, this message translates to:
  /// **'We will send a 6-digit code to this number by SMS.'**
  String get signInPhoneHelp;

  /// Shown when the mobile number field is empty.
  ///
  /// In en, this message translates to:
  /// **'Type your mobile number.'**
  String get signInPhoneEmpty;

  /// Shown when the typed mobile number cannot be a Bangladeshi mobile number.
  ///
  /// In en, this message translates to:
  /// **'Check the number. A mobile number has 11 digits and starts with 01, for example 01712-345678.'**
  String get signInPhoneInvalid;

  /// Button that asks the server to send a sign-in code by SMS.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get signInSendCode;

  /// Shown on the Send code button while it works.
  ///
  /// In en, this message translates to:
  /// **'Sending the code…'**
  String get signInSendingCode;

  /// Heading of the step where the person types the code from the SMS.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from the SMS'**
  String get signInCodeTitle;

  /// Says where the code was sent. Worded so it never reveals whether the number has an account.
  ///
  /// In en, this message translates to:
  /// **'If {phone} is the mobile number on your account, an SMS with a 6-digit code is on its way. It can take a minute.'**
  String signInCodeSent(String phone);

  /// Says who sends the SMS, and warns never to share the code.
  ///
  /// In en, this message translates to:
  /// **'Your organisation sends this SMS. Never share the code with anyone.'**
  String get signInCodeFrom;

  /// Shown after a new code was sent: only the newest code works.
  ///
  /// In en, this message translates to:
  /// **'We sent a new code. Use the code in the newest SMS.'**
  String get signInCodeNew;

  /// Label of the code field.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get signInCode;

  /// Shown when fewer than 6 digits were typed.
  ///
  /// In en, this message translates to:
  /// **'Type all 6 digits of the code.'**
  String get signInCodeIncomplete;

  /// Countdown under the Send a new code button.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{You can ask for a new code in 1 second.} other{You can ask for a new code in {seconds} seconds.}}'**
  String signInNewCodeIn(int seconds);

  /// Button that sends a new code by SMS; it works after the countdown.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get signInNewCode;

  /// Button that goes back to typing the mobile number.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get signInChangeNumber;

  /// Heading while Google's sign-in page is open in the browser.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Google…'**
  String get signInGoogleWaiting;

  /// Text while Google's sign-in page is open in the browser; a Cancel button follows.
  ///
  /// In en, this message translates to:
  /// **'Google\'s page has opened. Sign in there, then come back to this app.'**
  String get signInGoogleWaitingHelp;

  /// Bottom navigation: today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// Bottom navigation: forms.
  ///
  /// In en, this message translates to:
  /// **'Forms'**
  String get navForms;

  /// Bottom navigation: sending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get navSending;

  /// Bottom navigation: more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// Spoken name of the bottom navigation bar.
  ///
  /// In en, this message translates to:
  /// **'Main menu'**
  String get navMainMenu;

  /// Title of the home screen.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// Bold first part of the offline banner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline.'**
  String get offlineTitle;

  /// Second part of the offline banner.
  ///
  /// In en, this message translates to:
  /// **'Keep working: everything is being saved on this phone.'**
  String get offlineMessage;

  /// Label under the number of forms waiting to be sent.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get statWaiting;

  /// Label under the number of drafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts saved'**
  String get statDrafts;

  /// Last time the phone talked to the server. {when} is a time such as "today at 9:15 am".
  ///
  /// In en, this message translates to:
  /// **'Last synced {when}. Waiting forms send by themselves when there is signal.'**
  String lastSyncedAt(String when);

  /// Shown before the first sync.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet. Connect to the internet once to get your forms and send your work.'**
  String get lastSyncedNever;

  /// Heading of the list of forms.
  ///
  /// In en, this message translates to:
  /// **'Forms to fill'**
  String get formsToFill;

  /// Heading shown when no form is on the phone.
  ///
  /// In en, this message translates to:
  /// **'No forms yet'**
  String get formsEmptyTitle;

  /// Explains what to do when no form is on the phone.
  ///
  /// In en, this message translates to:
  /// **'Your forms appear here after the first sync. Connect to the internet, then press \"Update forms\".'**
  String get formsEmptyBody;

  /// Button that downloads new forms.
  ///
  /// In en, this message translates to:
  /// **'Update forms'**
  String get formsUpdate;

  /// Shown on the update button while it works.
  ///
  /// In en, this message translates to:
  /// **'Updating forms…'**
  String get formsUpdating;

  /// Shown when updating forms failed; {reason} is a plain sentence.
  ///
  /// In en, this message translates to:
  /// **'The forms could not be updated. {reason}'**
  String formsUpdateFailed(String reason);

  /// Detail line of a form card without drafts.
  ///
  /// In en, this message translates to:
  /// **'Start a new one'**
  String get formMetaNew;

  /// Detail line of a form card with drafts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 draft saved} other{{count} drafts saved}}'**
  String formMetaDrafts(int count);

  /// Heading of the list of drafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get draftsHeading;

  /// Detail line of a draft. {when} is a time such as "today at 9:15 am".
  ///
  /// In en, this message translates to:
  /// **'Saved {when}'**
  String draftSavedAt(String when);

  /// Spoken hint of a draft card.
  ///
  /// In en, this message translates to:
  /// **'Continue this draft'**
  String get draftContinue;

  /// Banner shown on the home screen when the session has ended.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to send your forms. Your answers stay on this phone.'**
  String get signInAgainBanner;

  /// Banner on the home screen when sending stopped because the person must replace a one-time password.
  ///
  /// In en, this message translates to:
  /// **'Your organisation gave you a one-time password. Choose your own password to send your forms. Your answers stay on this phone.'**
  String get passwordChangeBanner;

  /// Button on the home-screen banner that opens the step to choose a new password.
  ///
  /// In en, this message translates to:
  /// **'Choose password'**
  String get passwordChangeOpen;

  /// Banner shown when the app is too old for the server.
  ///
  /// In en, this message translates to:
  /// **'Please update the app to send your forms. Your answers are kept.'**
  String get syncBlockedUpdate;

  /// Shown while forms are being sent.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get syncSendingNow;

  /// Title of the screen that lists finished forms.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get sendingTitle;

  /// Shown when no form was finished yet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Forms you finish will show here.'**
  String get sendingEmpty;

  /// Button that tries to send waiting forms at once.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get sendingNow;

  /// Status of a finished form not yet sent.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get stateQueued;

  /// Status of a form being sent.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get stateSending;

  /// Status of a sent form. {when} is a time.
  ///
  /// In en, this message translates to:
  /// **'Sent {when}'**
  String stateSent(String when);

  /// Status of a form the server refused.
  ///
  /// In en, this message translates to:
  /// **'Could not send'**
  String get stateProblem;

  /// Status chip: the work is safe on this phone but not sent.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get stateOnPhone;

  /// Detail line of a finished form. {when} is a time.
  ///
  /// In en, this message translates to:
  /// **'Finished {when}'**
  String sendingFinishedAt(String when);

  /// Progress above a question.
  ///
  /// In en, this message translates to:
  /// **'Question {n} of {total}'**
  String questionProgress(int n, int total);

  /// Shown after the answers were saved on the phone.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedBadge;

  /// Icon button that closes the form. The answers stay saved as a draft.
  ///
  /// In en, this message translates to:
  /// **'Close form'**
  String get closeForm;

  /// Word shown next to a question that must be answered.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredMark;

  /// Button that goes to the previous question.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get entryBack;

  /// Button that goes to the next question.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get entryNext;

  /// Button on the last question.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get entryFinish;

  /// Help text of a choose-one question.
  ///
  /// In en, this message translates to:
  /// **'Choose one.'**
  String get helpChooseOne;

  /// Help text of a choose-many question.
  ///
  /// In en, this message translates to:
  /// **'Choose all that apply.'**
  String get helpChooseMany;

  /// What the date button says before a date is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get pickDate;

  /// Shown when a required question has no answer.
  ///
  /// In en, this message translates to:
  /// **'Please answer this question.'**
  String get issueRequired;

  /// Shown when the answer breaks the form's rule and the form gives no message.
  ///
  /// In en, this message translates to:
  /// **'This answer does not look right. Please check it.'**
  String get issueConstraint;

  /// Shown when a whole number was expected.
  ///
  /// In en, this message translates to:
  /// **'Type a whole number, for example 5.'**
  String get issueInvalidInteger;

  /// Shown when a number was expected.
  ///
  /// In en, this message translates to:
  /// **'Type a number, for example 2.5.'**
  String get issueInvalidDecimal;

  /// Shown when a date was expected.
  ///
  /// In en, this message translates to:
  /// **'Choose a date.'**
  String get issueInvalidDate;

  /// Shown when the answer is not one of the choices.
  ///
  /// In en, this message translates to:
  /// **'Choose from the list.'**
  String get issueInvalidChoice;

  /// Shown when text could not be accepted.
  ///
  /// In en, this message translates to:
  /// **'This answer could not be read. Please check it.'**
  String get issueInvalidText;

  /// Title of the card shown for a question the app cannot show.
  ///
  /// In en, this message translates to:
  /// **'This question type is not supported yet'**
  String get unsupportedTitle;

  /// Explains the unsupported question card (optional question).
  ///
  /// In en, this message translates to:
  /// **'This version of the app cannot show it. Your organisation can update the form or the app. You can go on to the next question.'**
  String get unsupportedBody;

  /// Explains the unsupported question card (required question).
  ///
  /// In en, this message translates to:
  /// **'This question must be answered, so this form cannot be finished yet. Your answers so far are saved. Please tell your organisation.'**
  String get unsupportedRequiredBody;

  /// Question asked at the end of a repeated group.
  ///
  /// In en, this message translates to:
  /// **'Add another {label}?'**
  String repeatPromptTitle(String label);

  /// Question asked at the end of a repeated group without a name.
  ///
  /// In en, this message translates to:
  /// **'Add another one?'**
  String get repeatPromptTitleNoLabel;

  /// Button that adds another repeated group.
  ///
  /// In en, this message translates to:
  /// **'Add another'**
  String get repeatAdd;

  /// Button that goes on without adding another group.
  ///
  /// In en, this message translates to:
  /// **'No more'**
  String get repeatNoMore;

  /// Title shown when a form cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'This form could not be opened'**
  String get formOpenFailedTitle;

  /// Shown when the cached form is missing.
  ///
  /// In en, this message translates to:
  /// **'This form is not on the phone. Press \"Update forms\" on the home screen when you have internet.'**
  String get formNotOnPhone;

  /// Button on the form-open problem screen.
  ///
  /// In en, this message translates to:
  /// **'Back to the list'**
  String get entryBackToToday;

  /// Title of the last screen of a form.
  ///
  /// In en, this message translates to:
  /// **'Finish and send'**
  String get finishTitle;

  /// Icon button that goes back to the questions.
  ///
  /// In en, this message translates to:
  /// **'Back to the questions'**
  String get finishBackToQuestions;

  /// Heading of the summary box.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryTitle;

  /// Label in the summary box.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get summaryAnswered;

  /// Value in the summary box.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total}'**
  String summaryAnsweredValue(int answered, int total);

  /// Label in the summary box.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get summaryStarted;

  /// Shown above the summary when all is answered.
  ///
  /// In en, this message translates to:
  /// **'Everything is answered. You can send this form.'**
  String get summaryReady;

  /// Title of the box that lists what to fix; count is the number of questions to fix.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One answer needs fixing} other{{count} answers need fixing}}'**
  String validationTitle(int count);

  /// Text in the box that lists what to fix; count is the number of questions to fix.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Fix it, then send again.} other{Fix each one, then send again.}}'**
  String validationMessage(int count);

  /// One line of the box that lists what to fix.
  ///
  /// In en, this message translates to:
  /// **'{question}: {reason}'**
  String validationItem(String question, String reason);

  /// Main button on the finish screen.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get finishSend;

  /// Shown on the send button while it works.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get finishSending;

  /// Button that saves the form and closes it without sending.
  ///
  /// In en, this message translates to:
  /// **'Keep as a draft'**
  String get finishKeepDraft;

  /// Shown after the form was kept as a draft.
  ///
  /// In en, this message translates to:
  /// **'Saved as a draft.'**
  String get finishDraftKept;

  /// Title when the server has the form.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get outcomeSentTitle;

  /// Text when the server has the form.
  ///
  /// In en, this message translates to:
  /// **'Your answers have reached your organisation.'**
  String get outcomeSentBody;

  /// Chip when the server has the form. {when} is a time.
  ///
  /// In en, this message translates to:
  /// **'Sent {when}'**
  String outcomeSentChip(String when);

  /// Title when the form is saved and will be sent later.
  ///
  /// In en, this message translates to:
  /// **'Waiting for signal'**
  String get outcomeWaitingTitle;

  /// Text when the form is saved and will be sent later.
  ///
  /// In en, this message translates to:
  /// **'Your answers are safely saved on this phone. They will be sent by themselves when there is signal. You do not need to do anything.'**
  String get outcomeWaitingBody;

  /// Number of forms waiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 form is waiting to be sent.} other{{count} forms are waiting to be sent.}}'**
  String outcomeWaitingCount(int count);

  /// Title when sending failed.
  ///
  /// In en, this message translates to:
  /// **'Could not send'**
  String get outcomeProblemTitle;

  /// Reassurance when sending failed.
  ///
  /// In en, this message translates to:
  /// **'Your answers are not lost. They are saved on this phone.'**
  String get outcomeProblemSafe;

  /// Button that starts another copy of the same form.
  ///
  /// In en, this message translates to:
  /// **'Start the next one'**
  String get outcomeNext;

  /// Button that goes to the home screen.
  ///
  /// In en, this message translates to:
  /// **'Back to today\'s list'**
  String get outcomeBackToToday;

  /// Button on the problem screen when sign-in is needed.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get outcomeSignIn;

  /// Title of the more screen.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTitle;

  /// Title of the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Heading of the language setting.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// The Bangla language, written in Bangla.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get languageBangla;

  /// The English language, written in English.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Heading of the account section.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// Shows who is signed in.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String settingsSignedInAs(String name);

  /// Button that signs the person out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// Title of the sign-out question.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutConfirmTitle;

  /// Sign-out question when nothing is waiting to be sent.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to send forms. Your drafts stay on this phone.'**
  String get signOutNothingWaiting;

  /// Warning before signing out while forms are unsent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 form has not been sent yet.} other{{count} forms have not been sent yet.}} They stay safe on this phone, but they can only be sent from your account. Sign in again with the same account when you have signal.'**
  String signOutOutboxWarning(int count);

  /// Row that opens the About screen.
  ///
  /// In en, this message translates to:
  /// **'About Obhijatra'**
  String get settingsAbout;

  /// Row that opens the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsSection;

  /// Title of the About screen.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// The app version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// Credit line. Plain text in both languages.
  ///
  /// In en, this message translates to:
  /// **'Made by Aninda Studio'**
  String get aboutMadeBy;

  /// Heading of the licence notice.
  ///
  /// In en, this message translates to:
  /// **'Free software'**
  String get aboutLicenceHeading;

  /// The AGPL notice.
  ///
  /// In en, this message translates to:
  /// **'Obhijatra is free software, shared under the GNU Affero General Public License, version 3 (AGPL-3.0). You may use it, study it, change it and share it. If you run a changed version for other people, you must share your changes under the same licence. There is no warranty.'**
  String get aboutLicenceBody;

  /// Link to the source code.
  ///
  /// In en, this message translates to:
  /// **'Get the source code'**
  String get aboutSourceLink;

  /// Shown when the source code link cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'The link could not be opened. The address is {url}'**
  String aboutLinkFailed(String url);

  /// Row that opens the list of licences of the parts the app is built from.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutLicences;

  /// Title of the screens that ask the person to unlock the app.
  ///
  /// In en, this message translates to:
  /// **'Your data is locked'**
  String get lockTitle;

  /// Text of the unlock screen on a phone that has a screen lock.
  ///
  /// In en, this message translates to:
  /// **'Use your phone\'s screen lock (PIN, pattern, password or fingerprint) to open the app.'**
  String get lockDeviceBody;

  /// Button that unlocks the app.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockUnlock;

  /// Title of the phone's own unlock prompt (Android). Obhijatra is the app's name.
  ///
  /// In en, this message translates to:
  /// **'Unlock Obhijatra'**
  String get lockPromptTitle;

  /// Why the app asks for the phone's screen lock; shown inside the phone's own prompt.
  ///
  /// In en, this message translates to:
  /// **'Confirm it is you to open the forms on this phone.'**
  String get lockDeviceReason;

  /// Shown when the phone's unlock prompt was closed or did not work.
  ///
  /// In en, this message translates to:
  /// **'The phone did not unlock the app. Press Unlock to try again.'**
  String get lockDeviceCancelled;

  /// Shown when the phone itself refuses to unlock for a while after too many wrong tries.
  ///
  /// In en, this message translates to:
  /// **'The phone\'s lock is paused after too many tries. Wait a little, then press Unlock again.'**
  String get lockDeviceLockedOut;

  /// Text of the unlock screen on a phone without a screen lock.
  ///
  /// In en, this message translates to:
  /// **'Type your 6-digit app PIN.'**
  String get lockPinBody;

  /// Label of the field where the app PIN is typed.
  ///
  /// In en, this message translates to:
  /// **'App PIN'**
  String get pinLabel;

  /// Shown after a wrong app PIN; count is how many tries are left before the app makes the person wait.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Wrong PIN. You can try 1 more time before a short wait.} other{Wrong PIN. You can try {count} more times before a short wait.}}'**
  String pinWrong(int count);

  /// Shown while the app makes the person wait after too many wrong PINs; the number counts down.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong tries. Try again in {count, plural, =1{1 second} other{{count} seconds}}.'**
  String pinWaitSeconds(int count);

  /// Shown while the app makes the person wait (more than a minute and a half) after too many wrong PINs.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong tries. Try again in {count, plural, =1{1 minute} other{{count} minutes}}.'**
  String pinWaitMinutes(int count);

  /// Shown when the typed PIN is not 6 digits.
  ///
  /// In en, this message translates to:
  /// **'Type 6 digits.'**
  String get pinNeedsSixDigits;

  /// Quiet button on the PIN screen; leads to signing in with the internet to choose a new PIN.
  ///
  /// In en, this message translates to:
  /// **'Forgot your PIN?'**
  String get pinForgot;

  /// Shown on the unlock button while the PIN is checked.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get pinChecking;

  /// Title of the screen where the app PIN is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose an app PIN'**
  String get pinSetTitle;

  /// Text of the screen where the app PIN is chosen.
  ///
  /// In en, this message translates to:
  /// **'This phone has no screen lock, so the app needs its own PIN. Choose 6 digits that others cannot guess. You will type them each time you open the app.'**
  String get pinSetBody;

  /// Label of the first PIN field when choosing a PIN.
  ///
  /// In en, this message translates to:
  /// **'New PIN (6 digits)'**
  String get pinNew;

  /// Label of the second PIN field when choosing a PIN.
  ///
  /// In en, this message translates to:
  /// **'Type the same PIN again'**
  String get pinConfirm;

  /// Shown when the two typed PINs differ.
  ///
  /// In en, this message translates to:
  /// **'The two PINs are not the same. Type the PIN again.'**
  String get pinMismatch;

  /// Button that saves the chosen PIN.
  ///
  /// In en, this message translates to:
  /// **'Save PIN'**
  String get pinSave;

  /// Shown on the save button while the PIN is saved.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get pinSaving;

  /// Why the person must sign in again: the offline limit of 30 days has passed.
  ///
  /// In en, this message translates to:
  /// **'It is more than 30 days since you last signed in with the internet on this phone, or the phone\'s date has changed. Connect to the internet and sign in to open your data.'**
  String get reSignInExpired;

  /// Why the person must sign in again: there is no way to unlock the app on this phone.
  ///
  /// In en, this message translates to:
  /// **'This phone has no screen lock and no app PIN. Connect to the internet and sign in, then choose an app PIN.'**
  String get reSignInNoLock;

  /// Shown after Forgot your PIN.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet and sign in with your account. Then you can choose a new app PIN.'**
  String get reSignInForgotPin;

  /// Shown when someone signs in with a different account to unlock the app.
  ///
  /// In en, this message translates to:
  /// **'The data on this phone belongs to another account. Sign in with the account that last used this phone.'**
  String get reSignInWrongAccount;

  /// Quiet button that goes back from signing in to typing the PIN.
  ///
  /// In en, this message translates to:
  /// **'Back to the PIN'**
  String get reSignInBack;

  /// After a forgotten PIN only email and password can sign in (an SMS code or Google only shows that someone holds the phone). Shown when the server also offers SMS or Google sign-in.
  ///
  /// In en, this message translates to:
  /// **'To reset your PIN, sign in with your email and password. If your account has no password, ask your organisation admin.'**
  String get reSignInPasswordForPin;

  /// On a phone with no screen lock and no app PIN only email and password can sign in. Shown when the server also offers SMS or Google sign-in.
  ///
  /// In en, this message translates to:
  /// **'To choose an app PIN, sign in with your email and password. If your account has no password, ask your organisation admin.'**
  String get reSignInPasswordForLock;

  /// Title of the full-screen step where a person replaces the one-time password an organisation admin gave them.
  ///
  /// In en, this message translates to:
  /// **'Choose your own password'**
  String get passwordChangeTitle;

  /// Why the person must choose a password, under the title of the step.
  ///
  /// In en, this message translates to:
  /// **'Your organisation gave you a one-time password. Choose your own password now. From now on, you will sign in with it.'**
  String get passwordChangeBody;

  /// Label of the field for the one-time password the organisation gave (the current password).
  ///
  /// In en, this message translates to:
  /// **'One-time password'**
  String get passwordChangeCurrent;

  /// Help under the one-time password label.
  ///
  /// In en, this message translates to:
  /// **'The password your organisation gave you.'**
  String get passwordChangeCurrentHelp;

  /// Label of the field for the person's own new password.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get passwordChangeNew;

  /// Plain hint under the new password label. The server needs at least 12 characters.
  ///
  /// In en, this message translates to:
  /// **'Use 3 or 4 words you will remember, at least 12 characters.'**
  String get passwordChangeHint;

  /// Label of the field where the new password is typed a second time.
  ///
  /// In en, this message translates to:
  /// **'Type the new password again'**
  String get passwordChangeRepeat;

  /// Shown under the one-time password field when it is empty.
  ///
  /// In en, this message translates to:
  /// **'Type the one-time password from your organisation.'**
  String get passwordChangeCurrentEmpty;

  /// Shown under the new password field when it is shorter than 12 characters.
  ///
  /// In en, this message translates to:
  /// **'Use at least 12 characters.'**
  String get passwordChangeTooShort;

  /// Shown under the new password field when it is longer than the server allows (71 characters).
  ///
  /// In en, this message translates to:
  /// **'Use no more than 71 characters.'**
  String get passwordChangeTooLong;

  /// Shown under the new password field when it is the same as the one-time password.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password, not the one-time password.'**
  String get passwordChangeSameAsOld;

  /// Shown under the repeat field when it differs from the new password.
  ///
  /// In en, this message translates to:
  /// **'The two passwords are not the same. Type the new password again.'**
  String get passwordChangeMismatch;

  /// Main button of the step: saves the new password.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get passwordChangeSave;

  /// The main button while the new password is being saved.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get passwordChangeSaving;

  /// Quiet button on the step: leaves without choosing a password and goes back to signing in.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get passwordChangeSignOut;

  /// Main button when the new password was saved but the app could not sign in with it: goes back to signing in.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get passwordChangeSignInAgain;

  /// Heading of the security notes on the About screen.
  ///
  /// In en, this message translates to:
  /// **'Keeping the data safe'**
  String get aboutSecurityHeading;

  /// Security notes on the About screen, including the advice to use one phone per person until each person's data can be kept apart.
  ///
  /// In en, this message translates to:
  /// **'The app locks when it has been in the background for 5 minutes. Open it with your phone\'s screen lock, or with the app PIN if the phone has no screen lock. If you have not signed in with the internet for 30 days, the app stays locked until you sign in again. Use one phone per person: until the app can keep each person\'s data apart, anyone who can open the app on this phone can see the forms on it.'**
  String get aboutSecurityBody;

  /// Button that signs out, so the person can sign in again, when their sign-in has ended or belongs to another phone.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get actionSignInAgain;

  /// Title of the screen shown while this phone enrols with the organisation's server (device trust), right after sign-in.
  ///
  /// In en, this message translates to:
  /// **'Setting up this phone'**
  String get deviceSettingUpTitle;

  /// Explains the setting-up screen.
  ///
  /// In en, this message translates to:
  /// **'Before you can get forms, this phone must be set up with your organisation\'s server. This needs an internet connection.'**
  String get deviceSettingUpBody;

  /// Shown and spoken while the phone enrols.
  ///
  /// In en, this message translates to:
  /// **'Setting up…'**
  String get deviceSettingUpWorking;

  /// Title of the screen shown while this phone waits for a branch manager or an organisation admin to approve it.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get deviceWaitingTitle;

  /// Says who approves the phone.
  ///
  /// In en, this message translates to:
  /// **'Before this phone can get or send forms, your branch manager or an organisation admin must approve it.'**
  String get deviceWaitingBody;

  /// Shown on the waiting screen when the organisation's server no longer knew this phone (for example after it was restored from a backup), so the phone was set up again with the same numbers.
  ///
  /// In en, this message translates to:
  /// **'The server no longer knew this phone, so it needs approval again.'**
  String get deviceServerForgot;

  /// Title of the screen shown when this phone's yearly approval has run out.
  ///
  /// In en, this message translates to:
  /// **'Approval has run out'**
  String get deviceRenewalTitle;

  /// Explains the renewal screen.
  ///
  /// In en, this message translates to:
  /// **'Each approval lasts one year, and this phone\'s has run out. Your branch manager or an organisation admin must approve it again. They check the same numbers as before.'**
  String get deviceRenewalBody;

  /// Title of the screen shown when the organisation has switched this phone off (revoked it).
  ///
  /// In en, this message translates to:
  /// **'This phone has been switched off'**
  String get deviceSwitchedOffTitle;

  /// Explains the switched-off screen.
  ///
  /// In en, this message translates to:
  /// **'Your organisation has switched off this phone for Obhijatra, so it cannot get or send forms. This happens, for example, when a phone is reported lost.'**
  String get deviceSwitchedOffBody;

  /// Reassurance on the switched-off screen.
  ///
  /// In en, this message translates to:
  /// **'Your unsent forms and drafts stay on this phone.'**
  String get deviceSwitchedOffKept;

  /// What to do on the switched-off screen.
  ///
  /// In en, this message translates to:
  /// **'Ask your organisation admin whether you should use this phone. If so, set it up again, then ask your branch manager or an organisation admin to approve it.'**
  String get deviceSwitchedOffNext;

  /// Heading above the 18-digit check code (six groups of three digits) that the approver checks. Called 'numbers', as in the manager app and on the server.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s numbers'**
  String get deviceCodeHeading;

  /// What a screen reader says for the check code, read digit by digit, group by group.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s numbers: {numbers}'**
  String deviceCodeSpoken(String numbers);

  /// How to give the approver the numbers.
  ///
  /// In en, this message translates to:
  /// **'Show these numbers to them in person, or read them out on a phone call.'**
  String get deviceShowInPerson;

  /// Warning on the waiting screen.
  ///
  /// In en, this message translates to:
  /// **'Never send the numbers in a message (SMS, WhatsApp or email): your approver must see or hear them from you.'**
  String get deviceNeverSend;

  /// Says that the waiting screen asks the server again by itself.
  ///
  /// In en, this message translates to:
  /// **'While this screen is open, it checks again by itself every 15 seconds.'**
  String get deviceAutoCheck;

  /// When the server last answered about this phone.
  ///
  /// In en, this message translates to:
  /// **'Last checked {when}'**
  String deviceLastChecked(String when);

  /// Button that asks the server again whether this phone is approved.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get deviceCheckAgain;

  /// Shown on the button while the server is asked.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get deviceChecking;

  /// Button that opens the app before the phone is approved, to fill in forms already on the phone. They are sent once it is approved.
  ///
  /// In en, this message translates to:
  /// **'Fill in forms on this phone for now'**
  String get deviceFillInForms;

  /// Shown on the device screen when the server cannot be reached.
  ///
  /// In en, this message translates to:
  /// **'There is no internet connection, so this phone could not reach your organisation\'s server. Connect to the internet, then try again.'**
  String get deviceCheckOffline;

  /// Button on the switched-off screen.
  ///
  /// In en, this message translates to:
  /// **'Set up this phone again'**
  String get deviceSetUpAgain;

  /// Title of the confirmation before setting the phone up again.
  ///
  /// In en, this message translates to:
  /// **'Set up this phone again?'**
  String get deviceSetUpAgainTitle;

  /// What setting the phone up again does.
  ///
  /// In en, this message translates to:
  /// **'This phone gets new numbers, and you are signed out. Your unsent forms and drafts stay on this phone. Then sign in again, and ask your branch manager or an organisation admin to approve the new numbers.'**
  String get deviceSetUpAgainBody;

  /// Confirms setting the phone up again.
  ///
  /// In en, this message translates to:
  /// **'Set up again'**
  String get deviceSetUpAgainConfirm;

  /// Notice on the Today screen.
  ///
  /// In en, this message translates to:
  /// **'This phone is not set up with your organisation\'s server yet. Finished forms are sent once it is set up and approved.'**
  String get deviceNoticeSettingUp;

  /// Notice on the Today screen.
  ///
  /// In en, this message translates to:
  /// **'This phone is waiting for approval. Finished forms are sent once it is approved.'**
  String get deviceNoticeWaiting;

  /// Notice on the Today screen.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s approval has run out. Finished forms are sent once it is approved again.'**
  String get deviceNoticeRenewal;

  /// Notice on the Today screen.
  ///
  /// In en, this message translates to:
  /// **'This phone is switched off for Obhijatra. Finished forms stay on this phone.'**
  String get deviceNoticeSwitchedOff;

  /// Button on the Today notice that opens the waiting screen.
  ///
  /// In en, this message translates to:
  /// **'Show this phone\'s numbers'**
  String get deviceShowCode;

  /// Button on the Today notice that opens the device screen.
  ///
  /// In en, this message translates to:
  /// **'See what to do'**
  String get deviceSeeWhatToDo;

  /// Heading of the Settings section about this phone's approval.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get settingsThisPhone;

  /// This phone's status in Settings.
  ///
  /// In en, this message translates to:
  /// **'Approved until {date}'**
  String deviceStatusApproved(String date);

  /// This phone's status in Settings.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get deviceStatusWaiting;

  /// This phone's status in Settings.
  ///
  /// In en, this message translates to:
  /// **'Approval has run out'**
  String get deviceStatusRenewal;

  /// This phone's status in Settings.
  ///
  /// In en, this message translates to:
  /// **'Switched off'**
  String get deviceStatusSwitchedOff;

  /// This phone's status in Settings.
  ///
  /// In en, this message translates to:
  /// **'Not set up yet'**
  String get deviceStatusSettingUp;

  /// Plain-language explanation of the problem code "offline". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'There is no internet connection right now. Your work is safe on this phone and will be sent when the signal returns.'**
  String get problem_offline;

  /// Plain-language explanation of the problem code "timeout". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The connection is too slow. We will try again by ourselves.'**
  String get problem_timeout;

  /// Plain-language explanation of the problem code "serverError". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The server has a problem. This is not your fault. We will try again by ourselves.'**
  String get problem_serverError;

  /// Plain-language explanation of the problem code "serverBusy". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The server is busy. We will try again in a little while.'**
  String get problem_serverBusy;

  /// Plain-language explanation of the problem code "signInRequired". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to send your forms. Your answers stay on this phone.'**
  String get problem_signInRequired;

  /// Plain-language explanation of the problem code "signInFailed". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The email or password is not right, or this account is not active. Check them and try again.'**
  String get problem_signInFailed;

  /// Plain-language explanation of the problem code "accountNotPermitted". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This account is not allowed to do this. Please contact your organisation.'**
  String get problem_accountNotPermitted;

  /// Plain-language explanation of the problem code "differentUser". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Forms from another person are still waiting on this phone. Sign in as that person to send them first.'**
  String get problem_differentUser;

  /// Plain-language explanation of the problem code "appUpdateRequired". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This app is too old to send forms. Please update the app. Your answers are kept.'**
  String get problem_appUpdateRequired;

  /// Plain-language explanation of the problem code "serverIncompatible". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This app and the server do not match. Please update the app or ask your organisation.'**
  String get problem_serverIncompatible;

  /// Plain-language explanation of the problem code "serverNotSetUp". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The server is not ready yet. Please ask your organisation\'s administrator.'**
  String get problem_serverNotSetUp;

  /// Plain-language explanation of the problem code "clockSkew": the phone's clock is more than 10 minutes away from the server's. Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The date or time on this phone is wrong, so forms cannot be sent. Open the phone\'s Settings, set the right date and time (turn on automatic date and time if you can), then come back to the app. Your forms are kept on this phone.'**
  String get problem_clockSkew;

  /// Plain-language explanation of the problem code "duplicateInstance". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The server already has a different form with the same code. Your answers are kept. Please tell your organisation.'**
  String get problem_duplicateInstance;

  /// Plain-language explanation of the problem code "formNotOnServer". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The server does not have this version of the form. Please tell your organisation.'**
  String get problem_formNotOnServer;

  /// Plain-language explanation of the problem code "submissionInvalid". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The server could not accept this form. Your answers are kept. Please tell your organisation.'**
  String get problem_submissionInvalid;

  /// Plain-language explanation of the problem code "submissionTooLarge". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This form, with its files, is too big to send. Please tell your organisation.'**
  String get problem_submissionTooLarge;

  /// Plain-language explanation of the problem code "attachmentMissing". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'A photo or file of this form is missing on this phone. Please tell your organisation.'**
  String get problem_attachmentMissing;

  /// Plain-language explanation of the problem code "formInvalid". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This form could not be opened. Get the forms again when you have internet, or tell your organisation.'**
  String get problem_formInvalid;

  /// Plain-language explanation of the problem code "databaseKeyMissing". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The key to the saved data on this phone is missing, so the data cannot be opened. Please contact your organisation before you do anything else.'**
  String get problem_databaseKeyMissing;

  /// Plain-language explanation of the problem code "databaseKeyRejected". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The saved data on this phone could not be unlocked. Do not delete the app. Please contact your organisation.'**
  String get problem_databaseKeyRejected;

  /// Plain-language explanation of the problem code "databaseFromNewerApp". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The saved data was made by a newer version of the app. Please update the app.'**
  String get problem_databaseFromNewerApp;

  /// Plain-language explanation of the problem code "databaseUnavailable". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The saved data on this phone could not be opened. Please restart the phone. If it happens again, contact your organisation.'**
  String get problem_databaseUnavailable;

  /// Plain-language explanation of the problem code "unexpectedResponse". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The server answered in a way the app does not understand. We will try again later.'**
  String get problem_unexpectedResponse;

  /// Plain-language explanation of the problem code "redirected": the server answered with a redirect, which the app never follows (often a public Wi-Fi sign-in page). Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The server address sent the app to a different address, so nothing was sent. If you use public Wi-Fi, open its sign-in page first. Otherwise, check the server address with your organisation. We will try again later.'**
  String get problem_redirected;

  /// Plain-language explanation of the problem code "phoneNumberInvalid". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This mobile number is not in the right form. Check it and try again.'**
  String get problem_phoneNumberInvalid;

  /// Plain-language explanation of the problem code "tooManySignInCodes". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Too many codes were asked for. Wait 15 minutes, or use another way to sign in.'**
  String get problem_tooManySignInCodes;

  /// Plain-language explanation of the problem code "signInCodeWrong". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'That code is wrong or has expired. Check the SMS, or ask for a new code. After 10 wrong tries, sign-in is locked for 15 minutes.'**
  String get problem_signInCodeWrong;

  /// Plain-language explanation of the problem code "tooManyCodeTries". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait 15 minutes, then ask for a new code.'**
  String get problem_tooManyCodeTries;

  /// Plain-language explanation of the problem code "signInMethodOff". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This way to sign in is switched off on your organisation\'s server. Use another way to sign in.'**
  String get problem_signInMethodOff;

  /// Plain-language explanation of the problem code "googleSignInRefused". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Ask your organisation admin to add your Google email address to your account, or use another way to sign in.'**
  String get problem_googleSignInRefused;

  /// Plain-language explanation of the problem code "signInCancelled". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was stopped. You can try again.'**
  String get problem_signInCancelled;

  /// Plain-language explanation of the problem code "browserUnavailable". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This phone could not open a web page to sign in. Use another way to sign in.'**
  String get problem_browserUnavailable;

  /// Plain-language explanation of the problem code "passwordChangeRequired". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Choose your own password before you continue. Your organisation gave you a one-time password. Your work is safe on this phone.'**
  String get problem_passwordChangeRequired;

  /// Plain-language explanation of the problem code "currentPasswordWrong". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'That password is not right. Type the one-time password exactly as your organisation gave it to you.'**
  String get problem_currentPasswordWrong;

  /// Plain-language explanation of the problem code "newPasswordInvalid". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This new password cannot be used. Use at least 12 characters, for example 3 or 4 words.'**
  String get problem_newPasswordInvalid;

  /// Plain-language explanation of the problem code "passwordChangedSignInAgain". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Your new password is saved. Sign in again with your new password.'**
  String get problem_passwordChangedSignInAgain;

  /// Plain-language explanation of the problem code "deviceNotEnrolled". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This phone is not set up with your organisation\'s server yet. Connect to the internet and open the app: it sets itself up. Your work is safe on this phone.'**
  String get problem_deviceNotEnrolled;

  /// Plain-language explanation of the problem code "deviceSignatureInvalid". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The server could not check this phone\'s request. We will try again by ourselves. If it keeps happening, sign out and sign in again.'**
  String get problem_deviceSignatureInvalid;

  /// Plain-language explanation of the problem code "deviceUnknown". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Your organisation\'s server no longer knew this phone, so the phone is set up again with the same numbers and must be approved again. Your forms stay on this phone.'**
  String get problem_deviceUnknown;

  /// Plain-language explanation of the problem code "deviceClockWrong". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'The date or time on this phone is wrong, so the server cannot accept it. Open the phone\'s Settings and turn on automatic date and time, then come back and try again. Your forms are kept on this phone.'**
  String get problem_deviceClockWrong;

  /// Plain-language explanation of the problem code "deviceNotApproved". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This phone is waiting for approval by your branch manager or an organisation admin. Your forms are kept and sent once it is approved.'**
  String get problem_deviceNotApproved;

  /// Plain-language explanation of the problem code "deviceApprovalExpired". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s approval has run out. Ask your branch manager or an organisation admin to approve it again. Your forms are kept.'**
  String get problem_deviceApprovalExpired;

  /// Plain-language explanation of the problem code "deviceRevoked". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Your organisation has switched off this phone for Obhijatra. Your forms stay on this phone. Ask your organisation admin what to do.'**
  String get problem_deviceRevoked;

  /// Plain-language explanation of the problem code "sessionEnded". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in has ended. Please sign in again to send your forms. Your answers stay on this phone.'**
  String get problem_sessionEnded;

  /// Plain-language explanation of the problem code "sessionOnOtherDevice". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This sign-in belongs to another phone. Please sign in again on this phone. Your answers stay on this phone.'**
  String get problem_sessionOnOtherDevice;

  /// Plain-language explanation of the problem code "deviceKeyInUse". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s numbers are already in use, so it could not be set up. Try again. If it happens again, ask your organisation admin.'**
  String get problem_deviceKeyInUse;

  /// Plain-language explanation of the problem code "tooManyDevicesWaiting". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Three of your phones are already waiting for approval. Ask your branch manager or an organisation admin to approve them or switch them off, then try again.'**
  String get problem_tooManyDevicesWaiting;

  /// Plain-language explanation of the problem code "unknown". Shown to a field officer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Your work is safe on this phone. Please try again.'**
  String get problem_unknown;
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
