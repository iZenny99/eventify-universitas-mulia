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

  Widget _buildHeader(TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FutureBuilder<Map<String, String?>>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  final avatarUrl = snapshot.data?['avatar'];
                  final name = snapshot.data?['name'] ?? '-';
                  return CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '-',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<Map<String, String?>>(
                      future: _profileFuture,
                      builder: (context, snapshot) {
                        final name = snapshot.data?['name'] ?? '-';
                        return Text(
                          'Halo, $name',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Temukan, daftar, dan simpan event kampus dengan tampilan yang lebih bersih.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
                icon: Stack(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textPrimary,
                      size: 28,
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: TextField(
              readOnly: true,
              onTap: () => Navigator.pushNamed(context, '/search'),
              decoration: InputDecoration(
                hintText: 'Cari event, workshop, seminar...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(textTheme),
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _profileFuture = _loadProfileData();
                _refreshKey++;
              });
              await _loadCategories();
            },
            child: FutureBuilder<List<EventModel>>(
              key: ValueKey('$_selectedCategoryIndex-$_refreshKey'),
              future: _eventRepository.getUpcomingEvents(
                category: _categories[_selectedCategoryIndex],
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: const [
                      SizedBox(height: 72),
                      Center(child: CircularProgressIndicator()),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      const SizedBox(height: 72),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text('Gagal memuat event: ${snapshot.error}'),
                        ),
                      ),
                    ],
                  );
                }

                final events = snapshot.data ?? [];

                if (events.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: const [
                      SizedBox(height: 72),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('Belum ada event mendatang.'),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
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
          ),
        ),
      ],
    );
  }
}
