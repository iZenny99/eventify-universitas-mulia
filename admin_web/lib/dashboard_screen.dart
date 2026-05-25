import 'package:fl_chart/fl_chart.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1100;

        final content = Container(
          color: AppTheme.background,
          child: _buildContent(),
        );

        return Scaffold(
          appBar: isCompact
              ? AppBar(
                  title: const Text('Eventify Admin'),
                  backgroundColor: AppTheme.surface,
                  foregroundColor: AppTheme.textPrimary,
                  elevation: 0,
                )
              : null,
          drawer: isCompact
              ? Drawer(child: SafeArea(child: _buildSideNav(isCompact: true)))
              : null,
          body: Row(
            children: [
              if (!isCompact) _buildSideNav(isCompact: false),
              if (!isCompact)
                const VerticalDivider(width: 1, color: AppTheme.divider),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSideNav({required bool isCompact}) {
    return SizedBox(
      width: isCompact ? 280 : 250,
      child: Container(
        color: AppTheme.surface,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.event_available,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Eventify Admin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildNavItem(0, Icons.dashboard_rounded, 'Overview'),
            _buildNavItem(1, Icons.event_rounded, 'Kelola Event'),
            _buildNavItem(2, Icons.people_rounded, 'Pengguna'),
            const SizedBox(height: 24),
            const Divider(color: AppTheme.divider),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => Supabase.instance.client.auth.signOut(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    final attendanceRows = await adminClient
        .from('event_registrations')
        .select('attended_at')
        .not('attended_at', 'is', null);

    final now = DateTime.now();
    final startDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final Map<String, int> counts = {};
    final List<String> labels = [];
    for (int i = 0; i < 7; i++) {
      final day = startDay.add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      counts[key] = 0;
      labels.add('${day.day}/${day.month}');
    }

    for (final row in (attendanceRows as List)) {
      final raw = row['attended_at']?.toString();
      if (raw == null) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) continue;
      final dayKey =
          '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
      if (counts.containsKey(dayKey)) {
        counts[dayKey] = (counts[dayKey] ?? 0) + 1;
      }
    }

    final attendanceSeries = counts.values
        .toList()
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.toDouble()))
        .toList();

    return _OverviewData(
      totalEvents: (events as List).length,
      totalUsers: (users as List).length,
      totalRegistrations: (registrations as List).length,
      latestRegistrations: latestRegistrations,
      attendanceSeries: attendanceSeries,
      attendanceLabels: labels,
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.of(context).size.width < 900
        ? 24.0
        : 40.0;

    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
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
                attendanceSeries: [],
                attendanceLabels: [],
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overview',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 900;
                  final cards = [
                    _StatCard(label: 'Event Aktif', value: data.totalEvents),
                    _StatCard(label: 'Total Pengguna', value: data.totalUsers),
                    _StatCard(
                      label: 'Total Pendaftaran',
                      value: data.totalRegistrations,
                    ),
                  ];

                  if (isCompact) {
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: cards
                          .map((card) => SizedBox(width: 260, child: card))
                          .toList(),
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[1]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[2]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              _buildAttendanceChart(data),
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

  Widget _buildAttendanceChart(_OverviewData data) {
    final series = data.attendanceSeries;
    final labels = data.attendanceLabels;

    if (series.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Text('Belum ada data kehadiran.'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kehadiran 7 Hari Terakhir',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[index],
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: series,
                    isCurved: true,
                    barWidth: 3,
                    color: AppTheme.primary,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withValues(alpha: 0.12),
                    ),
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return Container(
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

  Future<List<Map<String, dynamic>>> _loadRegistrations(String eventId) async {
    final response = await adminClient
        .from('event_registrations')
        .select(
          '*, profiles(full_name, email, nim, faculty, major, academic_year, phone_number), registration_form_answers(answer_text, event_form_fields(label))',
        )
        .eq('event_id', eventId)
        .order('registered_at', ascending: false);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _updateRegistrationStatus(
    String registrationId,
    String status,
  ) async {
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
        .eq('id', registrationId);
  }

  Future<List<Map<String, dynamic>>> _loadComments(String eventId) async {
    final response = await adminClient
        .from('event_comments')
        .select(
          'id, comment_text, rating, created_at, is_deleted, profiles(full_name, email, avatar_url)',
        )
        .eq('event_id', eventId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _softDeleteComment(String commentId) async {
    await adminClient
        .from('event_comments')
        .update({'is_deleted': true})
        .eq('id', commentId);
  }

  double? _calculateAverageRating(List<Map<String, dynamic>> comments) {
    final ratings = comments
        .where((item) => item['is_deleted'] != true)
        .map((item) => item['rating'])
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList();

    if (ratings.isEmpty) return null;
    final total = ratings.reduce((a, b) => a + b);
    return total / ratings.length;
  }

  String _formatDate(String? value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;

    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
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

  Color _eventStatusColor(String status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'ongoing':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return AppTheme.textSecondary;
    }
  }

  Widget _buildStatusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    Color? accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: accent ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, dynamic value) {
    final text = (value == null || value.toString().isEmpty)
        ? '-'
        : value.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  void _showEventDetails(Map<String, dynamic> event) {
    final eventId = event['id']?.toString();
    if (eventId == null) return;

    final title = event['title']?.toString() ?? '-';
    final status = event['status']?.toString() ?? 'draft';
    final startDate = event['start_date']?.toString();

    Future<List<Map<String, dynamic>>> registrationsFuture = _loadRegistrations(
      eventId,
    );
    Future<List<Map<String, dynamic>>> commentsFuture = _loadComments(eventId);

    showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        final isCompact = size.width < 900;
        final dialogWidth = isCompact ? size.width - 32 : 980.0;
        final dialogHeight = size.height * (isCompact ? 0.9 : 0.8);

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 24,
            vertical: 24,
          ),
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                void refreshRegistrations() {
                  setDialogState(() {
                    registrationsFuture = _loadRegistrations(eventId);
                  });
                }

                void refreshComments() {
                  setDialogState(() {
                    commentsFuture = _loadComments(eventId);
                  });
                }

                return DefaultTabController(
                  length: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tanggal mulai: ${_formatDate(startDate)}',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusPill(
                              status.toUpperCase(),
                              _eventStatusColor(status),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.divider),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const TabBar(
                          isScrollable: true,
                          labelColor: AppTheme.primary,
                          unselectedLabelColor: AppTheme.textSecondary,
                          tabs: [
                            Tab(text: 'Pendaftar'),
                            Tab(text: 'Komentar'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildRegistrationsTab(
                              future: registrationsFuture,
                              onRefresh: refreshRegistrations,
                            ),
                            _buildCommentsTab(
                              future: commentsFuture,
                              onRefresh: refreshComments,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegistrationsTab({
    required Future<List<Map<String, dynamic>>> future,
    required VoidCallback onRefresh,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('Belum ada pendaftar'));
          }

          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final reg = data[index];
              final profile = reg['profiles'] as Map<String, dynamic>?;
              final answers =
                  (reg['registration_form_answers'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [];
              final status = reg['status']?.toString() ?? 'pending';

              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      profile?['full_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${profile?['email'] ?? '-'} | NIM: ${profile?['nim'] ?? '-'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            await _updateRegistrationStatus(
                              reg['id'].toString(),
                              value,
                            );
                            onRefresh();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'confirmed',
                              child: Text('Konfirmasi'),
                            ),
                            PopupMenuItem(
                              value: 'cancelled',
                              child: Text('Batalkan'),
                            ),
                            PopupMenuItem(
                              value: 'attended',
                              child: Text('Tandai Hadir'),
                            ),
                          ],
                          child: _buildStatusPill(
                            status.toUpperCase(),
                            _eventStatusColor(status),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const Text(
                        'Profil Peserta:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildProfileRow('Fakultas', profile?['faculty']),
                      _buildProfileRow('Prodi', profile?['major']),
                      _buildProfileRow('Angkatan', profile?['academic_year']),
                      _buildProfileRow('No. HP', profile?['phone_number']),
                      const SizedBox(height: 12),
                      const Text(
                        'Data Formulir Pendaftaran:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (answers.isEmpty)
                        const Text('Tidak ada jawaban formulir.')
                      else
                        ...answers.map((ans) {
                          final label =
                              ans['event_form_fields']?['label'] ??
                              'Unknown Field';
                          final val = ans['answer_text'] ?? '-';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 150,
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                const Text(': '),
                                Expanded(
                                  child: Text(
                                    val,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCommentsTab({
    required Future<List<Map<String, dynamic>>> future,
    required VoidCallback onRefresh,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final comments = snapshot.data ?? [];
          if (comments.isEmpty) {
            return const Center(child: Text('Belum ada komentar.'));
          }

          final activeComments = comments
              .where((item) => item['is_deleted'] != true)
              .toList();
          final avgRating = _calculateAverageRating(comments);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _buildMetricCard(
                    label: 'Total Komentar',
                    value: comments.length.toString(),
                  ),
                  _buildMetricCard(
                    label: 'Aktif',
                    value: activeComments.length.toString(),
                    accent: Colors.green,
                  ),
                  if (avgRating != null)
                    _buildMetricCard(
                      label: 'Rating Rata-rata',
                      value: avgRating.toStringAsFixed(1),
                      accent: Colors.orange,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final profile =
                        comment['profiles'] as Map<String, dynamic>?;
                    final name =
                        profile?['full_name']?.toString() ?? 'Pengguna';
                    final email = profile?['email']?.toString() ?? '-';
                    final avatarUrl = profile?['avatar_url']?.toString();
                    final isDeleted = comment['is_deleted'] == true;
                    final rating = comment['rating'];

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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                backgroundImage: avatarUrl == null
                                    ? null
                                    : NetworkImage(avatarUrl),
                                child: avatarUrl == null
                                    ? Text(
                                        _buildInitials(name),
                                        style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w700,
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildStatusPill(
                                    isDeleted ? 'DELETED' : 'ACTIVE',
                                    isDeleted ? Colors.red : Colors.green,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatDate(
                                      comment['created_at']?.toString(),
                                    ),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (rating != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${rating.toString()}/5',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          if (rating != null) const SizedBox(height: 8),
                          Text(
                            comment['comment_text']?.toString() ?? '-',
                            style: const TextStyle(height: 1.5),
                          ),
                          if (!isDeleted) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Hapus komentar?'),
                                      content: const Text(
                                        'Komentar akan disembunyikan dari publik.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Batal'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            'Hapus',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm != true) return;

                                  await _softDeleteComment(
                                    comment['id'].toString(),
                                  );
                                  onRefresh();
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Hapus',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.of(context).size.width < 900
        ? 24.0
        : 40.0;

    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 720;
              final title = const Text(
                'Kelola Event',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              );
              final button = ElevatedButton.icon(
                onPressed: widget.onCreateEvent,
                icon: const Icon(Icons.add),
                label: const Text('Buat Event Baru'),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), button],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [title, button],
              );
            },
          ),
          const SizedBox(height: 24),
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
                                    Text(
                                      event['start_date']?.toString() ?? '-',
                                    ),
                                  ),
                                  DataCell(
                                    PopupMenuButton<String>(
                                      onSelected: (value) => _updateEventStatus(
                                        event['id'],
                                        value,
                                      ),
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
                                      child: _buildStatusPill(
                                        event['status']
                                                ?.toString()
                                                .toUpperCase() ??
                                            '-',
                                        _eventStatusColor(
                                          event['status']?.toString() ?? '',
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(
                                            Icons.info_outline,
                                            size: 18,
                                          ),
                                          label: const Text('Detail'),
                                          onPressed: () =>
                                              _showEventDetails(event),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.primary,
                                            side: const BorderSide(
                                              color: AppTheme.primary,
                                            ),
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

class _OverviewData {
  const _OverviewData({
    required this.totalEvents,
    required this.totalUsers,
    required this.totalRegistrations,
    required this.latestRegistrations,
    required this.attendanceSeries,
    required this.attendanceLabels,
  });

  final int totalEvents;
  final int totalUsers;
  final int totalRegistrations;
  final List<Map<String, dynamic>> latestRegistrations;
  final List<FlSpot> attendanceSeries;
  final List<String> attendanceLabels;
}
