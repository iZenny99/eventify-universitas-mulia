import '../../events/domain/event_model.dart';

class TicketModel {
  const TicketModel({
    required this.id,
    required this.eventId,
    required this.userId,
    this.status = 'pending',
    this.qrCode,
    this.registeredAt,
    this.confirmedAt,
    this.attendedAt,
    this.event,
  });

  final String id;
  final String eventId;
  final String userId;
  final String status;
  final String? qrCode;
  final DateTime? registeredAt;
  final DateTime? confirmedAt;
  final DateTime? attendedAt;
  final EventModel? event;

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String? ?? 'pending',
      qrCode: json['qr_code'] as String?,
      registeredAt: json['registered_at'] != null ? DateTime.parse(json['registered_at']) : null,
      confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at']) : null,
      attendedAt: json['attended_at'] != null ? DateTime.parse(json['attended_at']) : null,
      event: json['events'] != null ? EventModel.fromJson(json['events']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'status': status,
      'qr_code': qrCode,
      'registered_at': registeredAt?.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'attended_at': attendedAt?.toIso8601String(),
    };
  }
}
