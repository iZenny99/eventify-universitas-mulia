import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/supabase_tables.dart';
import '../domain/event_comment.dart';

class CommentRepository {
  CommentRepository({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<EventComment>> getCommentsByEvent(String eventId) async {
    try {
      final response = await _supabase
          .from(AppTables.eventComments)
          .select('*, profiles(full_name, avatar_url)')
          .eq('event_id', eventId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => EventComment.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<EventComment> addComment({
    required String eventId,
    required String userId,
    required String commentText,
    int? rating,
  }) async {
    try {
      final payload = {
        'event_id': eventId,
        'user_id': userId,
        'comment_text': commentText.trim(),
        'rating': rating,
      };

      final response = await _supabase
          .from(AppTables.eventComments)
          .insert(payload)
          .select('*, profiles(full_name, avatar_url)')
          .single();

      return EventComment.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteComment({
    required String commentId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from(AppTables.eventComments)
          .update({'is_deleted': true})
          .eq('id', commentId)
          .eq('user_id', userId)
          .select()
          .single();
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> canUserComment({
    required String eventId,
    required String userId,
  }) async {
    try {
      final registration = await _supabase
          .from(AppTables.registrations)
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .eq('status', 'confirmed')
          .maybeSingle();

      if (registration == null) return false;

      final event = await _supabase
          .from(AppTables.events)
          .select('status')
          .eq('id', eventId)
          .maybeSingle();

      final status = event?['status'] as String?;
      return status == 'published' ||
          status == 'ongoing' ||
          status == 'completed';
    } catch (e) {
      rethrow;
    }
  }
}
