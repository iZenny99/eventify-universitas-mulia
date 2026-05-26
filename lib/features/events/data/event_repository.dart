import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/supabase_tables.dart';
import '../domain/event_model.dart';

class EventRepository {
  static final ValueNotifier<Map<String, dynamic>?> bookmarkToggleNotifier = ValueNotifier(null);
  
  final _supabase = Supabase.instance.client;

  Future<List<EventModel>> getUpcomingEvents({String? category}) async {
    try {
      var query = _supabase.from(AppTables.upcomingEvents).select();

      if (category != null && category != 'Semua') {
        query = query.eq('category_name', category);
      }

      final response = await query.order('start_date', ascending: true);

      return (response as List)
          .map((json) => EventModel.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getCategories() async {
    try {
      final response = await _supabase
          .from(AppTables.categories)
          .select('name')
          .eq('is_active', true)
          .order('name');

      final names = (response as List).map((e) => e['name'] as String).toList();
      return ['Semua', ...names];
    } catch (e) {
      return ['Semua'];
    }
  }

  Future<List<EventModel>> getFeaturedEvents() async {
    try {
      final response = await _supabase
          .from(AppTables.events)
          .select()
          .eq('status', 'published')
          .not('banner_url', 'is', null)
          .order('created_at', ascending: false)
          .limit(5);

      return (response as List)
          .map((json) => EventModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<EventModel>> searchEvents({
    String? query,
    String? category,
    String? status, // 'aktif' or 'selesai'
  }) async {
    try {
      var req = _supabase.from(AppTables.upcomingEvents).select();

      if (category != null && category != 'Semua') {
        req = req.eq('category_name', category);
      }
      
      if (query != null && query.trim().isNotEmpty) {
        req = req.or('title.ilike.%${query.trim()}%,location_name.ilike.%${query.trim()}%');
      }

      if (status == 'aktif') {
        req = req.gte('end_date', DateTime.now().toIso8601String());
      } else if (status == 'selesai') {
        req = req.lt('end_date', DateTime.now().toIso8601String());
      }

      final response = await req.order('start_date', ascending: true);
      return (response as List).map((e) => EventModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> checkIsBookmarked(String eventId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _supabase
          .from(AppTables.eventBookmarks)
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', user.id)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleBookmark(String eventId, bool isCurrentlyBookmarked) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      if (isCurrentlyBookmarked) {
        await _supabase
            .from(AppTables.eventBookmarks)
            .delete()
            .eq('event_id', eventId)
            .eq('user_id', user.id);
        bookmarkToggleNotifier.value = {'eventId': eventId, 'isBookmarked': false};
        return false;
      } else {
        await _supabase.from(AppTables.eventBookmarks).insert({
          'event_id': eventId,
          'user_id': user.id,
        });
        bookmarkToggleNotifier.value = {'eventId': eventId, 'isBookmarked': true};
        return true;
      }
    } catch (_) {
      // Revert state if failed
      return isCurrentlyBookmarked;
    }
  }
}
