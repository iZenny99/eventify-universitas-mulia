class EventComment {
  const EventComment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.commentText,
    this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.userFullName,
    this.userAvatarUrl,
  });

  final String id;
  final String eventId;
  final String userId;
  final String commentText;
  final int? rating;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String? userFullName;
  final String? userAvatarUrl;

  factory EventComment.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;

    return EventComment(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      commentText: json['comment_text'] as String,
      rating: json['rating'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      userFullName: profile?['full_name'] as String?,
      userAvatarUrl: profile?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'comment_text': commentText,
      'rating': rating,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }
}
