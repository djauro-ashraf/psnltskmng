import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/app/router.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/features/settings/settings.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';

class PersonalTskMngApp extends ConsumerWidget {
  const PersonalTskMngApp({super.key});

  ThemeMode _toThemeMode(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
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
    // select(): the app root rebuilds only when theme or language change.
    final themeMode = ref.watch(
      settingsViewModelProvider.select((s) => s.themeMode),
    );
    final localeCode = ref.watch(
      settingsViewModelProvider.select((s) => s.localeCode),
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
      routerConfig: router,
    );
  }
}
