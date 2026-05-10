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
      organizer: 'BEM Universitas Mulia',
      date: DateTime(2026, 5, 22),
      location: 'Auditorium Utama',
      category: 'Seminar',
      posterUrl:
          'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=800&q=80',
      quota: 300,
      description:
          'Temu wicara teknologi masa depan bersama praktisi industri dan alumni. Bahas AI, cloud, dan peluang karier di 2026.',
    ),
    EventModel(
      id: 'ev-002',
      title: 'UI/UX Sprint Camp',
      organizer: 'HIMTI',
      date: DateTime(2026, 6, 2),
      location: 'Lab Desain 2',
      category: 'Workshop',
      posterUrl:
          'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=900&q=80',
      quota: 80,
      description:
          'Pelatihan intensif 2 hari untuk membangun desain produk digital yang rapi, modern, dan siap portofolio.',
    ),
    EventModel(
      id: 'ev-003',
      title: 'Hackathon Mulia 48H',
      organizer: 'Tech Community UM',
      date: DateTime(2026, 6, 15),
      location: 'Innovation Hub',
      category: 'Competition',
      posterUrl:
          'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=850&q=80',
      quota: 120,
      description:
          'Kompetisi membangun solusi digital untuk kampus selama 48 jam. Bawa tim terbaikmu dan raih hadiah menarik.',
    ),
    EventModel(
      id: 'ev-004',
      title: 'Mulia Career Expo',
      organizer: 'CDC Universitas Mulia',
      date: DateTime(2026, 7, 5),
      location: 'Hall Utama',
      category: 'Career',
      posterUrl:
          'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=820&q=80',
      quota: 500,
      description:
          'Bertemu langsung dengan perusahaan partner kampus. Ada sesi coaching CV dan interview simulasi.',
    ),
    EventModel(
      id: 'ev-005',
      title: 'Festival Kreatif Mahasiswa',
      organizer: 'UKM Kreatif',
      date: DateTime(2026, 7, 18),
      location: 'Lapangan Kampus',
      category: 'Festival',
      posterUrl:
          'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=880&q=80',
      quota: 1000,
      description:
          'Panggung karya mahasiswa: musik, film pendek, seni visual, dan booth komunitas kreatif.',
    ),
  ];

  static final List<EventModel> myEvents = <EventModel>[events[0], events[1]];

  static const UserProfile profile = UserProfile(
    name: 'Adryo Faresy',
    email: 'adryo.faresy@universitasmulia.ac.id',
    nim: '21111001',
    faculty: 'Fakultas Ilmu Komputer',
    major: 'Informatika',
    year: '2023',
  );

  static final List<TicketModel> tickets = myEvents
      .map(
        (event) => TicketModel(
          event: event,
          qrCode: '${event.id.toUpperCase()}-${profile.nim}',
        ),
      )
      .toList();

  static final List<CertificateModel> certificates = <CertificateModel>[
    CertificateModel(
      id: 'cert-001',
      title: 'Sertifikat Partisipasi',
      eventName: 'Future Tech Summit 2026',
      issuedAt: DateTime(2026, 5, 23),
    ),
    CertificateModel(
      id: 'cert-002',
      title: 'Sertifikat Peserta',
      eventName: 'UI/UX Sprint Camp',
      issuedAt: DateTime(2026, 6, 3),
    ),
  ];
}
