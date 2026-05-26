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
    List<String> mentionedUserIds = const [],
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

      await _processMentions(mentionedUserIds, eventId, userId);

      return EventComment.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<EventComment> updateComment({
    required String commentId,
    required String userId,
    required String commentText,
    required String eventId,
    List<String> mentionedUserIds = const [],
  }) async {
    try {
      final response = await _supabase
          .from(AppTables.eventComments)
          .update({'comment_text': commentText.trim()})
          .eq('id', commentId)
          .eq('user_id', userId)
          .select('*, profiles(full_name, avatar_url)')
          .single();

      await _processMentions(mentionedUserIds, eventId, userId);

      return EventComment.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _processMentions(
    List<String> mentionedUserIds,
    String eventId,
    String senderId,
  ) async {
    try {
      if (mentionedUserIds.isEmpty) return;

      final Set<String> uniqueUserIds = mentionedUserIds.toSet();

      for (String targetUserId in uniqueUserIds) {
        if (targetUserId != senderId) {
          // Verify if user exists before sending notif
          final exists = await _supabase
              .from(AppTables.profiles)
              .select('id')
              .eq('id', targetUserId)
              .maybeSingle();
              
          if (exists != null) {
            await _supabase.from(AppTables.notifications).insert({
              'user_id': targetUserId,
              'message': 'Seseorang menyebut Anda dalam komentar acara.',
              'event_id': eventId,
            });
          }
        }
      }
    } catch (_) {
      // Ignore errors for notifications
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
      // Allow any logged-in user to comment
      return userId.isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }
}
