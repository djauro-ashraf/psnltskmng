import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/agent/models/agent_catalog.dart';
import 'package:personaltskmng/ask/controller/ask_providers.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/ai_setup_view_model.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';
import 'package:personaltskmng/quran_data/controller/auto_read_provider.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/tafsir_providers.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

// The bridge between the agent's catalog and the app: reads every setting of
// AgentCatalog and writes one, always through the notifier the settings screens
// use, so the agent can never do to a setting what the user could not. (It never
// touches a key: the catalog has none.)

/// The current value of every setting under the names of [AgentCatalog]; the
/// status rules appear as `rules`: only the numbers that differ from the
/// original.
Map<String, Object?> readAgentSettings(Ref ref) {
  final app = ref.read(settingsViewModelProvider);
  final memo = ref.read(memoProvider);
  final ask = ref.read(askSettingsProvider);
  final s = memo.settings;
  final p = memo.planner;
  final wishes = p.text.length > 300 ? '${p.text.substring(0, 297)}…' : p.text;
  final copy = ref.read(aiCopyInstructionProvider);
  return {
    'theme': app.themeMode.name,
    'language': app.localeCode ?? 'system',
    'readingDirection': app.readingDirection == ReadingDirection.rightToLeft
        ? 'rtl'
        : 'ltr',
    'backupFrequency': app.backupFrequency,
    'keepSensible': s.sensible,
    'attentionDays': s.attentionDays,
    'attentionLimit': s.attentionLimit,
    'defaultPartition': s.partitionId,
    // The preset the status rules are exactly, else the user's own.
    'rulesPreset': s.rules.preset?.name ?? 'custom',
    'rules': {
      for (final key in StatusRules.keys)
        if (s.rules.value(key) != StatusRules.defaults.value(key))
          key: s.rules.value(key),
    },
    'trackReading': s.trackReading,
    'readMinSeconds': s.readMinSeconds,
    'readMemoriseSeconds': s.readMemoriseSeconds,
    'readIdleSeconds': s.readIdleSeconds,
    'readKeepDays': s.readKeepDays,
    'plannerMinutes': p.minutes,
    'plannerMaxItems': p.maxItems,
    'plannerRecentDays': p.recentDays,
    'plannerUseDefault': p.useDefault,
    'plannerWishes': wishes,
    'plannerAi': app.aiEnabled,
    'plannerProvider': app.aiProvider,
    'plannerModel': app.aiModels[app.aiProvider] ?? '',
    'askEnabled': ask.enabled,
    'askProvider': ask.provider,
    'askModel': ask.models[ask.provider] ?? '',
    'askAnswerLanguage': ask.answerLanguage,
    'askAnswerLength': ask.answerLength,
    'readerView': ref.read(quranViewProvider).name,
    'textSize': ref.read(textSizeProvider),
    'keepAwake': ref.read(keepAwakeProvider),
    'rukuTicks': ref.read(rukuTicksProvider),
    'wordsUnit': ref.read(wordsUnitProvider).name,
    'autoReadSpeed': ref.read(autoReadProvider).wordsPerMinute.round(),
    'translation': ref.read(translationChoiceProvider) ?? 'auto',
    'tafsirSource': ref.read(tafsirSourceProvider) ?? 'auto',
    'aiCopyInstruction': copy.length > 200 ? '${copy.substring(0, 197)}…' : copy,
  };
}

/// Applies [value] (already checked by [AgentSettingSpec.normalise]) to the
/// setting [spec]. True when it was saved; false when the app could not use it
/// (an id that does not exist, a number the rules refuse, a storage error).
Future<bool> writeAgentSetting(
  Ref ref,
  AgentSettingSpec spec,
  Object value,
) async {
  final memo = ref.read(memoProvider.notifier);
  final current = ref.read(memoProvider);
  final app = ref.read(settingsViewModelProvider);
  final settings = ref.read(settingsViewModelProvider.notifier);

  // One number of the status rules: the app moves the rest of its ladder just
  // enough to keep the rules usable, exactly as the rules screen does.
  final ruleKey = AgentCatalog.ruleKey(spec.id);
  if (ruleKey != null) {
    await memo.setSettings(
      current.settings.copyWith(
        rules: current.settings.rules.adjusted(ruleKey, value as int),
      ),
    );
    return true;
  }

  switch (spec.id) {
    // -- appearance and language ---------------------------------------------------
    case 'theme':
      return await settings.setThemeMode(switch (value) {
            'light' => AppThemeMode.light,
            'dark' => AppThemeMode.dark,
            _ => AppThemeMode.system,
          }) ==
          null;
    case 'language':
      return await settings.setLocaleCode(
            value == 'system' ? null : value as String,
          ) ==
          null;
    case 'readingDirection':
      return await settings.setReadingDirection(
            value == 'ltr'
                ? ReadingDirection.leftToRight
                : ReadingDirection.rightToLeft,
          ) ==
          null;
    case 'backupFrequency':
      return await settings.setBackupFrequency(value as String) == null;
    // -- memorisation --------------------------------------------------------------
    case 'keepSensible':
      await memo.setSettings(current.settings.copyWith(sensible: value as bool));
      return true;
    case 'attentionDays':
      await memo.setSettings(
        current.settings.copyWith(attentionDays: value as int),
      );
      return true;
    case 'attentionLimit':
      await memo.setSettings(
        current.settings.copyWith(attentionLimit: value as int),
      );
      return true;
    case 'defaultPartition':
      if (!current.partitions.any((p) => p.id == value)) return false;
      await memo.setSettings(
        current.settings.copyWith(partitionId: value as String),
      );
      return true;
    case 'rulesPreset':
      await memo.setSettings(
        current.settings.copyWith(
          rules: StatusRules.ofPreset(switch (value) {
            'relaxed' => RulesPreset.relaxed,
            'strict' => RulesPreset.strict,
            _ => RulesPreset.original,
          }),
        ),
      );
      return true;
    case 'trackReading':
      await memo.setSettings(
        current.settings.copyWith(trackReading: value as bool),
      );
      return true;
    case 'readMinSeconds':
      await memo.setSettings(
        current.settings.copyWith(readMinSeconds: value as int),
      );
      return true;
    case 'readMemoriseSeconds':
      await memo.setSettings(
        current.settings.copyWith(readMemoriseSeconds: value as int),
      );
      return true;
    case 'readIdleSeconds':
      await memo.setSettings(
        current.settings.copyWith(readIdleSeconds: value as int),
      );
      return true;
    case 'readKeepDays':
      await memo.setSettings(
        current.settings.copyWith(readKeepDays: value as int),
      );
      return true;
    // -- the planner ---------------------------------------------------------------
    case 'plannerMinutes':
      await memo.setPlanner(current.planner.copyWith(minutes: value as int));
      return true;
    case 'plannerMaxItems':
      await memo.setPlanner(current.planner.copyWith(maxItems: value as int));
      return true;
    case 'plannerRecentDays':
      await memo.setPlanner(current.planner.copyWith(recentDays: value as int));
      return true;
    case 'plannerUseDefault':
      await memo.setPlanner(
        current.planner.copyWith(useDefault: value as bool),
      );
      return true;
    case 'plannerWishes':
      await memo.setPlanner(current.planner.copyWith(text: value as String));
      return true;
    // (The planner's setup is read only here: it needs the AI runtime.)
    case 'plannerAi':
      return ref.read(aiSetupViewModelProvider.notifier).setEnabled(value as bool);
    case 'plannerProvider':
      return ref
          .read(aiSetupViewModelProvider.notifier)
          .setProvider(value as String);
    case 'plannerModel':
      return ref
          .read(aiSetupViewModelProvider.notifier)
          .setModel(app.aiProvider, value as String);
    // -- the assistant -------------------------------------------------------------
    case 'askEnabled':
      ref.read(askSettingsProvider.notifier).setEnabled(value as bool);
      return true;
    case 'askProvider':
      ref.read(askSettingsProvider.notifier).setProvider(value as String);
      return true;
    case 'askModel':
      ref
          .read(askSettingsProvider.notifier)
          .setModel(ref.read(askSettingsProvider).provider, value as String);
      return true;
    case 'askAnswerLanguage':
      ref.read(askSettingsProvider.notifier).setLanguage(value as String);
      return true;
    case 'askAnswerLength':
      ref.read(askSettingsProvider.notifier).setLength(value as String);
      return true;
    // -- the reader ----------------------------------------------------------------
    case 'readerView':
      await ref
          .read(quranViewProvider.notifier)
          .set(QuranView.values.asNameMap()[value]!);
      return true;
    case 'textSize':
      await ref.read(textSizeProvider.notifier).set(value as int);
      return true;
    case 'keepAwake':
      await ref.read(keepAwakeProvider.notifier).set(value as bool);
      return true;
    case 'rukuTicks':
      await ref.read(rukuTicksProvider.notifier).set(value as bool);
      return true;
    case 'wordsUnit':
      await ref
          .read(wordsUnitProvider.notifier)
          .set(WordsUnit.values.asNameMap()[value]!);
      return true;
    case 'autoReadSpeed':
      ref
          .read(autoReadProvider.notifier)
          .setWordsPerMinute((value as int).toDouble());
      return true;
    case 'translation':
      {
        final id = value as String;
        if (id != quranTranslationOff) {
          final installed = await ref.read(installedTranslationsProvider.future);
          if (!installed.any((p) => p.id == id)) return false;
        }
        await ref.read(translationChoiceProvider.notifier).set(id);
        return true;
      }
    case 'tafsirSource':
      {
        final id = value as String;
        final sources = await ref.read(tafsirSourcesProvider.future);
        if (!sources.any((t) => t.id == id)) return false;
        await ref.read(tafsirSourceProvider.notifier).set(id);
        return true;
      }
    case 'aiCopyInstruction':
      await ref.read(aiCopyInstructionProvider.notifier).set(value as String);
      return true;
    default:
      return false;
  }
}
