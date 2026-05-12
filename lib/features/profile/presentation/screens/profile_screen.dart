import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/theme_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ThemeController _themeController = ThemeController.instance;
  late final Future<UserProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<UserProfile> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const UserProfile(
        id: '',
        fullName: '-',
        email: '-',
        nim: '-',
        faculty: 'None',
        major: '-',
        academicYear: '-',
      );
    }

    final data = await Supabase.instance.client
        .from('profiles')
        .select(
          'full_name,nim,faculty,major,academic_year,phone_number,avatar_url',
        )
        .eq('id', user.id)
        .single();

    final nama = (data['full_name'] as String?)?.trim();
    final nim = data['nim']?.toString();
    final faculty = data['faculty']?.toString();
    final programStudi = data['major']?.toString();
    final angkatan = data['academic_year']?.toString();
    final phoneNumber = data['phone_number']?.toString();
    final avatarUrl = data['avatar_url']?.toString();

    return UserProfile(
      id: user.id,
      fullName: (nama != null && nama.isNotEmpty) ? nama : '-',
      email: user.email ?? '-',
      nim: (nim != null && nim.isNotEmpty) ? nim : '-',
      faculty: (faculty != null && faculty.isNotEmpty) ? faculty : 'None',
      major: (programStudi != null && programStudi.isNotEmpty)
          ? programStudi
          : '-',
      academicYear: (angkatan != null && angkatan.isNotEmpty) ? angkatan : '-',
      phoneNumber: (phoneNumber != null && phoneNumber.isNotEmpty)
          ? phoneNumber
          : '-',
      avatarUrl: (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<UserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat profil.', style: textTheme.bodyLarge),
            );
          }

          final profile =
              snapshot.data ??
              const UserProfile(
                id: '',
                fullName: '-',
                email: '-',
                nim: '-',
                faculty: 'None',
                major: '-',
                academicYear: '-',
              );

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil Saya',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Profile Header Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.divider,
                          backgroundImage: profile.avatarUrl != null
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          child: profile.avatarUrl == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 40,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName,
                              style: textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile.email,
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                'MAHASISWA AKTIF',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Academic Information Section
                _buildSectionLabel(context, 'Data Akademik'),
                const SizedBox(height: AppSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      _buildProfileItem(
                        context,
                        Icons.badge_outlined,
                        'NIM',
                        profile.nim ?? '-',
                      ),
                      const Divider(indent: 56),
                      _buildProfileItem(
                        context,
                        Icons.apartment_rounded,
                        'Fakultas',
                        profile.faculty ?? 'None',
                      ),
                      const Divider(indent: 56),
                      _buildProfileItem(
                        context,
                        Icons.school_outlined,
                        'Program Studi',
                        profile.major ?? '-',
                      ),
                      const Divider(indent: 56),
                      _buildProfileItem(
                        context,
                        Icons.calendar_today_rounded,
                        'Angkatan',
                        profile.academicYear ?? '-',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                _buildSectionLabel(context, 'Kontak'),
                const SizedBox(height: AppSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      _buildProfileItem(
                        context,
                        Icons.phone_rounded,
                        'No. HP',
                        profile.phoneNumber ?? '-',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Theme Section
                _buildSectionLabel(context, 'Tampilan'),
                const SizedBox(height: AppSpacing.md),
                AnimatedBuilder(
                  animation: _themeController,
                  builder: (context, _) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          RadioGroup<ThemeMode>(
                            groupValue: _themeController.mode,
                            onChanged: (mode) {
                              if (mode != null) {
                                _themeController.setMode(mode);
                              }
                            },
                            child: Column(
                              children: [
                                RadioListTile<ThemeMode>(
                                  value: ThemeMode.light,
                                  activeColor: AppColors.primary,
                                  title: Text(
                                    'Tema Terang',
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  secondary: Icon(
                                    Icons.wb_sunny_rounded,
                                    color: AppColors.accent,
                                  ),
                                ),
                                const Divider(height: 0),
                                RadioListTile<ThemeMode>(
                                  value: ThemeMode.dark,
                                  activeColor: AppColors.primary,
                                  title: Text(
                                    'Tema Gelap',
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  secondary: Icon(
                                    Icons.nightlight_round,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.xl),

                // Admin Section
                _buildSectionLabel(context, 'Pengaturan Admin'),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.attendanceScanner),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.accent,
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Scan Presensi Event',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Klik untuk masuk ke mode admin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Logout Button
                TextButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (_) => false,
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, size: 20),
                      const SizedBox(width: 12),
                      const Text('Keluar dari Akun'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
