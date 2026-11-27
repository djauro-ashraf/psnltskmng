import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/agent/controller/agent_providers.dart';
import 'package:personaltskmng/agent/data/agent_settings_store.dart';
import 'package:personaltskmng/agent/models/agent_settings.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/router_settings_section.dart';

import '../../support/reader_harness.dart';

/// The Router card of the settings: the way requests are sorted, and the
/// dedicated sorter with its two fields.
///
/// NOT RUN: written without being able to run Flutter.

Widget _app({
  AgentRouting routing = AgentRouting.smart,
  List overrides = const [],
}) => testApp(
  home: const Scaffold(
    body: SingleChildScrollView(child: RouterSettingsSection()),
  ),
  overrides: [
    agentSettingsStoreProvider.overrideWithValue(
      MemoryAgentSettingsStore(
        AgentSettings(enabled: true, routing: routing).encode(),
      ),
    ),
    ...overrides,
  ],
);

ProviderContainer _scope(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(RouterSettingsSection)),
);

void main() {
  testWidgets('shows the three ways of sorting, Smart chosen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    for (final label in ['Everything', 'By words', 'Smart']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    final smart = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Smart'),
    );
    expect(smart.selected, isTrue);
  });

  testWidgets('choosing a way is kept', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('By words'));
    await tester.pumpAndSettle();

    expect(
      _scope(tester).read(agentSettingsProvider).routing,
      AgentRouting.local,
    );
  });

  testWidgets('the dedicated sorter has its own two fields, in Smart only', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Dedicated sorter (optional)'), findsOneWidget);
    expect(find.text('Cloudflare account ID'), findsOneWidget);
    expect(find.text('Cloudflare API token'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.pumpWidget(_app(routing: AgentRouting.local));
    await tester.pumpAndSettle();
    expect(find.text('Dedicated sorter (optional)'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('says plainly what the app does with nothing saved', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      find.text('Not set: the agent’s own provider sorts.'),
      findsOneWidget,
    );
    // Nothing to test or remove yet.
    final test = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Test'),
    );
    expect(test.onPressed, isNull);
  });

  testWidgets('saves the two values apart, and says it is ready', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), ' acc123 ');
    await tester.enterText(find.byType(TextField).at(1), 'secret-token');
    await tester.tap(find.widgetWithText(FilledButton, 'Save key'));
    await tester.pumpAndSettle();

    final keys = _scope(tester).read(agentKeysProvider);
    expect(await keys.read(routerAccountName), 'acc123');
    expect(await keys.read(routerKeyName), 'secret-token');
    expect(
      find.text(
        'Ready: Cloudflare sorts first, the agent’s own provider if it fails.',
      ),
      findsOneWidget,
    );
    // The fields are emptied: the token is not left on the screen.
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller!.text, isEmpty);
    }
  });

  testWidgets('half saved is said, and the sorter is not ready', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'secret-token');
    await tester.tap(find.widgetWithText(FilledButton, 'Save key'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Only one of the two is saved'),
      findsOneWidget,
    );
    final test = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Test'),
    );
    expect(test.onPressed, isNull);
  });

  testWidgets('an account id with more than letters and digits is not saved', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'acc/123');
    await tester.enterText(find.byType(TextField).at(1), 'secret-token');
    await tester.tap(find.widgetWithText(FilledButton, 'Save key'));
    await tester.pumpAndSettle();

    final keys = _scope(tester).read(agentKeysProvider);
    expect(await keys.read(routerAccountName), isNull);
    expect(await keys.read(routerKeyName), isNull);
    expect(
      find.text('The account ID has only letters and digits.'),
      findsOneWidget,
    );
  });

  testWidgets('remove clears both', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final keys = _scope(tester).read(agentKeysProvider);
    await keys.write(routerAccountName, 'acc123');
    await keys.write(routerKeyName, 'secret-token');
    _scope(tester).invalidate(agentRouterSetupProvider);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Remove key'));
    await tester.pumpAndSettle();

    expect(await keys.read(routerAccountName), isNull);
    expect(await keys.read(routerKeyName), isNull);
    expect(
      find.text('Not set: the agent’s own provider sorts.'),
      findsOneWidget,
    );
  });
}
