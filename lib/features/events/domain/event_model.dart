class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.organizer,
    required this.date,
    required this.location,
    required this.category,
    required this.posterUrl,
    required this.quota,
    required this.description,
  });

  final String id;
  final String title;
  final String organizer;
  final DateTime date;
  final String location;
  final String category;
  final String posterUrl;
  final int quota;
  final String description;
}
