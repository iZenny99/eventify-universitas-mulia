import 'package:flutter/material.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/events/domain/event_model.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/attendance/presentation/screens/attendance_scanner_screen.dart';
import '../../features/home/presentation/screens/root_screen.dart';
import '../../features/home/presentation/screens/search_screen.dart';
import '../../features/home/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/attendance/presentation/screens/my_qr_screen.dart';
import '../../features/attendance/presentation/screens/attendance_dashboard_screen.dart';
import '../../features/auth/presentation/screens/verify_reset_code_screen.dart';
import '../../features/auth/presentation/screens/create_new_password_screen.dart';
import '../../core/models/user_profile.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String root = '/root';
  static const String eventDetail = '/event-detail';
  static const String attendanceScanner = '/attendance-scanner';
  static const String attendanceDashboard = '/attendance-dashboard';
  static const String forgotPassword = '/forgot-password';
  static const String editProfile = '/edit-profile';
  static const String notifications = '/notifications';
  static const String myQr = '/my-qr';
  static const String verifyResetCode = '/verify-reset-code';
  static const String createNewPassword = '/create-new-password';

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
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case myQr:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => MyQrScreen(
            eventName: args['eventName'] as String,
            qrToken: args['qrToken'] as String,
          ),
        );
      case attendanceDashboard:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AttendanceDashboardScreen(
            eventId: args['eventId'] as String,
            eventName: args['eventName'] as String,
          ),
        );
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case verifyResetCode:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => VerifyResetCodeScreen(
            email: args['email'] as String,
          ),
        );
      case createNewPassword:
        return MaterialPageRoute(builder: (_) => const CreateNewPasswordScreen());
      case attendanceScanner:
        return MaterialPageRoute(
          builder: (_) => const AttendanceScannerScreen(),
        );
      case editProfile:
        final profile = settings.arguments as UserProfile;
        return MaterialPageRoute(
          builder: (_) => EditProfileScreen(profile: profile),
        );
      case eventDetail:
        final event = settings.arguments as EventModel?;
        return MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        );
      case '/search':
        return MaterialPageRoute(
          builder: (_) => const SearchScreen(),
        );
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}
