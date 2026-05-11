import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'event_form_screen.dart';
import 'user_management_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isCreatingEvent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: AppTheme.surface,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Eventify Admin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 40),
                _buildNavItem(0, Icons.dashboard_rounded, 'Overview'),
                _buildNavItem(1, Icons.event_rounded, 'Kelola Event'),
                _buildNavItem(2, Icons.people_rounded, 'Pengguna'),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () => Supabase.instance.client.auth.signOut(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: AppTheme.divider),
          // Main Content
          Expanded(
            child: Container(
              color: AppTheme.background,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onTap: () => setState(() {
        _selectedIndex = index;
        _isCreatingEvent = false;
      }),
      selectedTileColor: AppTheme.primary.withValues(alpha: 0.1),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const Center(child: Text('Halaman Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)));
      case 1:
        return _isCreatingEvent 
          ? EventFormScreen(onBack: () => setState(() => _isCreatingEvent = false))
          : EventManagementView(onCreateEvent: () => setState(() => _isCreatingEvent = true));
      case 2:
        return const UserManagementView();
      default:
        return const SizedBox.shrink();
    }
  }
}

class EventManagementView extends StatefulWidget {
  final VoidCallback onCreateEvent;
  const EventManagementView({super.key, required this.onCreateEvent});

  @override
  State<EventManagementView> createState() => _EventManagementViewState();
}

class _EventManagementViewState extends State<EventManagementView> {
  void _showRegistrations(String eventId, String eventTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pendaftar: $eventTitle'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client
                .from('event_registrations')
                .select('*, profiles(full_name, email, nim)')
                .eq('event_id', eventId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              final data = snapshot.data!;
              if (data.isEmpty) return const Center(child: Text('Belum ada pendaftar'));
              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final reg = data[index];
                  final profile = reg['profiles'];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(profile['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${profile['email']} | NIM: ${profile['nim'] ?? '-'}'),
                    trailing: Text(reg['status'].toString().toUpperCase()),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
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
                'Kelola Event',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: widget.onCreateEvent,
                icon: const Icon(Icons.add),
                label: const Text('Buat Event Baru'),
              ),
            ],
          ),
          const SizedBox(height: 40),
          // Data Table
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client.from('events').stream(primaryKey: ['id']),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final events = snapshot.data!;
                  if (events.isEmpty) {
                    return const Center(child: Text('Belum ada event yang dibuat.'));
                  }
                  return SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Judul', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: events.map((event) => DataRow(
                        cells: [
                          DataCell(Text(event['title']?.toString() ?? '-')),
                          DataCell(Text(event['start_date']?.toString() ?? '-')),
                          DataCell(Text(event['status']?.toString().toUpperCase() ?? '-')),
                          DataCell(
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.people, color: Colors.green, size: 20), onPressed: () => _showRegistrations(event['id'], event['title'])),
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: (){}),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: (){}),
                              ],
                            )
                          ),
                        ],
                      )).toList(),
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
