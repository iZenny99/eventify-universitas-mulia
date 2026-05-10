import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _namaController = TextEditingController();
  final _nimController = TextEditingController();
  final _prodiController = TextEditingController();
  final _angkatanController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _namaController.dispose();
    _nimController.dispose();
    _prodiController.dispose();
    _angkatanController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_isLoading) return;

    final namaLengkap = _namaController.text.trim();
    final nim = _nimController.text.trim();
    final programStudi = _prodiController.text.trim();
    final angkatanText = _angkatanController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (namaLengkap.isEmpty ||
        nim.isEmpty ||
        programStudi.isEmpty ||
        angkatanText.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon lengkapi semua data.')),
      );
      return;
    }

    final angkatan = int.tryParse(angkatanText);
    if (angkatan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Angkatan harus berupa angka.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.register(
      email: email,
      password: password,
      namaLengkap: namaLengkap,
      nim: nim,
      programStudi: programStudi,
      angkatan: angkatan,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    final message = result['message'] as String? ?? 'Terjadi kesalahan.';
    if (result['success'] == true) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.login,
        arguments: 'Registrasi berhasil. Silahkan login.',
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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
            AppTextField(
              label: 'Nama Lengkap',
              hint: 'Masukkan nama lengkap sesuai KTM',
              icon: Icons.person_outline_rounded,
              controller: _namaController,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'NIM',
              hint: 'Contoh: 2111001',
              icon: Icons.badge_outlined,
              controller: _nimController,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Academic Information Section
            _buildSectionHeader(context, 'Akademik'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Program Studi',
              hint: 'Contoh: Informatika',
              icon: Icons.school_outlined,
              controller: _prodiController,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Angkatan',
              hint: 'Contoh: 2021',
              icon: Icons.calendar_month_outlined,
              keyboardType: TextInputType.number,
              controller: _angkatanController,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Account Information Section
            _buildSectionHeader(context, 'Keamanan Akun'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Email Kampus',
              hint: 'nim@universitasmulia.ac.id',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Password',
              hint: 'Minimal 8 karakter',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              controller: _passwordController,
            ),
            const SizedBox(height: AppSpacing.xl),
            
            PrimaryButton(
              label: _isLoading ? 'Memproses...' : 'Daftar Sekarang',
              onPressed: _isLoading ? null : _handleRegister,
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
