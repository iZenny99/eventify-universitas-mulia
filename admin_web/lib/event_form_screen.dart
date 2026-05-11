import 'package:flutter/material.dart';
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
  
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  
  bool _isLoading = false;

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

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih tanggal dan waktu!')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = adminClient;
      
      // Auto-create category if empty
      var catRes = await supabase.from('event_categories').select().limit(1);
      String? categoryId;
      if (catRes.isEmpty) {
        final newCat = await supabase.from('event_categories').insert({'name': 'Seminar', 'color_hex': '#6C63FF'}).select();
        categoryId = newCat[0]['id'];
      } else {
        categoryId = catRes[0]['id'];
      }

      // Auto-create organizer if empty
      var orgRes = await supabase.from('organizations').select().limit(1);
      String? orgId;
      if (orgRes.isEmpty) {
        final newOrg = await supabase.from('organizations').insert({'name': 'BEM Universitas'}).select();
        orgId = newOrg[0]['id'];
      } else {
        orgId = orgRes[0]['id'];
      }

      // Formatting time to HH:mm:ss for Postgres TIME
      String formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

      await supabase.from('events').insert({
        'title': _titleCtrl.text,
        'slug': _slugCtrl.text.toLowerCase().replaceAll(' ', '-'),
        'short_description': _shortDescCtrl.text,
        'description': _descCtrl.text,
        'location_name': _locationCtrl.text,
        'poster_url': _posterUrlCtrl.text.isEmpty ? null : _posterUrlCtrl.text,
        'start_date': _startDate!.toIso8601String().split('T')[0],
        'end_date': _endDate!.toIso8601String().split('T')[0],
        'start_time': formatTime(_startTime!),
        'end_time': formatTime(_endTime!),
        'max_participants': _maxParticipantsCtrl.text.isEmpty ? null : int.tryParse(_maxParticipantsCtrl.text),
        'category_id': categoryId,
        'organizer_id': orgId,
        'status': 'published', // auto publish for now
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event Berhasil Dibuat!')));
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
              const SizedBox(width: 16),
              const Text('Buat Event Baru', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
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
                        decoration: const InputDecoration(labelText: 'Judul Event'),
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                        onChanged: (v) {
                          if (_slugCtrl.text.isEmpty || _slugCtrl.text == v.substring(0, v.length>1?v.length-1:0).toLowerCase().replaceAll(' ', '-')) {
                            _slugCtrl.text = v.toLowerCase().replaceAll(' ', '-');
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _slugCtrl,
                        decoration: const InputDecoration(labelText: 'URL Slug (contoh: seminar-tech-2026)'),
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(true),
                              icon: const Icon(Icons.calendar_today),
                              label: Text(_startDate == null ? 'Pilih Tgl Mulai' : _startDate!.toIso8601String().split('T')[0]),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectTime(true),
                              icon: const Icon(Icons.access_time),
                              label: Text(_startTime == null ? 'Pilih Jam Mulai' : _startTime!.format(context)),
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
                              label: Text(_endDate == null ? 'Pilih Tgl Selesai' : _endDate!.toIso8601String().split('T')[0]),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectTime(false),
                              icon: const Icon(Icons.access_time),
                              label: Text(_endTime == null ? 'Pilih Jam Selesai' : _endTime!.format(context)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationCtrl,
                        decoration: const InputDecoration(labelText: 'Nama Lokasi (Gedung/Ruangan)'),
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _shortDescCtrl,
                        decoration: const InputDecoration(labelText: 'Deskripsi Singkat (Max 150 char)'),
                        maxLength: 150,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(labelText: 'Deskripsi Lengkap'),
                        maxLines: 5,
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _maxParticipantsCtrl,
                        decoration: const InputDecoration(labelText: 'Kuota Peserta (Kosongkan jika tak terbatas)'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _posterUrlCtrl,
                        decoration: const InputDecoration(labelText: 'URL Poster (Image Link)'),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveEvent,
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
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
