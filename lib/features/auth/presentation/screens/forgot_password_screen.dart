import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();

    // Basic email validation
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan masukkan format email yang valid'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final redirectTo = dotenv.env['SUPABASE_RESET_REDIRECT_URL'];
    final result = await _authService.resetPassword(
      email: email,
      redirectTo: redirectTo != null && redirectTo.isNotEmpty
          ? redirectTo
          : null,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    final success = result['success'] == true;
    final message = result['message'] as String? ?? 'Terjadi kesalahan.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    if (success) {
      Navigator.pushNamed(
        context,
        AppRoutes.verifyResetCode,
        arguments: {'email': email},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.lock_reset_rounded,
                size: 80,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Lupa Password? 🔒',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Masukkan email kampus Anda dan kami akan mengirimkan link untuk mereset password.',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _emailController,
              label: 'Email Kampus',
              hint: 'nim@students.universitasmulia.ac.id',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Kirim Link Reset',
              isLoading: _isLoading,
              onPressed: _handleResetPassword,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Ingat kata sandi?', style: textTheme.bodyMedium),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                  child: const Text('Kembali ke Login'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
