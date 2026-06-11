import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'category_management_view.dart';
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
            _buildNavItem(2, Icons.category_rounded, 'Kelola Kategori'),
            _buildNavItem(3, Icons.people_rounded, 'Pengguna'),
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
        return const CategoryManagementView();
      case 3:
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
  late Stream<_OverviewData> _overviewStream;

  @override
  void initState() {
    super.initState();
    _overviewStream = _buildOverviewStream();
  }

  Stream<_OverviewData> _buildOverviewStream() async* {
    // Listen to users stream
    final usersStream = adminClient.from('profiles').stream(primaryKey: ['id']);
    // Since combining streams in Dart without RxDart is tricky, we can just yield whenever profiles or events change.
    // To make it simple but effective, we use a timer-based poll or a simpler stream.
    // For true realtime without rxdart, we listen to events and profiles separately and update a local state,
    // OR we yield periodically, OR we just use a unified stream.
    await for (final users in usersStream) {
      final events = await adminClient
          .from('events')
          .select('id')
          .eq('status', 'published');
      final registrations = await adminClient
          .from('event_registrations')
          .select('id')
          .neq('status', 'cancelled');
      final Map<String, int> counts = {};
      final List<String> labels = [];
      final now = DateTime.now();
      final startDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      for (int i = 0; i < 7; i++) {
        final day = startDay.add(Duration(days: i));
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        counts[key] = 0;
        labels.add('${day.day}/${day.month}');
      }
      for (final row in users) {
        final raw = row['created_at']?.toString();
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
      yield _OverviewData(
        totalEvents: (events as List).length,
        totalUsers: users.length,
        totalRegistrations: (registrations as List).length,
        latestRegistrations: const [],
        attendanceSeries: attendanceSeries,
        attendanceLabels: labels,
      );
    }
    // Since Supabase returns Stream, we can just map the profiles stream and inside it fetch events and registrations.
    await for (final users in usersStream) {
      final events = await adminClient
          .from('events')
          .select('id')
          .eq('status', 'published');
      final registrations = await adminClient
          .from('event_registrations')
          .select('id')
          .neq('status', 'cancelled');

      final Map<String, int> counts = {};
      final List<String> labels = [];
      final now = DateTime.now();
      final startDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      for (int i = 0; i < 7; i++) {
        final day = startDay.add(Duration(days: i));
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        counts[key] = 0;
        labels.add('${day.day}/${day.month}');
      }

      for (final row in users) {
        final raw = row['created_at']?.toString();
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

      yield _OverviewData(
        totalEvents: (events as List).length,
        totalUsers: users.length,
        totalRegistrations: (registrations as List).length,
        latestRegistrations: const [],
        attendanceSeries: attendanceSeries,
        attendanceLabels: labels,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.of(context).size.width < 900
        ? 24.0
        : 40.0;

    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: StreamBuilder<_OverviewData>(
        stream: _overviewStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
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
                    final cardWidth = constraints.maxWidth < 600
                        ? double.infinity
                        : (constraints.maxWidth - 16) / 2;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: cards
                          .map(
                            (card) => SizedBox(width: cardWidth, child: card),
                          )
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
            'Pertumbuhan Pengguna 7 Hari Terakhir',
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Event?'),
        content: const Text(
          'Tindakan ini akan menghapus event secara permanen beserta seluruh data pendaftar dan komentar!',
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
              'Hapus Paksa',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final regs = await adminClient
          .from('event_registrations')
          .select('id')
          .eq('event_id', eventId);
      final regIds = (regs as List).map((e) => e['id']).toList();

      if (regIds.isNotEmpty) {
        for (var rid in regIds) {
          await adminClient
              .from('registration_form_answers')
              .delete()
              .eq('registration_id', rid);
          await adminClient
              .from('certificates')
              .delete()
              .eq('registration_id', rid);
        }
        for (var rid in regIds) {
          await adminClient.from('event_registrations').delete().eq('id', rid);
        }
      }

      await adminClient.from('certificates').delete().eq('event_id', eventId);
      await adminClient
          .from('event_bookmarks')
          .delete()
          .eq('event_id', eventId);
      await adminClient
          .from('event_form_fields')
          .delete()
          .eq('event_id', eventId);
      await adminClient.from('event_comments').delete().eq('event_id', eventId);
      await adminClient.from('notifications').delete().eq('event_id', eventId);
      await adminClient.from('events').delete().eq('id', eventId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event berhasil dihapus bersih.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error menghapus event: $e')));
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadRegistrations(String eventId) async {
    final response = await adminClient
        .from('event_registrations')
        .select(
          '*, profiles(full_name, email, nim, faculty, major, academic_year, phone_number), registration_form_answers(answer_text, event_form_fields(label))',
        )
        .eq('event_id', eventId)
        .neq('status', 'cancelled')
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

  Future<void> _setRegistrationStatusWithFeedback({
    required String registrationId,
    required String status,
    required VoidCallback onRefresh,
    required String successMessage,
  }) async {
    try {
      await _updateRegistrationStatus(registrationId, status);
      onRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui status: $e')));
    }
  }

  Future<void> _confirmRegistrationStatusChange({
    required String title,
    required String message,
    required String registrationId,
    required String status,
    required VoidCallback onRefresh,
    required String successMessage,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, lanjutkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _setRegistrationStatusWithFeedback(
      registrationId: registrationId,
      status: status,
      onRefresh: onRefresh,
      successMessage: successMessage,
    );
  }

  Future<void> _bulkConfirmAttendance({
    required String eventId,
    required VoidCallback onRefresh,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi massal kehadiran?'),
        content: const Text(
          'Semua pendaftar dengan status CONFIRMED akan diubah menjadi ATTENDED. Gunakan ini setelah peserta diverifikasi atau acara selesai.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await adminClient
          .from('event_registrations')
          .select('id')
          .eq('event_id', eventId)
          .eq('status', 'confirmed');

      final rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (rows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada pendaftar berstatus confirmed.'),
          ),
        );
        return;
      }

      for (final row in rows) {
        final regId = row['id']?.toString();
        if (regId == null) continue;
        await _updateRegistrationStatus(regId, 'attended');
      }

      onRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Berhasil menandai ${rows.length} peserta sebagai hadir.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal konfirmasi massal: $e')));
    }
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
    Future<List<Map<String, dynamic>>> certificatesFuture = _loadCertificates(
      eventId,
    );

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

                void refreshCertificates() {
                  setDialogState(() {
                    certificatesFuture = _loadCertificates(eventId);
                  });
                }

                return DefaultTabController(
                  length: 4,
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
                            Tab(text: 'Statistik'),
                            Tab(text: 'Pendaftar'),
                            Tab(text: 'Sertifikat'),
                            Tab(text: 'Komentar'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildStatsTab(future: registrationsFuture),
                            _buildRegistrationsTab(
                              eventId: eventId,
                              eventTitle: title,
                              future: registrationsFuture,
                              onRefresh: refreshRegistrations,
                            ),
                            _buildCertificatesTab(
                              eventId: eventId,
                              eventTitle: title,
                              future: certificatesFuture,
                              onRefresh: refreshCertificates,
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

  Widget _buildStatsTab({required Future<List<Map<String, dynamic>>> future}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final regs = snapshot.data ?? [];

          final Map<String, int> counts = {};
          final List<String> labels = [];

          final now = DateTime.now();
          final startDay = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6));
          for (int i = 0; i < 7; i++) {
            final day = startDay.add(Duration(days: i));
            final key =
                '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
            counts[key] = 0;
            labels.add('${day.day}/${day.month}');
          }

          if (regs.isNotEmpty) {
            for (final reg in regs) {
              final raw = reg['registered_at']?.toString();
              if (raw == null) continue;
              final parsed = DateTime.tryParse(raw);
              if (parsed == null) continue;
              final dayKey =
                  '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
              if (counts.containsKey(dayKey)) {
                counts[dayKey] = (counts[dayKey] ?? 0) + 1;
              }
            }
          }

          final series = counts.values
              .toList()
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricCard(
                label: 'Total Pendaftar',
                value: regs.length.toString(),
              ),
              const SizedBox(height: 32),
              const Text(
                'Pertumbuhan Pendaftar 7 Hari Terakhir',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: series.isEmpty || counts.values.every((v) => v == 0)
                    ? const Center(
                        child: Text('Belum ada data pendaftar minggu ini.'),
                      )
                    : Container(
                        padding: const EdgeInsets.only(right: 24, top: 24),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  getTitlesWidget: (value, meta) {
                                    if (value % 1 != 0) {
                                      return const SizedBox.shrink();
                                    }
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
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                                dotData: FlDotData(show: true),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRegistrationsTab({
    required String eventId,
    required String eventTitle,
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

          final pendingCount = data
              .where(
                (item) =>
                    (item['status']?.toString() ?? 'pending') == 'pending',
              )
              .length;
          final confirmedCount = data
              .where(
                (item) =>
                    (item['status']?.toString() ?? 'pending') == 'confirmed',
              )
              .length;
          final attendedCount = data
              .where(
                (item) =>
                    (item['status']?.toString() ?? 'pending') == 'attended',
              )
              .length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricCard(
                    label: 'Total Pendaftar',
                    value: data.length.toString(),
                  ),
                  _buildMetricCard(
                    label: 'Pending',
                    value: pendingCount.toString(),
                    accent: Colors.orange,
                  ),
                  _buildMetricCard(
                    label: 'Confirmed',
                    value: confirmedCount.toString(),
                    accent: Colors.blue,
                  ),
                  _buildMetricCard(
                    label: 'Attended',
                    value: attendedCount.toString(),
                    accent: Colors.green,
                  ),
                  if (confirmedCount > 0)
                    ElevatedButton.icon(
                      onPressed: () => _bulkConfirmAttendance(
                        eventId: eventId,
                        onRefresh: onRefresh,
                      ),
                      icon: const Icon(Icons.how_to_reg_rounded),
                      label: const Text('Konfirmasi Massal Hadir'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Event: $eventTitle',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
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
                    final regId = reg['id']?.toString() ?? '';
                    final confirmedAt = reg['confirmed_at']?.toString();
                    final attendedAt = reg['attended_at']?.toString();

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
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
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
                                  await _setRegistrationStatusWithFeedback(
                                    registrationId: regId,
                                    status: value,
                                    onRefresh: onRefresh,
                                    successMessage:
                                        'Status pendaftar berhasil diperbarui.',
                                  );
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
                                  _registrationStatusColor(status),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            24,
                            8,
                            24,
                            16,
                          ),
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
                            _buildProfileRow(
                              'Angkatan',
                              profile?['academic_year'],
                            ),
                            _buildProfileRow(
                              'No. HP',
                              profile?['phone_number'],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Aksi Absensi Manual',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      _buildStatusPill(
                                        _registrationStatusLabel(status),
                                        _registrationStatusColor(status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      if (confirmedAt != null)
                                        Text(
                                          'Dikonfirmasi: ${_formatDate(confirmedAt)}',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      if (attendedAt != null)
                                        Text(
                                          'Hadir: ${_formatDate(attendedAt)}',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      if (confirmedAt == null &&
                                          attendedAt == null)
                                        const Text(
                                          'Belum ada validasi manual dari admin.',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      if (status != 'cancelled' &&
                                          status != 'confirmed' &&
                                          status != 'attended')
                                        OutlinedButton.icon(
                                          onPressed: regId.isEmpty
                                              ? null
                                              : () => _confirmRegistrationStatusChange(
                                                  title:
                                                      'Konfirmasi pendaftaran?',
                                                  message:
                                                      'Pendaftaran ${profile?['full_name'] ?? 'peserta ini'} akan diubah menjadi CONFIRMED untuk event $eventTitle.',
                                                  registrationId: regId,
                                                  status: 'confirmed',
                                                  onRefresh: onRefresh,
                                                  successMessage:
                                                      'Pendaftaran berhasil dikonfirmasi.',
                                                ),
                                          icon: const Icon(
                                            Icons.verified_user_rounded,
                                          ),
                                          label: const Text('Konfirmasi'),
                                        ),
                                      if (status != 'cancelled' &&
                                          status != 'attended')
                                        ElevatedButton.icon(
                                          onPressed: regId.isEmpty
                                              ? null
                                              : () => _confirmRegistrationStatusChange(
                                                  title: 'Tandai hadir?',
                                                  message:
                                                      'Pendaftar ${profile?['full_name'] ?? 'peserta ini'} akan ditandai sebagai ATTENDED. Gunakan ini jika peserta sudah hadir di acara.',
                                                  registrationId: regId,
                                                  status: 'attended',
                                                  onRefresh: onRefresh,
                                                  successMessage:
                                                      'Status hadir berhasil disimpan.',
                                                ),
                                          icon: const Icon(
                                            Icons.how_to_reg_rounded,
                                          ),
                                          label: const Text('Tandai Hadir'),
                                        ),
                                      if (status == 'cancelled')
                                        const Text(
                                          'Pendaftar dibatalkan, tidak dapat diubah ke hadir dari panel ini.',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Data Formulir Pendaftaran:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (answers.isEmpty)
                              const Text('Tidak ada jawaban form tambahan.')
                            else
                              ...answers.map(
                                (answer) => _buildProfileRow(
                                  answer['event_form_fields']?['label']
                                          ?.toString() ??
                                      '-',
                                  answer['answer_text']?.toString(),
                                ),
                              ),
                          ],
                        ),
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

  Future<List<Map<String, dynamic>>> _loadCertificates(String eventId) async {
    final registrationsResponse = await adminClient
        .from('event_registrations')
        .select(
          'id, status, attended_at, profiles(full_name, nim, email), event_id',
        )
        .eq('event_id', eventId)
        .eq('status', 'attended')
        .order('attended_at', ascending: false);

    final certificateResponse = await adminClient
        .from('certificates')
        .select('registration_id, title, certificate_url, issued_at')
        .eq('event_id', eventId)
        .order('issued_at', ascending: false);

    final certificatesByRegistration = <String, Map<String, dynamic>>{};
    for (final item in certificateResponse as List) {
      final row = Map<String, dynamic>.from(item as Map);
      final registrationId = row['registration_id']?.toString();
      if (registrationId != null) {
        certificatesByRegistration[registrationId] = row;
      }
    }

    return (registrationsResponse as List).map((item) {
      final row = Map<String, dynamic>.from(item as Map);
      final registrationId = row['id']?.toString();
      row['certificate'] = registrationId == null
          ? null
          : certificatesByRegistration[registrationId];
      return row;
    }).toList();
  }

  Future<Uint8List> _buildCertificateBytes({
    required String eventTitle,
    required String participantName,
    required String nim,
    required DateTime attendedAt,
  }) async {
    const width = 1600.0;
    const height = 1131.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, width, height);

    canvas.drawRect(rect, Paint()..color = const Color(0xFFF8FAFC));

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = const Color(0xFFEF4444);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(24), const Radius.circular(36)),
      borderPaint,
    );

    final accentPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(
      const Offset(1400, 160),
      84,
      Paint()..color = accentPaint.color.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      const Offset(1500, 250),
      48,
      Paint()..color = accentPaint.color.withValues(alpha: 0.18),
    );

    void drawCenteredText(
      String text, {
      required double top,
      required double fontSize,
      required FontWeight fontWeight,
      required Color color,
      double maxWidth = width - 220,
      TextAlign align = TextAlign.center,
      double letterSpacing = 0,
    }) {
      final painter = TextPainter(
        textAlign: align,
        textDirection: ui.TextDirection.ltr,
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            letterSpacing: letterSpacing,
            height: 1.2,
          ),
        ),
      )..layout(maxWidth: maxWidth);

      painter.paint(canvas, Offset((width - painter.width) / 2, top));
    }

    drawCenteredText(
      'EVENTIFY',
      top: 90,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: const Color(0xFFEF4444),
      letterSpacing: 4,
    );

    drawCenteredText(
      'SERTIFIKAT PENGHARGAAN',
      top: 180,
      fontSize: 56,
      fontWeight: FontWeight.w900,
      color: const Color(0xFF111827),
    );

    drawCenteredText(
      'Diberikan kepada',
      top: 300,
      fontSize: 28,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF475569),
    );

    drawCenteredText(
      participantName,
      top: 360,
      fontSize: 64,
      fontWeight: FontWeight.w900,
      color: const Color(0xFF111827),
      maxWidth: width - 180,
    );

    drawCenteredText(
      'NIM: $nim',
      top: 455,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF475569),
    );

    drawCenteredText(
      'Atas partisipasinya dalam event',
      top: 525,
      fontSize: 26,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF475569),
    );

    drawCenteredText(
      eventTitle,
      top: 575,
      fontSize: 38,
      fontWeight: FontWeight.w800,
      color: const Color(0xFFEF4444),
      maxWidth: width - 220,
    );

    drawCenteredText(
      'Tanggal kehadiran: ${_formatDate(attendedAt.toIso8601String())}',
      top: 670,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF334155),
    );

    drawCenteredText(
      'Sertifikat ini diterbitkan secara digital oleh Admin Eventify',
      top: 860,
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF64748B),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<String> _uploadCertificateFile({
    required String eventId,
    required String registrationId,
    required Uint8List bytes,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'certificates/$eventId/$registrationId-$timestamp.png';
    await adminClient.storage
        .from('event_assets')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );
    return adminClient.storage.from('event_assets').getPublicUrl(path);
  }

  Future<int> _issueCertificatesForEvent({
    required String eventId,
    required String eventTitle,
  }) async {
    final attendedRows = await adminClient
        .from('event_registrations')
        .select('id, attended_at, profiles(full_name, nim, email)')
        .eq('event_id', eventId)
        .eq('status', 'attended')
        .order('attended_at', ascending: false);

    final existingCertificates = await adminClient
        .from('certificates')
        .select('registration_id')
        .eq('event_id', eventId);

    final issuedRegistrationIds = <String>{
      for (final item in existingCertificates as List)
        item['registration_id']?.toString() ?? '',
    }..remove('');

    var createdCount = 0;
    for (final item in attendedRows as List) {
      final row = Map<String, dynamic>.from(item as Map);
      final registrationId = row['id']?.toString();
      if (registrationId == null ||
          issuedRegistrationIds.contains(registrationId)) {
        continue;
      }

      final profile = row['profiles'] as Map<String, dynamic>?;
      final participantName = profile?['full_name']?.toString() ?? 'Peserta';
      final nim = profile?['nim']?.toString() ?? '-';
      final attendedAtRaw = row['attended_at']?.toString();
      final attendedAt = attendedAtRaw != null
          ? DateTime.tryParse(attendedAtRaw) ?? DateTime.now()
          : DateTime.now();

      final certificateBytes = await _buildCertificateBytes(
        eventTitle: eventTitle,
        participantName: participantName,
        nim: nim,
        attendedAt: attendedAt,
      );

      final certificateUrl = await _uploadCertificateFile(
        eventId: eventId,
        registrationId: registrationId,
        bytes: certificateBytes,
      );

      await adminClient.from('certificates').insert({
        'registration_id': registrationId,
        'user_id': profile?['id'] ?? row['user_id'],
        'event_id': eventId,
        'title': 'Sertifikat $eventTitle',
        'certificate_url': certificateUrl,
        'issued_at': DateTime.now().toUtc().toIso8601String(),
      });

      issuedRegistrationIds.add(registrationId);
      createdCount += 1;
    }

    return createdCount;
  }

  Widget _buildCertificatesTab({
    required String eventId,
    required String eventTitle,
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

          final participants = snapshot.data ?? [];
          final issued = participants
              .where((item) => item['certificate'] != null)
              .length;
          final pending = participants.length - issued;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricCard(
                    label: 'Peserta Hadir',
                    value: participants.length.toString(),
                    accent: Colors.blue,
                  ),
                  _buildMetricCard(
                    label: 'Sertifikat Terbit',
                    value: issued.toString(),
                    accent: Colors.green,
                  ),
                  _buildMetricCard(
                    label: 'Menunggu Dibuat',
                    value: pending.toString(),
                    accent: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: participants.isEmpty
                      ? null
                      : () async {
                          try {
                            final created = await _issueCertificatesForEvent(
                              eventId: eventId,
                              eventTitle: eventTitle,
                            );
                            onRefresh();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  created == 0
                                      ? 'Tidak ada sertifikat baru untuk diterbitkan.'
                                      : 'Berhasil menerbitkan $created sertifikat.',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Gagal menerbitkan sertifikat: $e',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Terbitkan Sertifikat Massal'),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Usulan Format Sertifikat',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Format yang disarankan: PDF A4 landscape, judul sertifikat, nama peserta, nama event, tanggal pelaksanaan, tanda tangan/otorisasi admin, dan kode verifikasi atau QR.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pemberian disarankan: otomatis untuk semua pendaftar berstatus attended. Admin cukup menandai hadir, lalu sistem menyiapkan sertifikat per peserta sebagai satu record pada tabel certificates.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: participants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final participant = participants[index];
                    final profile =
                        participant['profiles'] as Map<String, dynamic>?;
                    final certificate =
                        participant['certificate'] as Map<String, dynamic>?;
                    final attendedAt = participant['attended_at']?.toString();

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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile?['full_name']?.toString() ??
                                          'Peserta',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'NIM: ${profile?['nim']?.toString() ?? '-'}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hadir: ${_formatDate(attendedAt)}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusPill(
                                certificate == null ? 'MENUNGGU' : 'TERBIT',
                                certificate == null
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.primary.withValues(alpha: 0.08),
                                  AppTheme.primary.withValues(alpha: 0.18),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Preview Format',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '• Event: $eventTitle\n• Nama Peserta: ${profile?['full_name']?.toString() ?? '-'}\n• Status: ${certificate == null ? 'Siap diterbitkan' : 'Sudah diterbitkan'}\n• Disarankan file: PDF landscape',
                                  style: const TextStyle(height: 1.5),
                                ),
                                if (certificate != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'URL Sertifikat: ${certificate['certificate_url']?.toString() ?? '-'}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
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

  Color _registrationStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.blue;
      case 'attended':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _registrationStatusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'CONFIRMED';
      case 'attended':
        return 'ATTENDED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return 'PENDING';
    }
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

                  final uniqueEvents = <Map<String, dynamic>>[];
                  final seenIds = <String>{};
                  for (final event in events) {
                    final id = event['id']?.toString();
                    if (id == null || seenIds.add(id)) {
                      uniqueEvents.add(event);
                    }
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
                        rows: uniqueEvents
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
