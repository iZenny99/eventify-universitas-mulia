class NimParser {
  static const Map<String, String> _prodiMap = {
    // Fakultas Ilmu Komputer
    '11': 'Informatika (S1)',
    '12': 'Teknologi Informasi (S1)',
    '13': 'Sistem Informasi (S1)',
    // Fakultas Ekonomi dan Bisnis
    '21': 'Akuntansi (S1)',
    '22': 'Manajemen (S1)',
    // Fakultas Humaniora dan Kesehatan
    '31': 'Hukum (S1)',
    '32': 'Pendidikan Guru Anak Usia Dini (PG PAUD S1)',
    '33': 'Farmasi (S1)',
  };

  static const Map<String, String> _fakultasMap = {
    '11': 'Fakultas Ilmu Komputer',
    '12': 'Fakultas Ilmu Komputer',
    '13': 'Fakultas Ilmu Komputer',
    '21': 'Fakultas Ekonomi dan Bisnis',
    '22': 'Fakultas Ekonomi dan Bisnis',
    '31': 'Fakultas Humaniora dan Kesehatan',
    '32': 'Fakultas Humaniora dan Kesehatan',
    '33': 'Fakultas Humaniora dan Kesehatan',
  };

  final String nim;

  NimParser(this.nim);

  bool get isValidLength => nim.length == 7;
  bool get isNumeric => int.tryParse(nim) != null;

  String? get yearCode => isValidLength ? nim.substring(0, 2) : null;
  String? get prodiCode => isValidLength ? nim.substring(2, 4) : null;
  String? get sequence => isValidLength ? nim.substring(4, 7) : null;

  bool get isValidProdi => _prodiMap.containsKey(prodiCode);

  bool get isValid => isValidLength && isNumeric && isValidProdi;

  String get angkatan {
    if (yearCode == null) return '-';
    final yy = int.tryParse(yearCode!) ?? 0;
    return (2000 + yy).toString();
  }

  String get programStudi {
    return _prodiMap[prodiCode] ?? 'Kode prodi pada NIM tidak valid.';
  }

  String get fakultas {
    return _fakultasMap[prodiCode] ?? '-';
  }

  String get emailKampus {
    if (!isValid) return '';
    return '$nim@student.universitasmulia.ac.id';
  }
}
