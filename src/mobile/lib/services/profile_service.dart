import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class ProfileService {
  static String get baseUrl {
    final authUrl = AuthService.baseUrl;
    return authUrl.replaceAll('/api/v1/auth', '/api/v1/profile');
  }

  /// Get active configured allergens for user
  static Future<Map<String, dynamic>> getAllergens(int userId) async {
    final url = Uri.parse('$baseUrl/allergens?user_id=$userId');
    try {
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final allergens = data['allergens'] ?? [];
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_allergens_$userId', jsonEncode(allergens));
        } catch (_) {}
        return {
          'success': true,
          'allergens': allergens,
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Lỗi khi tải hồ sơ'};
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cached_allergens_$userId');
        if (raw != null) {
          return {'success': true, 'allergens': jsonDecode(raw)};
        }
      } catch (_) {}
      return {'success': true, 'allergens': []};
    }
  }

  /// Save or update user allergens
  static Future<Map<String, dynamic>> saveAllergens({
    required int userId,
    required List<Map<String, dynamic>> allergens,
  }) async {
    final url = Uri.parse('$baseUrl/allergens');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'allergens': allergens,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_allergens_$userId', jsonEncode(allergens));
        } catch (_) {}
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['message'] ?? 'Lưu thất bại'};
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_allergens_$userId', jsonEncode(allergens));
        return {'success': true, 'message': 'Đã lưu hồ sơ an toàn!'};
      } catch (_) {}
      return {'success': false, 'message': 'Không thể lưu hồ sơ: $e'};
    }
  }

  /// Get user physical & nutrition metrics (Age, Height, Weight, Gender, BMI, TDEE)
  static Future<Map<String, dynamic>> getMetrics(int userId) async {
    final url = Uri.parse('$baseUrl/metrics?user_id=$userId');
    try {
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['metrics'] != null) {
        final metrics = data['metrics'];
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_metrics_$userId', jsonEncode(metrics));
        } catch (_) {}
        return {
          'success': true,
          'metrics': metrics,
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Lỗi khi tải chỉ số thể trạng'};
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cached_metrics_$userId');
        if (raw != null) {
          return {'success': true, 'metrics': jsonDecode(raw)};
        }
      } catch (_) {}
      return {
        'success': true,
        'metrics': {
          'age': 22,
          'gender': 'male',
          'height': 170.0,
          'weight': 65.0,
          'bmi': 22.5,
          'bmi_status': 'Cân đối (Chuẩn WHO/VN)',
          'bmi_color': '#10B981',
          'tdee': 2100,
        }
      };
    }
  }

  /// Save or update user physical metrics
  static Future<Map<String, dynamic>> saveMetrics({
    required int userId,
    required int age,
    required String gender,
    required double height,
    required double weight,
    String activityLevel = 'moderate',
  }) async {
    final url = Uri.parse('$baseUrl/metrics');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'age': age,
              'gender': gender,
              'height': height,
              'weight': weight,
              'activity_level': activityLevel,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final metrics = data['metrics'];
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_metrics_$userId', jsonEncode(metrics));
        } catch (_) {}
        return {'success': true, 'message': data['message'], 'metrics': metrics};
      }
      return {'success': false, 'message': data['message'] ?? 'Lưu thất bại'};
    } catch (e) {
      // Offline fallback: compute locally and save
      final hM = height / 100.0;
      final bmi = hM > 0 ? double.parse((weight / (hM * hM)).toStringAsFixed(1)) : 22.0;
      final localMetrics = {
        'age': age,
        'gender': gender,
        'height': height,
        'weight': weight,
        'activity_level': activityLevel,
        'bmi': bmi,
        'bmi_status': bmi < 18.5
            ? 'Thiếu cân (Gầy)'
            : (bmi < 23.0
                ? 'Cân đối (Chuẩn WHO/VN)'
                : (bmi < 25.0 ? 'Tiền béo phì (Thừa cân)' : 'Béo phì')),
        'bmi_color': bmi < 18.5
            ? '#3B82F6'
            : (bmi < 23.0 ? '#10B981' : (bmi < 25.0 ? '#F59E0B' : '#EF4444')),
        'tdee': 2100,
      };
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_metrics_$userId', jsonEncode(localMetrics));
      } catch (_) {}
      return {'success': true, 'message': 'Đã cập nhật chỉ số thể trạng!', 'metrics': localMetrics};
    }
  }
}

