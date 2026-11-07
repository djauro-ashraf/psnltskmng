import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/auto_read_pill.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';

void main() {
  testWidgets('AutoReadPill renders controls and responds to user actions',
      (tester) async {
    final store = MemoryQuranPrefsStore();
    var paceTapped = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quranPrefsStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: AutoReadPill(
                onTapPace: () => paceTapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    // Initial state: 60 WPM, paused
    expect(find.text('60 WPM'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    // Tap play
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();

    // Now showing pause icon
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // Tap plus button (+10 WPM)
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('70 WPM'), findsOneWidget);

    // Tap minus button (-10 WPM)
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pumpAndSettle();
    expect(find.text('60 WPM'), findsOneWidget);

    // Tap pace label
    await tester.tap(find.text('60 WPM'));
    await tester.pumpAndSettle();
    expect(paceTapped, isTrue);
  });
}

