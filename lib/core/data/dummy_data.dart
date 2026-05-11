import '../../features/attendance/domain/ticket_model.dart';
import '../../features/certificates/domain/certificate_model.dart';
import '../../features/events/domain/event_model.dart';
import '../models/user_profile.dart';

class DummyData {
  static const List<String> categories = <String>[
    'Seminar',
    'Workshop',
    'Competition',
    'Festival',
    'Career',
  ];

  static final List<EventModel> events = <EventModel>[
    EventModel(
      id: 'ev-001',
      title: 'Future Tech Summit 2026',
      slug: 'future-tech-summit-2026',
      organizerName: 'BEM Universitas Mulia',
      startDate: DateTime(2026, 5, 22),
      endDate: DateTime(2026, 5, 22),
      startTime: '09:00:00',
      endTime: '15:00:00',
      locationName: 'Auditorium Utama',
      categoryName: 'Seminar',
      posterUrl:
          'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=800&q=80',
      maxParticipants: 300,
      status: 'published',
      description:
          'Temu wicara teknologi masa depan bersama praktisi industri dan alumni. Bahas AI, cloud, dan peluang karier di 2026.',
    ),
    EventModel(
      id: 'ev-002',
      title: 'UI/UX Sprint Camp',
      slug: 'ui-ux-sprint-camp',
      organizerName: 'HIMTI',
      startDate: DateTime(2026, 6, 2),
      endDate: DateTime(2026, 6, 3),
      startTime: '08:00:00',
      endTime: '17:00:00',
      locationName: 'Lab Desain 2',
      categoryName: 'Workshop',
      posterUrl:
          'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=900&q=80',
      maxParticipants: 80,
      status: 'published',
      description:
          'Pelatihan intensif 2 hari untuk membangun desain produk digital yang rapi, modern, dan siap portofolio.',
    ),
    EventModel(
      id: 'ev-003',
      title: 'Hackathon Mulia 48H',
      slug: 'hackathon-mulia-48h',
      organizerName: 'Tech Community UM',
      startDate: DateTime(2026, 6, 15),
      endDate: DateTime(2026, 6, 17),
      startTime: '10:00:00',
      endTime: '10:00:00',
      locationName: 'Innovation Hub',
      categoryName: 'Competition',
      posterUrl:
          'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=850&q=80',
      maxParticipants: 120,
      status: 'published',
      description:
          'Kompetisi membangun solusi digital untuk kampus selama 48 jam. Bawa tim terbaikmu dan raih hadiah menarik.',
    ),
    EventModel(
      id: 'ev-004',
      title: 'Mulia Career Expo',
      slug: 'mulia-career-expo',
      organizerName: 'CDC Universitas Mulia',
      startDate: DateTime(2026, 7, 5),
      endDate: DateTime(2026, 7, 5),
      startTime: '08:00:00',
      endTime: '16:00:00',
      locationName: 'Hall Utama',
      categoryName: 'Career',
      posterUrl:
          'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=820&q=80',
      maxParticipants: 500,
      status: 'published',
      description:
          'Bertemu langsung dengan perusahaan partner kampus. Ada sesi coaching CV dan interview simulasi.',
    ),
    EventModel(
      id: 'ev-005',
      title: 'Festival Kreatif Mahasiswa',
      slug: 'festival-kreatif-mahasiswa',
      organizerName: 'UKM Kreatif',
      startDate: DateTime(2026, 7, 18),
      endDate: DateTime(2026, 7, 18),
      startTime: '15:00:00',
      endTime: '22:00:00',
      locationName: 'Lapangan Kampus',
      categoryName: 'Festival',
      posterUrl:
          'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=880&q=80',
      maxParticipants: 1000,
      status: 'published',
      description:
          'Panggung karya mahasiswa: musik, film pendek, seni visual, dan booth komunitas kreatif.',
    ),
  ];

  static final List<EventModel> myEvents = <EventModel>[events[0], events[1]];

  static const UserProfile profile = UserProfile(
    id: 'dummy-usr-123',
    fullName: 'Adryo Faresy',
    email: 'adryo.faresy@universitasmulia.ac.id',
    nim: '21111001',
    faculty: 'Fakultas Ilmu Komputer',
    major: 'Informatika',
    academicYear: '2023',
  );

  static final List<TicketModel> tickets = myEvents
      .map(
        (event) => TicketModel(
          id: 'tkt-${event.id}',
          eventId: event.id,
          userId: profile.id,
          event: event,
          status: 'confirmed',
          qrCode: '${event.id.toUpperCase()}-${profile.nim}',
        ),
      )
      .toList();

  static final List<CertificateModel> certificates = <CertificateModel>[
    CertificateModel(
      id: 'cert-001',
      title: 'Sertifikat Partisipasi',
      eventName: 'Future Tech Summit 2026',
      certificateUrl: 'https://example.com/cert-001.pdf',
      issuedAt: DateTime(2026, 5, 23),
    ),
    CertificateModel(
      id: 'cert-002',
      title: 'Sertifikat Peserta',
      eventName: 'UI/UX Sprint Camp',
      certificateUrl: 'https://example.com/cert-002.pdf',
      issuedAt: DateTime(2026, 6, 3),
    ),
  ];
}
