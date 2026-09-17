import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/features/training/data/training_progress.dart';
import 'src/features/training/presentation/training_screen.dart';

/// Standalone local preview: no account, network client, or production bootstrap.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(TrainingPreviewApp(preferences: preferences));
}

class TrainingPreviewApp extends StatelessWidget {
  final SharedPreferences preferences;

  const TrainingPreviewApp({super.key, required this.preferences});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale(
      String.fromEnvironment('TRAINING_LOCALE', defaultValue: 'ru'),
    ),
    supportedLocales: const [Locale('ru'), Locale('zh')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B7280)),
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      fontFamily: 'Gilroy',
      useMaterial3: true,
    ),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: TrainingScreen(
              store: TrainingProgressStore(
                preferences,
                accountKey: 'local-preview',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
