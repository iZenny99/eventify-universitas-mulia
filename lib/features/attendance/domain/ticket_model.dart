import '../../events/domain/event_model.dart';

class TicketModel {
  const TicketModel({required this.event, required this.qrCode});

  final EventModel event;
  final String qrCode;
}
