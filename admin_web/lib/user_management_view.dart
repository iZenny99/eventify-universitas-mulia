import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';
import 'theme.dart';

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

  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final profiles = await adminClient
        .from('profiles')
        .select('id, full_name, email, nim, is_active, created_at');
    final registrations = await adminClient
        .from('event_registrations')
        .select('user_id');

    final counts = <String, int>{};
    for (final reg in (registrations as List)) {
      final userId = reg['user_id'] as String?;
      if (userId == null) continue;
      counts[userId] = (counts[userId] ?? 0) + 1;
    }

    return (profiles as List).map((user) {
      final userMap = Map<String, dynamic>.from(user as Map);
      final id = userMap['id'] as String? ?? '';
      return {...userMap, 'registration_count': counts[id] ?? 0};
    }).toList();
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

      if (res.user != null && _nimCtrl.text.isNotEmpty) {
        await adminClient
            .from('profiles')
            .update({
              'nim': _nimCtrl.text.trim(),
              'full_name': _nameCtrl.text.trim(),
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
      setState(() => _usersFuture = _loadUsers());
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
    if (mounted) setState(() => _usersFuture = _loadUsers());
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
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _usersFuture,
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
                    child: DataTable(
                      columns: const [
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
                            DataCell(Text(u['full_name']?.toString() ?? '-')),
                            DataCell(Text(u['email']?.toString() ?? '-')),
                            DataCell(Text(u['nim']?.toString() ?? '-')),
                            DataCell(
                              Text(u['registration_count']?.toString() ?? '0'),
                            ),
                            DataCell(Text(isActive ? 'AKTIF' : 'NONAKTIF')),
                            DataCell(
                              IconButton(
                                icon: Icon(
                                  isActive
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                  color: isActive
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                                onPressed: () =>
                                    _toggleActive(u['id'], isActive),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
