import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../data/comment_repository.dart';
import '../../data/mention_service.dart';
import '../../domain/event_comment.dart';
import '../../domain/event_model.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, this.event});

  final EventModel? event;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CommentRepository _commentRepository = CommentRepository();
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? _registration;
  int _confirmedCount = 0;
  bool _isLoadingAction = false;
  bool _isLoadingComments = false;
  bool _isSubmittingComment = false;

  // Mentions
  final _mentionService = MentionService();
  List<MentionUser> _mentionSuggestions = [];
  bool _isMentioning = false;
  String _mentionQuery = '';
  Timer? _debounceTimer;
  final List<String> _mentionedUserIds = [];

  List<EventComment> _comments = [];
  EventComment? _editingComment;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onCommentChanged);
    _loadRegistrationState();
    _loadConfirmedCount();
    _loadComments();
    _loadCommentAccess();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    final text = _commentController.text;
    final cursorPosition = _commentController.selection.baseOffset;
    if (cursorPosition == -1) return;

    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastAtSymbol = textBeforeCursor.lastIndexOf('@');

    if (lastAtSymbol != -1) {
      final textAfterAt = textBeforeCursor.substring(lastAtSymbol + 1);
      if (!textAfterAt.contains(' ')) {
        setState(() {
          _isMentioning = true;
          _mentionQuery = textAfterAt;
        });
        _searchMentions(_mentionQuery);
        return;
      }
    }

    if (_isMentioning) {
      setState(() {
        _isMentioning = false;
        _mentionSuggestions.clear();
      });
    }
  }

  void _searchMentions(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _mentionService.searchUsers(query);
      if (mounted) {
        setState(() {
          _mentionSuggestions = results;
        });
      }
    });
  }

  void _selectMention(MentionUser user) {
    final text = _commentController.text;
    final cursorPosition = _commentController.selection.baseOffset;

    final textBeforeCursor = text.substring(0, cursorPosition);
    final textAfterCursor = text.substring(cursorPosition);

    final lastAtSymbol = textBeforeCursor.lastIndexOf('@');
    final textBeforeAt = textBeforeCursor.substring(0, lastAtSymbol);

    final replacement = '@${user.name} ';
    _commentController.text = textBeforeAt + replacement + textAfterCursor;
    _commentController.selection = TextSelection.collapsed(
      offset: textBeforeAt.length + replacement.length,
    );

    if (!_mentionedUserIds.contains(user.id)) {
      _mentionedUserIds.add(user.id);
    }

    setState(() {
      _isMentioning = false;
      _mentionSuggestions.clear();
    });
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

  Future<void> _loadComments() async {
    final eventId = widget.event?.id;
    if (eventId == null) return;

    if (mounted) setState(() => _isLoadingComments = true);
    try {
      final comments = await _commentRepository.getCommentsByEvent(eventId);
      if (!mounted) return;
      setState(() => _comments = comments);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal memuat komentar.')));
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _loadCommentAccess() async {
    final eventId = widget.event?.id;
    if (eventId == null) return;

    if (mounted) setState(() {});
  }

  bool get _isLoggedIn => _supabase.auth.currentUser != null;

  String? get _registrationStatus => _registration?['status'] as String?;

  bool get _isCancelled => _registrationStatus == 'cancelled';

  bool get _isRegistered => _registration != null && !_isCancelled;

  bool get _hasUserCommented {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    return _comments.any(
      (comment) => comment.userId == userId && !comment.isDeleted,
    );
  }

  String? get _commentAccessMessage {
    if (!_isLoggedIn) {
      return 'Login untuk memberikan komentar.';
    }

    if (!_isRegistered) {
      return 'Anda harus terdaftar dulu untuk memberikan komentar.';
    }

    if (_editingComment == null && _hasUserCommented) {
      return 'Anda sudah memberikan komentar untuk event ini. Satu akun hanya dapat komentar sekali.';
    }

    return null;
  }

  Future<void> _handleRegister(EventModel data) async {
    if (_isLoadingAction) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Beri jeda sedikit agar event tap/click benar-benar selesai diproses oleh Flutter
    // Ini adalah 'workaround' untuk bug mouse_tracker di beberapa versi Flutter
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    setState(() => _isLoadingAction = true);
    List fields = [];
    try {
      final response = await _supabase
          .from('event_form_fields')
          .select()
          .eq('event_id', data.id)
          .order('sort_order');
      fields = response as List;
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil form pendaftaran.')),
      );
      return;
    }

    if (!mounted) return;

    Map<String, String>? answers;
    if (fields.isEmpty || _registration != null) {
      answers = {};
    } else {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _isLoadingAction = false);

      answers = await _showRegistrationForm(fields: fields);
      if (answers == null) return;

      if (!mounted) return;
      setState(() => _isLoadingAction = true);
    }

    try {
      await _submitRegistration(data, answers);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal: ${e.message}')));
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

    final qrCode = const Uuid().v4();
    Map<String, dynamic> registration;
    if (_registration == null) {
      registration = await _supabase
          .from('event_registrations')
          .insert({
            'event_id': data.id,
            'user_id': user.id,
            'status': 'confirmed',
            'qr_code': qrCode,
          })
          .select()
          .single();
    } else {
      registration = await _supabase
          .from('event_registrations')
          .update({'status': 'confirmed', 'qr_code': qrCode})
          .eq('id', _registration!['id'])
          .select()
          .single();
    }

    if (answers.isNotEmpty) {
      await _supabase
          .from('registration_form_answers')
          .delete()
          .eq('registration_id', registration['id']);

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

    final qrValue =
        registration['qr_code']?.toString() ??
        registration['id']?.toString() ??
        '-';

    final isFirstRegistration = _registration == null;

    if (mounted) {
      setState(() => _isLoadingAction = false);
    }

    // Load ulang status layar
    await _loadRegistrationState();
    await _loadConfirmedCount();
    await _loadCommentAccess();

    if (isFirstRegistration) {
      // Show QR in next frame to prevent freeze on first registration
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showQrDialog(qrValue, data.title);
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Berhasil mendaftar kembali! Tiket dapat dilihat di profil Anda.',
            ),
          ),
        );
      }
    }
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
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 560,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Form Pendaftaran',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: fields.map<Widget>((field) {
                              final id = field['id'] as String;
                              final label =
                                  field['label']?.toString() ?? 'Field';
                              final type =
                                  field['field_type']?.toString() ?? 'text';
                              final isRequired = field['is_required'] == true;

                              if (type == 'dropdown') {
                                final options =
                                    (field['options'] as List?)
                                        ?.cast<dynamic>() ??
                                    [];
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
                                      labelText: isRequired
                                          ? '$label *'
                                          : label,
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
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () {
                                final answers = <String, String>{};
                                bool hasError = false;

                                for (final field in fields) {
                                  final id = field['id'] as String;
                                  final label =
                                      field['label']?.toString() ?? 'Field';
                                  final type =
                                      field['field_type']?.toString() ?? 'text';
                                  final isRequired =
                                      field['is_required'] == true;
                                  final value = type == 'dropdown'
                                      ? dropdownValues[id]
                                      : controllers[id]?.text.trim();

                                  if (isRequired &&
                                      (value == null || value.isEmpty)) {
                                    hasError = true;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$label wajib diisi.'),
                                      ),
                                    );
                                    break;
                                  }

                                  if (value != null && value.isNotEmpty) {
                                    if (type == 'email' &&
                                        !_isValidEmail(value)) {
                                      hasError = true;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Email untuk $label tidak valid.',
                                          ),
                                        ),
                                      );
                                      break;
                                    }

                                    if (type == 'number' &&
                                        !_isValidNumber(value)) {
                                      hasError = true;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '$label harus berupa angka.',
                                          ),
                                        ),
                                      );
                                      break;
                                    }

                                    if (type == 'phone' &&
                                        !_isValidPhone(value)) {
                                      hasError = true;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'No HP pada $label tidak valid.',
                                          ),
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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

    // Tampilkan popup konfirmasi
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Batalkan Pendaftaran?'),
          content: const Text(
            'Apakah kamu yakin ingin membatalkan pendaftaran event ini? Tiket QR kamu akan dihapus.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tidak'),
            ),
            SizedBox(
              width: 140,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Ya, Batalkan',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoadingAction = true);
    try {
      // Tambahkan .select().single() agar jika terblokir RLS / gagal, langsung melempar error
      await _supabase
          .from('event_registrations')
          .update({'status': 'cancelled'})
          .eq('id', _registration!['id'])
          .select()
          .single();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pendaftaran dibatalkan.')));
      await _loadRegistrationState();
      await _loadConfirmedCount();
      await _loadCommentAccess();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: ${e.message} (Cek RLS Database)')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal membatalkan.')));
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _handleSubmitComment() async {
    if (_isSubmittingComment) return;

    final user = _supabase.auth.currentUser;
    final eventId = widget.event?.id;
    if (user == null || eventId == null) return;

    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Komentar tidak boleh kosong.')),
      );
      return;
    }

    if (_editingComment == null && !_isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus terdaftar dulu untuk memberikan komentar.'),
        ),
      );
      return;
    }

    if (_editingComment == null && _hasUserCommented) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda sudah memberikan komentar untuk event ini.'),
        ),
      );
      return;
    }

    setState(() => _isSubmittingComment = true);
    try {
      if (_editingComment != null) {
        await _commentRepository.updateComment(
          commentId: _editingComment!.id,
          userId: user.id,
          commentText: text,
          eventId: eventId,
          mentionedUserIds: _mentionedUserIds,
        );
      } else {
        await _commentRepository.addComment(
          eventId: eventId,
          userId: user.id,
          commentText: text,
          mentionedUserIds: _mentionedUserIds,
        );
      }
      _commentController.clear();
      _mentionedUserIds.clear();
      _editingComment = null;
      await _loadComments();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final lower = e.message.toLowerCase();
      if (lower.contains('row level security') ||
          lower.contains('violates row-level security') ||
          lower.contains('new row violates row level security')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _commentAccessMessage ?? 'Anda belum diizinkan memberi komentar.',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal: ${e.message}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal mengirim komentar.')));
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _handleDeleteComment(EventComment comment) async {
    if (_isSubmittingComment) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus komentar?'),
          content: const Text('Komentar akan disembunyikan dari publik.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isSubmittingComment = true);
    try {
      await _commentRepository.deleteComment(
        commentId: comment.id,
        userId: user.id,
      );
      await _loadComments();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal: ${e.message}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus komentar.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
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

    final currentUser = _supabase.auth.currentUser;
    final isAdmin = currentUser != null && data.organizerId == currentUser.id;

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
                onPressed: () {
                  // ignore: deprecated_member_use
                  Share.share(
                    '🎓 Ikuti ${data.categoryName ?? "Event"}: ${data.title}\n📍 ${data.locationName}\n📅 ${DateFormatter.formatShort(data.startDate)}\n\n${data.shortDescription ?? ""}\n\nDaftar sekarang:\nhttps://eventify.app/event/${data.id}',
                    subject: 'Event Eventify: ${data.title}',
                  );
                },
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
            CachedNetworkImage(
              imageUrl: data.posterUrl ?? 'https://via.placeholder.com/400',
              height: MediaQuery.of(context).size.height * 0.45,
              width: double.infinity,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 250),
              fadeOutDuration: const Duration(milliseconds: 100),
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
                  const SizedBox(height: 32),
                  _buildCommentsSection(context: context, textTheme: textTheme),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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
          child: isAdmin
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.attendanceDashboard,
                            arguments: {
                              'eventId': data.id,
                              'eventName': data.title,
                            },
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Dashboard',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: PrimaryButton(
                        label: 'Scan QR',
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.attendanceScanner,
                          );
                        },
                      ),
                    ),
                  ],
                )
              : _isRegistered
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoadingAction ? null : _handleCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: 'Tampilkan QR',
                        onPressed: _isLoadingAction
                            ? null
                            : () {
                                final qrToken =
                                    _registration?['qr_code'] as String? ??
                                    _registration?['id'] as String?;
                                if (qrToken == null || qrToken.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Data pendaftaran tidak valid.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.myQr,
                                  arguments: {
                                    'eventName': data.title,
                                    'qrToken': qrToken,
                                  },
                                );
                              },
                        isLoading: _isLoadingAction,
                      ),
                    ),
                  ],
                )
              : PrimaryButton(
                  label: buttonLabel,
                  onPressed: _isLoadingAction ? null : buttonAction,
                  isLoading: _isLoadingAction,
                ),
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

  Widget _buildCommentsSection({
    required BuildContext context,
    required TextTheme textTheme,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    final accessMessage = _commentAccessMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Komentar',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_isLoadingComments)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Belum ada komentar.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final comment = _comments[index];
              final isOwn = userId != null && comment.userId == userId;
              return _buildCommentItem(comment, isOwn: isOwn);
            },
          ),
        const SizedBox(height: 16),
        if (accessMessage != null && _editingComment == null)
          _buildCommentHint(accessMessage)
        else
          _buildCommentForm(),
      ],
    );
  }

  Widget _buildCommentItem(EventComment comment, {required bool isOwn}) {
    final name = comment.userFullName ?? 'Pengguna';
    final avatarUrl = comment.userAvatarUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: avatarUrl == null
                    ? null
                    : NetworkImage(avatarUrl),
                child: avatarUrl == null
                    ? Text(
                        _buildInitials(name),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatter.formatShort(comment.createdAt),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (comment.rating != null)
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${comment.rating}/5',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCommentText(comment.commentText),
          if (isOwn) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmittingComment
                      ? null
                      : () {
                          setState(() {
                            _editingComment = comment;
                            _commentController.text = comment.commentText;
                          });
                        },
                  child: Text(
                    'Edit',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
                TextButton(
                  onPressed: _isSubmittingComment
                      ? null
                      : () => _handleDeleteComment(comment),
                  child: Text(
                    'Hapus',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentText(String text) {
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    final Iterable<Match> matches = mentionRegex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(color: AppColors.textPrimary, height: 1.5),
      );
    }

    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: AppColors.textPrimary,
          height: 1.5,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildCommentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isMentioning && _mentionSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _mentionSuggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = _mentionSuggestions[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  title: Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${user.nim} • ${user.major}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => _selectMention(user),
                );
              },
            ),
          ),
        TextField(
          controller: _commentController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Tulis komentar kamu...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_editingComment != null)
              TextButton(
                onPressed: _isSubmittingComment
                    ? null
                    : () {
                        setState(() {
                          _editingComment = null;
                          _commentController.clear();
                        });
                      },
                child: const Text('Batal'),
              ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _isSubmittingComment ? null : _handleSubmitComment,
                child: _isSubmittingComment
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Text(_editingComment != null ? 'Perbarui' : 'Kirim'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentHint(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(message, style: TextStyle(color: AppColors.textSecondary)),
    );
  }

  String _buildInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '-';

    final parts = trimmed.split(' ');
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}
