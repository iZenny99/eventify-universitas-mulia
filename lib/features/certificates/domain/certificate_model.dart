class CertificateModel {
  const CertificateModel({
    required this.id,
    required this.title,
    required this.eventName,
    required this.issuedAt,
  });

  final String id;
  final String title;
  final String eventName;
  final DateTime issuedAt;
}
