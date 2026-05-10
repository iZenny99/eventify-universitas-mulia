import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: const Text('Buat Akun'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ayo Bergabung! 🚀',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lengkapi data dirimu untuk mulai mengikuti berbagai event kampus.',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            
            // Personal Information Section
            _buildSectionHeader(context, 'Informasi Pribadi'),
            const SizedBox(height: AppSpacing.md),
            const AppTextField(
              label: 'Nama Lengkap',
              hint: 'Masukkan nama lengkap sesuai KTM',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            const AppTextField(
              label: 'NIM',
              hint: 'Contoh: 2111001',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Academic Information Section
            _buildSectionHeader(context, 'Akademik'),
            const SizedBox(height: AppSpacing.md),
            const AppTextField(
              label: 'Program Studi',
              hint: 'Contoh: Informatika',
              icon: Icons.school_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            const AppTextField(
              label: 'Angkatan',
              hint: 'Contoh: 2021',
              icon: Icons.calendar_month_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Account Information Section
            _buildSectionHeader(context, 'Keamanan Akun'),
            const SizedBox(height: AppSpacing.md),
            const AppTextField(
              label: 'Email Kampus',
              hint: 'nim@universitasmulia.ac.id',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            const AppTextField(
              label: 'Password',
              hint: 'Minimal 8 karakter',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            
            PrimaryButton(
              label: 'Daftar Sekarang',
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRoutes.root);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Sudah punya akun?',
                  style: textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Login di sini'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
        ),
      ],
    );
  }
}
