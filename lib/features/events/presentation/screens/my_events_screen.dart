import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/event_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../domain/event_model.dart';
import '../../../attendance/domain/ticket_model.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  int _selectedTab = 0;
  late Future<List<TicketModel>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _ticketsFuture = _loadTickets();
  }

  Future<List<TicketModel>> _loadTickets() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final response = await Supabase.instance.client
        .from('event_registrations')
        .select('*, events(*)')
        .eq('user_id', user.id)
        .eq('status', 'confirmed')
        .order('registered_at', ascending: false);

    return (response as List)
        .map((json) => TicketModel.fromJson(json))
        .toList();
  }

  List<TicketModel> _filterTickets(List<TicketModel> tickets) {
    if (_selectedTab == 2) return tickets;

    final now = DateTime.now();
    return tickets.where((ticket) {
      final event = ticket.event;
      if (event == null) return false;

      final isUpcoming = event.startDate.isAfter(now);
      final isCompleted =
          event.status == 'completed' || ticket.attendedAt != null;

      if (_selectedTab == 0) return isUpcoming;
      return isCompleted;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _ticketsFuture = _loadTickets();
          });
          await _ticketsFuture;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Saya',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kelola event yang telah kamu daftarkan di sini.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                _buildSimpleTab(context, 'Mendatang', _selectedTab == 0, () {
                  setState(() => _selectedTab = 0);
                }),
                const SizedBox(width: 12),
                _buildSimpleTab(context, 'Riwayat', _selectedTab == 1, () {
                  setState(() => _selectedTab = 1);
                }),
                const SizedBox(width: 12),
                _buildSimpleTab(context, 'Semua', _selectedTab == 2, () {
                  setState(() => _selectedTab = 2);
                }),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Tiket Terdaftar'),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<TicketModel>>(
              future: _ticketsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('Gagal memuat data: ${snapshot.error}'),
                    ),
                  );
                }

                final tickets = _filterTickets(snapshot.data ?? []);
                if (tickets.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    final event =
                        ticket.event ??
                        EventModel(
                          id: '-1',
                          title: 'Event',
                          slug: 'event',
                          description: '- ',
                          startDate: DateTime.now(),
                          endDate: DateTime.now(),
                          startTime: '00:00:00',
                          endTime: '00:00:00',
                          locationName: '-',
                        );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EventCard(
                          event: event,
                          enableHero: false,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.eventDetail,
                              arguments: event,
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'Status: ${ticket.status.toUpperCase()}',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemCount: tickets.length,
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSimpleTab(
    BuildContext context,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.divider,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.event_busy_rounded, size: 80, color: AppColors.divider),
          const SizedBox(height: 24),
          Text(
            'Belum ada event terdaftar',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('Cari event menarik di halaman Home!'),
        ],
      ),
    );
  }
}
