import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';

/// Builds a [MemoText] for [code] ("en" or "fr") without an app around it.
Future<MemoText> _text(WidgetTester tester, String code) async {
  late MemoText text;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Localizations(
        locale: Locale(code),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            text = MemoText.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return text;
}

void main() {
  for (final code in ['en', 'fr']) {
    group('every number and status is explained ($code)', () {
      testWidgets('each status rule has a plain explanation', (tester) async {
        final text = await _text(tester, code);
        for (final key in StatusRules.keys) {
          final info = text.ruleInfo(key);
          for (final part in [info.what, info.raise, info.lower, info.unit]) {
            expect(part.trim(), isNotEmpty, reason: key);
            expect(part, isNot(contains('null')), reason: key);
            expect(part, isNot(contains(r'$')), reason: key);
          }
          expect(text.ruleLabel(key).trim(), isNotEmpty, reason: key);
          expect(text.ruleGroup(key).trim(), isNotEmpty, reason: key);
        }
      });

      testWidgets('each other number has a title and what raising or lowering does', (tester) async {
        final text = await _text(tester, code);
        for (final key in [
          'attentionDays', 'attentionLimit', 'readMin', 'readMemorise',
          'readIdle', 'readKeep', 'plannerMinutes', 'plannerItems', 'plannerRecent',
        ]) {
          final info = text.settingInfo(key);
          for (final part in [info.title, info.what, info.raise, info.lower]) {
            expect(part.trim(), isNotEmpty, reason: key);
          }
        }
      });

      testWidgets('every status has a story written from the numbers', (tester) async {
        final text = await _text(tester, code);
        for (final status in MemoStatus.values) {
          final story = text.statusStory(status, StatusRules.defaults);
          expect(story.trim(), isNotEmpty);
          expect(story, isNot(contains(r'$')));
          expect(text.status(status).trim(), isNotEmpty);
          expect(text.statusMeaning(status).trim(), isNotEmpty);
        }
        // The story carries the user's own numbers.
        final custom = StatusRules.defaults.withValue('target.1', 11);
        expect(text.statusStory(MemoStatus.learning1, custom), contains('11'));
      });
    });
  }
}
