import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/supabase_tables.dart';
import '../domain/event_model.dart';

class EventRepository {
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

  Future<EventModel?> getFeaturedEvent() async {
    try {
      final response = await _supabase
          .from(AppTables.events)
          .select()
          .eq('status', 'published')
          .not('banner_url', 'is', null)
          .order('created_at', ascending: false)
          .limit(1);

      final rows = response as List;
      if (rows.isEmpty) return null;
      return EventModel.fromJson(rows.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
