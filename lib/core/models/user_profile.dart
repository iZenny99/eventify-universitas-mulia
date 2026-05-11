class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.nim,
    this.faculty,
    this.major,
    this.academicYear,
    this.phoneNumber,
    this.avatarUrl,
    this.isActive = true,
  });

  final String id;
  final String email;
  final String fullName;
  final String? nim;
  final String? faculty;
  final String? major;
  final String? academicYear;
  final String? phoneNumber;
  final String? avatarUrl;
  final bool isActive;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      nim: json['nim'] as String?,
      faculty: json['faculty'] as String?,
      major: json['major'] as String?,
      academicYear: json['academic_year'] as String?,
      phoneNumber: json['phone_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'nim': nim,
      'faculty': faculty,
      'major': major,
      'academic_year': academicYear,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'is_active': isActive,
    };
  }
}
