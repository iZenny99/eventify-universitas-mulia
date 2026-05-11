import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://awupuhimbzppoqoeerei.supabase.co',
    anonKey: 'sb_publishable_hdpNKgQkEEe2XXh4yLNasw_qrg1Vxve',
  );

  runApp(const AdminApp());
}

final adminClient = SupabaseClient(
  'https://awupuhimbzppoqoeerei.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3dXB1aGltYnpwcG9xb2VlcmVpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODQ5NDI3MCwiZXhwIjoyMDk0MDcwMjcwfQ.aXTGZfl88Z6vdLB8hGDxNKiGTGYU1ZX0qiYhPaNroSw',
);

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eventify Admin Dashboard',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final session = snapshot.data?.session;
        if (session != null) {
          return const DashboardScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}
