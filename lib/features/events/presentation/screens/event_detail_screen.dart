import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/event_model.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, this.event});

  final EventModel? event;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _registration;
  int _confirmedCount = 0;
  bool _isLoadingAction = false;

  @override
  void initState() {
    super.initState();
    _loadRegistrationState();
    _loadConfirmedCount();
  }

  Future<void> _loadRegistrationState() async {
    final user = _supabase.auth.currentUser;
    final eventId = widget.event?.id;
    if (user == null || eventId == null) return;

    final data = await _supabase
        .from('event_registrations')
        .select('id, status')
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (!mounted) return;
    setState(() => _registration = data);
  }

  Future<void> _loadConfirmedCount() async {
    final eventId = widget.event?.id;
    if (eventId == null) return;

    final rows = await _supabase
        .from('event_registrations')
        .select('id')
        .eq('event_id', eventId)
        .eq('status', 'confirmed');

    if (!mounted) return;
    setState(() => _confirmedCount = (rows as List).length);
  }

  bool get _isLoggedIn => _supabase.auth.currentUser != null;

  String? get _registrationStatus => _registration?['status'] as String?;

  bool get _isCancelled => _registrationStatus == 'cancelled';

  bool get _isRegistered => _registration != null && !_isCancelled;

  Future<void> _handleRegister(EventModel data) async {
    if (_isLoadingAction) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoadingAction = true);
    try {
      final fields = await _supabase
          .from('event_form_fields')
          .select()
          .eq('event_id', data.id)
          .order('sort_order');

      final answers = await _showRegistrationForm(fields: fields as List);
      if (answers == null) {
        if (mounted) setState(() => _isLoadingAction = false);
        return;
      }

      await _submitRegistration(data, answers);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mendaftar. Silakan coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _submitRegistration(
    EventModel data,
    Map<String, String> answers,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    Map<String, dynamic> registration;
    if (_registration == null) {
      registration = await _supabase
          .from('event_registrations')
          .insert({
            'event_id': data.id,
            'user_id': user.id,
            'status': 'confirmed',
            'confirmed_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
    } else {
      registration = await _supabase
          .from('event_registrations')
          .update({
            'status': 'confirmed',
            'confirmed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _registration!['id'])
          .select()
          .single();
    }

    if (answers.isNotEmpty) {
      final payload = answers.entries
          .map(
            (entry) => {
              'registration_id': registration['id'],
              'field_id': entry.key,
              'answer_text': entry.value,
            },
          )
          .toList();
      await _supabase.from('registration_form_answers').insert(payload);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pendaftaran berhasil dikirim!')),
    );
    final qrValue =
        registration['qr_code']?.toString() ??
        registration['id']?.toString() ??
        '-';
    await _showQrDialog(qrValue, data.title);
    await _loadRegistrationState();
    await _loadConfirmedCount();
  }

  Future<Map<String, String>?> _showRegistrationForm({
    required List fields,
  }) async {
    if (fields.isEmpty) {
      return <String, String>{};
    }

    final controllers = <String, TextEditingController>{};
    final dropdownValues = <String, String?>{};

    for (final field in fields) {
      controllers[field['id'] as String] = TextEditingController();
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Form Pendaftaran'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: fields.map<Widget>((field) {
                    final id = field['id'] as String;
                    final label = field['label']?.toString() ?? 'Field';
                    final type = field['field_type']?.toString() ?? 'text';
                    final isRequired = field['is_required'] == true;

                    if (type == 'dropdown') {
                      final options =
                          (field['options'] as List?)?.cast<dynamic>() ?? [];
                      final items = options
                          .map(
                            (opt) => DropdownMenuItem<String>(
                              value: opt.toString(),
                              child: Text(opt.toString()),
                            ),
                          )
                          .toList();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue: dropdownValues[id],
                          items: items,
                          decoration: InputDecoration(
                            labelText: isRequired ? '$label *' : label,
                          ),
                          onChanged: (value) => setDialogState(() {
                            dropdownValues[id] = value;
                          }),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: controllers[id],
                        decoration: InputDecoration(
                          labelText: isRequired ? '$label *' : label,
                        ),
                        keyboardType: type == 'number'
                            ? TextInputType.number
                            : type == 'email'
                            ? TextInputType.emailAddress
                            : type == 'phone'
                            ? TextInputType.phone
                            : TextInputType.text,
                        maxLines: type == 'textarea' ? 3 : 1,
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final answers = <String, String>{};
                    bool hasError = false;

                    for (final field in fields) {
                      final id = field['id'] as String;
                      final label = field['label']?.toString() ?? 'Field';
                      final type = field['field_type']?.toString() ?? 'text';
                      final isRequired = field['is_required'] == true;
                      final value = type == 'dropdown'
                          ? dropdownValues[id]
                          : controllers[id]?.text.trim();

                      if (isRequired && (value == null || value.isEmpty)) {
                        hasError = true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$label wajib diisi.')),
                        );
                        break;
                      }

                      if (value != null && value.isNotEmpty) {
                        if (type == 'email' && !_isValidEmail(value)) {
                          hasError = true;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Email untuk $label tidak valid.'),
                            ),
                          );
                          break;
                        }

                        if (type == 'number' && !_isValidNumber(value)) {
                          hasError = true;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$label harus berupa angka.'),
                            ),
                          );
                          break;
                        }

                        if (type == 'phone' && !_isValidPhone(value)) {
                          hasError = true;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No HP pada $label tidak valid.'),
                            ),
                          );
                          break;
                        }
                      }

                      if (value != null && value.isNotEmpty) {
                        answers[id] = value;
                      }
                    }

                    if (!hasError) {
                      Navigator.pop(context, answers);
                    }
                  },
                  child: const Text('Kirim'),
                ),
              ],
            );
          },
        );
      },
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }

    return result;
  }

  bool _isValidEmail(String value) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(value);
  }

  bool _isValidNumber(String value) {
    return RegExp(r'^\d+$').hasMatch(value);
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^\d{8,15}$').hasMatch(value);
  }

  Future<void> _showQrDialog(String qrValue, String eventTitle) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tiket Berhasil Dibuat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eventTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    QrImageView(data: qrValue, size: 160),
                    const SizedBox(height: 12),
                    Text(
                      qrValue,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCancel() async {
    if (_isLoadingAction || _registration == null) return;

    setState(() => _isLoadingAction = true);
    try {
      await _supabase
          .from('event_registrations')
          .update({'status': 'cancelled'})
          .eq('id', _registration!['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pendaftaran dibatalkan.')));
      await _loadRegistrationState();
      await _loadConfirmedCount();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal membatalkan.')));
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.event;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Event')),
        body: const Center(child: Text('Event tidak ditemukan.')),
      );
    }
    final textTheme = Theme.of(context).textTheme;
    final maxParticipants = data.maxParticipants;
    final remaining = maxParticipants == null
        ? null
        : (maxParticipants - _confirmedCount).clamp(0, maxParticipants);
    final isFull = remaining != null && remaining <= 0;
    final isPublished = data.status == 'published';

    String buttonLabel;
    VoidCallback? buttonAction;

    if (!_isLoggedIn) {
      buttonLabel = 'Login untuk Daftar';
      buttonAction = null;
    } else if (!isPublished) {
      buttonLabel = 'Event belum dibuka';
      buttonAction = null;
    } else if (isFull) {
      buttonLabel = 'Kuota penuh';
      buttonAction = null;
    } else if (_isRegistered) {
      buttonLabel = 'Batalkan Pendaftaran';
      buttonAction = _handleCancel;
    } else if (_isCancelled) {
      buttonLabel = 'Daftar Lagi';
      buttonAction = () => _handleRegister(data);
    } else {
      buttonLabel = 'Daftar Sekarang';
      buttonAction = () => _handleRegister(data);
    }

    final quotaText = maxParticipants == null
        ? 'Tidak terbatas'
        : '${remaining ?? 0}/$maxParticipants tersisa';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: AppColors.surface,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: AppColors.surface,
              child: IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.share_outlined,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'event_${data.id}',
              child: CachedNetworkImage(
                imageUrl: data.posterUrl ?? 'https://via.placeholder.com/400',
                height: MediaQuery.of(context).size.height * 0.45,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 400,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 400,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 50,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            Container(
              transform: Matrix4.translationValues(0, -30, 0),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          (data.categoryName ?? 'EVENT').toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Text(
                        data.isPaid ? 'Berbayar' : 'Gratis',
                        style: TextStyle(
                          color: data.isPaid
                              ? AppColors.warning
                              : AppColors.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.title,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          context,
                          Icons.calendar_month_rounded,
                          'Tanggal',
                          DateFormatter.formatShort(data.startDate),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoItem(
                          context,
                          Icons.access_time_rounded,
                          'Waktu',
                          '${data.startTime.substring(0, 5)} WIB',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    context,
                    Icons.location_on_rounded,
                    'Lokasi',
                    data.locationName,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    context,
                    Icons.group_rounded,
                    'Kuota',
                    quotaText,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: const Icon(
                          Icons.groups_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diselenggarakan oleh',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            data.organizerName ?? 'Penyelenggara',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Tentang Event',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.description,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: PrimaryButton(
          label: buttonLabel,
          onPressed: _isLoadingAction ? null : buttonAction,
          isLoading: _isLoadingAction,
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
