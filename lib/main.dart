import 'package:flutter/material.dart';

import 'core/routes/app_routes.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_controller.dart';

void main() {
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
