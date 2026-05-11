class CertificateModel {
  const CertificateModel({
    required this.id,
    this.registrationId,
    this.userId,
    this.eventId,
    required this.title,
    required this.certificateUrl,
    required this.issuedAt,
    this.eventName,
  });

  final String id;
  final String? registrationId;
  final String? userId;
  final String? eventId;
  final String title;
  final String certificateUrl;
  final DateTime issuedAt;
  final String? eventName; // For UI display

  factory CertificateModel.fromJson(Map<String, dynamic> json) {
    return CertificateModel(
      id: json['id'] as String,
      registrationId: json['registration_id'] as String?,
      userId: json['user_id'] as String?,
      eventId: json['event_id'] as String?,
      title: json['title'] as String,
      certificateUrl: json['certificate_url'] as String,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      eventName: json['events']?['title'] as String?, // Nested query
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'registration_id': registrationId,
      'user_id': userId,
      'event_id': eventId,
      'title': title,
      'certificate_url': certificateUrl,
      'issued_at': issuedAt.toIso8601String(),
    };
  }
}

