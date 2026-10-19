import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/app/router.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/features/settings/settings.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

class PersonalTskMngApp extends ConsumerWidget {
  const PersonalTskMngApp({super.key});

  ThemeMode _toThemeMode(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }

  TextDirection _toTextDirection(ReadingDirection direction) {
    return switch (direction) {
      ReadingDirection.rightToLeft => TextDirection.rtl,
      ReadingDirection.leftToRight => TextDirection.ltr,
    };
  }

  /// Exact match first, then language-only match, otherwise English.
  Locale _resolveLocale(Locale? deviceLocale, Iterable<Locale> supported) {
    if (deviceLocale != null) {
      for (final locale in supported) {
        if (locale.languageCode == deviceLocale.languageCode &&
            locale.countryCode == deviceLocale.countryCode) {
          return locale;
        }
      }
      for (final locale in supported) {
        if (locale.languageCode == deviceLocale.languageCode) return locale;
      }
    }
    return const Locale('en');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // select(): the app root rebuilds only when theme, language or reading
    // direction change.
    final themeMode = ref.watch(
      settingsViewModelProvider.select((s) => s.themeMode),
    );
    final localeCode = ref.watch(
      settingsViewModelProvider.select((s) => s.localeCode),
    );
    final readingDirection = ref.watch(
      settingsViewModelProvider.select((s) => s.readingDirection),
    );
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _toThemeMode(themeMode),
      locale: localeCode == null ? null : Locale(localeCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: _resolveLocale,
      // Above the navigator, so pages, dialogs and sheets all see it.
      builder: (context, child) => TextFlow(
        direction: _toTextDirection(readingDirection),
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: router,
    );
  }
}
