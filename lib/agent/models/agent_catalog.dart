import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';

/// What kind of value a setting takes.
enum AgentValueKind {
  /// true / false.
  flag,

  /// A whole number in a range.
  number,

  /// One word of a fixed list.
  choice,

  /// Free text of a limited length (may be empty).
  text,

  /// An identifier (a model, a partition, a translation): its shape is checked
  /// here and its meaning by the app when the setting is applied.
  word,
}

/// One setting the agent may change: the single source of truth for its name,
/// its values, what the AI is told about it (`about`) and how the screen words
/// it. The parser validates from this, the prompt is written from it, and the
/// controller must apply every id in [AgentCatalog.all] (a test checks it).
/// Pure Dart.
final class AgentSettingSpec {
  const AgentSettingSpec(
    this.id,
    this.kind, {
    required this.en,
    required this.fr,
    required this.about,
    this.min = 0,
    this.max = 0,
    this.choices = const [],
    this.maxLength = 0,
    this.aliases = const {},
  });

  /// The name the AI writes.
  final String id;
  final AgentValueKind kind;

  /// The name on the screen, in English and French.
  final String en;
  final String fr;

  /// One short line for the AI: what the setting does.
  final String about;

  /// The range of a [AgentValueKind.number], both included.
  final int min;
  final int max;

  /// The words of a [AgentValueKind.choice].
  final List<String> choices;

  /// The longest [AgentValueKind.text].
  final int maxLength;

  /// Other spellings that mean one of the values (lower case).
  final Map<String, String> aliases;

  static final RegExp _wordShape = RegExp(r'^[A-Za-z0-9_.:/\-]{1,80}$');

  /// [raw] as a value of this setting, or null when it is not one (the
  /// instruction is then dropped, never repaired).
  Object? normalise(Object? raw) {
    switch (kind) {
      case AgentValueKind.flag:
        {
          if (raw is bool) return raw;
          if (raw is String) {
            final word = raw.trim().toLowerCase();
            if (word == 'true' || word == 'on' || word == 'yes') return true;
            if (word == 'false' || word == 'off' || word == 'no') return false;
          }
          return null;
        }
      case AgentValueKind.number:
        {
          int? number;
          if (raw is int) number = raw;
          if (raw is double && raw == raw.roundToDouble()) number = raw.toInt();
          if (raw is String) number = int.tryParse(raw.trim());
          if (number == null || number < min || number > max) return null;
          return number;
        }
      case AgentValueKind.choice:
        {
          if (raw is! String) return null;
          final word = raw.trim().toLowerCase();
          final mapped = aliases[word] ?? word;
          return choices.contains(mapped) ? mapped : null;
        }
      case AgentValueKind.text:
        {
          if (raw is! String) return null;
          final text = raw.trim();
          return text.length > maxLength ? null : text;
        }
      case AgentValueKind.word:
        {
          if (raw is! String) return null;
          final word = raw.trim();
          final mapped = aliases[word.toLowerCase()];
          if (mapped != null) return mapped;
          return _wordShape.hasMatch(word) ? word : null;
        }
    }
  }

  /// The values as the prompt shows them.
  String get valueDoc {
    switch (kind) {
      case AgentValueKind.flag:
        return 'true | false';
      case AgentValueKind.number:
        return '$min to $max';
      case AgentValueKind.choice:
        return choices.map((c) => '"$c"').join(' | ');
      case AgentValueKind.text:
        return 'text, at most $maxLength characters';
      case AgentValueKind.word:
        return aliases.isEmpty
            ? 'an identifier'
            : 'an identifier, or "${aliases.keys.first}"';
    }
  }

  /// A value in the words of the screen (a flag as On / Off, the rest as is).
  String label(Object value, {required bool french}) {
    if (value is bool) {
      return value ? (french ? 'Activé' : 'On') : (french ? 'Désactivé' : 'Off');
    }
    if (value is String && value.isEmpty) {
      return french ? '(par défaut)' : '(default)';
    }
    if (value is String && value.length > 60) return '${value.substring(0, 57)}…';
    return '$value';
  }
}

/// Every setting the agent may change. What is NOT here, and why:
///
/// * API keys and the saved-keys vault: they must never pass through an AI.
/// * The agent's own switch, provider, model, key and approval mode: an AI that
///   could switch its own approval off could remove the user's last check.
/// * The Quran pack source address: it decides what the app downloads.
/// * Connecting or disconnecting the Google account: it is an identity step
///   the user does on screen.
abstract final class AgentCatalog {
  static final List<String> _providers = [for (final p in aiProviderInfos) p.id];

  /// The settings by name (the rules are in [rules]).
  static final List<AgentSettingSpec> named = [
    // -- appearance and language -------------------------------------------------
    const AgentSettingSpec(
      'theme',
      AgentValueKind.choice,
      en: 'Theme',
      fr: 'Thème',
      about: 'light, dark or follow the phone',
      choices: ['system', 'light', 'dark'],
      aliases: {'auto': 'system'},
    ),
    const AgentSettingSpec(
      'language',
      AgentValueKind.choice,
      en: 'Language',
      fr: 'Langue',
      about: 'language of the app',
      choices: ['system', 'en', 'fr'],
      aliases: {'auto': 'system', 'english': 'en', 'french': 'fr', 'français': 'fr'},
    ),
    const AgentSettingSpec(
      'readingDirection',
      AgentValueKind.choice,
      en: 'Reading direction',
      fr: 'Sens de lecture',
      about: 'how text-order things run: right to left (the book) or left to right',
      choices: ['rtl', 'ltr'],
      aliases: {
        'righttoleft': 'rtl',
        'right-to-left': 'rtl',
        'lefttoright': 'ltr',
        'left-to-right': 'ltr',
      },
    ),
    const AgentSettingSpec(
      'backupFrequency',
      AgentValueKind.choice,
      en: 'Automatic backup',
      fr: 'Sauvegarde automatique',
      about: 'how often the app backs up to Google Drive by itself',
      choices: ['manual', 'daily', 'weekly'],
    ),
    // -- memorisation ------------------------------------------------------------
    const AgentSettingSpec(
      'keepSensible',
      AgentValueKind.flag,
      en: 'Keep memorise and review sensible',
      fr: 'Garder mémoriser et réviser cohérents',
      about: 'true: memorise only lands on ayahs not learned, review only on learned ones',
    ),
    const AgentSettingSpec(
      'attentionDays',
      AgentValueKind.number,
      en: 'Days ahead for “needs attention”',
      fr: 'Jours à l’avance pour « À revoir »',
      about: 'how many days ahead Today looks for what is about to fall',
      min: 1,
      max: 60,
    ),
    const AgentSettingSpec(
      'attentionLimit',
      AgentValueKind.number,
      en: '“Needs attention” list length',
      fr: 'Longueur de la liste « À revoir »',
      about: 'the most pieces the needs-attention list shows',
      min: 1,
      max: 100,
    ),
    const AgentSettingSpec(
      'defaultPartition',
      AgentValueKind.word,
      en: 'Default pieces',
      fr: 'Morceaux par défaut',
      about: 'the id of the partition Overview and the planner open with (an id from app.units)',
    ),
    const AgentSettingSpec(
      'rulesPreset',
      AgentValueKind.choice,
      en: 'Status rules',
      fr: 'Règles des statuts',
      about: 'relaxed: fewer reviews to climb and more days before anything fades; strict: the opposite; original: the app\'s own numbers. Changes every status, so only when asked',
      choices: ['original', 'relaxed', 'strict'],
    ),
    const AgentSettingSpec(
      'trackReading',
      AgentValueKind.flag,
      en: 'Track reading time',
      fr: 'Suivre le temps de lecture',
      about: 'whether the reader keeps the time spent on each page to suggest a log',
    ),
    const AgentSettingSpec(
      'readMinSeconds',
      AgentValueKind.number,
      en: 'Seconds for a page to count as read',
      fr: 'Secondes pour qu’une page compte comme lue',
      about: 'a page shown for less than this many seconds in a day is not counted as read',
      min: 5,
      max: 3600,
    ),
    const AgentSettingSpec(
      'readMemoriseSeconds',
      AgentValueKind.number,
      en: 'Seconds on a new page to suggest Memorise',
      fr: 'Secondes sur une page nouvelle pour suggérer Mémoriser',
      about: 'seconds on a page with nothing learned that make the suggestion Memorise; not below readMinSeconds',
      min: 5,
      max: 36000,
    ),
    const AgentSettingSpec(
      'readIdleSeconds',
      AgentValueKind.number,
      en: 'Idle seconds before reading stops counting',
      fr: 'Secondes d’inactivité avant que la lecture ne compte plus',
      about: 'time on a page stops counting this many seconds after the last touch',
      min: 30,
      max: 7200,
    ),
    const AgentSettingSpec(
      'readKeepDays',
      AgentValueKind.number,
      en: 'Keep reading data for (days)',
      fr: 'Garder les données de lecture (jours)',
      about: 'days the time-on-page evidence is kept',
      min: 1,
      max: 365,
    ),
    // -- the planner -------------------------------------------------------------
    const AgentSettingSpec(
      'plannerMinutes',
      AgentValueKind.number,
      en: 'Planner minutes a day',
      fr: 'Minutes par jour (planificateur)',
      about: 'minutes a day the plan may use',
      min: 5,
      max: 1440,
    ),
    const AgentSettingSpec(
      'plannerMaxItems',
      AgentValueKind.number,
      en: 'Most suggestions in a plan',
      fr: 'Maximum de suggestions par plan',
      about: 'the most lines one plan may have',
      min: 1,
      max: 30,
    ),
    const AgentSettingSpec(
      'plannerRecentDays',
      AgentValueKind.number,
      en: 'Days of log the planner sees',
      fr: 'Jours de journal vus par le planificateur',
      about: 'days of the log the planner AI is shown',
      min: 1,
      max: 60,
    ),
    const AgentSettingSpec(
      'plannerUseDefault',
      AgentValueKind.flag,
      en: 'Planner uses the default wishes',
      fr: 'Le planificateur utilise les souhaits par défaut',
      about: 'true: the planner follows the app\'s default wishes; false: it follows plannerWishes',
    ),
    const AgentSettingSpec(
      'plannerWishes',
      AgentValueKind.text,
      en: 'Planner wishes',
      fr: 'Souhaits du planificateur',
      about: 'the user\'s own instructions to the planner AI, in their words; also set plannerUseDefault to false for them to apply',
      maxLength: 1500,
    ),
    AgentSettingSpec(
      'plannerAi',
      AgentValueKind.flag,
      en: 'AI planner',
      fr: 'Planificateur IA',
      about: 'the switch of the AI planner (it needs its own key, which only the user can add)',
    ),
    AgentSettingSpec(
      'plannerProvider',
      AgentValueKind.choice,
      en: 'Planner provider',
      fr: 'Fournisseur du planificateur',
      about: 'which AI provider the planner uses',
      choices: _providers,
    ),
    const AgentSettingSpec(
      'plannerModel',
      AgentValueKind.word,
      en: 'Planner model',
      fr: 'Modèle du planificateur',
      about: 'the model the planner calls on its provider; "default" goes back to the provider\'s own',
      aliases: {'default': ''},
    ),
    // -- the assistant -----------------------------------------------------------
    const AgentSettingSpec(
      'askEnabled',
      AgentValueKind.flag,
      en: 'Assistant',
      fr: 'Assistant',
      about: 'the switch of the assistant chats (it needs its own key, which only the user can add)',
    ),
    AgentSettingSpec(
      'askProvider',
      AgentValueKind.choice,
      en: 'Assistant provider',
      fr: 'Fournisseur de l’assistant',
      about: 'which AI provider the assistant uses',
      choices: _providers,
    ),
    const AgentSettingSpec(
      'askModel',
      AgentValueKind.word,
      en: 'Assistant model',
      fr: 'Modèle de l’assistant',
      about: 'the model the assistant calls on its provider; "default" goes back to the provider\'s own',
      aliases: {'default': ''},
    ),
    const AgentSettingSpec(
      'askAnswerLanguage',
      AgentValueKind.choice,
      en: 'Assistant answer language',
      fr: 'Langue des réponses de l’assistant',
      about: 'language the assistant answers in',
      choices: ['auto', 'en', 'fr', 'ar'],
      aliases: {'english': 'en', 'french': 'fr', 'arabic': 'ar'},
    ),
    const AgentSettingSpec(
      'askAnswerLength',
      AgentValueKind.choice,
      en: 'Assistant answer length',
      fr: 'Longueur des réponses de l’assistant',
      about: 'how long the assistant\'s answers are',
      choices: ['normal', 'short'],
    ),
    // -- the reader --------------------------------------------------------------
    const AgentSettingSpec(
      'readerView',
      AgentValueKind.choice,
      en: 'Reader view',
      fr: 'Vue du lecteur',
      about: 'how the reader shows a page: the mushaf page, the words stream, or the details',
      choices: ['mushaf', 'words', 'details'],
    ),
    const AgentSettingSpec(
      'textSize',
      AgentValueKind.number,
      en: 'Reader text size',
      fr: 'Taille du texte du lecteur',
      about: 'text size of the reader, 0 smallest to 3 largest',
      min: 0,
      max: 3,
    ),
    const AgentSettingSpec(
      'keepAwake',
      AgentValueKind.flag,
      en: 'Keep the screen awake while reading',
      fr: 'Garder l’écran allumé pendant la lecture',
      about: 'keeps the screen on in the reader',
    ),
    const AgentSettingSpec(
      'rukuTicks',
      AgentValueKind.flag,
      en: 'Ruku marks',
      fr: 'Repères de ruku',
      about: 'shows the ruku marks in the reader',
    ),
    const AgentSettingSpec(
      'wordsUnit',
      AgentValueKind.choice,
      en: 'Words stream unit',
      fr: 'Unité du flux de mots',
      about: 'the unit the words stream is cut in',
      choices: ['page', 'ruku', 'hizb', 'juz', 'surah', 'ch', 'quran'],
    ),
    const AgentSettingSpec(
      'autoReadSpeed',
      AgentValueKind.number,
      en: 'Auto-read speed (words a minute)',
      fr: 'Vitesse de lecture automatique (mots par minute)',
      about: 'words a minute of the auto-read pacer',
      min: 20,
      max: 180,
    ),
    const AgentSettingSpec(
      'translation',
      AgentValueKind.word,
      en: 'Translation',
      fr: 'Traduction',
      about: 'the id of a downloaded translation (app.translations), or "off"',
    ),
    const AgentSettingSpec(
      'tafsirSource',
      AgentValueKind.word,
      en: 'Tafsir source',
      fr: 'Source du tafsir',
      about: 'the id of a downloaded tafsir (app.tafsirs)',
    ),
    const AgentSettingSpec(
      'aiCopyInstruction',
      AgentValueKind.text,
      en: 'Instruction added when copying an ayah for an AI',
      fr: 'Consigne ajoutée en copiant un ayah pour une IA',
      about: 'the sentence put with an ayah copied for an AI',
      maxLength: 1500,
    ),
  ];

  /// The prefix of the status-rule settings: `rule.target.1`.
  static const String rulePrefix = 'rule.';

  /// One setting per number of the status rules (the 43 keys of
  /// `StatusRules`), each as `rule.<key>`. The app keeps each ladder in order.
  static final List<AgentSettingSpec> rules = [
    for (final key in StatusRules.keys)
      AgentSettingSpec(
        '$rulePrefix$key',
        AgentValueKind.number,
        en: 'Rule $key',
        fr: 'Règle $key',
        about: 'a number of the status rules',
        min: _ruleMin(key),
        max: 3650,
      ),
  ];

  static int _ruleMin(String key) =>
      key.startsWith('forgive') || key.startsWith('penalty') ? 0 : 1;

  /// Every setting.
  static final List<AgentSettingSpec> all = [...named, ...rules];

  static String _plain(String id) =>
      id.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]'), '');

  static final Map<String, AgentSettingSpec> _byPlainId = {
    for (final spec in all) _plain(spec.id): spec,
  };

  /// The setting the AI means by [id] (case and `_` / `-` do not matter), or
  /// null when there is no such setting.
  static AgentSettingSpec? byId(String id) => _byPlainId[_plain(id)];

  /// The status-rule key of a `rule.` setting, else null.
  static String? ruleKey(String id) => id.startsWith(rulePrefix)
      ? id.substring(rulePrefix.length)
      : null;
}
