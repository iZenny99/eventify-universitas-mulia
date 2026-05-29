import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/nim_parser.dart';
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
  final _fakultasController = TextEditingController();
  final _prodiController = TextEditingController();
  final _angkatanController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _nimError;

  @override
  void initState() {
    super.initState();
    _nimController.addListener(_onNimChanged);
  }

  void _onNimChanged() {
    final nim = _nimController.text.trim();
    if (nim.isEmpty) {
      setState(() {
        _nimError = null;
        _fakultasController.clear();
        _prodiController.clear();
        _angkatanController.clear();
        _emailController.clear();
      });
      return;
    }

    final parser = NimParser(nim);
    setState(() {
      if (!parser.isValidLength) {
        _nimError = 'NIM harus 7 digit.';
      } else if (!parser.isNumeric) {
        _nimError = 'NIM harus berupa angka.';
      } else if (!parser.isValidProdi) {
        _nimError = 'Kode prodi pada NIM tidak valid.';
      } else {
        _nimError = null;
      }

      if (parser.isValidLength && parser.isNumeric) {
        _fakultasController.text = parser.fakultas;
        _prodiController.text = parser.programStudi;
        _angkatanController.text = parser.angkatan;
        if (parser.isValidProdi) {
           _emailController.text = parser.emailKampus;
        } else {
           _emailController.clear();
        }
      } else {
        _fakultasController.clear();
        _prodiController.clear();
        _angkatanController.clear();
        _emailController.clear();
      }
    });
  }

  @override
  void dispose() {
    _nimController.removeListener(_onNimChanged);
    _namaController.dispose();
    _nimController.dispose();
    _fakultasController.dispose();
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
    final password = _passwordController.text;

    if (namaLengkap.isEmpty ||
        nim.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon isi nama, NIM, dan password.')),
      );
      return;
    }

    final parser = NimParser(nim);
    if (!parser.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NIM tidak valid. Periksa kembali input Anda.')),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password minimal 8 karakter.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.register(
      email: parser.emailKampus,
      password: password,
      namaLengkap: namaLengkap,
      nim: nim,
      fakultas: parser.fakultas,
      programStudi: parser.programStudi,
      angkatan: int.parse(parser.angkatan),
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
              hint: 'Contoh: 2411000',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              controller: _nimController,
            ),
            if (_nimError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 12),
                child: Text(
                  _nimError!,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),

            // Academic Information Section
            _buildSectionHeader(context, 'Akademik (Otomatis)'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Fakultas',
              hint: '-',
              icon: Icons.apartment_rounded,
              controller: _fakultasController,
              readOnly: true,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Program Studi',
              hint: '-',
              icon: Icons.school_outlined,
              controller: _prodiController,
              readOnly: true,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Angkatan',
              hint: '-',
              icon: Icons.calendar_month_outlined,
              controller: _angkatanController,
              readOnly: true,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Account Information Section
            _buildSectionHeader(context, 'Keamanan Akun'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Email Kampus',
              hint: 'nim@students.universitasmulia.ac.id',
              icon: Icons.alternate_email_rounded,
              controller: _emailController,
              readOnly: true,
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
                Text('Sudah punya akun?', style: textTheme.bodyMedium),
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
