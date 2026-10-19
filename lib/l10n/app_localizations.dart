import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'QRM Intelligent Planner'**
  String get appTitle;

  /// No description provided for @languageName.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @dailyPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dailyPlanTitle;

  /// No description provided for @dailyPlanEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'What should I do today?'**
  String get dailyPlanEmptyTitle;

  /// No description provided for @dailyPlanEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your daily plan will appear here once you create a Q.'**
  String get dailyPlanEmptyMessage;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsThemeSection.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeSection;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsReadingDirectionSection.
  ///
  /// In en, this message translates to:
  /// **'Reading direction'**
  String get settingsReadingDirectionSection;

  /// No description provided for @settingsReadingDirectionHint.
  ///
  /// In en, this message translates to:
  /// **'How the text runs on screen. Right to left puts page 1 on the right, like the book. It applies to the page strips, the Overview cells and the paging in Browse; minutes and other bars are not affected.'**
  String get settingsReadingDirectionHint;

  /// No description provided for @settingsReadingRightToLeft.
  ///
  /// In en, this message translates to:
  /// **'Right to left'**
  String get settingsReadingRightToLeft;

  /// No description provided for @settingsReadingLeftToRight.
  ///
  /// In en, this message translates to:
  /// **'Left to right'**
  String get settingsReadingLeftToRight;

  /// No description provided for @failureStorage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while saving or loading your data. Please try again.'**
  String get failureStorage;

  /// No description provided for @failureNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item could not be found.'**
  String get failureNotFound;

  /// No description provided for @routeNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get routeNotFoundTitle;

  /// No description provided for @routeNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'The page you are looking for does not exist.'**
  String get routeNotFoundMessage;

  /// No description provided for @routeNotFoundAction.
  ///
  /// In en, this message translates to:
  /// **'Back to Today'**
  String get routeNotFoundAction;

  /// No description provided for @valueNone.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get valueNone;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @minutesValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesValue(String minutes);

  /// No description provided for @pagesSingle.
  ///
  /// In en, this message translates to:
  /// **'p {page}'**
  String pagesSingle(int page);

  /// No description provided for @pagesRange.
  ///
  /// In en, this message translates to:
  /// **'p {from} - {to}'**
  String pagesRange(int from, int to);

  /// No description provided for @chLabelOne.
  ///
  /// In en, this message translates to:
  /// **'ch {ch}'**
  String chLabelOne(int ch);

  /// No description provided for @chLabelRun.
  ///
  /// In en, this message translates to:
  /// **'ch {first} - {last}'**
  String chLabelRun(int first, int last);

  /// No description provided for @chSegmentText.
  ///
  /// In en, this message translates to:
  /// **'{label}, {pages}'**
  String chSegmentText(String label, String pages);

  /// No description provided for @chFromBeginning.
  ///
  /// In en, this message translates to:
  /// **'ch {ch}, from its beginning (p {first})'**
  String chFromBeginning(int ch, int first);

  /// No description provided for @chFromBeginningTo.
  ///
  /// In en, this message translates to:
  /// **'ch {ch}, from its beginning (p {first}) to p {last}'**
  String chFromBeginningTo(int ch, int first, int last);

  /// No description provided for @todayStorageError.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get todayStorageError;

  /// No description provided for @todayNothingToPlan.
  ///
  /// In en, this message translates to:
  /// **'Nothing to plan yet. Tap Log session to record what you studied.'**
  String get todayNothingToPlan;

  /// No description provided for @summaryBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get summaryBudget;

  /// No description provided for @summaryPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get summaryPlan;

  /// No description provided for @summaryDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get summaryDone;

  /// No description provided for @summaryLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get summaryLeft;

  /// No description provided for @summaryBudgetSplit.
  ///
  /// In en, this message translates to:
  /// **'{base} min + {extra} min added'**
  String summaryBudgetSplit(String base, String extra);

  /// No description provided for @planMake.
  ///
  /// In en, this message translates to:
  /// **'Make a plan'**
  String get planMake;

  /// No description provided for @planAddTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get planAddTime;

  /// No description provided for @planAddTimeOption.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String planAddTimeOption(int minutes);

  /// No description provided for @proposalTitle.
  ///
  /// In en, this message translates to:
  /// **'Latest plan'**
  String get proposalTitle;

  /// No description provided for @proposalSource.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String proposalSource(String source);

  /// No description provided for @proposalSourceRuleBased.
  ///
  /// In en, this message translates to:
  /// **'Rule-based planner'**
  String get proposalSourceRuleBased;

  /// No description provided for @proposalEmpty.
  ///
  /// In en, this message translates to:
  /// **'This plan has no operations.'**
  String get proposalEmpty;

  /// No description provided for @proposalAtRisk.
  ///
  /// In en, this message translates to:
  /// **'At risk tonight if nothing more is done: {pages}'**
  String proposalAtRisk(String pages);

  /// No description provided for @proposalNotIncluded.
  ///
  /// In en, this message translates to:
  /// **'Not included ({count})'**
  String proposalNotIncluded(int count);

  /// No description provided for @rowDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get rowDone;

  /// No description provided for @rowMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get rowMarkDone;

  /// No description provided for @rowMarkNotSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Done, not successful'**
  String get rowMarkNotSuccessful;

  /// No description provided for @rowMarkPartial.
  ///
  /// In en, this message translates to:
  /// **'Done partly'**
  String get rowMarkPartial;

  /// No description provided for @rowMenuNotSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Not successful'**
  String get rowMenuNotSuccessful;

  /// No description provided for @rowMenuDonePartly.
  ///
  /// In en, this message translates to:
  /// **'Done partly'**
  String get rowMenuDonePartly;

  /// No description provided for @rowMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get rowMenuTooltip;

  /// No description provided for @partialTitle.
  ///
  /// In en, this message translates to:
  /// **'Done partly'**
  String get partialTitle;

  /// No description provided for @partialFrom.
  ///
  /// In en, this message translates to:
  /// **'From page'**
  String get partialFrom;

  /// No description provided for @partialTo.
  ///
  /// In en, this message translates to:
  /// **'To page'**
  String get partialTo;

  /// No description provided for @partialChipLabel.
  ///
  /// In en, this message translates to:
  /// **'ch {ch} ({pages})'**
  String partialChipLabel(int ch, String pages);

  /// No description provided for @partialSharedNote.
  ///
  /// In en, this message translates to:
  /// **'p {page} belongs to ch {ch}.'**
  String partialSharedNote(int page, int ch);

  /// No description provided for @partialInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter pages from {first} to {last}.'**
  String partialInvalid(int first, int last);

  /// No description provided for @partialMergedNote.
  ///
  /// In en, this message translates to:
  /// **'This op includes a merged ch. R on a merged ch is all or nothing, so it cannot be done partly. Use Done to log the whole op.'**
  String get partialMergedNote;

  /// No description provided for @partialConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get partialConfirm;

  /// No description provided for @logSomethingElse.
  ///
  /// In en, this message translates to:
  /// **'Log session'**
  String get logSomethingElse;

  /// No description provided for @logOperation.
  ///
  /// In en, this message translates to:
  /// **'Operation'**
  String get logOperation;

  /// No description provided for @logSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get logSuccessful;

  /// No description provided for @logRejected.
  ///
  /// In en, this message translates to:
  /// **'The rules refused this:'**
  String get logRejected;

  /// No description provided for @logConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get logConfirm;

  /// No description provided for @logPagesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter whole page numbers, from the first to the last.'**
  String get logPagesInvalid;

  /// No description provided for @loggedTitle.
  ///
  /// In en, this message translates to:
  /// **'Logged today'**
  String get loggedTitle;

  /// No description provided for @loggedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet.'**
  String get loggedEmpty;

  /// No description provided for @loggedKindPlanned.
  ///
  /// In en, this message translates to:
  /// **'planned'**
  String get loggedKindPlanned;

  /// No description provided for @loggedKindPartial.
  ///
  /// In en, this message translates to:
  /// **'partial'**
  String get loggedKindPartial;

  /// No description provided for @loggedKindCustom.
  ///
  /// In en, this message translates to:
  /// **'manual'**
  String get loggedKindCustom;

  /// No description provided for @loggedNotSuccessful.
  ///
  /// In en, this message translates to:
  /// **'not successful'**
  String get loggedNotSuccessful;

  /// No description provided for @failedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your saved data could not be loaded'**
  String get failedTitle;

  /// No description provided for @failedMessage.
  ///
  /// In en, this message translates to:
  /// **'{reason}'**
  String failedMessage(String reason);

  /// No description provided for @failedStartFresh.
  ///
  /// In en, this message translates to:
  /// **'Start fresh'**
  String get failedStartFresh;

  /// No description provided for @failedConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Start fresh?'**
  String get failedConfirmTitle;

  /// No description provided for @failedConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The damaged file was kept: it was renamed and is still in the app data folder. Starting fresh creates a new, empty Q.'**
  String get failedConfirmBody;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your Q'**
  String get setupTitle;

  /// No description provided for @setupIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell the app which pages are in which state today. Pages you do not list are ND.'**
  String get setupIntro;

  /// No description provided for @setupMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes per day'**
  String get setupMinutes;

  /// No description provided for @setupRowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pages already learned'**
  String get setupRowsTitle;

  /// No description provided for @setupAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add a row'**
  String get setupAddRow;

  /// No description provided for @setupRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Row {n}'**
  String setupRowTitle(int n);

  /// No description provided for @setupRemoveRow.
  ///
  /// In en, this message translates to:
  /// **'Remove row'**
  String get setupRemoveRow;

  /// No description provided for @setupFrom.
  ///
  /// In en, this message translates to:
  /// **'From page'**
  String get setupFrom;

  /// No description provided for @setupTo.
  ///
  /// In en, this message translates to:
  /// **'To page'**
  String get setupTo;

  /// No description provided for @setupState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get setupState;

  /// No description provided for @setupProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress units'**
  String get setupProgress;

  /// No description provided for @setupDays.
  ///
  /// In en, this message translates to:
  /// **'Days since last R'**
  String get setupDays;

  /// No description provided for @setupDaysHelp.
  ///
  /// In en, this message translates to:
  /// **'0 means reviewed today, so no R is offered for these pages today.'**
  String get setupDaysHelp;

  /// No description provided for @setupConsolidated.
  ///
  /// In en, this message translates to:
  /// **'Was in C before'**
  String get setupConsolidated;

  /// No description provided for @setupStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get setupStart;

  /// No description provided for @setupStartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Start with nothing learned'**
  String get setupStartEmpty;

  /// No description provided for @setupBudgetInvalid.
  ///
  /// In en, this message translates to:
  /// **'Minutes per day must be a number above 0.'**
  String get setupBudgetInvalid;

  /// No description provided for @setupSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the setup. Please try again.'**
  String get setupSaveFailed;

  /// No description provided for @setupProblemNumbers.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: enter whole numbers in the fields.'**
  String setupProblemNumbers(int row);

  /// No description provided for @setupProblemState.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: this state is not allowed.'**
  String setupProblemState(int row);

  /// No description provided for @setupProblemFromAfterTo.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: the first page is after the last page.'**
  String setupProblemFromAfterTo(int row);

  /// No description provided for @setupProblemOutOfBounds.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: page {page} is outside 1 - 604.'**
  String setupProblemOutOfBounds(int row, int page);

  /// No description provided for @setupProblemProgressNegative.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: progress cannot be below 0.'**
  String setupProblemProgressNegative(int row);

  /// No description provided for @setupProblemProgressTooHigh.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: progress {value} is too high (max {max}).'**
  String setupProblemProgressTooHigh(int row, int value, int max);

  /// No description provided for @setupProblemProgressNotForState.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: progress units are only for D rows.'**
  String setupProblemProgressNotForState(int row);

  /// No description provided for @setupProblemDaysNegative.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: days since the last R cannot be below 0.'**
  String setupProblemDaysNegative(int row);

  /// No description provided for @setupProblemOverlap.
  ///
  /// In en, this message translates to:
  /// **'Rows {row} and {other} overlap.'**
  String setupProblemOverlap(int row, int other);

  /// No description provided for @setupProblemInvalidQ.
  ///
  /// In en, this message translates to:
  /// **'The Q is not valid: {detail}'**
  String setupProblemInvalidQ(String detail);

  /// No description provided for @navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// No description provided for @overviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overviewTitle;

  /// No description provided for @overviewNeedSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish the setup on Today first to see your Q.'**
  String get overviewNeedSetup;

  /// No description provided for @overviewMain.
  ///
  /// In en, this message translates to:
  /// **'Main range: {text}'**
  String overviewMain(String text);

  /// No description provided for @overviewNoMain.
  ///
  /// In en, this message translates to:
  /// **'No main range yet.'**
  String get overviewNoMain;

  /// No description provided for @overviewNextForward.
  ///
  /// In en, this message translates to:
  /// **'Next forward M starts at p {page}.'**
  String overviewNextForward(int page);

  /// No description provided for @overviewNextBackward.
  ///
  /// In en, this message translates to:
  /// **'Next backward M starts at p {page} (s {s}, block {block}).'**
  String overviewNextBackward(int page, int s, String block);

  /// No description provided for @overviewDRanges.
  ///
  /// In en, this message translates to:
  /// **'D ranges: {count}'**
  String overviewDRanges(int count);

  /// No description provided for @overviewMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged ch: {count}'**
  String overviewMerged(int count);

  /// No description provided for @overviewBadgeMerged.
  ///
  /// In en, this message translates to:
  /// **'merged'**
  String get overviewBadgeMerged;

  /// No description provided for @sheetPageTitle.
  ///
  /// In en, this message translates to:
  /// **'p {page}: {label}'**
  String sheetPageTitle(int page, String label);

  /// No description provided for @sheetProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress {units} of {needed} units'**
  String sheetProgress(int units, int needed);

  /// No description provided for @sheetProgressNone.
  ///
  /// In en, this message translates to:
  /// **'No progress units in this state'**
  String get sheetProgressNone;

  /// No description provided for @sheetPrimeYes.
  ///
  /// In en, this message translates to:
  /// **'Prime: yes'**
  String get sheetPrimeYes;

  /// No description provided for @sheetPrimeNo.
  ///
  /// In en, this message translates to:
  /// **'Prime: no'**
  String get sheetPrimeNo;

  /// No description provided for @sheetLastR.
  ///
  /// In en, this message translates to:
  /// **'Last R: {date} ({days} days ago)'**
  String sheetLastR(String date, int days);

  /// No description provided for @sheetLastRNone.
  ///
  /// In en, this message translates to:
  /// **'No R yet'**
  String get sheetLastRNone;

  /// No description provided for @sheetLActive.
  ///
  /// In en, this message translates to:
  /// **'L active until {date}'**
  String sheetLActive(String date);

  /// No description provided for @sheetNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next step down without an R: {date}'**
  String sheetNextStep(String date);

  /// No description provided for @proposalSourceAi.
  ///
  /// In en, this message translates to:
  /// **'AI planner ({name})'**
  String proposalSourceAi(String name);

  /// No description provided for @proposalSourceFallback.
  ///
  /// In en, this message translates to:
  /// **'Offline fallback (the AI planner did not answer)'**
  String get proposalSourceFallback;

  /// No description provided for @proposalSourceOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline planner (rules)'**
  String get proposalSourceOffline;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved.'**
  String get settingsSaved;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the settings.'**
  String get settingsSaveFailed;

  /// No description provided for @settingsFixProblems.
  ///
  /// In en, this message translates to:
  /// **'Fix the problems shown to save.'**
  String get settingsFixProblems;

  /// No description provided for @settingsPlanningNote.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to the next plan. Today’s budget stays; use Add time on Today.'**
  String get settingsPlanningNote;

  /// No description provided for @settingsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Settings are disabled because the stored data could not be loaded.'**
  String get settingsDisabled;

  /// No description provided for @settingsResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get settingsResetAll;

  /// No description provided for @settingsResetAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset all settings?'**
  String get settingsResetAllTitle;

  /// No description provided for @settingsResetAllBody.
  ///
  /// In en, this message translates to:
  /// **'All planning settings go back to their defaults. Nothing is saved until you press Save.'**
  String get settingsResetAllBody;

  /// No description provided for @settingsResetSection.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get settingsResetSection;

  /// No description provided for @settingsDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get settingsDiscardTitle;

  /// No description provided for @settingsDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes.'**
  String get settingsDiscardBody;

  /// No description provided for @settingsDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get settingsDiscard;

  /// No description provided for @settingsKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get settingsKeepEditing;

  /// No description provided for @settingsSectionBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get settingsSectionBudget;

  /// No description provided for @settingsSectionExpansion.
  ///
  /// In en, this message translates to:
  /// **'Expansion'**
  String get settingsSectionExpansion;

  /// No description provided for @settingsSectionTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get settingsSectionTime;

  /// No description provided for @settingsSectionShared.
  ///
  /// In en, this message translates to:
  /// **'Shared pages'**
  String get settingsSectionShared;

  /// No description provided for @settingsSectionL.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get settingsSectionL;

  /// No description provided for @settingsSectionPriorities.
  ///
  /// In en, this message translates to:
  /// **'Priorities'**
  String get settingsSectionPriorities;

  /// No description provided for @settingsSectionPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning and workload'**
  String get settingsSectionPlanning;

  /// No description provided for @settingsSectionAi.
  ///
  /// In en, this message translates to:
  /// **'AI planner'**
  String get settingsSectionAi;

  /// No description provided for @stepperLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get stepperLess;

  /// No description provided for @stepperMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get stepperMore;

  /// No description provided for @fieldBaseBudget.
  ///
  /// In en, this message translates to:
  /// **'Minutes per day'**
  String get fieldBaseBudget;

  /// No description provided for @fieldDirectionMode.
  ///
  /// In en, this message translates to:
  /// **'Expansion direction'**
  String get fieldDirectionMode;

  /// No description provided for @modeBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get modeBoth;

  /// No description provided for @modeForwardOnly.
  ///
  /// In en, this message translates to:
  /// **'Forward only'**
  String get modeForwardOnly;

  /// No description provided for @modeBackwardOnly.
  ///
  /// In en, this message translates to:
  /// **'Backward only'**
  String get modeBackwardOnly;

  /// No description provided for @fieldExpansionTarget.
  ///
  /// In en, this message translates to:
  /// **'Target pages per period'**
  String get fieldExpansionTarget;

  /// No description provided for @fieldExpansionPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period (days)'**
  String get fieldExpansionPeriod;

  /// No description provided for @fieldMaxInRow.
  ///
  /// In en, this message translates to:
  /// **'Max in a row in one direction'**
  String get fieldMaxInRow;

  /// No description provided for @fieldAllowSameDirection.
  ///
  /// In en, this message translates to:
  /// **'Allow the same direction when the opposite is blocked'**
  String get fieldAllowSameDirection;

  /// No description provided for @fieldMainTieBreak.
  ///
  /// In en, this message translates to:
  /// **'Main range tie-break'**
  String get fieldMainTieBreak;

  /// No description provided for @tieLowerPages.
  ///
  /// In en, this message translates to:
  /// **'Lower pages'**
  String get tieLowerPages;

  /// No description provided for @tieHigherPages.
  ///
  /// In en, this message translates to:
  /// **'Higher pages'**
  String get tieHigherPages;

  /// No description provided for @fieldTargetPerDirection.
  ///
  /// In en, this message translates to:
  /// **'Target per direction (empty = half of the target)'**
  String get fieldTargetPerDirection;

  /// No description provided for @fieldCapacityGate.
  ///
  /// In en, this message translates to:
  /// **'Capacity gate'**
  String get fieldCapacityGate;

  /// No description provided for @fieldAllowBeyondTarget.
  ///
  /// In en, this message translates to:
  /// **'Allow beyond the target'**
  String get fieldAllowBeyondTarget;

  /// No description provided for @fieldMMinutesNd.
  ///
  /// In en, this message translates to:
  /// **'M minutes per ND page'**
  String get fieldMMinutesNd;

  /// No description provided for @fieldMMinutesF3.
  ///
  /// In en, this message translates to:
  /// **'M minutes per F3 page'**
  String get fieldMMinutesF3;

  /// No description provided for @fieldRStart.
  ///
  /// In en, this message translates to:
  /// **'First R minutes (normal page)'**
  String get fieldRStart;

  /// No description provided for @fieldPrimeFactor.
  ///
  /// In en, this message translates to:
  /// **'First R factor for prime pages'**
  String get fieldPrimeFactor;

  /// No description provided for @fieldRD3Cap.
  ///
  /// In en, this message translates to:
  /// **'D3 floor (minutes)'**
  String get fieldRD3Cap;

  /// No description provided for @fieldRCCap.
  ///
  /// In en, this message translates to:
  /// **'C minutes'**
  String get fieldRCCap;

  /// No description provided for @fieldCurve.
  ///
  /// In en, this message translates to:
  /// **'Curve steepness'**
  String get fieldCurve;

  /// No description provided for @fieldD3Mode.
  ///
  /// In en, this message translates to:
  /// **'D3 mode'**
  String get fieldD3Mode;

  /// No description provided for @d3ModeCap.
  ///
  /// In en, this message translates to:
  /// **'Cap'**
  String get d3ModeCap;

  /// No description provided for @d3ModeCont.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get d3ModeCont;

  /// No description provided for @fieldD3Hold.
  ///
  /// In en, this message translates to:
  /// **'D3 hold units'**
  String get fieldD3Hold;

  /// No description provided for @sharedOpen.
  ///
  /// In en, this message translates to:
  /// **'Edit shared pages'**
  String get sharedOpen;

  /// No description provided for @sharedCustomCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pages with their own share'**
  String sharedCustomCount(int count);

  /// No description provided for @sharedProblems.
  ///
  /// In en, this message translates to:
  /// **'{count} shared pages have a problem.'**
  String sharedProblems(int count);

  /// No description provided for @sharedTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared pages'**
  String get sharedTitle;

  /// No description provided for @sharedChPair.
  ///
  /// In en, this message translates to:
  /// **'ch {a} / ch {b}'**
  String sharedChPair(int a, int b);

  /// No description provided for @sharedSplit.
  ///
  /// In en, this message translates to:
  /// **'ch {a} gets {aShare}, ch {b} gets {bShare}'**
  String sharedSplit(int a, String aShare, int b, String bShare);

  /// No description provided for @sharedReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to 0.5'**
  String get sharedReset;

  /// No description provided for @fieldLDays.
  ///
  /// In en, this message translates to:
  /// **'L days'**
  String get fieldLDays;

  /// No description provided for @priorityHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder. The first one gets minutes first.'**
  String get priorityHint;

  /// No description provided for @workClassRecoverF3.
  ///
  /// In en, this message translates to:
  /// **'F3 recovery or restart'**
  String get workClassRecoverF3;

  /// No description provided for @workClassExpand.
  ///
  /// In en, this message translates to:
  /// **'Expansion'**
  String get workClassExpand;

  /// No description provided for @workClassWorkingSetR.
  ///
  /// In en, this message translates to:
  /// **'Working-set R'**
  String get workClassWorkingSetR;

  /// No description provided for @workClassMaintainC.
  ///
  /// In en, this message translates to:
  /// **'C maintenance'**
  String get workClassMaintainC;

  /// No description provided for @fieldMaintainLead.
  ///
  /// In en, this message translates to:
  /// **'C maintenance lead (days)'**
  String get fieldMaintainLead;

  /// No description provided for @fieldMaxSnapshotGroups.
  ///
  /// In en, this message translates to:
  /// **'Max snapshot groups'**
  String get fieldMaxSnapshotGroups;

  /// No description provided for @fieldWeekStartsOn.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get fieldWeekStartsOn;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @fieldProtectMandatory.
  ///
  /// In en, this message translates to:
  /// **'Protect mandatory work'**
  String get fieldProtectMandatory;

  /// No description provided for @fieldCatchUpStretch.
  ///
  /// In en, this message translates to:
  /// **'Catch-up stretch'**
  String get fieldCatchUpStretch;

  /// No description provided for @fieldMaxDaily.
  ///
  /// In en, this message translates to:
  /// **'Max minutes per day (empty = no cap)'**
  String get fieldMaxDaily;

  /// No description provided for @fieldUtilization.
  ///
  /// In en, this message translates to:
  /// **'Utilization'**
  String get fieldUtilization;

  /// No description provided for @aiEnable.
  ///
  /// In en, this message translates to:
  /// **'Use the AI planner'**
  String get aiEnable;

  /// No description provided for @aiProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get aiProviderLabel;

  /// No description provided for @aiModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get aiModelLabel;

  /// No description provided for @aiModelDefault.
  ///
  /// In en, this message translates to:
  /// **'Empty = default ({model})'**
  String aiModelDefault(String model);

  /// No description provided for @aiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get aiKeyLabel;

  /// No description provided for @aiKeySave.
  ///
  /// In en, this message translates to:
  /// **'Save key'**
  String get aiKeySave;

  /// No description provided for @aiKeyRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove key'**
  String get aiKeyRemove;

  /// No description provided for @aiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'A key is saved. It is not shown again.'**
  String get aiKeySaved;

  /// No description provided for @aiKeyNone.
  ///
  /// In en, this message translates to:
  /// **'No key saved.'**
  String get aiKeyNone;

  /// No description provided for @aiKeySavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Key saved.'**
  String get aiKeySavedMessage;

  /// No description provided for @aiKeyRemovedMessage.
  ///
  /// In en, this message translates to:
  /// **'Key removed.'**
  String get aiKeyRemovedMessage;

  /// No description provided for @aiKeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the key.'**
  String get aiKeyFailed;

  /// No description provided for @aiNeedsKey.
  ///
  /// In en, this message translates to:
  /// **'Save a key to use the AI planner.'**
  String get aiNeedsKey;

  /// No description provided for @aiOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'Without a key, or if the provider fails, the offline planner is used.'**
  String get aiOfflineNote;

  /// No description provided for @aiPrivacy.
  ///
  /// In en, this message translates to:
  /// **'A plan request sends a summary of your Q (page states, no personal text) to the provider.'**
  String get aiPrivacy;

  /// No description provided for @fieldAiLowFactor.
  ///
  /// In en, this message translates to:
  /// **'AI plan: low factor'**
  String get fieldAiLowFactor;

  /// No description provided for @fieldAiHighFactor.
  ///
  /// In en, this message translates to:
  /// **'AI plan: high factor'**
  String get fieldAiHighFactor;

  /// No description provided for @todayOverBudget.
  ///
  /// In en, this message translates to:
  /// **'This plan is {minutes} min over today’s budget'**
  String todayOverBudget(String minutes);

  /// No description provided for @navBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get navBrowse;

  /// No description provided for @browseTitle.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browseTitle;

  /// No description provided for @browsePsTitle.
  ///
  /// In en, this message translates to:
  /// **'ps'**
  String get browsePsTitle;

  /// No description provided for @browseSsTitle.
  ///
  /// In en, this message translates to:
  /// **'ss'**
  String get browseSsTitle;

  /// No description provided for @browseChTitle.
  ///
  /// In en, this message translates to:
  /// **'ch'**
  String get browseChTitle;

  /// No description provided for @browseMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get browseMoreDetails;

  /// No description provided for @browseGroupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get browseGroupBy;

  /// No description provided for @browseGroupNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get browseGroupNone;

  /// No description provided for @browseGroupCh.
  ///
  /// In en, this message translates to:
  /// **'ch'**
  String get browseGroupCh;

  /// No description provided for @browseGroupS.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get browseGroupS;

  /// No description provided for @sLabelOne.
  ///
  /// In en, this message translates to:
  /// **'s {s}'**
  String sLabelOne(int s);

  /// No description provided for @sLabelRun.
  ///
  /// In en, this message translates to:
  /// **'s {first} - {last}'**
  String sLabelRun(int first, int last);

  /// No description provided for @browsePageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} p'**
  String browsePageCount(int count);

  /// No description provided for @browseTrail.
  ///
  /// In en, this message translates to:
  /// **'{first} · {second}'**
  String browseTrail(String first, String second);

  /// No description provided for @browseGroupState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get browseGroupState;

  /// No description provided for @browseGroupNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get browseGroupNotes;

  /// No description provided for @browseGroupHasNotes.
  ///
  /// In en, this message translates to:
  /// **'Has open notes'**
  String get browseGroupHasNotes;

  /// No description provided for @browseGroupNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No open notes'**
  String get browseGroupNoNotes;

  /// No description provided for @browseSCount.
  ///
  /// In en, this message translates to:
  /// **'{count} s'**
  String browseSCount(int count);

  /// No description provided for @browseChCount.
  ///
  /// In en, this message translates to:
  /// **'{count} ch'**
  String browseChCount(int count);

  /// No description provided for @browseOpenNotes.
  ///
  /// In en, this message translates to:
  /// **'{count} open notes'**
  String browseOpenNotes(int count);

  /// No description provided for @infoState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get infoState;

  /// No description provided for @infoComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get infoComplete;

  /// No description provided for @infoWorstState.
  ///
  /// In en, this message translates to:
  /// **'Worst state'**
  String get infoWorstState;

  /// No description provided for @infoAllAtLeastD3.
  ///
  /// In en, this message translates to:
  /// **'All pages at least D3'**
  String get infoAllAtLeastD3;

  /// No description provided for @infoYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get infoYes;

  /// No description provided for @infoNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get infoNo;

  /// No description provided for @infoMergedShared.
  ///
  /// In en, this message translates to:
  /// **'Merged ch: shared state'**
  String get infoMergedShared;

  /// No description provided for @infoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The state is not available until your Q is loaded.'**
  String get infoUnavailable;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTitle;

  /// No description provided for @notesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get notesAdd;

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open notes.'**
  String get notesEmpty;

  /// No description provided for @notesArchiveLink.
  ///
  /// In en, this message translates to:
  /// **'Archive ({count})'**
  String notesArchiveLink(int count);

  /// No description provided for @notesArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get notesArchiveTitle;

  /// No description provided for @notesArchiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing archived here.'**
  String get notesArchiveEmpty;

  /// No description provided for @notesTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes for what you reviewed'**
  String get notesTodayTitle;

  /// No description provided for @noteRemembered.
  ///
  /// In en, this message translates to:
  /// **'I remembered'**
  String get noteRemembered;

  /// No description provided for @noteRememberedToday.
  ///
  /// In en, this message translates to:
  /// **'Remembered today, counted when the day ends'**
  String get noteRememberedToday;

  /// No description provided for @noteRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get noteRestore;

  /// No description provided for @noteDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get noteDelete;

  /// No description provided for @noteDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get noteDeleteTitle;

  /// No description provided for @noteDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'It is deleted for good.'**
  String get noteDeleteMessage;

  /// No description provided for @noteResolvedOn.
  ///
  /// In en, this message translates to:
  /// **'Remembered 5 days, resolved {date}'**
  String noteResolvedOn(String date);

  /// No description provided for @noteAddTitle.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get noteAddTitle;

  /// No description provided for @noteAddText.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteAddText;

  /// No description provided for @noteAddPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get noteAddPage;

  /// No description provided for @noteAddPageOutside.
  ///
  /// In en, this message translates to:
  /// **'Pick a page from {first} to {last}'**
  String noteAddPageOutside(int first, int last);

  /// No description provided for @noteAddFiledUnder.
  ///
  /// In en, this message translates to:
  /// **'Filed under'**
  String get noteAddFiledUnder;

  /// No description provided for @noteAddSave.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get noteAddSave;
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
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
