import 'package:flutter/material.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../screens/forgot_password_screen.dart';
import '../../features/events/domain/event_model.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/attendance/presentation/screens/attendance_scanner_screen.dart';
import '../../features/home/presentation/screens/root_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String root = '/root';
  static const String eventDetail = '/event-detail';
  static const String attendanceScanner = '/attendance-scanner';
  static const String forgotPassword = '/forgot-password';

  static Route<dynamic> generate(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case root:
        return MaterialPageRoute(builder: (_) => const RootScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case attendanceScanner:
        return MaterialPageRoute(
          builder: (_) => const AttendanceScannerScreen(),
        );
      case eventDetail:
        final event = settings.arguments as EventModel?;
        return MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        );
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}
