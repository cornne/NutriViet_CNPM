import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_locale.dart';

class AuthService {
  // Production Cloud Backend API root (Cloudflare Workers + D1; override via --dart-define=NUTRIVIET_API_ROOT=...)
  static const String apiRoot = String.fromEnvironment(
    'NUTRIVIET_API_ROOT',
    defaultValue: 'https://nutriviet.nutriviet-api.workers.dev/api/v1',
  );
  static const String baseUrl = '$apiRoot/auth';

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
          'message': AppLocale.t(
            'Lỗi máy chủ (${response.statusCode}).',
            'Server error (${response.statusCode}).',
          ),
        };
      }

      if (response.statusCode == 201) {
        return {
          'success': true,
          'requires_verification': data['requires_verification'] ?? true,
          'message': data['message'] ??
              AppLocale.t(
                'Vui lòng kiểm tra email để kích hoạt tài khoản.',
                'Please check your email to activate your account.',
              ),
          'user': data['user']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ??
              AppLocale.t('Đăng ký không thành công', 'Registration failed'),
          'code': data['code'] ?? 'REGISTRATION_FAILED',
        };
      }
    } catch (e) {
      debugPrint('[AUTH REGISTER ERROR] $e');
      return {
        'success': false,
        'message': AppLocale.t(
          'Không thể kết nối tới máy chủ. Vui lòng kiểm tra kết nối mạng.',
          'Unable to connect to the server. Please check your internet connection.',
        ),
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
          'message': AppLocale.t(
            'Lỗi phản hồi máy chủ (${response.statusCode}).',
            'Server response error (${response.statusCode}).',
          ),
        };
      }

      if (response.statusCode == 200) {
        final rawUser = Map<String, dynamic>.from(data['user'] as Map);
        final token = (data['token'] ?? '').toString();
        rawUser['token'] = token;
        rawUser['role'] = (rawUser['role'] ?? 'user').toString();
        rawUser['is_guest'] = false;
        await _saveSession(token, rawUser);
        return {'success': true, 'token': token, 'user': rawUser};
      } else if (data['code'] == 'ACCOUNT_BANNED') {
        return {
          'success': false,
          'code': 'ACCOUNT_BANNED',
          'message': data['message'] ??
              AppLocale.t(
                'Tài khoản này đã bị quản trị viên tạm khóa.',
                'This account has been suspended by an administrator.',
              ),
        };
      } else if (response.statusCode == 403 || data['code'] == 'EMAIL_NOT_VERIFIED') {
        return {
          'success': false,
          'code': 'EMAIL_NOT_VERIFIED',
          'message': data['message'] ??
              AppLocale.t(
                'Tài khoản chưa được kích hoạt qua email.',
                'Your account has not been verified via email.',
              ),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ??
              AppLocale.t(
                'Email hoặc mật khẩu không chính xác.',
                'Incorrect email or password.',
              ),
          'code': data['code'] ?? 'AUTH_FAILED',
        };
      }
    } catch (e) {
      debugPrint('[AUTH LOGIN ERROR] $e');
      return {
        'success': false,
        'message': AppLocale.t(
          'Không thể kết nối tới máy chủ. Vui lòng kiểm tra kết nối mạng.',
          'Unable to connect to the server. Please check your internet connection.',
        ),
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
        'message': data['message'] ??
            AppLocale.t(
              'Đã gửi lại link xác thực vào hộp thư của bạn.',
              'Verification link resent to your inbox.',
            ),
      };
    } catch (e) {
      debugPrint('[AUTH RESEND ERROR] $e');
      return {
        'success': false,
        'message': AppLocale.t(
          'Không thể kết nối tới máy chủ khi gửi lại email.',
          'Unable to connect to the server while resending email.',
        ),
      };
    }
  }

  /// Request 6-digit password reset OTP via email
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
        'otp_sent': data['otp_sent'] == true,
        'message': data['message'] ??
            AppLocale.t(
              'Đã gửi mã OTP 6 chữ số vào hộp thư của bạn.',
              'A 6-digit OTP has been sent to your inbox.',
            ),
      };
    } catch (e) {
      debugPrint('[AUTH FORGOT PWD ERROR] $e');
      return {
        'success': false,
        'message': AppLocale.t(
          'Không thể kết nối tới máy chủ khi yêu cầu khôi phục mật khẩu.',
          'Unable to connect to the server for password recovery.',
        ),
      };
    }
  }

  /// Complete password reset using 6-digit email OTP
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/reset-password');

    try {
      debugPrint('[AUTH] POST $url');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'otp': otp.replaceAll(RegExp(r'\s+'), ''),
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'code': data['code'],
        'message': data['message'] ??
            (response.statusCode == 200
                ? AppLocale.t('Đặt lại mật khẩu thành công!', 'Password reset successfully!')
                : AppLocale.t('Mã OTP không hợp lệ hoặc đã hết hạn.', 'Invalid or expired OTP.')),
      };
    } catch (e) {
      debugPrint('[AUTH RESET PWD ERROR] $e');
      return {
        'success': false,
        'message': AppLocale.t(
          'Không thể kết nối tới máy chủ để đặt lại mật khẩu.',
          'Unable to connect to the server to reset password.',
        ),
      };
    }
  }

  /// Change Password (Requires active Bearer session token)
  static Future<Map<String, dynamic>> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/change-password');

    try {
      final token = await getToken();
      debugPrint('[AUTH] POST $url');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
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
        'message': data['message'] ??
            (response.statusCode == 200
                ? AppLocale.t('Đổi mật khẩu thành công!', 'Password changed successfully!')
                : AppLocale.t('Đổi mật khẩu thất bại.', 'Failed to change password.')),
      };
    } catch (e) {
      debugPrint('[AUTH CHANGE PWD ERROR] $e');
      return {
        'success': false,
        'message': AppLocale.t(
          'Không thể kết nối máy chủ để đổi mật khẩu ($e).',
          'Unable to connect to server to change password ($e).',
        ),
      };
    }
  }

  /// Update user full name (Requires active Bearer session token)
  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String fullName,
  }) async {
    final url = Uri.parse('$baseUrl/update-profile');

    try {
      final token = await getToken();
      debugPrint('[AUTH] POST $url');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
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
          'message': data['message'] ??
              AppLocale.t('Cập nhật thông tin thành công!', 'Profile updated successfully!'),
          'user': data['user'],
        };
      }
      return {
        'success': false,
        'message': data['message'] ??
            AppLocale.t('Cập nhật thất bại.', 'Failed to update profile.'),
      };
    } catch (e) {
      debugPrint('[AUTH UPDATE PROFILE ERROR] $e');
      return {
        'success': false,
        'message': AppLocale.t(
          'Không thể kết nối máy chủ để cập nhật thông tin.',
          'Unable to connect to server to update profile.',
        ),
      };
    }
  }

  static bool isGuest(Map<String, dynamic>? user) {
    if (user == null) return false;
    return user['is_guest'] == true ||
        (user['role']?.toString().toLowerCase() == 'guest') ||
        ((user['token'] ?? '').toString().isEmpty && (user['id'] == 0 || user['id'] == null));
  }

  static bool isAdmin(Map<String, dynamic>? user) {
    if (user == null || isGuest(user)) return false;
    return (user['role'] ?? '').toString().toLowerCase() == 'admin';
  }

  static Future<Map<String, dynamic>> enterGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.setBool('is_guest', true);
    await prefs.setString('user_role', 'guest');
    await prefs.setString('user_name', AppLocale.t('Khách', 'Guest'));
    await prefs.setString('user_email', '');
    await prefs.setInt('user_id', 0);
    return {
      'id': 0,
      'token': '',
      'full_name': AppLocale.t('Khách', 'Guest'),
      'email': '',
      'role': 'guest',
      'is_guest': true,
    };
  }

  static Future<void> _saveSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setBool('is_guest', false);
    await prefs.setString('user_role', (user['role'] ?? 'user').toString());
    await prefs.setString('user_name', user['full_name'] ?? '');
    await prefs.setString('user_email', user['email'] ?? '');
    await prefs.setInt(
      'user_id',
      user['id'] is int ? user['id'] : int.tryParse(user['id'].toString()) ?? 0,
    );
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuestFlag = prefs.getBool('is_guest') ?? false;
    if (isGuestFlag) {
      return {
        'id': 0,
        'token': '',
        'full_name': prefs.getString('user_name') ?? AppLocale.t('Khách', 'Guest'),
        'email': '',
        'role': 'guest',
        'is_guest': true,
      };
    }
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return null;
    return {
      'token': token,
      'full_name': prefs.getString('user_name') ?? '',
      'email': prefs.getString('user_email') ?? '',
      'id': prefs.getInt('user_id') ?? 0,
      'role': prefs.getString('user_role') ?? 'user',
      'is_guest': false,
    };
  }

  /// Returns the currently stored Bearer token (empty string for Guests / logged-out).
  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('is_guest') == true) return '';
    return (prefs.getString('auth_token') ?? '').trim();
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('auth_token') ?? '').trim();
    if (token.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse('$baseUrl/logout'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Best-effort remote session revocation; always clear local session
      }
    }
    await prefs.remove('auth_token');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('is_guest');
  }
}
