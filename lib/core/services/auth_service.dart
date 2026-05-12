import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String namaLengkap,
    required String nim,
    required String programStudi,
    required int angkatan,
  }) async {
    try {
      if (!email.endsWith('@students.universitasmulia.ac.id')) {
        return {
          'success': false,
          'message': 'Gunakan email kampus (@students.universitasmulia.ac.id)',
        };
      }

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': namaLengkap},
      );

      final user = response.user;
      if (user == null) {
        return {
          'success': false,
          'message': 'Registrasi gagal. User tidak ditemukan.',
        };
      }

      if (response.session == null) {
        await _client.auth.signInWithPassword(email: email, password: password);
      }

      await _client
          .from('profiles')
          .update({
            'nim': nim,
            'major': programStudi,
            'academic_year': angkatan.toString(),
          })
          .eq('id', user.id)
          .select()
          .single();

      return {
        'success': true,
        'message': 'Registrasi berhasil.',
        'user': user.toJson(),
      };
    } on AuthException catch (e) {
      final rawMessage = e.message.toLowerCase();
      String friendlyMessage = e.message;

      if (rawMessage.contains('already registered') ||
          rawMessage.contains('user already exists')) {
        friendlyMessage = 'Email sudah digunakan.';
      }

      return {'success': false, 'message': friendlyMessage};
    } on PostgrestException catch (e) {
      final rawMessage = e.message.toLowerCase();
      String friendlyMessage = e.message;

      if (rawMessage.contains('duplicate') || rawMessage.contains('unique')) {
        friendlyMessage = 'NIM sudah digunakan.';
      }

      return {'success': false, 'message': friendlyMessage};
    } catch (_) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan. Silakan coba lagi.',
      };
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);

      return {
        'success': true,
        'message': 'Link reset telah dikirim ke email kamu.',
      };
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (redirectTo != null &&
          redirectTo.isNotEmpty &&
          (message.contains('redirect') || message.contains('url'))) {
        try {
          await _client.auth.resetPasswordForEmail(email);
          return {
            'success': true,
            'message':
                'Link reset terkirim. Pastikan redirect URL sudah benar.',
          };
        } catch (_) {
          return {'success': false, 'message': e.message};
        }
      }
      return {'success': false, 'message': e.message};
    } catch (_) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan. Silakan coba lagi.',
      };
    }
  }
}
