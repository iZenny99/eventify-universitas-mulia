import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';
import 'main.dart';

class EventFormScreen extends StatefulWidget {
  final VoidCallback onBack;
  const EventFormScreen({super.key, required this.onBack});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _shortDescCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _posterUrlCtrl = TextEditingController();
  final _maxParticipantsCtrl = TextEditingController();
  final _customCategoryCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoading = false;
  bool _isLoadingCategories = true;

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  Uint8List? _posterBytes;
  String? _posterFileName;
  static const String _storageBucket = 'event_assets';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _slugCtrl.dispose();
    _shortDescCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _posterUrlCtrl.dispose();
    _maxParticipantsCtrl.dispose();
    _customCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await adminClient
          .from('event_categories')
          .select('id, name')
          .eq('is_active', true)
          .order('name');

      if (!mounted) return;
      setState(() {
        _categories = (rows as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _isLoadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<PlatformFile?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  Future<String?> _uploadImage({
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    final slug = _slugCtrl.text.trim().isEmpty
        ? _titleCtrl.text.trim().toLowerCase().replaceAll(' ', '-')
        : _slugCtrl.text.trim();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'events/$slug/$folder-$timestamp-$fileName';

    try {
      await adminClient.storage
          .from(_storageBucket)
          .uploadBinary(path, bytes, fileOptions: const FileOptions());
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('bucket') && message.contains('not found')) {
        throw Exception('Bucket "$_storageBucket" tidak ditemukan di Supabase. Silakan buat bucket storage baru bernama "$_storageBucket" dan set menjadi Public.');
      }
      rethrow;
    }

    return adminClient.storage.from(_storageBucket).getPublicUrl(path);
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _handlePickPoster() async {
    final file = await _pickImage();
    if (file == null || file.bytes == null) return;

    setState(() {
      _posterBytes = file.bytes;
      _posterFileName = file.name;
      _posterUrlCtrl.text = file.name;
    });
  }

  void _clearPoster() {
    setState(() {
      _posterBytes = null;
      _posterFileName = null;
      _posterUrlCtrl.clear();
    });
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null ||
        _endDate == null ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih tanggal dan waktu!')));
      return;
    }

    final customCategory = _customCategoryCtrl.text.trim();
    if ((_selectedCategoryId == null || _selectedCategoryId!.isEmpty) &&
        customCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori atau isi kategori baru.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = adminClient;
      String? categoryId = _selectedCategoryId;
      if (customCategory.isNotEmpty) {
        final existing = _categories.where((item) {
          final name = item['name']?.toString().toLowerCase() ?? '';
          return name == customCategory.toLowerCase();
        }).toList();

        if (existing.isNotEmpty) {
          categoryId = existing.first['id']?.toString();
        } else {
          try {
            final newCat = await supabase
                .from('event_categories')
                .insert({'name': customCategory, 'is_active': true})
                .select('id')
                .single();
            categoryId = newCat['id']?.toString();
          } catch (e) {
            // Jika gagal (kemungkinan duplikat nama yang is_active = false)
            final existingDb = await supabase
                .from('event_categories')
                .select('id')
                .ilike('name', customCategory)
                .maybeSingle();
            
            if (existingDb != null) {
              categoryId = existingDb['id']?.toString();
              // Aktifkan kembali kategori tersebut
              await supabase
                  .from('event_categories')
                  .update({'is_active': true})
                  .eq('id', categoryId!);
            } else {
              rethrow;
            }
          }
        }
      }

      // Auto-create organizer if empty
      var orgRes = await supabase.from('organizations').select().limit(1);
      String? orgId;
      if (orgRes.isEmpty) {
        final newOrg = await supabase.from('organizations').insert({
          'name': 'BEM Universitas',
        }).select();
        orgId = newOrg[0]['id'];
      } else {
        orgId = orgRes[0]['id'];
      }

      // Formatting time to HH:mm:ss for Postgres TIME
      String formatTime(TimeOfDay t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

      String? posterUrl = _posterUrlCtrl.text.trim().isEmpty
          ? null
          : _posterUrlCtrl.text.trim();
      if (_posterBytes != null && _posterFileName != null) {
        posterUrl = await _uploadImage(
          bytes: _posterBytes!,
          fileName: _posterFileName!,
          folder: 'poster',
        );
        if (posterUrl != null) _posterUrlCtrl.text = posterUrl;
      }

      await supabase
          .from('events')
          .insert({
            'title': _titleCtrl.text,
            'slug': _slugCtrl.text.toLowerCase().replaceAll(' ', '-'),
            'short_description': _shortDescCtrl.text,
            'description': _descCtrl.text,
            'location_name': _locationCtrl.text,
            'poster_url': posterUrl,
            'start_date': _startDate!.toIso8601String().split('T')[0],
            'end_date': _endDate!.toIso8601String().split('T')[0],
            'start_time': formatTime(_startTime!),
            'end_time': formatTime(_endTime!),
            'max_participants': _maxParticipantsCtrl.text.isEmpty
                ? null
                : int.tryParse(_maxParticipantsCtrl.text),
            'category_id': categoryId,
            'organizer_id': orgId,
            'status': 'published', // auto publish for now
          })
          .select()
          .single();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event Berhasil Dibuat!')));
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildImagePickerCard({
    required String title,
    required Uint8List? bytes,
    required String? url,
    required String? fileName,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasPreview = bytes != null || (url != null && url.startsWith('http'));
    final preview = bytes != null
        ? Image.memory(bytes, fit: BoxFit.cover, width: double.infinity)
        : (url != null && url.startsWith('http')
              ? Image.network(url, fit: BoxFit.cover, width: double.infinity)
              : null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasPreview
                  ? preview
                  : Center(
                      child: Text(
                        'Belum ada gambar',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            fileName ?? (url?.isNotEmpty == true ? url! : 'Tidak ada file'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Unggah'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: hasPreview ? onClear : null,
                child: const Text('Hapus'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 16),
              const Text(
                'Buat Event Baru',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Judul Event',
                        ),
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                        onChanged: (v) {
                          if (_slugCtrl.text.isEmpty ||
                              _slugCtrl.text ==
                                  v
                                      .substring(
                                        0,
                                        v.length > 1 ? v.length - 1 : 0,
                                      )
                                      .toLowerCase()
                                      .replaceAll(' ', '-')) {
                            _slugCtrl.text = v.toLowerCase().replaceAll(
                              ' ',
                              '-',
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _slugCtrl,
                        decoration: const InputDecoration(
                          labelText: 'URL Slug (contoh: seminar-tech-2026)',
                        ),
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      _isLoadingCategories
                          ? const LinearProgressIndicator(minHeight: 2)
                          : DropdownButtonFormField<String>(
                              key: ValueKey(_selectedCategoryId),
                              initialValue: _selectedCategoryId,
                              items: _categories
                                  .map(
                                    (cat) => DropdownMenuItem<String>(
                                      value: cat['id']?.toString(),
                                      child: Text(
                                        cat['name']?.toString() ?? '-',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _categories.isEmpty
                                  ? null
                                  : (value) => setState(() {
                                      _selectedCategoryId = value;
                                    }),
                              decoration: const InputDecoration(
                                labelText: 'Kategori Event',
                                hintText: 'Pilih kategori yang tersedia',
                              ),
                            ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customCategoryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kategori Baru (Opsional)',
                          hintText: 'Isi jika kategori tidak ada di daftar',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(true),
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                _startDate == null
                                    ? 'Pilih Tgl Mulai'
                                    : _startDate!.toIso8601String().split(
                                        'T',
                                      )[0],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectTime(true),
                              icon: const Icon(Icons.access_time),
                              label: Text(
                                _startTime == null
                                    ? 'Pilih Jam Mulai'
                                    : _startTime!.format(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(false),
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                _endDate == null
                                    ? 'Pilih Tgl Selesai'
                                    : _endDate!.toIso8601String().split('T')[0],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectTime(false),
                              icon: const Icon(Icons.access_time),
                              label: Text(
                                _endTime == null
                                    ? 'Pilih Jam Selesai'
                                    : _endTime!.format(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nama Lokasi (Gedung/Ruangan)',
                        ),
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _shortDescCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi Singkat (Max 150 char)',
                        ),
                        maxLength: 150,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi Lengkap',
                        ),
                        maxLines: 5,
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _maxParticipantsCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'Kuota Peserta (Kosongkan jika tak terbatas)',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Media Event',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _buildImagePickerCard(
                        title: 'Gambar Event',
                        bytes: _posterBytes,
                        url: _posterUrlCtrl.text.trim(),
                        fileName: _posterFileName,
                        onPick: _handlePickPoster,
                        onClear: _clearPoster,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveEvent,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text('SIMPAN EVENT'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
