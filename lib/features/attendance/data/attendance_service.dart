import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? studentData;

  AttendanceResponse(this.success, this.message, {this.studentData});
}

class AttendanceService {
  final _supabase = Supabase.instance.client;

  Future<AttendanceResponse> processQrScan(String qrDataRaw) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return AttendanceResponse(false, 'Admin belum login');

      String qrToken;
      try {
        final decoded = jsonDecode(qrDataRaw);
        qrToken = decoded['token'];
      } catch (e) {
        qrToken = qrDataRaw; // Fallback kalau bukan JSON
      }

      // 1. Cari registration berdasarkan qr_token (bisa qr_code atau id)
      final registration = await _supabase
          .from('event_registrations')
          .select('id, status, event_id, profiles(id, full_name, nim, avatar_url, major)')
          .or('qr_code.eq.$qrToken,id.eq.$qrToken')
          .maybeSingle();

      if (registration == null) {
        return AttendanceResponse(false, 'QR Code tidak valid atau tidak ditemukan');
      }

      final status = registration['status'];
      if (status == 'cancelled') {
        return AttendanceResponse(false, 'Pendaftaran untuk QR ini sudah dibatalkan');
      }
      
      final studentProfile = registration['profiles'];

      // 2. Cek apakah sudah hadir sebelumnya (menghindari double scan)
      final existingAttendance = await _supabase
          .from('event_attendance')
          .select('id')
          .eq('registration_id', registration['id'])
          .maybeSingle();

      if (existingAttendance != null || status == 'attended') {
        return AttendanceResponse(false, 'Mahasiswa ini sudah melakukan check-in sebelumnya!', studentData: studentProfile);
      }

      // 3. Masukkan ke event_attendance
      await _supabase.from('event_attendance').insert({
        'registration_id': registration['id'],
        'scanned_by': user.id,
      });

      // 4. Update status registrasi menjadi attended
      await _supabase
          .from('event_registrations')
          .update({'status': 'attended', 'attended_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', registration['id']);

      return AttendanceResponse(true, 'Check-in Berhasil!', studentData: studentProfile);
    } catch (e) {
      return AttendanceResponse(false, 'Terjadi kesalahan sistem: $e');
    }
  }
}
