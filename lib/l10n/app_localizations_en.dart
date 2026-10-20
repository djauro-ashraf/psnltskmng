// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'QRM Intelligent Planner';

  @override
  String get languageName => 'English';

  @override
  String get navToday => 'Today';

  @override
  String get navSettings => 'Settings';

  @override
  String get dailyPlanTitle => 'Today';

  @override
  String get dailyPlanEmptyTitle => 'What should I do today?';

  @override
  String get dailyPlanEmptyMessage =>
      'Your daily plan will appear here once you create a Q.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsThemeSection => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsReadingDirectionSection => 'Reading direction';

  @override
  String get settingsReadingDirectionHint =>
      'How the text runs on screen. Right to left puts page 1 on the right, like the book. It applies to the page strips, the Overview cells and the paging in Browse; minutes and other bars are not affected.';

  @override
  String get settingsReadingRightToLeft => 'Right to left';

  @override
  String get settingsReadingLeftToRight => 'Left to right';

  @override
  String get failureStorage =>
      'Something went wrong while saving or loading your data. Please try again.';

  @override
  String get failureNotFound => 'This item could not be found.';

  @override
  String get routeNotFoundTitle => 'Page not found';

  @override
  String get routeNotFoundMessage =>
      'The page you are looking for does not exist.';

  @override
  String get routeNotFoundAction => 'Back to Today';

  @override
  String get valueNone => '—';

  @override
  String get cancel => 'Cancel';

  @override
  String minutesValue(String minutes) {
    return '$minutes min';
  }

  @override
  String pagesSingle(int page) {
    return 'p $page';
  }

  @override
  String pagesRange(int from, int to) {
    return 'p $from - $to';
  }

  @override
  String chLabelOne(int ch) {
    return 'ch $ch';
  }

  @override
  String chLabelRun(int first, int last) {
    return 'ch $first - $last';
  }

  @override
  String chSegmentText(String label, String pages) {
    return '$label, $pages';
  }

  @override
  String chFromBeginning(int ch, int first) {
    return 'ch $ch, from its beginning (p $first)';
  }

  @override
  String chFromBeginningTo(int ch, int first, int last) {
    return 'ch $ch, from its beginning (p $first) to p $last';
  }

  @override
  String get todayStorageError => 'Could not save. Please try again.';

  @override
  String get todayNothingToPlan =>
      'Nothing to plan yet. Tap Log session to record what you studied.';

  @override
  String get summaryBudget => 'Budget';

  @override
  String get summaryPlan => 'Plan';

  @override
  String get summaryDone => 'Done';

  @override
  String get summaryLeft => 'Left';

  @override
  String summaryBudgetSplit(String base, String extra) {
    return '$base min + $extra min added';
  }

  @override
  String get planMake => 'Make a plan';

  @override
  String get planAddTime => 'Add time';

  @override
  String planAddTimeOption(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get proposalTitle => 'Latest plan';

  @override
  String proposalSource(String source) {
    return 'Source: $source';
  }

  @override
  String get proposalSourceRuleBased => 'Rule-based planner';

  @override
  String get proposalEmpty => 'This plan has no operations.';

  @override
  String proposalAtRisk(String pages) {
    return 'At risk tonight if nothing more is done: $pages';
  }

  @override
  String proposalNotIncluded(int count) {
    return 'Not included ($count)';
  }

  @override
  String get rowDone => 'Done';

  @override
  String get rowMarkDone => 'Done';

  @override
  String get rowMarkNotSuccessful => 'Done, not successful';

  @override
  String get rowMarkPartial => 'Done partly';

  @override
  String get rowMenuNotSuccessful => 'Not successful';

  @override
  String get rowMenuDonePartly => 'Done partly';

  @override
  String get rowMenuTooltip => 'More options';

  @override
  String get partialTitle => 'Done partly';

  @override
  String get partialFrom => 'From page';

  @override
  String get partialTo => 'To page';

  @override
  String partialChipLabel(int ch, String pages) {
    return 'ch $ch ($pages)';
  }

  @override
  String partialSharedNote(int page, int ch) {
    return 'p $page belongs to ch $ch.';
  }

  @override
  String partialInvalid(int first, int last) {
    return 'Enter pages from $first to $last.';
  }

  @override
  String get partialMergedNote =>
      'This op includes a merged ch. R on a merged ch is all or nothing, so it cannot be done partly. Use Done to log the whole op.';

  @override
  String get partialConfirm => 'Log';

  @override
  String get logSomethingElse => 'Log session';

  @override
  String get logOperation => 'Operation';

  @override
  String get logSuccessful => 'Successful';

  @override
  String get logRejected => 'The rules refused this:';

  @override
  String get logConfirm => 'Log';

  @override
  String get logPagesInvalid =>
      'Enter whole page numbers, from the first to the last.';

  @override
  String get loggedTitle => 'Logged today';

  @override
  String get loggedEmpty => 'Nothing logged yet.';

  @override
  String get loggedKindPlanned => 'planned';

  @override
  String get loggedKindPartial => 'partial';

  @override
  String get loggedKindCustom => 'manual';

  @override
  String get loggedNotSuccessful => 'not successful';

  @override
  String get failedTitle => 'Your saved data could not be loaded';

  @override
  String failedMessage(String reason) {
    return '$reason';
  }

  @override
  String get failedStartFresh => 'Start fresh';

  @override
  String get failedConfirmTitle => 'Start fresh?';

  @override
  String get failedConfirmBody =>
      'The damaged file was kept: it was renamed and is still in the app data folder. Starting fresh creates a new, empty Q.';

  @override
  String get setupTitle => 'Set up your Q';

  @override
  String get setupIntro =>
      'Tell the app which pages are in which state today. Pages you do not list are ND.';

  @override
  String get setupMinutes => 'Minutes per day';

  @override
  String get setupRowsTitle => 'Pages already learned';

  @override
  String get setupAddRow => 'Add a row';

  @override
  String setupRowTitle(int n) {
    return 'Row $n';
  }

  @override
  String get setupRemoveRow => 'Remove row';

  @override
  String get setupFrom => 'From page';

  @override
  String get setupTo => 'To page';

  @override
  String get setupState => 'State';

  @override
  String get setupProgress => 'Progress units';

  @override
  String get setupDays => 'Days since last R';

  @override
  String get setupDaysHelp =>
      '0 means reviewed today, so no R is offered for these pages today.';

  @override
  String get setupConsolidated => 'Was in C before';

  @override
  String get setupStart => 'Start';

  @override
  String get setupStartEmpty => 'Start with nothing learned';

  @override
  String get setupBudgetInvalid => 'Minutes per day must be a number above 0.';

  @override
  String get setupSaveFailed => 'Could not save the setup. Please try again.';

  @override
  String setupProblemNumbers(int row) {
    return 'Row $row: enter whole numbers in the fields.';
  }

  @override
  String setupProblemState(int row) {
    return 'Row $row: this state is not allowed.';
  }

  @override
  String setupProblemFromAfterTo(int row) {
    return 'Row $row: the first page is after the last page.';
  }

  @override
  String setupProblemOutOfBounds(int row, int page) {
    return 'Row $row: page $page is outside 1 - 604.';
  }

  @override
  String setupProblemProgressNegative(int row) {
    return 'Row $row: progress cannot be below 0.';
  }

  @override
  String setupProblemProgressTooHigh(int row, int value, int max) {
    return 'Row $row: progress $value is too high (max $max).';
  }

  @override
  String setupProblemProgressNotForState(int row) {
    return 'Row $row: progress units are only for D rows.';
  }

  @override
  String setupProblemDaysNegative(int row) {
    return 'Row $row: days since the last R cannot be below 0.';
  }

  @override
  String setupProblemOverlap(int row, int other) {
    return 'Rows $row and $other overlap.';
  }

  @override
  String setupProblemInvalidQ(String detail) {
    return 'The Q is not valid: $detail';
  }

  @override
  String get navOverview => 'Overview';

  @override
  String get overviewTitle => 'Overview';

  @override
  String get overviewNeedSetup =>
      'Finish the setup on Today first to see your Q.';

  @override
  String overviewMain(String text) {
    return 'Main range: $text';
  }

  @override
  String get overviewNoMain => 'No main range yet.';

  @override
  String overviewNextForward(int page) {
    return 'Next forward M starts at p $page.';
  }

  @override
  String overviewNextBackward(int page, int s, String block) {
    return 'Next backward M starts at p $page (s $s, block $block).';
  }

  @override
  String overviewDRanges(int count) {
    return 'D ranges: $count';
  }

  @override
  String overviewMerged(int count) {
    return 'Merged ch: $count';
  }

  @override
  String get overviewBadgeMerged => 'merged';

  @override
  String sheetPageTitle(int page, String label) {
    return 'p $page: $label';
  }

  @override
  String sheetProgress(int units, int needed) {
    return 'Progress $units of $needed units';
  }

  @override
  String get sheetProgressNone => 'No progress units in this state';

  @override
  String get sheetPrimeYes => 'Prime: yes';

  @override
  String get sheetPrimeNo => 'Prime: no';

  @override
  String sheetLastR(String date, int days) {
    return 'Last R: $date ($days days ago)';
  }

  @override
  String get sheetLastRNone => 'No R yet';

  @override
  String sheetLActive(String date) {
    return 'L active until $date';
  }

  @override
  String sheetNextStep(String date) {
    return 'Next step down without an R: $date';
  }

  @override
  String proposalSourceAi(String name) {
    return 'AI planner ($name)';
  }

  @override
  String get proposalSourceFallback =>
      'Offline fallback (the AI planner did not answer)';

  @override
  String get proposalSourceOffline => 'Offline planner (rules)';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsSaved => 'Settings saved.';

  @override
  String get settingsSaveFailed => 'Could not save the settings.';

  @override
  String get settingsFixProblems => 'Fix the problems shown to save.';

  @override
  String get settingsPlanningNote =>
      'Changes apply to the next plan. Today’s budget stays; use Add time on Today.';

  @override
  String get settingsDisabled =>
      'Settings are disabled because the stored data could not be loaded.';

  @override
  String get settingsResetAll => 'Reset all';

  @override
  String get settingsResetAllTitle => 'Reset all settings?';

  @override
  String get settingsResetAllBody =>
      'All planning settings go back to their defaults. Nothing is saved until you press Save.';

  @override
  String get settingsResetSection => 'Reset to defaults';

  @override
  String get settingsDiscardTitle => 'Discard changes?';

  @override
  String get settingsDiscardBody => 'You have unsaved changes.';

  @override
  String get settingsDiscard => 'Discard';

  @override
  String get settingsKeepEditing => 'Keep editing';

  @override
  String get settingsSectionBudget => 'Budget';

  @override
  String get settingsSectionExpansion => 'Expansion';

  @override
  String get settingsSectionTime => 'Time';

  @override
  String get settingsSectionShared => 'Shared pages';

  @override
  String get settingsSectionL => 'L';

  @override
  String get settingsSectionPriorities => 'Priorities';

  @override
  String get settingsSectionPlanning => 'Planning and workload';

  @override
  String get settingsSectionAi => 'AI planner';

  @override
  String get stepperLess => 'Less';

  @override
  String get stepperMore => 'More';

  @override
  String get fieldBaseBudget => 'Minutes per day';

  @override
  String get fieldDirectionMode => 'Expansion direction';

  @override
  String get modeBoth => 'Both';

  @override
  String get modeForwardOnly => 'Forward only';

  @override
  String get modeBackwardOnly => 'Backward only';

  @override
  String get fieldExpansionTarget => 'Target pages per period';

  @override
  String get fieldExpansionPeriod => 'Period (days)';

  @override
  String get fieldMaxInRow => 'Max in a row in one direction';

  @override
  String get fieldAllowSameDirection =>
      'Allow the same direction when the opposite is blocked';

  @override
  String get fieldMainTieBreak => 'Main range tie-break';

  @override
  String get tieLowerPages => 'Lower pages';

  @override
  String get tieHigherPages => 'Higher pages';

  @override
  String get fieldTargetPerDirection =>
      'Target per direction (empty = half of the target)';

  @override
  String get fieldCapacityGate => 'Capacity gate';

  @override
  String get fieldAllowBeyondTarget => 'Allow beyond the target';

  @override
  String get fieldMMinutesNd => 'M minutes per ND page';

  @override
  String get fieldMMinutesF3 => 'M minutes per F3 page';

  @override
  String get fieldRStart => 'First R minutes (normal page)';

  @override
  String get fieldPrimeFactor => 'First R factor for prime pages';

  @override
  String get fieldRD3Cap => 'D3 floor (minutes)';

  @override
  String get fieldRCCap => 'C minutes';

  @override
  String get fieldCurve => 'Curve steepness';

  @override
  String get fieldD3Mode => 'D3 mode';

  @override
  String get d3ModeCap => 'Cap';

  @override
  String get d3ModeCont => 'Continue';

  @override
  String get fieldD3Hold => 'D3 hold units';

  @override
  String get sharedOpen => 'Edit shared pages';

  @override
  String sharedCustomCount(int count) {
    return '$count pages with their own share';
  }

  @override
  String sharedProblems(int count) {
    return '$count shared pages have a problem.';
  }

  @override
  String get sharedTitle => 'Shared pages';

  @override
  String sharedChPair(int a, int b) {
    return 'ch $a / ch $b';
  }

  @override
  String sharedSplit(int a, String aShare, int b, String bShare) {
    return 'ch $a gets $aShare, ch $b gets $bShare';
  }

  @override
  String get sharedReset => 'Reset to 0.5';

  @override
  String get fieldLDays => 'L days';

  @override
  String get priorityHint =>
      'Drag to reorder. The first one gets minutes first.';

  @override
  String get workClassRecoverF3 => 'F3 recovery or restart';

  @override
  String get workClassExpand => 'Expansion';

  @override
  String get workClassWorkingSetR => 'Working-set R';

  @override
  String get workClassMaintainC => 'C maintenance';

  @override
  String get fieldMaintainLead => 'C maintenance lead (days)';

  @override
  String get fieldMaxSnapshotGroups => 'Max snapshot groups';

  @override
  String get fieldWeekStartsOn => 'Week starts on';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get fieldProtectMandatory => 'Protect mandatory work';

  @override
  String get fieldCatchUpStretch => 'Catch-up stretch';

  @override
  String get fieldMaxDaily => 'Max minutes per day (empty = no cap)';

  @override
  String get fieldUtilization => 'Utilization';

  @override
  String get aiEnable => 'Use the AI planner';

  @override
  String get aiProviderLabel => 'Provider';

  @override
  String get aiModelLabel => 'Model';

  @override
  String aiModelDefault(String model) {
    return 'Empty = default ($model)';
  }

  @override
  String get aiKeyLabel => 'API key';

  @override
  String get aiKeySave => 'Save key';

  @override
  String get aiKeyRemove => 'Remove key';

  @override
  String get aiKeySaved => 'A key is saved. It is not shown again.';

  @override
  String get aiKeyNone => 'No key saved.';

  @override
  String get aiKeySavedMessage => 'Key saved.';

  @override
  String get aiKeyRemovedMessage => 'Key removed.';

  @override
  String get aiKeyFailed => 'Could not change the key.';

  @override
  String get aiNeedsKey => 'Save a key to use the AI planner.';

  @override
  String get aiOfflineNote =>
      'Without a key, or if the provider fails, the offline planner is used.';

  @override
  String get aiPrivacy =>
      'A plan request sends a summary of your Q (page states, no personal text) to the provider.';

  @override
  String get aiModelPickerTitle => 'Choose a model';

  @override
  String get aiModelPickerHint =>
      'Free-plan models. You can also type any model name.';

  @override
  String get aiModelRecommended => 'Recommended';

  @override
  String get aiModelNoteNewest => 'Newest and smartest';

  @override
  String get aiModelNoteBalanced => 'Previous generation, fast and balanced';

  @override
  String get aiModelNoteLight => 'Lightweight, for simple tasks';

  @override
  String get aiModelNoteLargest => 'Largest open model, best reasoning';

  @override
  String get aiModelNoteSmall => 'Smaller and faster';

  @override
  String get aiSavedKeysTitle => 'Saved keys';

  @override
  String get aiSavedKeysDeviceOnly =>
      'Kept on this device only. Never in backups.';

  @override
  String get aiSavedKeysEmpty => 'No saved keys yet.';

  @override
  String get aiSavedKeyAdd => 'Add a key';

  @override
  String get aiSavedKeyNameLabel => 'Name';

  @override
  String get aiSavedKeyReplaces => 'Replaces the saved key with this name.';

  @override
  String get aiSavedKeyDelete => 'Delete';

  @override
  String aiSavedKeyDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get aiSavedKeyDeleteBody =>
      'It is removed from this device. The key in use does not change.';

  @override
  String aiSavedKeyUsing(String name) {
    return 'Using “$name”.';
  }

  @override
  String get fieldAiLowFactor => 'AI plan: low factor';

  @override
  String get fieldAiHighFactor => 'AI plan: high factor';

  @override
  String todayOverBudget(String minutes) {
    return 'This plan is $minutes min over today’s budget';
  }

  @override
  String get navBrowse => 'Browse';

  @override
  String get browseTitle => 'Browse';

  @override
  String get browsePsTitle => 'ps';

  @override
  String get browseSsTitle => 'ss';

  @override
  String get browseChTitle => 'ch';

  @override
  String get browseMoreDetails => 'More details';

  @override
  String get browseGroupBy => 'Group by';

  @override
  String get browseGroupNone => 'None';

  @override
  String get browseGroupCh => 'ch';

  @override
  String get browseGroupS => 's';

  @override
  String sLabelOne(int s) {
    return 's $s';
  }

  @override
  String sLabelRun(int first, int last) {
    return 's $first - $last';
  }

  @override
  String browsePageCount(int count) {
    return '$count p';
  }

  @override
  String browseTrail(String first, String second) {
    return '$first · $second';
  }

  @override
  String get browseGroupState => 'State';

  @override
  String get browseGroupNotes => 'Notes';

  @override
  String get browseGroupHasNotes => 'Has open notes';

  @override
  String get browseGroupNoNotes => 'No open notes';

  @override
  String browseSCount(int count) {
    return '$count s';
  }

  @override
  String browseChCount(int count) {
    return '$count ch';
  }

  @override
  String browseOpenNotes(int count) {
    return '$count open notes';
  }

  @override
  String get infoState => 'State';

  @override
  String get infoComplete => 'Complete';

  @override
  String get infoWorstState => 'Worst state';

  @override
  String get infoAllAtLeastD3 => 'All pages at least D3';

  @override
  String get infoYes => 'Yes';

  @override
  String get infoNo => 'No';

  @override
  String get infoMergedShared => 'Merged ch: shared state';

  @override
  String get infoUnavailable =>
      'The state is not available until your Q is loaded.';

  @override
  String get notesTitle => 'Notes';

  @override
  String get notesAdd => 'Add a note';

  @override
  String get notesEmpty => 'No open notes.';

  @override
  String notesArchiveLink(int count) {
    return 'Archive ($count)';
  }

  @override
  String get notesArchiveTitle => 'Archive';

  @override
  String get notesArchiveEmpty => 'Nothing archived here.';

  @override
  String get notesTodayTitle => 'Notes for what you reviewed';

  @override
  String get noteRemembered => 'I remembered';

  @override
  String get noteRememberedToday =>
      'Remembered today, counted when the day ends';

  @override
  String get noteRestore => 'Restore';

  @override
  String get noteDelete => 'Delete';

  @override
  String get noteDeleteTitle => 'Delete this note?';

  @override
  String get noteDeleteMessage => 'It is deleted for good.';

  @override
  String noteResolvedOn(String date) {
    return 'Remembered 5 days, resolved $date';
  }

  @override
  String get noteAddTitle => 'New note';

  @override
  String get noteAddText => 'Note';

  @override
  String get noteAddPage => 'Page';

  @override
  String noteAddPageOutside(int first, int last) {
    return 'Pick a page from $first to $last';
  }

  @override
  String get noteAddFiledUnder => 'Filed under';

  @override
  String get noteAddSave => 'Add';
}
