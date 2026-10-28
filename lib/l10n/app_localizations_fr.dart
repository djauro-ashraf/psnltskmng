// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'QRM Intelligent Planner';

  @override
  String get languageName => 'Français';

  @override
  String get navToday => 'Aujourd’hui';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get dailyPlanTitle => 'Aujourd’hui';

  @override
  String get dailyPlanEmptyTitle => 'Que dois-je faire aujourd’hui ?';

  @override
  String get dailyPlanEmptyMessage =>
      'Votre plan du jour apparaîtra ici dès que vous aurez créé un Q.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsThemeSection => 'Thème';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsLanguageSection => 'Langue';

  @override
  String get settingsLanguageSystem => 'Langue du système';

  @override
  String get settingsReadingDirectionSection => 'Sens de lecture';

  @override
  String get settingsReadingDirectionHint =>
      'La façon dont le texte se déroule à l’écran. De droite à gauche place la page 1 à droite, comme dans le livre. Cela s’applique aux bandes de pages, aux cases de l’aperçu et au défilement dans Parcourir ; les minutes et les autres barres ne changent pas.';

  @override
  String get settingsReadingRightToLeft => 'De droite à gauche';

  @override
  String get settingsReadingLeftToRight => 'De gauche à droite';

  @override
  String get failureStorage =>
      'Une erreur s’est produite lors de l’enregistrement ou du chargement de vos données. Veuillez réessayer.';

  @override
  String get failureNotFound => 'Cet élément est introuvable.';

  @override
  String get routeNotFoundTitle => 'Page introuvable';

  @override
  String get routeNotFoundMessage =>
      'La page que vous recherchez n’existe pas.';

  @override
  String get routeNotFoundAction => 'Retour à Aujourd’hui';

  @override
  String get valueNone => '—';

  @override
  String get cancel => 'Annuler';

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
    return 'ch $ch, depuis son début (p $first)';
  }

  @override
  String chFromBeginningTo(int ch, int first, int last) {
    return 'ch $ch, depuis son début (p $first) jusqu’à p $last';
  }

  @override
  String get todayStorageError =>
      'Enregistrement impossible. Veuillez réessayer.';

  @override
  String get todayNothingToPlan =>
      'Rien à planifier pour l’instant. Appuyez sur « Enregistrer une séance » pour noter ce que vous avez étudié.';

  @override
  String get summaryBudget => 'Budget';

  @override
  String get summaryPlan => 'Plan';

  @override
  String get summaryDone => 'Fait';

  @override
  String get summaryLeft => 'Reste';

  @override
  String summaryBudgetSplit(String base, String extra) {
    return '$base min + $extra min ajoutées';
  }

  @override
  String get planMake => 'Faire un plan';

  @override
  String get planAddTime => 'Ajouter du temps';

  @override
  String planAddTimeOption(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get proposalTitle => 'Dernier plan';

  @override
  String proposalSource(String source) {
    return 'Source : $source';
  }

  @override
  String get proposalSourceRuleBased => 'Planificateur à règles';

  @override
  String get proposalEmpty => 'Ce plan ne contient aucune opération.';

  @override
  String proposalAtRisk(String pages) {
    return 'À risque ce soir si rien d’autre n’est fait : $pages';
  }

  @override
  String proposalNotIncluded(int count) {
    return 'Non inclus ($count)';
  }

  @override
  String get rowDone => 'Fait';

  @override
  String get rowMarkDone => 'Fait';

  @override
  String get rowMarkNotSuccessful => 'Fait, sans succès';

  @override
  String get rowMarkPartial => 'Fait en partie';

  @override
  String get rowMenuNotSuccessful => 'Sans succès';

  @override
  String get rowMenuDonePartly => 'Fait en partie';

  @override
  String get rowMenuTooltip => 'Plus d’options';

  @override
  String get partialTitle => 'Fait en partie';

  @override
  String get partialFrom => 'De';

  @override
  String get partialTo => 'À';

  @override
  String partialChipLabel(int ch, String pages) {
    return 'ch $ch ($pages)';
  }

  @override
  String partialSharedNote(int page, int ch) {
    return 'p $page appartient à ch $ch.';
  }

  @override
  String partialInvalid(int first, int last) {
    return 'Saisissez des pages de $first à $last.';
  }

  @override
  String get partialMergedNote =>
      'Cette opération contient un ch fusionné. Un R sur un ch fusionné est tout ou rien : il ne peut pas être fait en partie. Utilisez « Fait » pour enregistrer toute l’opération.';

  @override
  String get partialConfirm => 'Enregistrer';

  @override
  String get logSomethingElse => 'Enregistrer une séance';

  @override
  String get logDay => 'Jour';

  @override
  String get logDayToday => 'Aujourd’hui';

  @override
  String get logDayYesterday => 'Hier';

  @override
  String logDayDaysAgo(int days) {
    return 'Il y a $days jours';
  }

  @override
  String logLateNote(String date) {
    return 'Enregistré le $date. Les jours suivants sont recalculés avec cette séance, et le plan d’aujourd’hui est effacé : demandez-en un nouveau.';
  }

  @override
  String logLateDone(String date) {
    return 'Enregistré le $date. Demandez un nouveau plan pour aujourd’hui.';
  }

  @override
  String get logOperation => 'Opération';

  @override
  String get logSuccessful => 'Réussi';

  @override
  String get logRejected => 'Les règles refusent ceci :';

  @override
  String get logConfirm => 'Enregistrer';

  @override
  String get logPagesInvalid =>
      'Saisissez un numéro de page, ou ch ou s avec un numéro : 12, ch 3, s 5.';

  @override
  String get logRangeHint =>
      'Un numéro de page, ou ch ou s avec un numéro : 12, p 12, ch 3, s 5. Laissez À vide pour enregistrer seulement la page, le ch ou le s de De.';

  @override
  String logResolved(String pages) {
    return 'Enregistre $pages';
  }

  @override
  String get logRangeBackwards => 'De ne doit pas venir après À.';

  @override
  String logUnitUnknown(String text, String units) {
    return '« $text » n’est pas une unité. Utilisez $units, ou seulement un numéro.';
  }

  @override
  String logUnitOutOfRange(String unit, int number, int max) {
    return '$unit $number n’existe pas : utilisez de $unit 1 à $unit $max.';
  }

  @override
  String logUnitUnavailable(String unit, int pages) {
    return '$unit demande le Q de $pages pages. Utilisez plutôt des numéros de page.';
  }

  @override
  String get loggedTitle => 'Enregistré aujourd’hui';

  @override
  String get loggedEmpty => 'Rien d’enregistré pour l’instant.';

  @override
  String get loggedKindPlanned => 'prévu';

  @override
  String get loggedKindPartial => 'partiel';

  @override
  String get loggedKindCustom => 'manuel';

  @override
  String get loggedNotSuccessful => 'sans succès';

  @override
  String get failedTitle =>
      'Vos données enregistrées n’ont pas pu être chargées';

  @override
  String failedMessage(String reason) {
    return '$reason';
  }

  @override
  String get failedStartFresh => 'Repartir à zéro';

  @override
  String get failedConfirmTitle => 'Repartir à zéro ?';

  @override
  String get failedConfirmBody =>
      'Le fichier endommagé a été conservé : il a été renommé et reste dans le dossier de données de l’appli. Repartir à zéro crée un nouveau Q vide.';

  @override
  String get setupTitle => 'Configurer votre Q';

  @override
  String get setupIntro =>
      'Indiquez à l’appli dans quel état se trouvent vos pages aujourd’hui. Les pages non listées sont ND.';

  @override
  String get setupMinutes => 'Minutes par jour';

  @override
  String get setupRowsTitle => 'Pages déjà apprises';

  @override
  String get setupAddRow => 'Ajouter une ligne';

  @override
  String setupRowTitle(int n) {
    return 'Ligne $n';
  }

  @override
  String get setupRemoveRow => 'Supprimer la ligne';

  @override
  String get setupFrom => 'De la page';

  @override
  String get setupTo => 'À la page';

  @override
  String get setupState => 'État';

  @override
  String get setupProgress => 'Unités de progression';

  @override
  String get setupDays => 'Jours depuis le dernier R';

  @override
  String get setupDaysHelp =>
      '0 signifie révisé aujourd’hui : aucun R n’est proposé pour ces pages aujourd’hui.';

  @override
  String get setupConsolidated => 'A déjà été en C';

  @override
  String get setupStart => 'Commencer';

  @override
  String get setupStartEmpty => 'Commencer sans rien d’appris';

  @override
  String get setupBudgetInvalid =>
      'Les minutes par jour doivent être un nombre supérieur à 0.';

  @override
  String get setupSaveFailed =>
      'Impossible d’enregistrer la configuration. Veuillez réessayer.';

  @override
  String setupProblemNumbers(int row) {
    return 'Ligne $row : saisissez des nombres entiers dans les champs.';
  }

  @override
  String setupProblemState(int row) {
    return 'Ligne $row : cet état n’est pas autorisé.';
  }

  @override
  String setupProblemFromAfterTo(int row) {
    return 'Ligne $row : la première page est après la dernière.';
  }

  @override
  String setupProblemOutOfBounds(int row, int page) {
    return 'Ligne $row : la page $page est hors de 1 - 604.';
  }

  @override
  String setupProblemProgressNegative(int row) {
    return 'Ligne $row : la progression ne peut pas être inférieure à 0.';
  }

  @override
  String setupProblemProgressTooHigh(int row, int value, int max) {
    return 'Ligne $row : la progression $value est trop élevée (max $max).';
  }

  @override
  String setupProblemProgressNotForState(int row) {
    return 'Ligne $row : les unités de progression ne concernent que les lignes D.';
  }

  @override
  String setupProblemDaysNegative(int row) {
    return 'Ligne $row : les jours depuis le dernier R ne peuvent pas être inférieurs à 0.';
  }

  @override
  String setupProblemOverlap(int row, int other) {
    return 'Les lignes $row et $other se chevauchent.';
  }

  @override
  String setupProblemInvalidQ(String detail) {
    return 'Le Q n’est pas valide : $detail';
  }

  @override
  String get navOverview => 'Aperçu';

  @override
  String get overviewTitle => 'Aperçu';

  @override
  String get overviewNeedSetup =>
      'Terminez d’abord la configuration dans Aujourd’hui pour voir votre Q.';

  @override
  String overviewMain(String text) {
    return 'Plage principale : $text';
  }

  @override
  String get overviewNoMain => 'Pas encore de plage principale.';

  @override
  String overviewNextForward(int page) {
    return 'Le prochain M vers l’avant commence à p $page.';
  }

  @override
  String overviewNextBackward(int page, int s, String block) {
    return 'Le prochain M vers l’arrière commence à p $page (s $s, bloc $block).';
  }

  @override
  String overviewDRanges(int count) {
    return 'Plages D : $count';
  }

  @override
  String overviewMerged(int count) {
    return 'ch fusionnés : $count';
  }

  @override
  String get overviewBadgeMerged => 'fusionné';

  @override
  String sheetPageTitle(int page, String label) {
    return 'p $page : $label';
  }

  @override
  String sheetProgress(int units, int needed) {
    return 'Progression $units sur $needed unités';
  }

  @override
  String get sheetProgressNone => 'Pas d’unités de progression dans cet état';

  @override
  String get sheetPrimeYes => 'Prime : oui';

  @override
  String get sheetPrimeNo => 'Prime : non';

  @override
  String sheetLastR(String date, int days) {
    return 'Dernier R : $date (il y a $days jours)';
  }

  @override
  String get sheetLastRNone => 'Pas encore de R';

  @override
  String sheetLActive(String date) {
    return 'L actif jusqu’au $date';
  }

  @override
  String sheetNextStep(String date) {
    return 'Prochaine baisse sans R : $date';
  }

  @override
  String proposalSourceAi(String name) {
    return 'Planificateur IA ($name)';
  }

  @override
  String get proposalSourceFallback =>
      'Repli hors ligne (le planificateur IA n’a pas répondu)';

  @override
  String get proposalSourceOffline => 'Planificateur hors ligne (règles)';

  @override
  String get settingsSave => 'Enregistrer';

  @override
  String get settingsSaved => 'Réglages enregistrés.';

  @override
  String get settingsSaveFailed => 'Impossible d’enregistrer les réglages.';

  @override
  String get settingsFixProblems =>
      'Corrigez les problèmes affichés pour enregistrer.';

  @override
  String get settingsPlanningNote =>
      'Les changements s’appliquent au prochain plan. Le budget du jour reste le même ; utilisez « Ajouter du temps » dans Aujourd’hui.';

  @override
  String get settingsDisabled =>
      'Les réglages sont désactivés car les données enregistrées n’ont pas pu être chargées.';

  @override
  String get settingsResetAll => 'Tout réinitialiser';

  @override
  String get settingsResetAllTitle => 'Tout réinitialiser ?';

  @override
  String get settingsResetAllBody =>
      'Tous les réglages de planification reviennent à leurs valeurs par défaut. Rien n’est enregistré tant que vous n’appuyez pas sur Enregistrer.';

  @override
  String get settingsResetSection => 'Valeurs par défaut';

  @override
  String get settingsDiscardTitle => 'Abandonner les modifications ?';

  @override
  String get settingsDiscardBody =>
      'Vous avez des modifications non enregistrées.';

  @override
  String get settingsDiscard => 'Abandonner';

  @override
  String get settingsKeepEditing => 'Continuer';

  @override
  String get settingsSectionBudget => 'Budget';

  @override
  String get settingsSectionExpansion => 'Expansion';

  @override
  String get settingsSectionTime => 'Temps';

  @override
  String get settingsSectionShared => 'Pages partagées';

  @override
  String get settingsSectionL => 'L';

  @override
  String get settingsSectionPriorities => 'Priorités';

  @override
  String get settingsSectionPlanning => 'Planification et charge';

  @override
  String get settingsSectionAi => 'Planificateur IA';

  @override
  String get stepperLess => 'Moins';

  @override
  String get stepperMore => 'Plus';

  @override
  String get fieldBaseBudget => 'Minutes par jour';

  @override
  String get fieldDirectionMode => 'Direction d’expansion';

  @override
  String get modeBoth => 'Les deux';

  @override
  String get modeForwardOnly => 'Vers l’avant seulement';

  @override
  String get modeBackwardOnly => 'Vers l’arrière seulement';

  @override
  String get fieldExpansionTarget => 'Pages cibles par période';

  @override
  String get fieldExpansionPeriod => 'Période (jours)';

  @override
  String get fieldMaxInRow => 'Maximum d’affilée dans une direction';

  @override
  String get fieldAllowSameDirection =>
      'Autoriser la même direction quand l’opposée est bloquée';

  @override
  String get fieldMainTieBreak => 'Départage de la plage principale';

  @override
  String get tieLowerPages => 'Pages basses';

  @override
  String get tieHigherPages => 'Pages hautes';

  @override
  String get fieldTargetPerDirection =>
      'Cible par direction (vide = moitié de la cible)';

  @override
  String get fieldCapacityGate => 'Contrôle de capacité';

  @override
  String get fieldAllowBeyondTarget => 'Autoriser au-delà de la cible';

  @override
  String get fieldMMinutesNd => 'Minutes de M par page ND';

  @override
  String get fieldMMinutesF3 => 'Minutes de M par page F3';

  @override
  String get fieldRStart => 'Minutes du premier R (page normale)';

  @override
  String get fieldPrimeFactor => 'Facteur du premier R pour les pages prime';

  @override
  String get fieldRD3Cap => 'Plancher D3 (minutes)';

  @override
  String get fieldRCCap => 'Minutes de C';

  @override
  String get fieldCurve => 'Raideur de la courbe';

  @override
  String get fieldD3Mode => 'Mode D3';

  @override
  String get d3ModeCap => 'Plafond';

  @override
  String get d3ModeCont => 'Continuer';

  @override
  String get fieldD3Hold => 'Unités de maintien D3';

  @override
  String get sharedOpen => 'Modifier les pages partagées';

  @override
  String sharedCustomCount(int count) {
    return '$count pages avec une part personnalisée';
  }

  @override
  String sharedProblems(int count) {
    return '$count pages partagées ont un problème.';
  }

  @override
  String get sharedTitle => 'Pages partagées';

  @override
  String sharedChPair(int a, int b) {
    return 'ch $a / ch $b';
  }

  @override
  String sharedSplit(int a, String aShare, int b, String bShare) {
    return 'ch $a reçoit $aShare, ch $b reçoit $bShare';
  }

  @override
  String get sharedReset => 'Remettre à 0,5';

  @override
  String get fieldLDays => 'Jours de L';

  @override
  String get priorityHint =>
      'Faites glisser pour réordonner. Le premier reçoit les minutes en premier.';

  @override
  String get workClassRecoverF3 => 'Reprise des F3 ou redémarrage';

  @override
  String get workClassExpand => 'Expansion';

  @override
  String get workClassWorkingSetR => 'R de l’ensemble de travail';

  @override
  String get workClassMaintainC => 'Entretien de C';

  @override
  String get fieldMaintainLead => 'Avance d’entretien de C (jours)';

  @override
  String get fieldMaxSnapshotGroups => 'Groupes maximum du résumé';

  @override
  String get fieldWeekStartsOn => 'La semaine commence le';

  @override
  String get weekdayMon => 'Lun';

  @override
  String get weekdayTue => 'Mar';

  @override
  String get weekdayWed => 'Mer';

  @override
  String get weekdayThu => 'Jeu';

  @override
  String get weekdayFri => 'Ven';

  @override
  String get weekdaySat => 'Sam';

  @override
  String get weekdaySun => 'Dim';

  @override
  String get fieldProtectMandatory => 'Protéger le travail obligatoire';

  @override
  String get fieldCatchUpStretch => 'Extension de rattrapage';

  @override
  String get fieldMaxDaily => 'Minutes maximum par jour (vide = sans plafond)';

  @override
  String get fieldUtilization => 'Taux d’utilisation';

  @override
  String get aiEnable => 'Utiliser le planificateur IA';

  @override
  String get aiProviderLabel => 'Fournisseur';

  @override
  String get aiModelLabel => 'Modèle';

  @override
  String aiModelDefault(String model) {
    return 'Vide = par défaut ($model)';
  }

  @override
  String get aiKeyLabel => 'Clé d’API';

  @override
  String get aiKeySave => 'Enregistrer la clé';

  @override
  String get aiKeyRemove => 'Supprimer la clé';

  @override
  String get aiKeySaved => 'Une clé est enregistrée. Elle n’est plus affichée.';

  @override
  String get aiKeyNone => 'Aucune clé enregistrée.';

  @override
  String get aiKeySavedMessage => 'Clé enregistrée.';

  @override
  String get aiKeyRemovedMessage => 'Clé supprimée.';

  @override
  String get aiKeyFailed => 'Impossible de modifier la clé.';

  @override
  String get aiNeedsKey =>
      'Enregistrez une clé pour utiliser le planificateur IA.';

  @override
  String get aiOfflineNote =>
      'Sans clé, ou si le fournisseur échoue, le planificateur hors ligne est utilisé.';

  @override
  String get aiPrivacy =>
      'Une demande de plan envoie au fournisseur un résumé de votre Q (états des pages, aucun texte personnel).';

  @override
  String get aiModelPickerTitle => 'Choisir un modèle';

  @override
  String get aiModelPickerHint =>
      'Modèles du forfait gratuit. Vous pouvez aussi saisir n’importe quel nom de modèle.';

  @override
  String get aiModelRecommended => 'Recommandé';

  @override
  String get aiModelNoteNewest => 'Le plus récent et le plus capable';

  @override
  String get aiModelNoteBalanced =>
      'Génération précédente, rapide et équilibré';

  @override
  String get aiModelNoteLight => 'Léger, pour les tâches simples';

  @override
  String get aiModelNoteLargest =>
      'Plus grand modèle ouvert, meilleur raisonnement';

  @override
  String get aiModelNoteSmall => 'Plus petit et plus rapide';

  @override
  String get aiSavedKeysTitle => 'Clés enregistrées';

  @override
  String get aiSavedKeysDeviceOnly =>
      'Gardées sur cet appareil uniquement. Jamais dans les sauvegardes.';

  @override
  String get aiSavedKeysEmpty => 'Aucune clé enregistrée pour l’instant.';

  @override
  String get aiSavedKeyAdd => 'Ajouter une clé';

  @override
  String get aiSavedKeyNameLabel => 'Nom';

  @override
  String get aiSavedKeyReplaces =>
      'Remplace la clé enregistrée portant ce nom.';

  @override
  String get aiSavedKeyDelete => 'Supprimer';

  @override
  String aiSavedKeyDeleteTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get aiSavedKeyDeleteBody =>
      'Elle est supprimée de cet appareil. La clé utilisée ne change pas.';

  @override
  String aiSavedKeyUsing(String name) {
    return 'Clé « $name » utilisée.';
  }

  @override
  String get fieldAiLowFactor => 'Plan IA : facteur bas';

  @override
  String get fieldAiHighFactor => 'Plan IA : facteur haut';

  @override
  String todayOverBudget(String minutes) {
    return 'Ce plan dépasse de $minutes min le budget du jour';
  }

  @override
  String get navBrowse => 'Parcourir';

  @override
  String get browseTitle => 'Parcourir';

  @override
  String get browsePsTitle => 'ps';

  @override
  String get browseSsTitle => 'ss';

  @override
  String get browseChTitle => 'ch';

  @override
  String get browseMoreDetails => 'Plus de détails';

  @override
  String get browseGroupBy => 'Grouper par';

  @override
  String get browseGroupNone => 'Aucun';

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
  String get browseGroupState => 'État';

  @override
  String get browseGroupNotes => 'Notes';

  @override
  String get browseGroupHasNotes => 'Avec notes ouvertes';

  @override
  String get browseGroupNoNotes => 'Sans note ouverte';

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
    return '$count notes ouvertes';
  }

  @override
  String get infoState => 'État';

  @override
  String get infoComplete => 'Complet';

  @override
  String get infoWorstState => 'État le plus faible';

  @override
  String get infoAllAtLeastD3 => 'Toutes les pages au moins en D3';

  @override
  String get infoYes => 'Oui';

  @override
  String get infoNo => 'Non';

  @override
  String get infoMergedShared => 'ch fusionné : état commun';

  @override
  String get infoUnavailable =>
      'L’état n’est pas disponible tant que votre Q n’est pas chargé.';

  @override
  String get notesTitle => 'Notes';

  @override
  String get notesAdd => 'Ajouter une note';

  @override
  String get notesEmpty => 'Aucune note ouverte.';

  @override
  String notesArchiveLink(int count) {
    return 'Archive ($count)';
  }

  @override
  String get notesArchiveTitle => 'Archive';

  @override
  String get notesArchiveEmpty => 'Rien d’archivé ici.';

  @override
  String get notesTodayTitle => 'Notes de ce que vous avez révisé';

  @override
  String get noteRemembered => 'Je m’en suis souvenu';

  @override
  String get noteRememberedToday =>
      'Retenu aujourd’hui, compté à la fin de la journée';

  @override
  String get noteRestore => 'Restaurer';

  @override
  String get noteDelete => 'Supprimer';

  @override
  String get noteDeleteTitle => 'Supprimer cette note ?';

  @override
  String get noteDeleteMessage => 'Elle est supprimée définitivement.';

  @override
  String noteResolvedOn(String date) {
    return 'Retenue 5 jours, résolue le $date';
  }

  @override
  String get noteAddTitle => 'Nouvelle note';

  @override
  String get noteAddText => 'Note';

  @override
  String get noteAddPage => 'Page';

  @override
  String noteAddPageOutside(int first, int last) {
    return 'Choisissez une page de $first à $last';
  }

  @override
  String get noteAddFiledUnder => 'Classée sous';

  @override
  String get noteAddSave => 'Ajouter';

  @override
  String get pageSideInfo => 'Infos';

  @override
  String get pageSideQuran => 'Coran';

  @override
  String get mushafNotInstalled =>
      'Les pages du Coran ne sont pas encore installées. Télécharge-les dans Données du Coran.';

  @override
  String get mushafFontMissing =>
      'La police de cette page est absente. Télécharge les polices dans Données du Coran.';

  @override
  String get mushafBroken =>
      'Les données de cette page n’ont pas pu être lues.';

  @override
  String get quranViewMushaf => 'Mushaf';

  @override
  String get quranViewWords => 'Mots';

  @override
  String get wordsNotInstalled =>
      'Les mots ou les lignes des pages ne sont pas encore téléchargés.';

  @override
  String get wordsNoTranslation =>
      'Aucune traduction n’est encore téléchargée. Télécharge-en une dans Données du Coran.';

  @override
  String get wordsTranslation => 'Traduction';

  @override
  String get quranDataOpen => 'Télécharger le Coran';

  @override
  String get quranDataTitle => 'Données du Coran';

  @override
  String get quranDataIntro =>
      'Télécharge le Coran une fois. Ensuite il fonctionne sans internet.';

  @override
  String get quranDataAddressTitle => 'Où sont les paquets';

  @override
  String get quranDataAddressHint => 'Adresse de manifest.json';

  @override
  String get quranDataAddressSave => 'Enregistrer et vérifier';

  @override
  String get quranDataNoAddress =>
      'Saisis l’adresse des paquets pour télécharger les lignes des pages, les mots et les traductions. Les polices n’en ont pas besoin.';

  @override
  String get quranDataManifestError =>
      'La liste des paquets n’a pas pu être chargée. Vérifie l’adresse et ta connexion.';

  @override
  String get quranDataSectionPages => 'Pages du Coran';

  @override
  String get quranDataSectionText => 'Mots et traductions';

  @override
  String get quranPackFontsTitle => 'Polices des pages';

  @override
  String get quranPackFontsDesc =>
      'Les lettres des 604 pages, comme dans le mushaf imprimé (604 fichiers).';

  @override
  String get quranPackTextFontTitle => 'Police du texte arabe';

  @override
  String get quranPackTextFontDesc =>
      'Pour les bandeaux de sourate et la vue Mots (1 fichier).';

  @override
  String get quranDataDownload => 'Télécharger';

  @override
  String get quranDataCancel => 'Annuler';

  @override
  String get quranDataDelete => 'Supprimer';

  @override
  String get quranDataDownloaded => 'Téléchargé';

  @override
  String get quranDataFailed => 'Échec du téléchargement :';

  @override
  String get quranDataCredits =>
      'Polices du Coran : fournies par Quran Foundation. Lignes des pages, mots et traductions : Quranic Universal Library (Tarteel). Chaque traduction appartient à son traducteur.';

  @override
  String get settingsQuranData => 'Données du Coran';

  @override
  String get settingsQuranDataHint =>
      'Télécharger le Coran, ses mots et ses traductions';

  @override
  String get quranEditionTitle => 'Édition du mushaf';

  @override
  String get quranEditionV1 => 'Édition 1405 (V1)';

  @override
  String get quranEditionV2 => 'Édition 1421 (V2)';

  @override
  String get quranEditionNoteV1 =>
      'L’édition classique de Médine, celle pour laquelle les tables de pages de l’application sont faites : chaque sourate commence et finit sur la page prévue par le planificateur.';

  @override
  String get quranEditionNoteV2 =>
      'L’édition plus récente de Médine. 36 pages contiennent d’autres versets que dans l’édition classique : un numéro de page peut donc désigner d’autres versets que dans les tables du planificateur.';

  @override
  String get quranEditionMissing =>
      'La liste des paquets n’a pas encore les lignes des pages de cette édition.';

  @override
  String get wordsFootnote => 'Note';
}
