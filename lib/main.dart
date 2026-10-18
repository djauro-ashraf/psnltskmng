import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/app/app.dart';
import 'package:personaltskmng/app/dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await buildOverrides();

  runApp(
    ProviderScope(
      overrides: overrides,
      retry: (retryCount, error) => null,
      child: const PersonalTskMngApp(),
    ),
  );
}
