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

      await _processMentions(commentText, eventId, userId);

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
  }) async {
    try {
      final response = await _supabase
          .from(AppTables.eventComments)
          .update({'comment_text': commentText.trim()})
          .eq('id', commentId)
          .eq('user_id', userId)
          .select('*, profiles(full_name, avatar_url)')
          .single();

      await _processMentions(commentText, eventId, userId);

      return EventComment.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _processMentions(
    String text,
    String eventId,
    String senderId,
  ) async {
    try {
      final RegExp mentionRegex = RegExp(r'@(\w+)');
      final Iterable<Match> matches = mentionRegex.allMatches(text);
      if (matches.isEmpty) return;

      final List<String> mentionedNames =
          matches.map((m) => m.group(1)!).toList();

      for (String name in mentionedNames) {
        final profilesResponse = await _supabase
            .from(AppTables.profiles)
            .select('id')
            .ilike('full_name', '%$name%')
            .limit(1)
            .maybeSingle();

        if (profilesResponse != null) {
          final targetUserId = profilesResponse['id'] as String;
          if (targetUserId != senderId) {
            await _supabase.from(AppTables.notifications).insert({
              'user_id': targetUserId,
              'message': 'Kamu telah ditandai dalam sebuah komentar.',
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
