import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routes/app_routes.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const EventifyApp());
}

class EventifyApp extends StatefulWidget {
  const EventifyApp({super.key});

  @override
  State<EventifyApp> createState() => _EventifyAppState();
}

class _EventifyAppState extends State<EventifyApp> {
  final ThemeController _themeController = ThemeController.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Eventify Universitas Mulia',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _themeController.mode,
          debugShowCheckedModeBanner: false,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.generate,
        );
      },
    );
  }
}
