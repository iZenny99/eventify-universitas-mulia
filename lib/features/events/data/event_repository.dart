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

      return (response as List).map((json) => EventModel.fromJson(json)).toList();
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
      // Fallback to basic categories if table is empty or error
      return ['Semua', 'Seminar', 'Workshop', 'Lomba', 'Seni'];
    }
  }
}
