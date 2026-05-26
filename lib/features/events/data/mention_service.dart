import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/data/supabase_tables.dart';

class MentionUser {
  final String id;
  final String name;
  final String nim;
  final String major;
  final String? avatarUrl;

  MentionUser({
    required this.id,
    required this.name,
    required this.nim,
    required this.major,
    this.avatarUrl,
  });

  factory MentionUser.fromJson(Map<String, dynamic> json) {
    return MentionUser(
      id: json['id'] as String,
      name: json['full_name'] as String? ?? 'User',
      nim: json['nim'] as String? ?? '-',
      major: json['major'] as String? ?? '-',
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class MentionService {
  final _supabase = Supabase.instance.client;

  Future<List<MentionUser>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await _supabase
          .from(AppTables.profiles)
          .select('id, full_name, nim, major, avatar_url')
          .or('full_name.ilike.%$query%,nim.ilike.%$query%')
          .limit(10);

      return (response as List).map((json) => MentionUser.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
}
