class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.slug,
    this.shortDescription,
    required this.description,
    this.posterUrl,
    this.bannerUrl,
    this.categoryId,
    this.organizerId,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.locationName,
    this.locationAddress,
    this.isOnline = false,
    this.meetingUrl,
    this.maxParticipants,
    this.status = 'draft',
    this.isPaid = false,
    this.price = 0.0,
    this.categoryName,
    this.organizerName,
  });

  final String id;
  final String title;
  final String slug;
  final String? shortDescription;
  final String description;
  final String? posterUrl;
  final String? bannerUrl;
  final String? categoryId;
  final String? organizerId;
  final DateTime startDate;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final String locationName;
  final String? locationAddress;
  final bool isOnline;
  final String? meetingUrl;
  final int? maxParticipants;
  final String status;
  final bool isPaid;
  final double price;
  
  // From views
  final String? categoryName;
  final String? organizerName;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      shortDescription: json['short_description'] as String?,
      description: json['description'] as String,
      posterUrl: json['poster_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      categoryId: json['category_id'] as String?,
      organizerId: json['organizer_id'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      locationName: json['location_name'] as String,
      locationAddress: json['location_address'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      meetingUrl: json['meeting_url'] as String?,
      maxParticipants: json['max_participants'] as int?,
      status: json['status'] as String? ?? 'draft',
      isPaid: json['is_paid'] as bool? ?? false,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      categoryName: json['category_name'] as String?,
      organizerName: json['organizer_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'short_description': shortDescription,
      'description': description,
      'poster_url': posterUrl,
      'banner_url': bannerUrl,
      'category_id': categoryId,
      'organizer_id': organizerId,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'start_time': startTime,
      'end_time': endTime,
      'location_name': locationName,
      'location_address': locationAddress,
      'is_online': isOnline,
      'meeting_url': meetingUrl,
      'max_participants': maxParticipants,
      'status': status,
      'is_paid': isPaid,
      'price': price,
    };
  }
}
