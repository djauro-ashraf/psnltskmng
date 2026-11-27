/// A part of the agent's language that the AI is taught only when the request
/// needs it.
///
/// The whole language is some 3,000 tokens and the picture of the app that goes
/// with every message some 2,000 more. A free plan lets a request carry 8,000
/// tokens at most (GitHub Models) or takes 8,000 a minute and 200,000 a day
/// (Groq): a request that carries only what it needs is a request that can be
/// made, and many more of them fit in a day. So the language is cut in modules;
/// the router picks the few a request needs, and the prompt is built from them
/// (see `AgentPrompt.build`). Pure Dart.
enum AgentModule {
  log(
    'log',
    'record what the user memorised or reviewed, choose the day to log for, '
        'undo a log',
  ),
  open(
    'open',
    'go to a screen, a page, a surah, an ayah, a tafsir, an assistant chat, '
        'or the reading options (line and word spacing)',
  ),
  settingsApp(
    'settings.app',
    'change theme, language, reading direction, reader (view, text size, '
        'translation, tafsir, auto-read, screen on, ruku marks)',
  ),
  settingsMemo(
    'settings.memo',
    'change the review rules and status ladders, what needs attention, '
        'automatic backups, reading-time tracking, the default partition',
  ),
  settingsAi(
    'settings.ai',
    'change the planner and the assistant: switches, provider, model, plan '
        'length and wishes, answer language and length',
  ),
  partitions(
    'partitions',
    'create or delete the user\'s own ways of cutting the Quran',
  ),
  notes(
    'notes',
    'add, mark as remembered, restore or delete notes on pages',
  ),
  data(
    'data',
    'erase the log, the reading data or the chats; back up or restore',
  ),
  plan('plan', 'ask the AI planner for today\'s plan'),
  progress(
    'progress',
    'answer a question about the user\'s progress, log or what needs attention',
  ),
  help('help', 'explain how the app and its screens work');

  const AgentModule(this.id, this.about);

  /// The name the AI writes in a `need` and the router in a triage.
  final String id;

  /// What the module teaches, in one line of English: the AI reads it in the
  /// list of what it was not taught, and the triage model reads it to choose.
  final String about;

  static AgentModule? byId(String id) {
    final wanted = id.trim().toLowerCase();
    for (final module in values) {
      if (module.id == wanted) return module;
    }
    return null;
  }

  /// A module that teaches some of the settings.
  bool get isSettings => settingsGroup != null;

  /// The group of settings this module teaches, if it teaches settings.
  AgentSettingGroup? get settingsGroup => switch (this) {
    AgentModule.settingsApp => AgentSettingGroup.app,
    AgentModule.settingsMemo => AgentSettingGroup.memo,
    AgentModule.settingsAi => AgentSettingGroup.ai,
    _ => null,
  };

  /// The parts of the picture of the app this module needs the AI to see.
  Set<AgentState> get state => switch (this) {
    AgentModule.log => const {AgentState.units, AgentState.logDay, AgentState.recentLog},
    AgentModule.open => const {AgentState.units},
    AgentModule.settingsApp => const {
      AgentState.settings,
      AgentState.translations,
      AgentState.tafsirs,
    },
    AgentModule.settingsMemo => const {AgentState.settings, AgentState.units},
    AgentModule.settingsAi => const {AgentState.settings, AgentState.planner},
    AgentModule.partitions => const {AgentState.units},
    AgentModule.notes => const {AgentState.notes},
    AgentModule.data => const {},
    AgentModule.plan => const {AgentState.planner},
    AgentModule.progress => const {
      AgentState.overall,
      AgentState.attention,
      AgentState.next,
      AgentState.recentLog,
    },
    AgentModule.help => const {},
  };
}

/// One part of the picture of the app (`"app"` in every message).
enum AgentState {
  /// The units and partitions (ids, names, how many pieces).
  units,

  /// The progress of the whole Quran.
  overall,

  /// The pieces that need attention.
  attention,

  /// The next piece to memorise.
  next,

  /// The recent log.
  recentLog,

  /// The day the Today screen logs for.
  logDay,

  /// The notes (when the user shares them).
  notes,

  /// The translations that are downloaded.
  translations,

  /// The tafsirs that are downloaded.
  tafsirs,

  /// The settings (only the groups that are taught).
  settings,

  /// Whether the AI planner can be asked.
  planner,
}

/// The settings the agent may change, in three groups, each taught by a module
/// of its own: a request about the theme has no use for the review ladders.
enum AgentSettingGroup {
  app,
  memo,
  ai;

  AgentModule get module => switch (this) {
    AgentSettingGroup.app => AgentModule.settingsApp,
    AgentSettingGroup.memo => AgentModule.settingsMemo,
    AgentSettingGroup.ai => AgentModule.settingsAi,
  };

  static const Map<String, AgentSettingGroup> _byId = {
    'theme': app,
    'language': app,
    'readingDirection': app,
    'readerView': app,
    'textSize': app,
    'keepAwake': app,
    'rukuTicks': app,
    'wordsUnit': app,
    'autoReadSpeed': app,
    'translation': app,
    'tafsirSource': app,
    'aiCopyInstruction': app,
    'backupFrequency': memo,
    'keepSensible': memo,
    'attentionDays': memo,
    'attentionLimit': memo,
    'defaultPartition': memo,
    'rulesPreset': memo,
    'trackReading': memo,
    'readMinSeconds': memo,
    'readMemoriseSeconds': memo,
    'readIdleSeconds': memo,
    'readKeepDays': memo,
    'plannerMinutes': ai,
    'plannerMaxItems': ai,
    'plannerRecentDays': ai,
    'plannerUseDefault': ai,
    'plannerWishes': ai,
    'plannerAi': ai,
    'plannerProvider': ai,
    'plannerModel': ai,
    'askEnabled': ai,
    'askProvider': ai,
    'askModel': ai,
    'askAnswerLanguage': ai,
    'askAnswerLength': ai,
  };

  /// The group of a setting by the name the AI writes (`rule.<key>` and the
  /// `rules` summary are the review rules), or null for a name that is in no
  /// group (a test makes sure there is none in the catalog).
  static AgentSettingGroup? of(String id) {
    if (id == 'rules' || id.startsWith('rule.')) return memo;
    return _byId[id];
  }
}

/// Sets of modules the app names.
abstract final class AgentModules {
  /// Every module: the whole language, as it was before it was cut.
  static const Set<AgentModule> all = {...AgentModule.values};

  /// What the AI is taught when nobody could say what a request needs (no
  /// router answer at all): the commonest things. A miss costs one more
  /// request, not a failure: the AI can ask for a module it was not taught.
  static const Set<AgentModule> fallback = {
    AgentModule.log,
    AgentModule.open,
    AgentModule.progress,
    AgentModule.settingsApp,
  };

  /// Most modules a request is routed to by the rules; more would not be a
  /// saving.
  static const int most = 4;

  static Set<AgentState> stateOf(Set<AgentModule> modules) => {
    for (final module in modules) ...module.state,
  };

  static Set<AgentSettingGroup> groupsOf(Set<AgentModule> modules) => {
    for (final module in modules)
      if (module.settingsGroup != null) module.settingsGroup!,
  };

  /// The modules in the order they are written in the prompt (always the same
  /// order, so that the start of a prompt is the same from one request to the
  /// next and a provider that caches prompts can use it).
  static List<AgentModule> ordered(Set<AgentModule> modules) => [
    for (final module in AgentModule.values)
      if (modules.contains(module)) module,
  ];
}
