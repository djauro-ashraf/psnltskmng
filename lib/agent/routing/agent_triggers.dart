import 'package:personaltskmng/agent/routing/agent_module.dart';

/// The words, in English, French and Arabic, that say which modules a request
/// needs. The first tier of the router: no network, no cost, and right for the
/// plain requests that make most of what is asked ("I reviewed ch 5", "dark
/// mode", "open page 30"). What it cannot place goes to the next tier.
///
/// A word counts only as a whole word (Arabic letters are letters here, which
/// the plain `\b` of a regular expression does not know). Pure Dart.
abstract final class AgentTriggers {
  static RegExp _words(List<String> alternatives) => RegExp(
    r'(?<![\p{L}\p{N}_])(?:' + alternatives.join('|') + r')(?![\p{L}\p{N}_])',
    caseSensitive: false,
    unicode: true,
  );

  /// A piece of a unit with its number: "ch 5", "p 12", "juz 30", "s 2",
  /// "page 12", "surah 2", "صفحة 12", an ayah "2:255".
  static final RegExp range = RegExp(
    r'(?<![\p{L}\p{N}_])(?:(?:ch|pp?|s|j|hz|ru|page|pages|juz|surah|sourate|hizb|ruku|صفحة|سورة|جزء|حزب)\s*\.?\s*\d+|\d{1,3}\s*:\s*\d{1,3})',
    caseSensitive: false,
    unicode: true,
  );

  /// Something was memorised, reviewed, finished.
  static final RegExp _did = _words([
    'reviewed', 'revised', 'revision', 'memori[sz]\\p{L}*', 'learn(?:ed|t|ing)?',
    'recite[sd]?', 'recited', 'finished', 'completed', 'did', 'done', 'repeated',
    'went over', 'revu', 'révis\\p{L}*', 'revis\\p{L}*', 'mémoris\\p{L}*',
    'appris', 'apprendre', 'récit\\p{L}*', 'recit\\p{L}*', 'fini', 'terminé',
    'termine', 'relu', 'j[\'’]ai fait',
    'حفظت', 'حفظنا', 'راجعت', 'مراجعة', 'قرأت', 'أتممت', 'أنهيت', 'سمّعت', 'سمعت',
  ]);

  static final RegExp _undo = _words([
    'undo', 'cancel (?:that|it|the last(?: one)?)', 'take (?:it )?back',
    'annul\\p{L}*', 'défaire', 'defaire', 'تراجع', 'ألغ\\p{L}*',
  ]);

  static final RegExp _day = _words([
    'yesterday', 'hier', 'أمس', 'البارحة', 'log day', 'log for',
  ]);

  static final RegExp _open = _words([
    'open', 'show(?: me)?', 'display', 'go to', 'take me', 'navigate',
    'bring up', 'launch', 'ouvr\\p{L}*', 'affich\\p{L}*', 'montre\\p{L}*',
    'va (?:à|a|au)', 'aller', 'emmène\\p{L}*', 'افتح', 'اعرض', 'خذني', 'اذهب',
    'tafsir', 'tafseer', 'تفسير', 'assistant chat',
    'reading options?', 'options de lecture', 'خيارات القراءة',
    '(?:line |word |letter )?spacing', 'space between \\p{L}+', 'espacement',
    'تباعد', 'المسافة',
  ]);

  static final RegExp _app = _words([
    'theme', 'thème', 'dark(?: mode)?', 'light mode', 'night mode', 'mode sombre',
    'mode clair', 'sombre', 'داكن', 'الوضع الليلي', 'المظهر',
    'language', 'langue', 'لغة', 'right to left', 'rtl', 'ltr',
    'text size', 'font size', 'taille (?:du|de la) texte', 'bigger text',
    'larger text', 'smaller text', 'حجم الخط', 'حجم النص',
    'mushaf view', 'words view', 'reader view', 'details view',
    'keep (?:the )?screen', 'screen on', 'awake', 'écran allumé',
    'ruku (?:marks|ticks)', 'ticks', 'translation', 'traduction', 'ترجمة',
    'tafsir source', 'auto-?read\\p{L}*', 'lecture auto\\p{L}*', 'words a minute',
    'words per minute', 'copy instruction',
  ]);

  static final RegExp _memo = _words([
    'attention', 'rules?', 'règles?', 'regles?', 'strict', 'relaxed', 'souple',
    'ladder', 'fad(?:e|es|ing)', 'forgive\\p{L}*', 'penalt\\p{L}*', 'pénalit\\p{L}*',
    'automatic backups?', 'backup (?:every|daily|weekly|frequency)',
    'sauvegarde automatique', 'track(?:ing)? (?:my )?reading', 'time on (?:the )?page',
    'idle', 'keep sensible', 'memorise only', 'default (?:partition|unit)',
    'partition par défaut', 'الإعدادات الافتراضية',
  ]);

  static final RegExp _ai = _words([
    'planner', 'plan (?:length|lines?|size)', 'minutes (?:a|per) day',
    'minutes par jour', 'wish(?:es)?', 'focus on', 'provider', 'fournisseur',
    'model', 'modèle', 'groq', 'gemini', 'github models?', 'openrouter',
    'ask ai', 'assistant (?:ai|model|language|length|answers?)',
    'answer (?:language|length)', 'réponses? de l[\'’]assistant',
    'plans? (?:shorter|longer)', 'plans? of \\d+', '\\d+ lines?',
    'المزود', 'النموذج', 'المساعد',
  ]);

  /// Words that start a change, with no hint of what is changed.
  static final RegExp _change = _words([
    'set', 'change', 'switch', 'turn (?:on|off)', 'enable', 'disable',
    'activate', 'deactivate', 'toggle', 'make it', 'make the', 'settings?',
    'réglages?', 'paramètres?', 'active', 'désactive', 'change\\p{L}*', 'mets',
    'passe', 'فعّل', 'فعل', 'عطّل', 'عطل', 'غيّر', 'غير', 'الإعدادات',
  ]);

  static final RegExp _partitions = _words([
    'partitions?', 'my ch', 'custom (?:units?|divisions?|cuts?)',
    'cut(?:ting)? the (?:quran|qur[\'’]an)', 'split the (?:quran|qur[\'’]an)',
    'divide the (?:quran|qur[\'’]an)', 'my (?:own )?units?', 'create (?:a )?unit',
    'découp\\p{L}*', 'diviser', 'تقسيم', 'قسّم', 'قسم',
  ]);

  static final RegExp _notes = _words([
    'notes?', 'note that', 'remember (?:that|this)', 'remembered',
    'archiv\\p{L}*', 'mémo', 'rappel', 'مذكرة', 'ملاحظة', 'ملاحظات',
  ]);

  static final RegExp _data = _words([
    'erase', 'wipe', 'delete (?:all|everything|the log|my log|all chats|chats)',
    'clear (?:the |my )?(?:log|chats|history)', 'reset (?:everything|all)',
    'efface\\p{L}*', 'supprim\\p{L}*', 'vide\\p{L}*', 'back ?up', 'restore',
    'sauvegard\\p{L}*', 'restaur\\p{L}*', 'google drive', 'drive', 'امسح',
    'احذف', 'نسخ احتياطي', 'استعادة',
  ]);

  static final RegExp _plan = _words([
    'plan', 'plans', 'planning', 'planifi\\p{L}*', 'schedule',
    'what should i (?:do|review|memori[sz]e|revise)', 'what to (?:do|review) today',
    'que (?:dois|faut)-?je', 'خطة', 'خطتي', 'ماذا أراجع',
  ]);

  static final RegExp _progress = _words([
    'how (?:many|much|am i|far)', 'progress', 'left', 'remaining', 'status',
    'stats?', 'statistic\\p{L}*', 'so far', 'what needs', 'needs? attention',
    'about to (?:fall|fade)', 'combien', 'avancement', 'progrès', 'progres',
    'reste', 'كم', 'تقدم', 'تقدّمي', 'المتبقي',
  ]);

  static final RegExp _help = _words([
    'how (?:do|does|can|to)', 'what (?:is|are|does)', 'explain', 'user guide',
    'tutorial', 'comment (?:faire|ça|ca|fonctionne|utiliser)', 'c[\'’]est quoi',
    'qu[\'’]est-ce', 'aide', 'كيف', 'ما هو', 'ما هي', 'شرح', 'مساعدة',
  ]);

  /// How many words of each module's list are in [text] (modules with none are
  /// left out), and whether there is a word that starts a change with no
  /// word about what is changed ("turn it off", "make it shorter"): the words
  /// of a module that only answers or advises (plan, progress, help) do not
  /// say what that is.
  static ({Map<AgentModule, int> hits, bool vagueChange}) scan(String text) {
    int count(RegExp pattern) => pattern.allMatches(text).length;

    final hasRange = range.hasMatch(text);
    final did = count(_did);
    final open = count(_open);
    final app = count(_app);
    final memo = count(_memo);
    final ai = count(_ai);
    final partitions = count(_partitions);
    final data = count(_data);
    final notes = count(_notes);
    final plan = count(_plan);
    final undo = count(_undo);
    final day = count(_day);

    final hits = <AgentModule, int>{};
    void add(AgentModule module, int n) {
      if (n > 0) hits[module] = (hits[module] ?? 0) + n;
    }

    add(AgentModule.log, did * 2 + undo * 2 + day);
    add(AgentModule.open, open * 2);
    add(AgentModule.settingsApp, app * 2);
    add(AgentModule.settingsMemo, memo * 2);
    add(AgentModule.settingsAi, ai * 2);
    add(AgentModule.partitions, partitions * 2);
    add(AgentModule.notes, notes * 2);
    add(AgentModule.data, data * 2);
    add(AgentModule.plan, plan);
    add(AgentModule.progress, count(_progress));
    add(AgentModule.help, count(_help));

    // A piece with its number and no word at all about what to do with it
    // ("ch 5"): it is a log or a place to go to.
    if (hasRange && hits.isEmpty) {
      add(AgentModule.log, 1);
      add(AgentModule.open, 1);
    }

    final topic = app + memo + ai > 0;
    final strong = hits.entries.any(
      (e) =>
          e.value > 1 &&
          e.key != AgentModule.plan &&
          e.key != AgentModule.progress &&
          e.key != AgentModule.help,
    );
    return (hits: hits, vagueChange: !topic && !strong && count(_change) > 0);
  }
}
