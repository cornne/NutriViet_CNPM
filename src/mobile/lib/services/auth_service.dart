import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Production Cloud Backend API (PythonAnywhere)
  static const String baseUrl = 'https://ngobinh2006.pythonanywhere.com/api/v1/auth';

  /// Register new user account
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/register');

    try {
      debugPrint('[AUTH] POST $url');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': fullName.trim(),
              'email': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[AUTH] Register response code: ${response.statusCode}, body: ${response.body}');

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        return {
          'success': false,
          'message': 'Lỗi máy chủ (${response.statusCode}).',
        };
      }

      if (response.statusCode == 201) {
        return {
          'success': true,
          'requires_verification': data['requires_verification'] ?? true,
          'message': data['message'] ?? 'Vui lòng kiểm tra email để kích hoạt tài khoản.',
          'user': data['user']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Đăng ký không thành công',
          'code': data['code'] ?? 'REGISTRATION_FAILED',
        };
      }
    } catch (e) {
      debugPrint('[AUTH REGISTER ERROR] $e');
      return {
        'success': false,
        'message': 'Không thể kết nối tới máy chủ. Vui lòng kiểm tra kết nối mạng hoặc DNS của máy ảo.',
        'error': e.toString(),
      };
    }
  }

  /// Authenticate existing user with strict email verification gate
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      debugPrint('[AUTH] POST $url');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[AUTH] Login response code: ${response.statusCode}, body: ${response.body}');

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        return {
          'success': false,
          'message': 'Lỗi phản hồi máy chủ (${response.statusCode}).',
        };
      }

      if (response.statusCode == 200) {
        await _saveSession(data['token'], data['user']);
        return {'success': true, 'user': data['user']};
      } else if (response.statusCode == 403 || data['code'] == 'EMAIL_NOT_VERIFIED') {
        return {
          'success': false,
          'code': 'EMAIL_NOT_VERIFIED',
          'message': data['message'] ?? 'Tài khoản chưa được kích hoạt qua email.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Email hoặc mật khẩu không chính xác.',
          'code': data['code'] ?? 'AUTH_FAILED',
        };
      }
    } catch (e) {
      debugPrint('[AUTH LOGIN ERROR] $e');
      return {
        'success': false,
        'message': 'Không thể kết nối tới máy chủ. Vui lòng kiểm tra kết nối mạng hoặc DNS máy ảo.',
        'error': e.toString(),
      };
    }
  }

  /// Resend verification email
  static Future<Map<String, dynamic>> resendVerification({required String email}) async {
    final url = Uri.parse('$baseUrl/resend-verification');

    try {
      debugPrint('[AUTH] POST $url');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Đã gửi lại link xác thực vào hộp thư của bạn.',
      };
    } catch (e) {
      debugPrint('[AUTH RESEND ERROR] $e');
      return {
        'success': false,
        'message': 'Không thể kết nối tới máy chủ khi gửi lại email.',
      };
    }
  }

  /// Request password recovery (Forgot Password)
  static Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final url = Uri.parse('$baseUrl/forgot-password');

    try {
      debugPrint('[AUTH] POST $url');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Đã gửi hướng dẫn khôi phục mật khẩu vào hộp thư Gmail của bạn.',
      };
    } catch (e) {
      debugPrint('[AUTH FORGOT PWD ERROR] $e');
      return {
        'success': false,
        'message': 'Không thể kết nối tới máy chủ khi yêu cầu khôi phục mật khẩu.',
      };
    }
  }

  /// Change Password (Supports both current normal password and temporary password from email)
  static Future<Map<String, dynamic>> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/change-password');

    try {
      debugPrint('[AUTH] POST $url');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Đổi mật khẩu thành công!' : 'Đổi mật khẩu thất bại.'),
      };
    } catch (e) {
      debugPrint('[AUTH CHANGE PWD ERROR] $e');
      return {
        'success': false,
        'message': 'Không thể kết nối máy chủ để đổi mật khẩu ($e).',
      };
    }
  }

  /// Update user full name
  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String fullName,
  }) async {
    final url = Uri.parse('$baseUrl/update-profile');

    try {
      debugPrint('[AUTH] POST $url');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'full_name': fullName.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', fullName.trim());
        return {
          'success': true,
          'message': data['message'] ?? 'Cập nhật thông tin thành công!',
          'user': data['user'],
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Cập nhật thất bại.',
      };
    } catch (e) {
      debugPrint('[AUTH UPDATE PROFILE ERROR] $e');
      return {
        'success': false,
        'message': 'Không thể kết nối máy chủ để cập nhật thông tin.',
      };
    }
  }

  static Future<void> _saveSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_name', user['full_name'] ?? '');
    await prefs.setString('user_email', user['email'] ?? '');
    await prefs.setInt('user_id', user['id'] is int ? user['id'] : int.tryParse(user['id'].toString()) ?? 0);
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return null;
    return {
      'token': token,
      'full_name': prefs.getString('user_name') ?? '',
      'email': prefs.getString('user_email') ?? '',
      'id': prefs.getInt('user_id') ?? 0,
    };
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
