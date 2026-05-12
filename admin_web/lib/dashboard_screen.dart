import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_form_screen.dart';
import 'main.dart';
import 'theme.dart';
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
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => Supabase.instance.client.auth.signOut(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: AppTheme.divider),
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
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
      ),
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
        return const OverviewView();
      case 1:
        return _isCreatingEvent
            ? EventFormScreen(
                onBack: () => setState(() => _isCreatingEvent = false),
              )
            : EventManagementView(
                onCreateEvent: () => setState(() => _isCreatingEvent = true),
              );
      case 2:
        return const UserManagementView();
      default:
        return const SizedBox.shrink();
    }
  }
}

class OverviewView extends StatefulWidget {
  const OverviewView({super.key});

  @override
  State<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends State<OverviewView> {
  late Future<_OverviewData> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _loadOverview();
  }

  Future<_OverviewData> _loadOverview() async {
    final events = await adminClient
        .from('events')
        .select('id')
        .eq('status', 'published');
    final users = await adminClient.from('profiles').select('id');
    final registrations = await adminClient
        .from('event_registrations')
        .select('id');

    final latestRegs = await adminClient
        .from('event_registrations')
        .select('status, registered_at, profiles(full_name), events(title)')
        .order('registered_at', ascending: false)
        .limit(10);

    final latestRegistrations = (latestRegs as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return _OverviewData(
      totalEvents: (events as List).length,
      totalUsers: (users as List).length,
      totalRegistrations: (registrations as List).length,
      latestRegistrations: latestRegistrations,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: FutureBuilder<_OverviewData>(
        future: _overviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data =
              snapshot.data ??
              const _OverviewData(
                totalEvents: 0,
                totalUsers: 0,
                totalRegistrations: 0,
                latestRegistrations: [],
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overview',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _StatCard(label: 'Event Aktif', value: data.totalEvents),
                  const SizedBox(width: 16),
                  _StatCard(label: 'Total Pengguna', value: data.totalUsers),
                  const SizedBox(width: 16),
                  _StatCard(
                    label: 'Total Pendaftaran',
                    value: data.totalRegistrations,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Pendaftaran Terbaru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: ListView.separated(
                    itemCount: data.latestRegistrations.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final reg = data.latestRegistrations[index];
                      final profile = reg['profiles'] as Map<String, dynamic>?;
                      final event = reg['events'] as Map<String, dynamic>?;
                      return ListTile(
                        title: Text(profile?['full_name']?.toString() ?? '-'),
                        subtitle: Text(event?['title']?.toString() ?? '-'),
                        trailing: Text(
                          reg['status']?.toString().toUpperCase() ?? '- ',
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class EventManagementView extends StatefulWidget {
  final VoidCallback onCreateEvent;
  const EventManagementView({super.key, required this.onCreateEvent});

  @override
  State<EventManagementView> createState() => _EventManagementViewState();
}

class _EventManagementViewState extends State<EventManagementView> {
  Future<void> _updateEventStatus(String eventId, String status) async {
    await adminClient
        .from('events')
        .update({'status': status})
        .eq('id', eventId);
  }

  Future<void> _deleteEvent(String eventId) async {
    final regs = await adminClient
        .from('event_registrations')
        .select('id')
        .eq('event_id', eventId);

    if ((regs as List).isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event sudah memiliki pendaftar.')),
      );
      return;
    }

    await adminClient.from('events').delete().eq('id', eventId);
  }

  void _showRegistrations(String eventId, String eventTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pendaftar: $eventTitle'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: adminClient
                .from('event_registrations')
                .select('*, profiles(full_name, email, nim), registration_form_answers(answer_text, event_form_fields(label))')
                .eq('event_id', eventId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              final data = snapshot.data ?? [];
              if (data.isEmpty) {
                return const Center(child: Text('Belum ada pendaftar'));
              }
              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final reg = data[index];
                  final profile = reg['profiles'] as Map<String, dynamic>?;
                  final answers = (reg['registration_form_answers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                  
                  final header = ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      profile?['full_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${profile?['email'] ?? '-'} | NIM: ${profile?['nim'] ?? '-'}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (status) async {
                        final updateData = {'status': status};
                        if (status == 'confirmed') {
                          updateData['confirmed_at'] = DateTime.now().toIso8601String();
                        }
                        if (status == 'attended') {
                          updateData['attended_at'] = DateTime.now().toIso8601String();
                        }
                        await adminClient
                            .from('event_registrations')
                            .update(updateData)
                            .eq('id', reg['id']);
                        if (ctx.mounted) {
                          setState(() {});
                          // Close dialog to refresh
                          Navigator.pop(ctx);
                          _showRegistrations(eventId, eventTitle);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'confirmed', child: Text('Konfirmasi')),
                        PopupMenuItem(value: 'cancelled', child: Text('Batalkan')),
                        PopupMenuItem(value: 'attended', child: Text('Tandai Hadir')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: reg['status'] == 'confirmed' ? Colors.green.withValues(alpha: 0.1) : 
                                 reg['status'] == 'cancelled' ? Colors.red.withValues(alpha: 0.1) : 
                                 Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          reg['status'].toString().toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: reg['status'] == 'confirmed' ? Colors.green : 
                                   reg['status'] == 'cancelled' ? Colors.red : 
                                   Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  );

                  if (answers.isEmpty) return header;

                  return Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: header.title!,
                      subtitle: header.subtitle,
                      leading: header.leading,
                      trailing: header.trailing,
                      childrenPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const Text('Data Formulir Pendaftaran:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        const SizedBox(height: 8),
                        ...answers.map((ans) {
                          final label = ans['event_form_fields']?['label'] ?? 'Unknown Field';
                          final val = ans['answer_text'] ?? '-';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 150, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
                                const Text(': '),
                                Expanded(child: Text(val, style: const TextStyle(fontWeight: FontWeight.w600))),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              );
            },
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
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: widget.onCreateEvent,
                icon: const Icon(Icons.add),
                label: const Text('Buat Event Baru'),
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
                stream: adminClient.from('events').stream(primaryKey: ['id']),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final events = snapshot.data ?? [];
                  if (events.isEmpty) {
                    return const Center(
                      child: Text('Belum ada event yang dibuat.'),
                    );
                  }
                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Judul',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Tanggal',
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
                      rows: events
                          .map(
                            (event) => DataRow(
                              cells: [
                                DataCell(
                                  Text(event['title']?.toString() ?? '-'),
                                ),
                                DataCell(
                                  Text(event['start_date']?.toString() ?? '-'),
                                ),
                                DataCell(
                                  PopupMenuButton<String>(
                                    onSelected: (value) =>
                                        _updateEventStatus(event['id'], value),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'draft',
                                        child: Text('Draft'),
                                      ),
                                      PopupMenuItem(
                                        value: 'published',
                                        child: Text('Published'),
                                      ),
                                      PopupMenuItem(
                                        value: 'ongoing',
                                        child: Text('Ongoing'),
                                      ),
                                      PopupMenuItem(
                                        value: 'completed',
                                        child: Text('Completed'),
                                      ),
                                      PopupMenuItem(
                                        value: 'cancelled',
                                        child: Text('Cancelled'),
                                      ),
                                    ],
                                    child: Text(
                                      event['status']
                                              ?.toString()
                                              .toUpperCase() ??
                                          '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.people, size: 18),
                                        label: const Text('Pendaftar'),
                                        onPressed: () => _showRegistrations(
                                          event['id'],
                                          event['title'],
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.green,
                                          side: const BorderSide(color: Colors.green),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        tooltip: 'Hapus Event',
                                        onPressed: () =>
                                            _deleteEvent(event['id']),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewData {
  const _OverviewData({
    required this.totalEvents,
    required this.totalUsers,
    required this.totalRegistrations,
    required this.latestRegistrations,
  });

  final int totalEvents;
  final int totalUsers;
  final int totalRegistrations;
  final List<Map<String, dynamic>> latestRegistrations;
}
