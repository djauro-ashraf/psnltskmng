import 'package:flutter/widgets.dart';
import 'package:personaltskmng/agent/models/agent_command.dart';
import 'package:personaltskmng/agent/controller/agent_providers.dart';
import 'package:personaltskmng/agent/models/agent_settings.dart';
import 'package:personaltskmng/agent/models/agent_turn.dart';
import 'package:personaltskmng/agent/routing/agent_module.dart';
import 'package:personaltskmng/agent/routing/agent_router.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';

/// The words of the agent screens, in English and French. Kept in one small
/// class (not in the ARB files), like `MemoText`, so the feature can change in
/// one place and needs no generated code.
class AgentText {
  const AgentText._(this._fr);

  /// The words for the language of [context] (French or else English).
  factory AgentText.of(BuildContext context) =>
      AgentText._(Localizations.localeOf(context).languageCode == 'fr');

  /// The words for a language code, without a context (tests).
  factory AgentText.forLanguage(String code) => AgentText._(code == 'fr');

  final bool _fr;

  String _t(String en, String fr) => _fr ? fr : en;

  // -- the screen ---------------------------------------------------------------
  String get title => _t('Agent', 'Agent');
  String get openTooltip => _t('Give a command', 'Donner une commande');
  String get hint =>
      _t('Tell the app what to do…', 'Dites à l’application quoi faire…');
  String get send => _t('Send', 'Envoyer');
  String get newConversation => _t('New conversation', 'Nouvelle conversation');
  String get intro => _t(
    'Say what you did or what you want, in your own words. I turn it into '
        'steps; the app carries them out and checks each one.',
    'Dites ce que vous avez fait ou ce que vous voulez, avec vos mots. Je le '
        'transforme en étapes ; l’application les exécute et vérifie chacune.',
  );
  List<String> get examples => _fr
      ? const [
          'J’ai révisé ch 5 aujourd’hui',
          'J’ai mémorisé la page 12 hier',
          'Ouvre le tafsir de 2:255',
          'Passe en mode sombre',
          'Fais-moi un plan pour aujourd’hui',
          'Plans de 5 lignes maximum',
        ]
      : const [
          'I reviewed ch 5 today',
          'I memorised page 12 yesterday',
          'Open the tafsir of 2:255',
          'Switch to dark mode',
          'Make me a plan for today',
          'Plans of 5 lines at most',
        ];
  String get notReadyTitle =>
      _t('The agent is not ready', 'L’agent n’est pas prêt');
  String get notReadyBody => _t(
    'Turn it on and add its API key in Settings.',
    'Activez-le et ajoutez sa clé API dans les paramètres.',
  );
  String get openSettings => _t('Open Settings', 'Ouvrir les paramètres');
  String get thinking => _t('Thinking…', 'Réflexion…');
  String get pendingTitle => _t('I am about to:', 'Je m’apprête à :');
  String get run => _t('Do it', 'Exécuter');
  String get cancel => _t('Cancel', 'Annuler');
  String get cancelled => _t('Cancelled.', 'Annulé.');
  String get undo => _t('Undo', 'Défaire');
  String get undone => _t('Undone.', 'Défait.');
  String get nothingToDo =>
      _t('Nothing for the app to do.', 'Rien à faire pour l’application.');

  /// Shown on a waiting request that holds something that cannot be undone.
  String get destructiveWarning => _t(
    'This cannot be undone, so it always waits for your tap.',
    'Cela ne peut pas être annulé : cela attend toujours votre feu vert.',
  );

  String dropped(int n) => n == 1
      ? _t(
          '1 instruction was not understood and was ignored.',
          '1 instruction n’a pas été comprise et a été ignorée.',
        )
      : _t(
          '$n instructions were not understood and were ignored.',
          '$n instructions n’ont pas été comprises et ont été ignorées.',
        );

  /// Why a turn failed, in a sentence. [message] is the provider's own words
  /// (never a key).
  String failure(AgentFailure failure, {String? message, AiErrorKind? kind}) {
    switch (failure) {
      case AgentFailure.noAi:
        return _t('The agent is switched off.', 'L’agent est désactivé.');
      case AgentFailure.unreadable:
        return _t(
          'I could not understand the answer. Try saying it another way.',
          'Je n’ai pas compris la réponse. Essayez de le dire autrement.',
        );
      case AgentFailure.provider:
        if (kind == AiErrorKind.missingKey) {
          return _t(
            'The agent has no API key. Add it in Settings.',
            'L’agent n’a pas de clé API. Ajoutez-la dans les paramètres.',
          );
        }
        if (message != null && message.trim().isNotEmpty) return message;
        return _t(
          'The agent could not answer.',
          'L’agent n’a pas pu répondre.',
        );
      case AgentFailure.other:
        return _t(
          'The agent could not answer.',
          'L’agent n’a pas pu répondre.',
        );
    }
  }

  // -- one instruction, in words ------------------------------------------------

  String kind(MemoKind kind) =>
      kind == MemoKind.m ? _t('Memorise', 'Mémoriser') : _t('Review', 'Réviser');

  String screen(AgentScreen screen) => switch (screen) {
    AgentScreen.today => _t('Today', 'Aujourd’hui'),
    AgentScreen.browse => _t('Browse', 'Parcourir'),
    AgentScreen.overview => _t('Overview', 'Vue d’ensemble'),
    AgentScreen.settings => _t('Settings', 'Paramètres'),
    AgentScreen.quranData => _t('Quran data', 'Données du Coran'),
    AgentScreen.chats => _t('Assistant chats', 'Chats de l’assistant'),
    AgentScreen.statusRules => _t('Status rules', 'Règles des statuts'),
    AgentScreen.statusGuide => _t('Status guide', 'Guide des statuts'),
    AgentScreen.partitions => _t('Partitions', 'Partitions'),
    AgentScreen.readingOptions => _t(
      'Reading options (spacing, text size)',
      'Options de lecture (espacement, taille du texte)',
    ),
  };

  String _place(AgentPlace place) {
    switch (place) {
      case final ScreenPlace p:
        return screen(p.screen);
      case final PagePlace p:
        return _t('page ${p.page}', 'la page ${p.page}');
      case final SurahPlace p:
        return _t('surah ${p.surah}', 'la sourate ${p.surah}');
      case final ChPlace p:
        return 'ch ${p.ch}';
      case final JuzPlace p:
        return _t('juz ${p.juz}', 'le juz ${p.juz}');
      case final PartPlace p:
        return _t(
          'surah ${p.surah} in ch ${p.ch}',
          'la sourate ${p.surah} dans ch ${p.ch}',
        );
      case final AyahPlace p:
        final view = p.view == null ? '' : ' (${p.view})';
        return '${p.ayah.key}$view';
      case final RangePlace p:
        return _t(
          'pages ${p.from}–${p.to}',
          'les pages ${p.from}–${p.to}',
        );
      case final TafsirPlace p:
        return _t(
          'the tafsir of ${p.ayah.key}',
          'le tafsir de ${p.ayah.key}',
        );
      case final AskPlace p:
        final about = p.ayah == null ? '' : ' · ${p.ayah!.key}';
        final prompt = p.prompt == null ? '' : ' · “${p.prompt}”';
        return _t(
          'the assistant$about$prompt',
          'l’assistant$about$prompt',
        );
    }
  }

  /// A choice value in words (the rest is shown as it is).
  String _choice(String value) {
    switch (value) {
      case 'system':
        return _t('System', 'Système');
      case 'light':
        return _t('Light', 'Clair');
      case 'dark':
        return _t('Dark', 'Sombre');
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      case 'ar':
        return 'العربية';
      case 'rtl':
        return _t('Right to left', 'De droite à gauche');
      case 'ltr':
        return _t('Left to right', 'De gauche à droite');
      case 'original':
        return _t('Original', 'Original');
      case 'relaxed':
        return _t('Relaxed', 'Détendu');
      case 'strict':
        return _t('Strict', 'Strict');
      case 'auto':
        return 'Auto';
      case 'normal':
        return _t('Normal', 'Normale');
      case 'short':
        return _t('Short', 'Courte');
      case 'manual':
        return _t('Manual', 'Manuelle');
      case 'daily':
        return _t('Daily', 'Quotidienne');
      case 'weekly':
        return _t('Weekly', 'Hebdomadaire');
      case 'words':
        return _t('Words', 'Mots');
      case 'details':
        return _t('Details', 'Détails');
      default:
        return value;
    }
  }

  /// A setting as a line: its name and its value.
  String setting(SetCommand c) {
    final name = _fr ? c.spec.fr : c.spec.en;
    final value = c.value;
    final shown = value is String && value.isNotEmpty && value.length <= 20
        ? _choice(value)
        : c.spec.label(value, french: _fr);
    return '$name: $shown';
  }

  String _quoted(String? text) {
    if (text == null || text.isEmpty) return '';
    final short = text.length > 60 ? '${text.substring(0, 57)}…' : text;
    return '“$short”';
  }

  /// An instruction as a line: for what is about to happen and for what
  /// happened. [today] marks a log of another day; [willLog] / [skipped] say
  /// what a log will do (only while it is still pending). [names] maps the ids
  /// the AI used (partitions, notes) to what the user knows them by.
  String command(
    AgentCommand command, {
    Day? today,
    int? willLog,
    int? skipped,
    Map<String, String> names = const {},
  }) {
    switch (command) {
      case final LogCommand c:
        final logDay = today != null && c.day != today ? ' · ${c.day}' : '';
        final logWhat = '${kind(c.kind)} · ${c.rangeText}$logDay';
        if (willLog == null) return logWhat;
        if (willLog == 0) {
          return '$logWhat · ${_t('nothing fits', 'rien ne convient')}';
        }
        final logLeft = (skipped ?? 0) > 0
            ? _t(' ($skipped left out)', ' ($skipped laissés de côté)')
            : '';
        return '$logWhat · $willLog ayahs$logLeft';
      case final LogDayCommand c:
        final dayName = c.day == null ? _t('today', 'aujourd’hui') : '${c.day}';
        return _t('Log for $dayName', 'Enregistrer pour $dayName');
      case final OpenCommand c:
        return _t('Open ${_place(c.place)}', 'Ouvrir ${_place(c.place)}');
      case final SetCommand c:
        return setting(c);
      case final PartitionSaveCommand c:
        final verb = c.id == null
            ? _t('Create partition', 'Créer le morceau')
            : _t('Replace partition', 'Remplacer le morceau');
        return '$verb “${c.name}” (${c.unit}) · '
            '${_t('${c.starts.length} cuts', '${c.starts.length} coupures')}';
      case final PartitionDeleteCommand c:
        final partName = names[c.id] ?? c.id;
        return _t(
          'Delete partition “$partName”',
          'Supprimer le morceau « $partName »',
        );
      case final NoteCommand c:
        final note = _quoted(names[c.id]);
        switch (c.op) {
          case NoteOp.add:
            return _t(
              'Add a note on page ${c.page}: ${_quoted(c.text)}',
              'Ajouter une note sur la page ${c.page} : ${_quoted(c.text)}',
            );
          case NoteOp.remembered:
            return _t('I remembered $note', 'Je m’en suis souvenu $note');
          case NoteOp.restore:
            return _t('Reopen the note $note', 'Rouvrir la note $note');
          case NoteOp.delete:
            return _t('Delete the note $note', 'Supprimer la note $note');
        }
      case final EraseCommand c:
        switch (c.what) {
          case AgentErase.log:
            return _t('Erase the whole log', 'Effacer tout le journal');
          case AgentErase.reading:
            return _t(
              'Erase the reading data',
              'Effacer les données de lecture',
            );
          case AgentErase.chats:
            return _t(
              'Delete every assistant chat',
              'Supprimer tous les chats de l’assistant',
            );
        }
      case final BackupCommand c:
        return c.op == BackupOp.now
            ? _t('Back up to Google Drive', 'Sauvegarder sur Google Drive')
            : _t(
                'Restore from Google Drive (replaces everything here)',
                'Restaurer depuis Google Drive (remplace tout ici)',
              );
      case PlanCommand _:
        return _t(
          'Ask the planner for a plan',
          'Demander un plan au planificateur',
        );
      case UndoCommand _:
        return _t('Undo the last log', 'Défaire le dernier enregistrement');
    }
  }

  /// What happened to an instruction, as a line.
  String result(
    AgentResult r, {
    Day? today,
    Map<String, String> names = const {},
  }) {
    final c = r.command;
    switch (r.kind) {
      case AgentResultKind.done:
        if (c is LogCommand) {
          final day = today != null && c.day != today ? ' · ${c.day}' : '';
          final left = r.skipped > 0
              ? _t(' (${r.skipped} left out)', ' (${r.skipped} laissés de côté)')
              : '';
          return _t(
            '${kind(c.kind)} logged on ${r.ayahs} ayahs · ${c.rangeText}$day$left',
            '${kind(c.kind)} enregistré sur ${r.ayahs} ayahs · ${c.rangeText}$day$left',
          );
        }
        return command(c, today: today, names: names);
      case AgentResultKind.nothingFits:
        if (c is LogCommand) {
          return c.kind == MemoKind.m
              ? _t(
                  'Nothing logged for ${c.rangeText}: it is already learned.',
                  'Rien d’enregistré pour ${c.rangeText} : c’est déjà appris.',
                )
              : _t(
                  'Nothing logged for ${c.rangeText}: it is not learned yet.',
                  'Rien d’enregistré pour ${c.rangeText} : ce n’est pas encore appris.',
                );
        }
        return command(c, today: today, names: names);
      case AgentResultKind.failed:
        return '${command(c, today: today, names: names)} — ${_t('failed', 'échec')}';
      case AgentResultKind.unavailable:
        if (c is PlanCommand) {
          return _t(
            'The planner is not set up (Settings → AI planner).',
            'Le planificateur n’est pas configuré (Paramètres → Planificateur IA).',
          );
        }
        if (c is UndoCommand) return _t('Nothing to undo.', 'Rien à défaire.');
        return '${command(c, today: today, names: names)} — ${_t('not possible now', 'impossible maintenant')}';
    }
  }

  // -- settings -----------------------------------------------------------------
  String get settingsTitle => _t('Agent (commands)', 'Agent (commandes)');
  String get enable => _t('Enable the agent', 'Activer l’agent');
  String get enableHelp => _t(
    'Type what you want in your own words and the app does it: open anything, '
        'log, change almost any setting, manage partitions and notes. The agent '
        'has its own API: its own provider, model and key, separate from the '
        'planner’s and the assistant’s.',
    'Écrivez ce que vous voulez avec vos mots et l’application le fait : '
        'ouvrir n’importe quoi, enregistrer, changer presque tous les réglages, '
        'gérer morceaux et notes. L’agent a sa propre API : son fournisseur, '
        'son modèle et sa clé, distincts de ceux du planificateur et de '
        'l’assistant.',
  );
  String get approvalAsk => _t('Ask before doing', 'Demander avant d’agir');
  String get approvalHelp => _t(
    'On: the agent shows what it will do and waits for your tap. Off: it acts '
        'at once. Either way, anything that cannot be undone (erasing the log, '
        'deleting a note, restoring a backup) always waits for your tap.',
    'Activé : l’agent montre ce qu’il va faire et attend votre feu vert. '
        'Désactivé : il agit tout de suite. Dans les deux cas, ce qui ne peut '
        'pas être annulé (effacer le journal, supprimer une note, restaurer '
        'une sauvegarde) attend toujours votre feu vert.',
  );
  String get shareNotes => _t(
    'Let the agent see my notes',
    'Laisser l’agent voir mes notes',
  );
  String get shareNotesHelp => _t(
    'On: the text of your notes (trimmed) goes to the provider so the agent can '
        'answer about them and manage them. Off: it never sees a note and can '
        'only add new ones.',
    'Activé : le texte de vos notes (raccourci) est envoyé au fournisseur pour '
        'que l’agent puisse répondre à leur sujet et les gérer. Désactivé : il '
        'ne voit jamais une note et ne peut qu’en ajouter.',
  );
  // -- what the AI is taught (the routing) ---------------------------------------
  String get routingTitle => _t('What the AI is taught', 'Ce que l’IA apprend');
  String get routingHelp => _t(
    'The agent’s language is cut in parts. A request is sent with only the '
        'parts it needs, so it is small: it fits the free plans, and many more '
        'of them fit in a day.',
    'Le langage de l’agent est découpé en parties. Une demande n’est envoyée '
        'qu’avec les parties dont elle a besoin : elle est petite, passe dans '
        'les offres gratuites, et beaucoup plus tiennent dans une journée.',
  );
  String routingName(AgentRouting routing) => switch (routing) {
    AgentRouting.off => _t('Everything', 'Tout'),
    AgentRouting.local => _t('By words', 'Par mots'),
    AgentRouting.smart => _t('Smart', 'Intelligent'),
  };
  String routingAbout(AgentRouting routing) => switch (routing) {
    AgentRouting.off => _t(
      'Always the whole language: the biggest requests.',
      'Toujours tout le langage : les plus grosses demandes.',
    ),
    AgentRouting.local => _t(
      'Chosen from the words of your request. No extra request.',
      'Choisi d’après les mots de votre demande. Aucune requête en plus.',
    ),
    AgentRouting.smart => _t(
      'Like “By words”; when the words say nothing, a small model sorts the '
          'request (one more, very small, request).',
      'Comme « Par mots » ; quand les mots ne disent rien, un petit modèle '
          'trie la demande (une requête de plus, très petite).',
    ),
  };

  // -- the router card of the settings --------------------------------------------
  String get routerSettingsTitle =>
      _t('Request router', 'Routeur de demandes');
  String get routerDedicatedTitle =>
      _t('Dedicated sorter (optional)', 'Trieur dédié (facultatif)');
  String get routerDedicatedHelp => _t(
    'A free Cloudflare account can sort your requests on a quota of its own, '
        'so your main provider keeps its tokens. Fill both fields. Leave them '
        'empty, or if it fails, the agent’s own provider sorts instead. In the '
        'Cloudflare dashboard, Workers AI → Use REST API shows the account ID '
        'and creates an API token with the Workers AI permission.',
    'Un compte Cloudflare gratuit peut trier vos demandes sur un quota à lui, '
        'et votre fournisseur principal garde ses jetons. Remplissez les deux '
        'champs. Laissés vides, ou en cas d’échec, c’est le fournisseur de '
        'l’agent qui trie. Dans le tableau de bord Cloudflare, Workers AI → '
        'Use REST API donne l’identifiant du compte et crée un jeton d’API '
        'avec la permission Workers AI.',
  );
  String get routerAccountLabel =>
      _t('Cloudflare account ID', 'Identifiant de compte Cloudflare');
  String get routerTokenLabel =>
      _t('Cloudflare API token', 'Jeton d’API Cloudflare');
  String routerStatus(RouterSetup setup) => switch (setup) {
    RouterSetup.none => _t(
      'Not set: the agent’s own provider sorts.',
      'Non configuré : le fournisseur de l’agent trie.',
    ),
    RouterSetup.incomplete => _t(
      'Only one of the two is saved: the agent’s own provider sorts until both are.',
      'Un seul des deux est enregistré : le fournisseur de l’agent trie tant que les deux ne le sont pas.',
    ),
    RouterSetup.ready => _t(
      'Ready: Cloudflare sorts first, the agent’s own provider if it fails.',
      'Prêt : Cloudflare trie d’abord, le fournisseur de l’agent en cas d’échec.',
    ),
  };
  String get routerAccountInvalid => _t(
    'The account ID has only letters and digits.',
    'L’identifiant de compte ne contient que des lettres et des chiffres.',
  );
  String get routerTest => _t('Test', 'Tester');
  String routerTestOk(String modules, int milliseconds) => _t(
    'It works: a sample request was sorted as “$modules” in $milliseconds ms.',
    'Ça marche : une demande d’essai a été triée « $modules » en $milliseconds ms.',
  );
  String get routerTestUnreadable => _t(
    'It answered, but not in a form the app can read. The agent’s own provider sorts instead.',
    'Il a répondu, mais sous une forme que l’application ne lit pas. Le fournisseur de l’agent trie à la place.',
  );
  String routerTestFailed(String why) => _t(
    'It failed: $why The agent’s own provider sorts instead.',
    'Échec : $why Le fournisseur de l’agent trie à la place.',
  );

  /// One line under an answer: what the AI was taught, how that was chosen and
  /// about how many tokens the request had.
  String routeCaption(AgentTurn turn) {
    final how = switch (turn.routedBy) {
      RouteVia.rules => _t('by words', 'par mots'),
      RouteVia.sticky => _t('follow-up', 'suite'),
      RouteVia.triage => _t('small model', 'petit modèle'),
      RouteVia.fallback => _t('default set', 'jeu par défaut'),
      RouteVia.asked => _t('asked by the AI', 'demandé par l’IA'),
      RouteVia.all || null => '',
    };
    final what = turn.routedBy == RouteVia.all
        ? _t('everything', 'tout')
        : turn.modules.isEmpty
        ? _t('core only', 'noyau seul')
        : [for (final m in AgentModules.ordered(turn.modules)) m.id].join(', ');
    final tokens = turn.promptTokens >= 1000
        ? '${(turn.promptTokens / 1000).toStringAsFixed(1)}K'
        : '${turn.promptTokens}';
    return [
      '${_t('Taught', 'Appris')}: $what',
      if (how.isNotEmpty) how,
      '≈ $tokens ${_t('tokens', 'jetons')}',
    ].join(' · ');
  }

  String get keyHelp => _t(
    'The agent’s own key, kept in secure storage on this device, apart from '
        'the other keys.',
    'La clé propre de l’agent, gardée dans le stockage sécurisé de cet '
        'appareil, à part des autres clés.',
  );
  String get needsKey => _t(
    'Add the agent’s API key to use it.',
    'Ajoutez la clé API de l’agent pour l’utiliser.',
  );
  String get privacy => _t(
    'What you type and a summary of your progress (pieces, statuses, the last '
        'week of your log, your settings, and your notes if allowed above) go '
        'to the provider you chose. Your keys and your backup never do. The '
        'agent cannot see or change API keys, its own settings, or where Quran '
        'packs are downloaded from; you do those by hand.',
    'Ce que vous écrivez et un résumé de votre progression (morceaux, statuts, '
        'la dernière semaine du journal, vos réglages, et vos notes si vous '
        'l’autorisez ci-dessus) sont envoyés au fournisseur choisi. Vos clés et '
        'votre sauvegarde ne le sont jamais. L’agent ne peut ni voir ni '
        'changer les clés API, ses propres réglages, ni la source des paquets '
        'du Coran ; vous le faites à la main.',
  );
  String get tryIt => _t('Open the agent', 'Ouvrir l’agent');
}
