import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';
import 'theme.dart';
import 'utils/nim_parser.dart';

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _nimCtrl = TextEditingController();
  final _facultyCtrl = TextEditingController();
  final _majorCtrl = TextEditingController();
  final _academicYearCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  late Stream<List<Map<String, dynamic>>> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = _buildUsersStream();
    _nimCtrl.addListener(_onNimChanged);
  }

  void _onNimChanged() {
    final nim = _nimCtrl.text.trim();
    if (nim.length >= 7) {
      final parser = NimParser(nim);
      if (parser.isValid) {
        _facultyCtrl.text = parser.fakultas;
        _majorCtrl.text = parser.programStudi;
        _academicYearCtrl.text = parser.angkatan;
      }
    }
  }

  @override
  void dispose() {
    _nimCtrl.removeListener(_onNimChanged);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _nimCtrl.dispose();
    _facultyCtrl.dispose();
    _majorCtrl.dispose();
    _academicYearCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _buildUsersStream() async* {
    final stream = adminClient.from('profiles').stream(primaryKey: ['id']).order('created_at', ascending: false);
    
    await for (final profiles in stream) {
      final registrations = await adminClient.from('event_registrations').select('user_id');
      final counts = <String, int>{};
      for (final reg in (registrations as List)) {
        final userId = reg['user_id'] as String?;
        if (userId == null) continue;
        counts[userId] = (counts[userId] ?? 0) + 1;
      }
      
      yield profiles.map((user) {
        final userMap = Map<String, dynamic>.from(user);
        final id = userMap['id'] as String? ?? '';
        return {...userMap, 'registration_count': counts[id] ?? 0};
      }).toList();
    }
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final res = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          emailConfirm: true,
          userMetadata: {'full_name': _nameCtrl.text.trim()},
        ),
      );

      if (res.user != null) {
        await adminClient
            .from('profiles')
            .update({
              'full_name': _nameCtrl.text.trim(),
              'nim': _nimCtrl.text.trim().isEmpty ? null : _nimCtrl.text.trim(),
              'faculty': _facultyCtrl.text.trim().isEmpty
                  ? null
                  : _facultyCtrl.text.trim(),
              'major': _majorCtrl.text.trim().isEmpty
                  ? null
                  : _majorCtrl.text.trim(),
              'academic_year': _academicYearCtrl.text.trim().isEmpty
                  ? null
                  : _academicYearCtrl.text.trim(),
              'phone_number': _phoneCtrl.text.trim().isEmpty
                  ? null
                  : _phoneCtrl.text.trim(),
            })
            .eq('id', res.user!.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengguna berhasil dibuat!')),
      );
      _emailCtrl.clear();
      _passwordCtrl.clear();
      _nameCtrl.clear();
      _nimCtrl.clear();
      _facultyCtrl.clear();
      _majorCtrl.clear();
      _academicYearCtrl.clear();
      _phoneCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleActive(String userId, bool isActive) async {
    await adminClient
        .from('profiles')
        .update({'is_active': !isActive})
        .eq('id', userId);
  }

  Future<void> _deleteUser(String userId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengguna?'),
        content: const Text(
          'Tindakan ini permanen. Seluruh pendaftaran atas nama pengguna ini akan ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Ya, Hapus',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await adminClient.auth.admin.deleteUser(userId);
      await adminClient.from('profiles').delete().eq('id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengguna berhasil dihapus.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      }
    }
  }

  void _showUserDetailDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detail Pengguna'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Nama', user['full_name']),
              _buildDetailRow('Email', user['email']),
              _buildDetailRow('NIM', user['nim']),
              _buildDetailRow('Fakultas', user['faculty']),
              _buildDetailRow('Prodi', user['major']),
              _buildDetailRow('Angkatan', user['academic_year']),
              _buildDetailRow('No. HP', user['phone_number']),
              _buildDetailRow(
                'Status',
                (user['is_active'] == true) ? 'AKTIF' : 'NONAKTIF',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    final text = (value == null || value.toString().isEmpty)
        ? '-'
        : value.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    _nameCtrl.text = user['full_name']?.toString() ?? '';
    _nimCtrl.text = user['nim']?.toString() ?? '';
    _facultyCtrl.text = user['faculty']?.toString() ?? '';
    _majorCtrl.text = user['major']?.toString() ?? '';
    _academicYearCtrl.text = user['academic_year']?.toString() ?? '';
    _phoneCtrl.text = user['phone_number']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profil Pengguna'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nimCtrl,
                decoration: const InputDecoration(labelText: 'NIM'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _facultyCtrl,
                decoration: const InputDecoration(labelText: 'Fakultas'),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _majorCtrl,
                decoration: const InputDecoration(labelText: 'Program Studi'),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _academicYearCtrl,
                decoration: const InputDecoration(labelText: 'Angkatan'),
                keyboardType: TextInputType.number,
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'No. HP'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              try {
                await adminClient
                    .from('profiles')
                    .update({
                      'full_name': _nameCtrl.text.trim(),
                      'nim': _nimCtrl.text.trim().isEmpty
                          ? null
                          : _nimCtrl.text.trim(),
                      'faculty': _facultyCtrl.text.trim().isEmpty
                          ? null
                          : _facultyCtrl.text.trim(),
                      'major': _majorCtrl.text.trim().isEmpty
                          ? null
                          : _majorCtrl.text.trim(),
                      'academic_year': _academicYearCtrl.text.trim().isEmpty
                          ? null
                          : _academicYearCtrl.text.trim(),
                      'phone_number': _phoneCtrl.text.trim().isEmpty
                          ? null
                          : _phoneCtrl.text.trim(),
                    })
                    .eq('id', user['id']);

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profil diperbarui!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Pengguna Baru'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                  validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password (min 6 char)',
                  ),
                  validator: (v) => v!.length < 6 ? 'Minimal 6 karakter' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nimCtrl,
                  decoration: const InputDecoration(
                    labelText: 'NIM (Opsional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _facultyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fakultas (Terisi Otomatis)',
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _majorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Program Studi (Terisi Otomatis)',
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _academicYearCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Angkatan (Terisi Otomatis)',
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'No. HP (Opsional)',
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _createUser();
            },
            child: const Text('Buat Akun'),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manajemen Pengguna',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateUserDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Tambah Pengguna'),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _usersStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = snapshot.data ?? [];
                  if (users.isEmpty) {
                    return const Center(child: Text('Belum ada pengguna.'));
                  }
                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Foto',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Nama',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Email',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'NIM',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Prodi',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Angkatan',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Event',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Status',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Aksi',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: users.map((u) {
                          final isActive = (u['is_active'] as bool?) ?? true;
                          return DataRow(
                            cells: [
                              DataCell(
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: u['avatar_url'] != null
                                      ? NetworkImage(u['avatar_url'])
                                      : null,
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                  child: u['avatar_url'] == null
                                      ? Text(
                                          (u['full_name']?.toString() ?? '?')[0].toUpperCase(),
                                          style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                                        )
                                      : null,
                                ),
                              ),
                              DataCell(Text(u['full_name']?.toString() ?? '-')),
                              DataCell(Text(u['email']?.toString() ?? '-')),
                              DataCell(Text(u['nim']?.toString() ?? '-')),
                              DataCell(Text(u['major']?.toString() ?? '-')),
                              DataCell(
                                Text(u['academic_year']?.toString() ?? '-'),
                              ),
                              DataCell(
                                Text(
                                  u['registration_count']?.toString() ?? '0',
                                ),
                              ),
                              DataCell(Text(isActive ? 'AKTIF' : 'NONAKTIF')),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.visibility,
                                        color: Colors.blueGrey,
                                        size: 20,
                                      ),
                                      tooltip: 'Detail Pengguna',
                                      onPressed: () => _showUserDetailDialog(u),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      tooltip: 'Edit Pengguna',
                                      onPressed: () => _showEditUserDialog(u),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isActive
                                            ? Icons.pause_circle
                                            : Icons.play_circle,
                                        color: isActive
                                            ? Colors.orange
                                            : Colors.green,
                                        size: 20,
                                      ),
                                      tooltip: isActive
                                          ? 'Nonaktifkan'
                                          : 'Aktifkan',
                                      onPressed: () =>
                                          _toggleActive(u['id'], isActive),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      tooltip: 'Hapus Pengguna',
                                      onPressed: () => _deleteUser(u['id']),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
