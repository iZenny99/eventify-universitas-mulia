import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/event_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../domain/event_model.dart';
import '../../data/event_repository.dart';
import '../../../attendance/domain/ticket_model.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  int _selectedTab = 0;
  late Future<List<TicketModel>> _ticketsFuture;
  late Future<List<EventModel>> _bookmarksFuture;
  RealtimeChannel? _subscription;
  RealtimeChannel? _bookmarksSubscription;

  @override
  void initState() {
    super.initState();
    _ticketsFuture = _loadTickets();
    _bookmarksFuture = _loadBookmarks();
    _setupRealtime();
    EventRepository.bookmarkToggleNotifier.addListener(_onGlobalBookmarkToggle);
  }

  void _onGlobalBookmarkToggle() {
    final payload = EventRepository.bookmarkToggleNotifier.value;
    if (payload != null && payload['isBookmarked'] == false) {
      // If an event was unbookmarked, instantly refresh the Tersimpan tab
      if (mounted) {
        setState(() {
          _bookmarksFuture = _loadBookmarks();
        });
      }
    }
  }

  void _setupRealtime() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _subscription = Supabase.instance.client
        .channel('public:event_registrations:my_events')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'event_registrations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) {
              if (mounted) {
                setState(() {
                  _ticketsFuture = _loadTickets();
                });
              }
            })
        .subscribe();

    _bookmarksSubscription = Supabase.instance.client
        .channel('public:event_bookmarks:my_events')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'event_bookmarks',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) {
              if (mounted) {
                setState(() {
                  _bookmarksFuture = _loadBookmarks();
                });
              }
            })
        .subscribe();
  }

  @override
  void dispose() {
    EventRepository.bookmarkToggleNotifier.removeListener(_onGlobalBookmarkToggle);
    _subscription?.unsubscribe();
    _bookmarksSubscription?.unsubscribe();
    super.dispose();
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

  Future<List<EventModel>> _loadBookmarks() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await Supabase.instance.client
          .from('event_bookmarks')
          .select('*, events(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => EventModel.fromJson(json['events']))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<TicketModel> _filterTickets(List<TicketModel> tickets) {
    final now = DateTime.now();
    return tickets.where((ticket) {
      final event = ticket.event;
      if (event == null) return false;

      final dateStr = event.startDate.toIso8601String().split('T').first;
      final timeStr = event.startTime;
      DateTime startDateTime;
      try {
        startDateTime = DateTime.parse('$dateStr $timeStr');
      } catch (_) {
        startDateTime = event.startDate;
      }

      final isUpcoming = startDateTime.isAfter(now);
      final isCompleted = !isUpcoming || event.status == 'completed' || ticket.attendedAt != null;

      if (_selectedTab == 0) return isUpcoming && event.status != 'completed' && ticket.attendedAt == null;
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
            _bookmarksFuture = _loadBookmarks();
          });
          await Future.wait([_ticketsFuture, _bookmarksFuture]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Header
              Container(
                padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFEF4444), // Primary
                      Color(0xFFF59E0B), // Accent
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Event Saya',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kelola event yang telah kamu daftarkan atau simpan di sini.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tabs inside Header
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildHeaderTab('Terdaftar', 0)),
                          Expanded(child: _buildHeaderTab('Riwayat', 1)),
                          Expanded(child: _buildHeaderTab('Tersimpan', 2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: _selectedTab == 2 ? 'Event Tersimpan' : 'Tiket Event',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_selectedTab == 2) _buildBookmarksList() else _buildTicketsList(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketsList() {
    return FutureBuilder<List<TicketModel>>(
      future: _ticketsFuture,
      builder: (context, snapshot) {
        final textTheme = Theme.of(context).textTheme;
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
    );
  }

  Widget _buildBookmarksList() {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<List<EventModel>>(
      future: _bookmarksFuture,
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

        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return Center(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Icon(Icons.bookmark_border_rounded, size: 80, color: AppColors.divider),
                const SizedBox(height: 24),
                Text(
                  'Belum ada event tersimpan',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final event = events[index];
            return EventCard(
              event: event,
              enableHero: false,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.eventDetail,
                  arguments: event,
                );
              },
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemCount: events.length,
        );
      },
    );
  }

  Widget _buildHeaderTab(String text, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.7),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
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
            _selectedTab == 1 ? 'Belum ada event yang selesai' : 'Belum ada event terdaftar',
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
