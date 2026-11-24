import 'package:flutter/widgets.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/rules/range_input.dart';

/// The words of the memorisation screens, in English and French. Kept in one
/// small class (not in the ARB files) so the whole feature can change in one
/// place; the rest of the app keeps using `context.l10n`.
class MemoText {
  const MemoText._(this._fr);

  /// The words for the language of [context] (French or else English).
  factory MemoText.of(BuildContext context) =>
      MemoText._(Localizations.localeOf(context).languageCode == 'fr');

  final bool _fr;

  String _t(String en, String fr) => _fr ? fr : en;

  // -- statuses -----------------------------------------------------------------
  /// The name of a status (never its old letters).
  String status(MemoStatus status) => switch (status) {
    MemoStatus.notLearned => _t('Not learned', 'Non appris'),
    MemoStatus.learning1 => _t('Learning 1', 'Apprentissage 1'),
    MemoStatus.learning2 => _t('Learning 2', 'Apprentissage 2'),
    MemoStatus.learning3 => _t('Learning 3', 'Apprentissage 3'),
    MemoStatus.consolidated => _t('Consolidated', 'Consolidé'),
    MemoStatus.fading1 => _t('Fading 1', 'En déclin 1'),
    MemoStatus.fading2 => _t('Fading 2', 'En déclin 2'),
    MemoStatus.forgotten => _t('Forgotten', 'Oublié'),
  };

  /// What a status means, in one line.
  String statusMeaning(MemoStatus status) => switch (status) {
    MemoStatus.notLearned => _t(
      'Never consolidated: new, or forgotten again.',
      'Jamais consolidé : nouveau, ou de nouveau oublié.',
    ),
    MemoStatus.learning1 || MemoStatus.learning2 || MemoStatus.learning3 => _t(
      'Being learned: reviews move it up a level.',
      'En cours d’apprentissage : les révisions le font monter d’un niveau.',
    ),
    MemoStatus.consolidated => _t('Solid.', 'Solide.'),
    MemoStatus.fading1 || MemoStatus.fading2 => _t(
      'Left without review: one review restores it.',
      'Laissé sans révision : une révision le restaure.',
    ),
    MemoStatus.forgotten => _t(
      'Consolidated once, then lost: memorise it again.',
      'Consolidé puis perdu : à mémoriser de nouveau.',
    ),
  };

  /// "Memorise" and "Review": the two things that can be logged.
  String kind(MemoKind kind) =>
      kind == MemoKind.m ? _t('Memorise', 'Mémoriser') : _t('Review', 'Réviser');

  // -- facts about a stretch of ayahs -------------------------------------------
  String learnedOf(int learned, int total) =>
      _t('Learned: $learned of $total ayahs', 'Appris : $learned sur $total ayahs');

  /// "Learning 2: 40 · Consolidated: 12", only the statuses that have ayahs.
  String countsLine(SpanStatus status) {
    final parts = <String>[
      for (final s in MemoStatus.values)
        if (s != MemoStatus.notLearned && status.count(s) > 0)
          '${this.status(s)}: ${status.count(s)}',
    ];
    return parts.isEmpty ? '' : parts.join(' · ');
  }

  String lastTouched(int days) => _t(
    'Last touched ${_days(days)} ago',
    'Dernière fois il y a ${_days(days)}',
  );
  String longestUntouched(int days) => _t(
    'Longest untouched: ${_days(days)}',
    'Plus ancien non revu : ${_days(days)}',
  );

  /// When something here next falls a step without a review ([days] from today,
  /// 0 or less meaning today or already).
  String nextStepDown(int days) => days <= 0
      ? _t('Next step down: today, unless reviewed', 'Prochaine baisse : aujourd’hui, sauf révision')
      : _t('Next step down in ${_days(days)}', 'Prochaine baisse dans ${_days(days)}');
  String _days(int d) => _fr ? '$d j' : '$d d';
  String get nothingYet => _t(
    'Nothing learned here yet.',
    'Rien d’appris ici pour l’instant.',
  );
  String get statusUnavailable => _t(
    'The status is not available yet.',
    'Le statut n’est pas encore disponible.',
  );
  String get complete => _t('Complete', 'Complet');
  String get worst => _t('Weakest', 'Le plus faible');

  // -- Today --------------------------------------------------------------------
  String get todayTitle => _t('Today', 'Aujourd’hui');
  String get logSection => _t('Log', 'Enregistrer');
  String get logHint => 'p 12 · ch 3 · s 2 · j 5 · 2:255-260';
  String get logButton => _t('Log', 'Enregistrer');
  String get logDayToday => _t('Today', 'Aujourd’hui');
  String logDay(String date) => _t('Day: $date', 'Jour : $date');
  String logged(MemoKind k, int ayahs) => _t(
    '${kind(k)} logged on $ayahs ayahs',
    '${kind(k)} enregistré sur $ayahs ayahs',
  );
  String loggedPartial(MemoKind k, int ayahs, int left) => _t(
    '${kind(k)} logged on $ayahs ayahs; $left left out because they do not '
        'fit (${k == MemoKind.m ? 'already learned' : 'not learned'}).',
    '${kind(k)} enregistré sur $ayahs ayahs ; $left laissés de côté car ils ne '
        'conviennent pas (${k == MemoKind.m ? 'déjà appris' : 'non appris'}).',
  );
  String nothingFits(MemoKind k) => k == MemoKind.m
      ? _t(
          'Nothing logged: everything there is already learned. '
              '(You can turn this rule off in Settings.)',
          'Rien d’enregistré : tout y est déjà appris. '
              '(Cette règle se désactive dans les réglages.)',
        )
      : _t(
          'Nothing logged: nothing there is learned (or it was forgotten), so '
              'there is nothing to review. (You can turn this rule off in Settings.)',
          'Rien d’enregistré : rien n’y est appris (ou c’est oublié), donc rien '
              'à réviser. (Cette règle se désactive dans les réglages.)',
        );
  String inputProblem(RangeInputProblem p) => switch (p) {
    RangeInputProblem.empty => _t('Type what you did.', 'Saisissez ce que vous avez fait.'),
    RangeInputProblem.unrecognised => _t(
      'Not understood. Try p 12, ch 3 or 2:255-260.',
      'Non compris. Essayez p 12, ch 3 ou 2:255-260.',
    ),
    RangeInputProblem.outOfRange => _t('That does not exist.', 'Cela n’existe pas.'),
    RangeInputProblem.backwards => _t('The end comes before the start.', 'La fin précède le début.'),
  };
  String get undo => _t('Undo', 'Annuler');
  String get loggedToday => _t('Logged on this day', 'Enregistré ce jour-là');
  String get nothingLoggedToday => _t('Nothing logged yet.', 'Rien d’enregistré.');
  String get storageError =>
      _t('Could not save. Please try again.', 'Échec de l’enregistrement. Réessayez.');
  String get loadProblem => _t(
    'The saved memorisation file could not be read. It was set aside and nothing was overwritten.',
    'Le fichier de mémorisation n’a pas pu être lu. Il a été mis de côté, rien n’a été écrasé.',
  );

  // -- Today: the worklist and the sheet ----------------------------------------
  String get needsAttention => _t('Needs attention', 'À revoir');
  String get nothingFalls => _t(
    'Nothing is about to fall. Well done.',
    'Rien ne va baisser. Bravo.',
  );
  String get nextToMemorise => _t('Next to memorise', 'Prochain à mémoriser');
  String get nothingToMemorise => _t('Everything is learned.', 'Tout est appris.');
  String get typeIt => _t('Type what you did', 'Saisir ce que vous avez fait');
  String loggingFor(String date) =>
      _t('Logging for $date', 'Enregistrement pour le $date');
  String get backToToday => _t('Back to today', 'Revenir à aujourd’hui');
  String get pickDay => _t('Log for another day', 'Enregistrer pour un autre jour');
  String get reviewed => _t('Reviewed', 'Révisé');
  String get memorised => _t('Memorised', 'Mémorisé');
  String get onlySomePages => _t('Only some pages', 'Seulement certaines pages');
  String pagesLabel(int a, int b) =>
      a == b ? _t('Page $a', 'Page $a') : _t('Pages $a-$b', 'Pages $a-$b');
  String willLog(int n) => n == 0
      ? _t('Nothing applies here', 'Rien ne s’applique ici')
      : _t('Logs $n ayahs', 'Enregistre $n ayahs');
  String forgottenAyahs(int n) => _t('Forgotten: $n ayahs', 'Oubliés : $n ayahs');
  String fadingAyahs(int n) => _t('Fading: $n ayahs', 'En déclin : $n ayahs');
  String fallsIn(int days) => days <= 0
      ? _t('Falls today unless reviewed', 'Baisse aujourd’hui sans révision')
      : _t('Falls in ${_days(days)}', 'Baisse dans ${_days(days)}');
  String leftToMemorise(int n) =>
      _t('$n ayahs left to memorise', '$n ayahs restants à mémoriser');

  /// The one line under a piece in the worklist: the most pressing fact.
  String attentionLine(SpanStatus status, int? daysToFall) {
    if (status.forgotten > 0) return forgottenAyahs(status.forgotten);
    if (status.fading > 0) return fadingAyahs(status.fading);
    if (daysToFall != null) return fallsIn(daysToFall);
    return '';
  }

  String get attentionDaysLabel =>
      _t('Needs attention: look ahead', 'À revoir : regarder à l’avance');
  String attentionDaysValue(int d) =>
      _t(d == 1 ? '1 day' : '$d days', d == 1 ? '1 jour' : '$d jours');

  // -- suggestions from reading -----------------------------------------------
  String get draftTitle => _t('Suggested from your reading', 'Suggéré par votre lecture');
  String get draftHelp => _t(
    'Nothing is logged until you confirm. Tap the kind to switch it, tap a line to change its pages, the cross drops it.',
    'Rien n’est enregistré tant que vous ne confirmez pas. Touchez le type pour le changer, une ligne pour modifier ses pages, la croix pour la retirer.',
  );
  String draftDay(int daysAgo, String date) => daysAgo <= 0
      ? _t('Today', 'Aujourd’hui')
      : daysAgo == 1
      ? _t('Yesterday', 'Hier')
      : date;
  String readMinutes(int seconds) =>
      seconds < 60 ? _t('under 1 min', 'moins d’1 min') : '${seconds ~/ 60} min';
  String draftLog(int n) => _t(
    n == 1 ? 'Log 1 line' : 'Log $n lines',
    n == 1 ? 'Enregistrer 1 ligne' : 'Enregistrer $n lignes',
  );
  String get draftDismiss => _t('Dismiss', 'Ignorer');
  String draftLogged(int ayahs, int skipped) => skipped > 0
      ? _t(
          'Logged $ayahs ayahs from your reading; $skipped left out because they do not fit.',
          '$ayahs ayahs enregistrés depuis votre lecture ; $skipped laissés de côté car ils ne conviennent pas.',
        )
      : _t(
          'Logged $ayahs ayahs from your reading',
          '$ayahs ayahs enregistrés depuis votre lecture',
        );
  String get editLine => _t('Edit line', 'Modifier la ligne');
  String get fromPage => _t('From page', 'De la page');
  String get toPage => _t('To page', 'À la page');
  String get removeLine => _t('Drop this line', 'Retirer cette ligne');
  String get doneLabel => _t('Done', 'Terminé');

  // -- settings: reading suggestions ---------------------------------------------
  String get trackReadingLabel => _t('Suggest a log from my reading', 'Suggérer un journal depuis ma lecture');
  String get trackReadingHelp => _t(
    'The reader keeps, on this device only, how long each page was open, for 30 days. It is used to suggest what to log; you confirm everything.',
    'Le lecteur garde, sur cet appareil seulement, la durée d’ouverture de chaque page, pendant 30 jours. Cela sert à suggérer quoi enregistrer ; vous confirmez tout.',
  );
  String get readMinLabel => _t('Counts as read after', 'Compte comme lu après');
  String get readMemoriseLabel => _t('Counts as memorising after', 'Compte comme mémorisation après');
  String get readIdleLabel => _t('Stop counting after no touch for', 'Arrêter de compter sans contact pendant');
  /// "45 s", "1 min 30 s", "5 min".
  String secondsLabel(int s) {
    if (s < 60) return '$s s';
    final minutes = s ~/ 60;
    final rest = s % 60;
    return rest == 0 ? '$minutes min' : '$minutes min $rest s';
  }
  String get eraseReadingLabel => _t('Erase reading data', 'Effacer les données de lecture');
  String get eraseReadingBody => _t(
    'This removes the time kept for each page and every suggestion. Your log is not touched.',
    'Cela supprime les durées gardées par page et toutes les suggestions. Votre journal n’est pas touché.',
  );
  String get readingErased => _t('Reading data erased.', 'Données de lecture effacées.');

  // -- planner ------------------------------------------------------------------
  String get planTitle => _t('Plan', 'Plan');
  String get planAsk => _t('Ask the AI for a plan', 'Demander un plan à l’IA');
  String get planAgain => _t('Ask again', 'Redemander');
  String get planNoAi => _t(
    'Set up an AI in Settings to get plans. Everything else works without it.',
    'Configurez une IA dans les réglages pour obtenir des plans. Le reste fonctionne sans.',
  );
  String get planLoading => _t('Planning…', 'Planification…');
  String get planFailed => _t('The planner could not answer.', 'Le planificateur n’a pas pu répondre.');
  String get planEmpty => _t('The AI had no usable suggestion.', 'L’IA n’a pas fait de suggestion utilisable.');
  String planDropped(int n) => _t(
    '$n suggestion(s) left out (unreadable or not allowed).',
    '$n suggestion(s) écartée(s) (illisibles ou non autorisées).',
  );
  String get planLog => _t('Log', 'Enregistrer');

  // -- overview -----------------------------------------------------------------
  String get overviewTitle => _t('Overview', 'Vue d’ensemble');
  String get wholeQuran => _t('Whole Quran, page by page', 'Tout le Coran, page par page');
  String get sortOrder => _t('In order', 'Dans l’ordre');
  String get sortUrgent => _t('Most urgent first', 'Plus urgent d’abord');
  String get pagesApproximate => _t(
    'Page numbers follow the standard print until the layout of the print you chose is downloaded.',
    'Les numéros de page suivent l’impression standard tant que la mise en page choisie n’est pas téléchargée.',
  );
  String segmentSubtitle(int learned, int total, int? since) => since == null
      ? '$learned/$total ayahs'
      : _t(
          '$learned/$total ayahs · last ${_days(since)} ago',
          '$learned/$total ayahs · il y a ${_days(since)}',
        );
  String get read => _t('Read', 'Lire');
  String get logReview => _t('Log review', 'Enregistrer une révision');
  String get logMemorise => _t('Log memorise', 'Enregistrer une mémorisation');

  // -- settings: memorisation ---------------------------------------------------
  String get memoSettingsTitle => _t('Memorisation', 'Mémorisation');
  String get sensibleLabel => _t('Keep memorise and review sensible', 'Garder mémoriser et réviser cohérents');
  String get sensibleHelp => _t(
    'Memorise only on ayahs that are not learned (or forgotten), review only on ayahs that are learned. The part that does not fit is left out. Turn off to log anything as typed.',
    'Mémoriser seulement ce qui n’est pas appris (ou oublié), réviser seulement ce qui l’est. La partie qui ne convient pas est laissée de côté. Désactivez pour tout enregistrer tel quel.',
  );
  String get defaultPartitionLabel => _t('Default pieces', 'Découpage par défaut');
  String get saveButton => _t('Save', 'Enregistrer');
  String get saved => _t('Saved', 'Enregistré');

  // -- settings: the rules behind the statuses ----------------------------------
  String get rulesTitle => _t('Status rules', 'Règles des statuts');
  String get rulesHelp => _t(
    'The numbers behind the statuses. The defaults are the original ones; change any of them and every status is worked out again from your log.',
    'Les nombres derrière les statuts. Les valeurs par défaut sont les originales ; modifiez-en, et tous les statuts sont recalculés depuis votre journal.',
  );
  String get rulesReset => _t('Back to the original numbers', 'Revenir aux nombres d’origine');
  String get rulesInvalid => _t(
    'These numbers do not hold together: each fading step must come after the previous one, and every number must be at least 1 (penalties and forgiveness may be 0).',
    'Ces nombres sont incohérents : chaque étape de déclin doit suivre la précédente, et chaque nombre doit valoir au moins 1 (pénalités et tolérance peuvent valoir 0).',
  );
  String get rulesSomeChanged => _t('Changed from the original', 'Modifié par rapport à l’original');

  /// The group heading of a rule key.
  String ruleGroup(String key) {
    if (key.startsWith('target') || key.startsWith('primeTarget')) {
      return _t('Reviews needed to move up a level', 'Révisions nécessaires pour monter d’un niveau');
    }
    if (key.startsWith('gap') || key.startsWith('primeGap')) {
      return _t('Longest gap that still counts (days)', 'Plus long écart qui compte (jours)');
    }
    if (key.startsWith('forgive')) {
      return _t('Late days forgiven (days)', 'Jours de retard tolérés (jours)');
    }
    if (key.startsWith('penalty')) {
      return _t('Reviews lost when too late', 'Révisions perdues en cas de retard');
    }
    if (key.startsWith('c.')) {
      return _t('Consolidated: days without review', 'Consolidé : jours sans révision');
    }
    return _t('Learning: days without review', 'Apprentissage : jours sans révision');
  }

  /// The label of one rule number.
  String ruleLabel(String key) {
    final dot = key.indexOf('.');
    final name = key.substring(0, dot);
    final tail = key.substring(dot + 1);
    if (name == 'c') {
      return switch (tail) {
        'fade1' => _t('Until ${status(MemoStatus.fading1)}', 'Jusqu’à ${status(MemoStatus.fading1)}'),
        'fade2' => _t('Until ${status(MemoStatus.fading2)}', 'Jusqu’à ${status(MemoStatus.fading2)}'),
        _ => _t('Until ${status(MemoStatus.forgotten)}', 'Jusqu’à ${status(MemoStatus.forgotten)}'),
      };
    }
    final prime = name.startsWith('prime');
    final level = status(MemoStatus.learning(int.parse(tail)));
    final base = switch (name.replaceFirst('prime', '').toLowerCase()) {
      'fade1' => _t('until ${status(MemoStatus.fading1)}', 'jusqu’à ${status(MemoStatus.fading1)}'),
      'fade2' => _t('until ${status(MemoStatus.fading2)}', 'jusqu’à ${status(MemoStatus.fading2)}'),
      'drop' => _t('until it drops a level', 'jusqu’à perdre un niveau'),
      _ => '',
    };
    final who = prime
        ? _t(' · relearning', ' · réapprentissage')
        : '';
    return base.isEmpty ? '$level$who' : '$level$who · $base';
  }

  String get startOverTitle => _t('Start over?', 'Recommencer ?');
  String get startOverBody => _t(
    'This erases your whole log, so every ayah becomes not learned. Your partitions, rules, notes and settings stay. This cannot be undone (a backup can restore it).',
    'Cela efface tout votre journal : tous les ayahs redeviennent non appris. Vos découpages, règles, notes et réglages restent. Irréversible (une sauvegarde peut le restaurer).',
  );
  String get startOverAction => _t('Erase the log', 'Effacer le journal');
  String get startOverHint => _t('Erase the log and start again', 'Effacer le journal et recommencer');
  String get startOverDone => _t('The log was erased.', 'Le journal a été effacé.');
  String get rulesOpen => _t('Numbers behind the statuses', 'Nombres derrière les statuts');

  // -- settings: planner wishes -------------------------------------------------
  String get plannerPrefsTitle => _t('Planner wishes', 'Souhaits pour le planificateur');
  String get plannerUseDefault => _t('Use the default wishes', 'Utiliser les souhaits par défaut');
  String get plannerWishesLabel => _t('What I want and what comes first', 'Ce que je veux et mes priorités');
  String get plannerMinutes => _t('Minutes a day', 'Minutes par jour');
  String get plannerDefaultIs => _t('The default wishes', 'Les souhaits par défaut');

  // -- settings: partitions -----------------------------------------------------
  String get partitionsTitle => _t('My partitions', 'Mes découpages');
  String get partitionsHelp => _t(
    'A partition cuts the Quran into your own pieces. Memorisation is never attached to it, so you can change it freely.',
    'Un découpage divise le Coran en vos propres morceaux. La mémorisation n’y est jamais attachée : modifiez-le librement.',
  );
  String get partitionNew => _t('New partition', 'Nouveau découpage');
  String get partitionEdit => _t('Edit', 'Modifier');
  String get partitionDelete => _t('Delete', 'Supprimer');
  String get partitionName => _t('Name', 'Nom');
  String get partitionUnit => _t('Short word (ch, part…)', 'Mot court (ch, partie…)');
  String get partitionStarts => _t('Where each piece starts', 'Où commence chaque morceau');
  String get partitionStartsHelp => _t(
    'One start per line or separated by commas: 2:142, p 22, j 3, s 5. The first piece always begins at 1:1.',
    'Un début par ligne ou séparés par des virgules : 2:142, p 22, j 3, s 5. Le premier morceau commence toujours en 1:1.',
  );
  String partitionPieces(int n) => _t('$n pieces', '$n morceaux');
  String get partitionInvalid => _t('Some starts could not be read.', 'Certains débuts n’ont pas pu être lus.');
  String get partitionNeedName => _t('Give it a name and a short word.', 'Donnez-lui un nom et un mot court.');
  String get partitionLast => _t('Keep at least one of your own partitions.', 'Gardez au moins un de vos découpages.');
  String get partitionUnitTaken => _t(
    'That short word is already used by a built-in partition.',
    'Ce mot court est déjà utilisé par un découpage intégré.',
  );
  String get cancel => _t('Cancel', 'Annuler');
  String get delete => _t('Delete', 'Supprimer');
  String get close => _t('Close', 'Fermer');

  // -- explaining every number ----------------------------------------------------
  String get changesWhat => _t('What it changes', 'Ce que cela change');
  String get raiseIt => _t('If you raise it', 'Si vous l’augmentez');
  String get lowerIt => _t('If you lower it', 'Si vous la diminuez');
  String defaultIs(String shown) => _t('Original: $shown', 'Original : $shown');
  String get resetOne => _t('Back to the original', 'Revenir à l’original');
  String get typeNumber => _t('Type a number', 'Saisissez un nombre');
  String betweenHint(String a, String b) => _t('Between $a and $b', 'Entre $a et $b');
  String get okLabel => _t('OK', 'OK');
  String get moreInfo => _t('What does this mean?', 'Que signifie ceci ?');
  String unitDays(int n) => _t(n == 1 ? 'day' : 'days', n == 1 ? 'jour' : 'jours');
  String unitReviews(int n) => _t(n == 1 ? 'review' : 'reviews', n == 1 ? 'révision' : 'révisions');
  String get unitPieces => _t('pieces', 'morceaux');
  String get unitMinutes => _t('minutes', 'minutes');
  String get unitSuggestions => _t('suggestions', 'suggestions');

  /// The title, what it is, and what raising or lowering does, for one of the
  /// number settings outside the status rules.
  ({String title, String what, String raise, String lower}) settingInfo(String key) =>
      switch (key) {
        'attentionDays' => (
          title: _t('Look ahead', 'Regarder à l’avance'),
          what: _t(
            'Today’s “Needs attention” list also shows pieces where something will fall a step within this many days, not only what is already fading.',
            'La liste « À revoir » montre aussi les morceaux où quelque chose va baisser d’ici ce nombre de jours, pas seulement ce qui décline déjà.',
          ),
          raise: _t('A longer list that warns you earlier.', 'Une liste plus longue qui prévient plus tôt.'),
          lower: _t('A shorter list: only what is about to fall.', 'Une liste plus courte : seulement ce qui va baisser.'),
        ),
        'attentionLimit' => (
          title: _t('List length', 'Longueur de la liste'),
          what: _t(
            'The most pieces “Needs attention” shows at once, most urgent first.',
            'Le nombre maximal de morceaux que « À revoir » montre, les plus urgents d’abord.',
          ),
          raise: _t('You see more of what is waiting.', 'Vous voyez plus de ce qui attend.'),
          lower: _t('A shorter, more focused list.', 'Une liste plus courte et plus ciblée.'),
        ),
        'readMin' => (
          title: _t('Counts as read after', 'Compte comme lu après'),
          what: _t(
            'A page that was open for less than this in a day is treated as passed through, not read, and nothing is suggested for it.',
            'Une page ouverte moins longtemps que cela dans une journée est considérée comme simplement parcourue : rien n’est suggéré.',
          ),
          raise: _t('Fewer suggestions, but surer ones.', 'Moins de suggestions, mais plus sûres.'),
          lower: _t('More suggestions, including pages you only glanced at.', 'Plus de suggestions, y compris des pages seulement entrevues.'),
        ),
        'readMemorise' => (
          title: _t('Counts as memorising after', 'Compte comme mémorisation après'),
          what: _t(
            'On a page with nothing learned, this much time in a day makes the suggestion “Memorise”. Less than that was only reading.',
            'Sur une page où rien n’est appris, cette durée dans une journée fait suggérer « Mémoriser ». Moins, c’était seulement de la lecture.',
          ),
          raise: _t('Fewer Memorise suggestions: only real memorising sessions.', 'Moins de suggestions Mémoriser : seulement les vraies séances.'),
          lower: _t('More Memorise suggestions, even for short stays.', 'Plus de suggestions Mémoriser, même pour des séjours courts.'),
        ),
        'readIdle' => (
          title: _t('Stop counting after no touch for', 'Arrêter de compter sans contact pendant'),
          what: _t(
            'Time on a page stops counting this long after your last touch. Reciting while looking at a page does not touch the screen, so this has to be generous.',
            'Le temps sur une page cesse de compter après ce délai sans contact. Réciter en regardant la page ne touche pas l’écran : ce délai doit être généreux.',
          ),
          raise: _t('Long recitations count in full, and so does a phone left open.', 'Les longues récitations comptent en entier, et un téléphone laissé ouvert aussi.'),
          lower: _t('Stricter: a long silent stay stops counting sooner.', 'Plus strict : un long séjour silencieux cesse de compter plus tôt.'),
        ),
        'readKeep' => (
          title: _t('Keep reading data for', 'Garder les données de lecture pendant'),
          what: _t(
            'How long the time spent on pages is kept, so a day you forgot to log can still be suggested later.',
            'Combien de temps les durées par page sont gardées, pour qu’un jour oublié puisse encore être suggéré.',
          ),
          raise: _t('You can catch up on older days.', 'Vous pouvez rattraper des jours plus anciens.'),
          lower: _t('Less is kept on your device.', 'Moins de données sont gardées sur l’appareil.'),
        ),
        'plannerMinutes' => (
          title: _t('Minutes a day', 'Minutes par jour'),
          what: _t(
            'How much time you tell the AI planner you have for memorising and reviewing on a day.',
            'Le temps que vous dites au planificateur IA avoir pour mémoriser et réviser dans une journée.',
          ),
          raise: _t('Bigger plans.', 'Des plans plus longs.'),
          lower: _t('Smaller plans.', 'Des plans plus courts.'),
        ),
        'plannerItems' => (
          title: _t('Most suggestions', 'Maximum de suggestions'),
          what: _t(
            'The most lines the AI planner may propose in one plan.',
            'Le nombre maximal de lignes que le planificateur IA peut proposer dans un plan.',
          ),
          raise: _t('Longer plans, more to choose from.', 'Des plans plus longs, plus de choix.'),
          lower: _t('Short, focused plans.', 'Des plans courts et ciblés.'),
        ),
        // 'plannerRecent'
        _ => (
          title: _t('History the AI sees', 'Historique vu par l’IA'),
          what: _t(
            'How many recent days of your log are sent to the AI, so it knows what you just did.',
            'Combien de jours récents de votre journal sont envoyés à l’IA, pour qu’elle sache ce que vous venez de faire.',
          ),
          raise: _t('A better picture for the AI, and more of your log sent.', 'Une meilleure image pour l’IA, et plus de votre journal envoyé.'),
          lower: _t('Less of your log is sent.', 'Moins de votre journal est envoyé.'),
        ),
      };

  /// What one status rule number is and what changing it does. [key] is a key of
  /// `StatusRules`.
  ({String what, String raise, String lower, String unit}) ruleInfo(String key) {
    final dot = key.indexOf('.');
    final name = key.substring(0, dot);
    final tail = key.substring(dot + 1);
    final prime = name.startsWith('prime');
    final base = prime ? name.replaceFirst('prime', '') : name;
    final lower0 = base.isEmpty ? base : base[0].toLowerCase() + base.substring(1);
    final level = lower0 == 'c' ? '' : status(MemoStatus.learning(int.tryParse(tail) ?? 1));
    final who = prime
        ? _t('an ayah that was Consolidated before and fell back (relearning)', 'un ayah déjà consolidé puis retombé (réapprentissage)')
        : _t('an ayah in $level', 'un ayah en $level');
    if (name == 'c') {
      final step = switch (tail) {
        'fade1' => status(MemoStatus.fading1),
        'fade2' => status(MemoStatus.fading2),
        _ => status(MemoStatus.forgotten),
      };
      return (
        what: _t(
          'Days a Consolidated ayah can go without a review before it becomes $step.',
          'Jours pendant lesquels un ayah Consolidé peut rester sans révision avant de devenir $step.',
        ),
        raise: _t('Solid ayahs stay solid longer between reviews.', 'Les ayahs solides le restent plus longtemps entre deux révisions.'),
        lower: _t('You must review solid ayahs more often.', 'Vous devez réviser les ayahs solides plus souvent.'),
        unit: unitDays(2),
      );
    }
    switch (lower0) {
      case 'target':
        return (
          what: _t(
            'Reviews needed by $who before it moves up to the next level.',
            'Révisions nécessaires à $who avant de monter au niveau suivant.',
          ),
          raise: _t('Slower climb, but each level is stronger.', 'Montée plus lente, mais chaque niveau est plus solide.'),
          lower: _t('Faster climb: fewer reviews per level.', 'Montée plus rapide : moins de révisions par niveau.'),
          unit: unitReviews(2),
        );
      case 'gap':
        return (
          what: _t(
            'The longest wait since the last time you touched it that still lets a review count in full, for $who.',
            'La plus longue attente depuis la dernière fois qui laisse une révision compter en entier, pour $who.',
          ),
          raise: _t('More room between reviews.', 'Plus de marge entre les révisions.'),
          lower: _t('You must review sooner for it to count.', 'Il faut réviser plus tôt pour que cela compte.'),
          unit: unitDays(2),
        );
      case 'forgive':
        return (
          what: _t(
            'How many days later than the longest wait are still forgiven, for $who. Beyond that a review is late and costs progress.',
            'Combien de jours au-delà de la plus longue attente sont encore tolérés, pour $who. Au-delà, la révision est en retard et coûte du progrès.',
          ),
          raise: _t('More forgiving.', 'Plus tolérant.'),
          lower: _t('0 means any lateness costs progress.', '0 signifie que tout retard coûte du progrès.'),
          unit: unitDays(2),
        );
      case 'penalty':
        return (
          what: _t(
            'Reviews taken away from the progress of $who when a review comes too late.',
            'Révisions retirées de la progression de $who quand une révision arrive trop tard.',
          ),
          raise: _t('Lateness costs more.', 'Le retard coûte plus.'),
          lower: _t('Lateness costs less.', 'Le retard coûte moins.'),
          unit: unitReviews(2),
        );
      case 'fade1':
        return (
          what: _t(
            'Days without a review before $who turns ${status(MemoStatus.fading1)}, a first warning. One review brings it back.',
            'Jours sans révision avant que $who passe à ${status(MemoStatus.fading1)}, un premier avertissement. Une révision le ramène.',
          ),
          raise: _t('The warning comes later.', 'L’avertissement vient plus tard.'),
          lower: _t('The warning comes sooner.', 'L’avertissement vient plus tôt.'),
          unit: unitDays(2),
        );
      case 'fade2':
        return (
          what: _t(
            'Days without a review before $who turns ${status(MemoStatus.fading2)}, a stronger warning. One review still brings it back.',
            'Jours sans révision avant que $who passe à ${status(MemoStatus.fading2)}, un avertissement plus fort. Une révision le ramène encore.',
          ),
          raise: _t('More time before the stronger warning.', 'Plus de temps avant l’avertissement fort.'),
          lower: _t('The stronger warning comes sooner.', 'L’avertissement fort vient plus tôt.'),
          unit: unitDays(2),
        );
      default:
        return (
          what: _t(
            'Days without a review before $who drops a level (from Learning 1 it goes back to ${status(MemoStatus.notLearned)}, or ${status(MemoStatus.forgotten)} if it was Consolidated before).',
            'Jours sans révision avant que $who perde un niveau (depuis Apprentissage 1 il redevient ${status(MemoStatus.notLearned)}, ou ${status(MemoStatus.forgotten)} s’il avait été consolidé).',
          ),
          raise: _t('It survives longer without review.', 'Il survit plus longtemps sans révision.'),
          lower: _t('It falls sooner.', 'Il tombe plus tôt.'),
          unit: unitDays(2),
        );
    }
  }

  // -- presets and the live preview -----------------------------------------------
  String preset(RulesPreset? p) => switch (p) {
    RulesPreset.original => _t('Original', 'Original'),
    RulesPreset.relaxed => _t('Relaxed', 'Détendu'),
    RulesPreset.strict => _t('Strict', 'Strict'),
    null => _t('Your own', 'Les vôtres'),
  };
  String presetHelp(RulesPreset p) => switch (p) {
    RulesPreset.original => _t('The numbers the app started with.', 'Les nombres de départ de l’application.'),
    RulesPreset.relaxed => _t(
      'Fewer reviews to climb, more days before anything fades, more slack for late reviews.',
      'Moins de révisions pour monter, plus de jours avant tout déclin, plus de tolérance.',
    ),
    RulesPreset.strict => _t(
      'More reviews to climb, fewer days before anything fades, less slack.',
      'Plus de révisions pour monter, moins de jours avant tout déclin, moins de tolérance.',
    ),
  };
  String get presetsTitle => _t('Start from', 'Partir de');
  String get previewTitle => _t('What these numbers mean for you', 'Ce que ces nombres signifient pour vous');
  String get previewEveryLabel => _t('A new ayah gets a review every', 'Un nouvel ayah est révisé tous les');
  String previewEveryValue(int n) => n == 1 ? _t('day', 'jour') : _t('$n days', '$n jours');
  String previewReaches(int l2, int l3, int c, int reviews) => _t(
    'It reaches ${status(MemoStatus.learning2)} on day $l2, ${status(MemoStatus.learning3)} on day $l3 and ${status(MemoStatus.consolidated)} on day $c, after $reviews reviews.',
    'Il atteint ${status(MemoStatus.learning2)} au jour $l2, ${status(MemoStatus.learning3)} au jour $l3 et ${status(MemoStatus.consolidated)} au jour $c, après $reviews révisions.',
  );
  String get previewNever => _t(
    'It never reaches Consolidated. With reviews this far apart it fades in between, and rescuing a fading ayah brings it back but earns no progress. Review more often, or raise the days before fading.',
    'Il n’atteint jamais Consolidé. Avec des révisions aussi espacées, il décline entre deux, et sauver un ayah en déclin le ramène sans faire progresser. Révisez plus souvent, ou augmentez les jours avant déclin.',
  );
  String previewNeverReviewed(int fade1, int fade2, int drop) => _t(
    'A new ayah you never review turns ${status(MemoStatus.fading1)} after $fade1 ${unitDays(fade1)}, ${status(MemoStatus.fading2)} after $fade2, and is dropped after $drop.',
    'Un nouvel ayah jamais révisé passe à ${status(MemoStatus.fading1)} après $fade1 ${unitDays(fade1)}, ${status(MemoStatus.fading2)} après $fade2, et est perdu après $drop.',
  );
  String previewLeftAlone(int fade1, int fade2, int forgotten) => _t(
    'A Consolidated ayah left alone turns ${status(MemoStatus.fading1)} after $fade1 days, ${status(MemoStatus.fading2)} after $fade2, and ${status(MemoStatus.forgotten)} after $forgotten.',
    'Un ayah Consolidé laissé seul passe à ${status(MemoStatus.fading1)} après $fade1 jours, ${status(MemoStatus.fading2)} après $fade2, et ${status(MemoStatus.forgotten)} après $forgotten.',
  );
  String movedAlso(List<String> labels) => _t(
    'Also moved to keep the steps in order: ${labels.join(', ')}.',
    'Aussi déplacé pour garder l’ordre des étapes : ${labels.join(', ')}.',
  );
  String get rulesGroupIntroClimb => _t(
    'Each learning level is passed by reviewing. “Relearning” means an ayah that was Consolidated before and fell back: it comes back faster and gets more slack.',
    'On franchit chaque niveau d’apprentissage en révisant. « Réapprentissage » : un ayah déjà consolidé puis retombé revient plus vite et a plus de tolérance.',
  );

  // -- the status guide -------------------------------------------------------------
  String get statusGuideTitle => _t('How statuses work', 'Comment fonctionnent les statuts');
  String get statusGuideIntro => _t(
    'Every ayah has one status. It changes when you log a Memorise or a Review, and by itself when days pass without one. The numbers below are your current ones: change them in Settings and this page changes with them.',
    'Chaque ayah a un statut. Il change quand vous enregistrez une mémorisation ou une révision, et tout seul quand des jours passent sans l’une ni l’autre. Les nombres ci-dessous sont les vôtres : changez-les dans les réglages et cette page change avec eux.',
  );
  String get statusGuideOpen => _t('How statuses work', 'Comment fonctionnent les statuts');
  String get statusGuideOpenHelp => _t('What each status means and what moves an ayah between them', 'Ce que signifie chaque statut et ce qui fait passer de l’un à l’autre');

  /// The story of one status, with the user's own numbers.
  String statusStory(MemoStatus s, StatusRules r) {
    String days(int n) => '$n ${unitDays(n)}';
    switch (s) {
      case MemoStatus.notLearned:
        return _t(
          'You have not memorised it yet, or it fell all the way back. Memorise it to start ${status(MemoStatus.learning1)}.',
          'Vous ne l’avez pas encore mémorisé, ou il est retombé tout en bas. Mémorisez-le pour commencer ${status(MemoStatus.learning1)}.',
        );
      case MemoStatus.learning1:
      case MemoStatus.learning2:
      case MemoStatus.learning3:
        final level = s.learningLevel!;
        final how = level == 1
            ? _t('memorising it', 'le mémoriser')
            : _t('finishing ${status(MemoStatus.learning(level - 1))}', 'terminer ${status(MemoStatus.learning(level - 1))}');
        final next = level == 3 ? status(MemoStatus.consolidated) : status(MemoStatus.learning(level + 1));
        final below = level == 1
            ? '${status(MemoStatus.notLearned)} (${status(MemoStatus.forgotten)} if it was Consolidated before)'
            : status(MemoStatus.learning(level - 1));
        return _t(
          'You get here by $how. Review it to climb: after ${r.target(level, prime: false)} reviews it becomes $next (${r.target(level, prime: true)} if it was Consolidated before). Leave it ${days(r.fade1(level, prime: false))} and it turns ${status(MemoStatus.fading1)}, ${days(r.fade2(level, prime: false))} and it turns ${status(MemoStatus.fading2)}, and after ${days(r.drop(level, prime: false))} it drops to $below.',
          'Vous arrivez ici en $how. Révisez pour monter : après ${r.target(level, prime: false)} révisions il devient $next (${r.target(level, prime: true)} s’il avait été consolidé). Laissez-le ${days(r.fade1(level, prime: false))} et il passe à ${status(MemoStatus.fading1)}, ${days(r.fade2(level, prime: false))} à ${status(MemoStatus.fading2)}, et après ${days(r.drop(level, prime: false))} il retombe à $below.',
        );
      case MemoStatus.consolidated:
        return _t(
          'You get here by finishing ${status(MemoStatus.learning3)}. Left without a review it turns ${status(MemoStatus.fading1)} after ${days(r.consolidatedFade1)}, ${status(MemoStatus.fading2)} after ${days(r.consolidatedFade2)}, and ${status(MemoStatus.forgotten)} after ${days(r.consolidatedForgotten)}.',
          'Vous arrivez ici en terminant ${status(MemoStatus.learning3)}. Sans révision il passe à ${status(MemoStatus.fading1)} après ${days(r.consolidatedFade1)}, ${status(MemoStatus.fading2)} après ${days(r.consolidatedFade2)}, et ${status(MemoStatus.forgotten)} après ${days(r.consolidatedForgotten)}.',
        );
      case MemoStatus.fading1:
      case MemoStatus.fading2:
        return _t(
          'It was left too long. One review brings it back to the level it came from (the review itself earns no progress). If it gets none it keeps falling.',
          'Il a été laissé trop longtemps. Une révision le ramène au niveau d’où il vient (elle ne fait pas progresser). Sans révision il continue de tomber.',
        );
      case MemoStatus.forgotten:
        return _t(
          'It was Consolidated, then left too long. Memorise it again; it then climbs again, with fewer reviews needed.',
          'Il était consolidé, puis laissé trop longtemps. Mémorisez-le de nouveau ; il remonte ensuite avec moins de révisions.',
        );
    }
  }

  // -- getting started ---------------------------------------------------------------
  String get gettingStartedTitle => _t('How this works', 'Comment ça marche');
  String get gettingStartedBody => _t(
    'Log what you do: Memorise when you learn new ayahs, Review when you go over ones you know. Every ayah has a status that follows from your log, and Today shows what needs a review and what to memorise next. Tap any status badge to see what it means.',
    'Enregistrez ce que vous faites : Mémoriser quand vous apprenez de nouveaux ayahs, Réviser quand vous repassez ceux que vous connaissez. Chaque ayah a un statut qui découle de votre journal, et Aujourd’hui montre ce qu’il faut revoir et quoi mémoriser ensuite. Touchez un badge de statut pour voir ce qu’il signifie.',
  );
  String get loggingCardTitle => _t('Logging', 'Enregistrement');
  String get statusesCardTitle => _t('Statuses', 'Statuts');
  String get readingCardTitle => _t('Reading suggestions', 'Suggestions de lecture');
  String get dataCardTitle => _t('Your pieces and your log', 'Vos morceaux et votre journal');
  String get defaultPartitionHelp => _t(
    'The pieces Today, the Overview and the planner use.',
    'Les morceaux utilisés par Aujourd’hui, la vue d’ensemble et le planificateur.',
  );
  String currentRules(RulesPreset? p) => _t('Numbers: ${preset(p)}', 'Nombres : ${preset(p)}');
}
