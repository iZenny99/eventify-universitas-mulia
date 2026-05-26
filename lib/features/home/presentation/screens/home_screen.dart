import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/category_chip.dart';
import '../../../../shared/widgets/event_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../events/domain/event_model.dart';
import '../../../events/data/event_repository.dart';
import 'root_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategoryIndex = 0;
  int _refreshKey = 0;
  late Future<Map<String, String?>> _profileFuture;
  final EventRepository _eventRepository = EventRepository();

  List<String> _categories = ['Semua'];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileData();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _eventRepository.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  Future<Map<String, String?>> _loadProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {'name': '-', 'avatar': null};

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return {'name': '-', 'avatar': null};
      final name = (data['full_name'] as String?)?.trim();
      return {
        'name': (name != null && name.isNotEmpty) ? name : '-',
        'avatar': data['avatar_url'] as String?,
      };
    } catch (e) {
      return {'name': '-', 'avatar': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _profileFuture = _loadProfileData();
          _refreshKey++;
        });
        await _loadCategories();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Header with Gradient
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
                  // Row for Profile and Notifications
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<Map<String, String?>>(
                              future: _profileFuture,
                              builder: (context, snapshot) {
                                final name = snapshot.data?['name'] ?? '-';
                                return Text(
                                  'Halo, $name! 👋',
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Siap menjelajahi event kampus hari ini?',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notifications & Avatar
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                            icon: Stack(
                              children: [
                                const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<Map<String, String?>>(
                            future: _profileFuture,
                            builder: (context, snapshot) {
                              final avatarUrl = snapshot.data?['avatar'];
                              return InkWell(
                                onTap: () {
                                  RootScreen.of(context)?.changeTab(4);
                                },
                                borderRadius: BorderRadius.circular(100),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                        ? CachedNetworkImageProvider(avatarUrl)
                                        : null,
                                    child: (avatarUrl == null || avatarUrl.isEmpty)
                                        ? const Icon(
                                            Icons.person_rounded,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Search Bar inside Header
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      readOnly: true,
                      onTap: () => Navigator.pushNamed(context, '/search'),
                      decoration: InputDecoration(
                        hintText: 'Cari event, workshop, seminar...',
                        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Kategori Populer'),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 48,
              child: _isLoadingCategories
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        return CategoryChip(
                          label: _categories[index],
                          selected: index == _selectedCategoryIndex,
                          onTap: () =>
                              setState(() => _selectedCategoryIndex = index),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemCount: _categories.length,
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Rekomendasi Untukmu'),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<EventModel>>(
              key: ValueKey(
                '$_selectedCategoryIndex-$_refreshKey',
              ), // Re-fetch when category changes or refreshed
              future: _eventRepository.getUpcomingEvents(
                category: _categories[_selectedCategoryIndex],
              ),
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
                      child: Text('Gagal memuat event: ${snapshot.error}'),
                    ),
                  );
                }

                final events = snapshot.data ?? [];

                if (events.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Belum ada event mendatang.'),
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
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
