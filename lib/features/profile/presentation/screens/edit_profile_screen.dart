import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _namaController;
  late final TextEditingController _nimController;
  late final TextEditingController _fakultasController;
  late final TextEditingController _prodiController;
  late final TextEditingController _angkatanController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  bool _isLoading = false;
  String? _avatarUrl;
  Uint8List? _selectedImageBytes;
  String? _selectedImageExt;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.profile.fullName);
    _nimController = TextEditingController(text: widget.profile.nim);
    _fakultasController = TextEditingController(text: widget.profile.faculty);
    _prodiController = TextEditingController(text: widget.profile.major);
    _angkatanController = TextEditingController(text: widget.profile.academicYear);
    _emailController = TextEditingController(text: widget.profile.email);
    _phoneController = TextEditingController(
      text: widget.profile.phoneNumber != '-' ? widget.profile.phoneNumber : '',
    );
    _avatarUrl = widget.profile.avatarUrl;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nimController.dispose();
    _fakultasController.dispose();
    _prodiController.dispose();
    _angkatanController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('08')) {
      cleaned = '+628${cleaned.substring(2)}';
    } else if (cleaned.startsWith('628')) {
      cleaned = '+628${cleaned.substring(3)}';
    }
    return cleaned;
  }

  bool _isValidPhone(String phone) {
    if (phone.isEmpty) return true; // Opsional
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    return cleaned.length >= 10 && cleaned.length <= 15;
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Kompresi
      );

      if (image == null) return;

      final fileBytes = await image.readAsBytes();
      
      // XFile.path on Web is a blob URL without extension. We use mimeType instead.
      final mimeType = image.mimeType ?? 'image/jpeg';
      String fileExt = 'jpg';
      if (mimeType.contains('/')) {
        fileExt = mimeType.split('/').last;
      }
      if (fileExt.length > 5 || fileExt.isEmpty) {
        fileExt = 'jpg';
      }

      setState(() {
        _selectedImageBytes = fileBytes;
        _selectedImageExt = fileExt;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih foto: $e')),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    final phone = _phoneController.text.trim();

    if (phone.isNotEmpty && !_isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor telepon harus 10-15 digit angka.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? finalAvatarUrl = _avatarUrl;

      // 1. Upload foto profil jika ada gambar baru yang dipilih
      if (_selectedImageBytes != null && _selectedImageExt != null) {
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.$_selectedImageExt';
        final filePath = '${widget.profile.id}/$fileName';

        // Determine content type based on extension
        String contentType = 'image/jpeg';
        if (_selectedImageExt == 'png') contentType = 'image/png';
        if (_selectedImageExt == 'gif') contentType = 'image/gif';
        if (_selectedImageExt == 'webp') contentType = 'image/webp';

        await Supabase.instance.client.storage.from('avatars').uploadBinary(
          filePath,
          _selectedImageBytes!,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );

        finalAvatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(filePath);
      }

      // 2. Update database (nomor telepon & avatar_url)
      final normalizedPhone = phone.isEmpty ? null : _normalizePhoneNumber(phone);
      
      await Supabase.instance.client
          .from('profiles')
          .update({
            'phone_number': normalizedPhone,
            'avatar_url': finalAvatarUrl,
          })
          .eq('id', widget.profile.id)
          .select();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedImageBytes != null 
            ? 'Gambar berhasil diupload & Profil diperbarui!' 
            : 'Profil berhasil diperbarui!'),
        ),
      );
      Navigator.pop(context, true); // Return true to refresh profile screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: const Text('Edit Profil'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Identitas akademik dikunci untuk menjaga keaslian data mahasiswa. Anda hanya dapat mengubah Nomor Telepon.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.divider,
                    backgroundImage: _selectedImageBytes != null
                        ? MemoryImage(_selectedImageBytes!)
                        : (_avatarUrl != null
                            ? CachedNetworkImageProvider(_avatarUrl!)
                            : null) as ImageProvider?,
                    child: (_selectedImageBytes == null && _avatarUrl == null)
                        ? Icon(Icons.person, size: 50, color: AppColors.textSecondary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            _buildSectionHeader(context, 'Data Akademik (Terkunci)'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nama Lengkap',
              hint: '-',
              icon: Icons.person_outline_rounded,
              controller: _namaController,
              readOnly: true,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'NIM',
              hint: '-',
              icon: Icons.badge_outlined,
              controller: _nimController,
              readOnly: true,
            ),
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
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Email Kampus',
              hint: '-',
              icon: Icons.alternate_email_rounded,
              controller: _emailController,
              readOnly: true,
            ),
            const SizedBox(height: AppSpacing.xl),

            _buildSectionHeader(context, 'Kontak yang Bisa Dihubungi'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nomor Telepon / WhatsApp',
              hint: 'Contoh: 08123456789',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              controller: _phoneController,
            ),
            const SizedBox(height: AppSpacing.xl),

            PrimaryButton(
              label: _isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
              onPressed: _isLoading ? null : _handleSave,
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
