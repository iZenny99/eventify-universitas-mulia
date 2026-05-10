import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/dummy_data.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/banner_card.dart';
import '../../../../shared/widgets/category_chip.dart';
import '../../../../shared/widgets/event_card.dart';
import '../../../../shared/widgets/section_header.dart';
import 'root_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategoryIndex = 0;
  late final Future<String> _nameFuture;

  @override
  void initState() {
    super.initState();
    _nameFuture = _loadName();
  }

  Future<String> _loadName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return '-';

    final data = await Supabase.instance.client
        .from('profiles')
        .select('nama_panjang')
        .eq('id', user.id)
        .single();

    final name = (data['nama_panjang'] as String?)?.trim();
    return (name != null && name.isNotEmpty) ? name : '-';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final categories = DummyData.categories;
    final events = DummyData.events;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String>(
                    future: _nameFuture,
                    builder: (context, snapshot) {
                      final name = snapshot.data ?? '-';
                      return Text(
                        'Halo, $name! 👋',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Siap menjelajahi event kampus hari ini?',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  // PERBAIKAN: Berpindah tab profil daripada push halaman baru agar BottomNav tidak hilang
                  RootScreen.of(context)?.changeTab(4);
                },
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.divider, // REMOVED const
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                    ), // REMOVED const
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Modern Search Bar
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari event, workshop, atau seminar...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ), // REMOVED const
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                fillColor: AppColors.surface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          const BannerCard(
            title: 'Future Tech Summit',
            subtitle: 'Workshop eksklusif mahasiswa IT',
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Kategori Populer'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                return CategoryChip(
                  label: categories[index],
                  selected: index == _selectedCategoryIndex,
                  onTap: () => setState(() => _selectedCategoryIndex = index),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: categories.length,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Rekomendasi Untukmu'),
          const SizedBox(height: AppSpacing.md),
          ListView.separated(
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
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
