import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_locale.dart';

class ProfileService {
  static const String cloudApiRoot = 'https://ngobinh2006.pythonanywhere.com/api/v1';

  // Persistent HTTP client for TCP/keep-alive reuse across tabs and API calls.
  static final http.Client _client = http.Client();
  static String? _cachedWorkingRoot;

  /// Candidate real backend roots (local FoodOn+WSGI server first, then Cloud server).
  /// Never returns fake/mock data if unreachable.
  static List<String> get _apiRoots {
    final base = kIsWeb
        ? ['http://127.0.0.1:8050/api/v1', 'http://192.168.1.15:8050/api/v1', cloudApiRoot]
        : (defaultTargetPlatform == TargetPlatform.android
            ? [
                'http://127.0.0.1:8050/api/v1',
                'http://192.168.1.15:8050/api/v1',
                'http://10.0.2.2:8050/api/v1',
                cloudApiRoot,
              ]
            : ['http://127.0.0.1:8050/api/v1', 'http://192.168.1.15:8050/api/v1', cloudApiRoot]);
    final cached = _cachedWorkingRoot;
    if (cached != null && base.contains(cached) && base.first != cached) {
      return [cached, ...base.where((r) => r != cached)];
    }
    return base;
  }

  static Duration _timeoutForRoot(String root) {
    if (root.contains('127.0.0.1') || root.contains('192.168.')) {
      return const Duration(milliseconds: 2200);
    }
    if (root.contains('10.0.2.2')) {
      return const Duration(milliseconds: 1200);
    }
    return const Duration(seconds: 8);
  }

  static Future<dynamic> _decodeJsonBytes(Uint8List bytes) {
    // Offload large JSON payloads (e.g., FoodOn/additive lists) off the 120Hz UI isolate.
    if (!kIsWeb && bytes.length > 4096) {
      return Isolate.run(() => jsonDecode(utf8.decode(bytes)));
    }
    return Future.value(jsonDecode(utf8.decode(bytes)));
  }

  static Future<Map<String, dynamic>> _getJson(
    String subPath, {
    bool preferCloudFirst = false,
  }) async {
    final roots = preferCloudFirst
        ? [cloudApiRoot, ..._apiRoots.where((r) => r != cloudApiRoot)]
        : _apiRoots;

    String lastError = AppLocale.t(
      'Không thể kết nối tới máy chủ.',
      'Unable to connect to the server.',
    );
    for (final root in roots) {
      final url = Uri.parse('$root$subPath');
      try {
        final response = await _client
            .get(url, headers: {'Content-Type': 'application/json'})
            .timeout(_timeoutForRoot(root));
        if (response.statusCode == 200) {
          final data = await _decodeJsonBytes(response.bodyBytes);
          if (data is Map<String, dynamic>) {
            _cachedWorkingRoot = root;
            return {'_ok': true, ...data};
          }
        } else if (response.statusCode == 404) {
          if (_cachedWorkingRoot == root) _cachedWorkingRoot = null;
        } else {
          try {
            final errData = await _decodeJsonBytes(response.bodyBytes);
            lastError = errData['message'] ??
                AppLocale.t(
                  'Lỗi máy chủ (${response.statusCode})',
                  'Server error (${response.statusCode})',
                );
          } catch (_) {
            lastError = AppLocale.t(
              'Lỗi máy chủ (${response.statusCode})',
              'Server error (${response.statusCode})',
            );
          }
        }
      } catch (e) {
        if (_cachedWorkingRoot == root) _cachedWorkingRoot = null;
        lastError = AppLocale.t(
          'Không thể kết nối máy chủ ($e)',
          'Unable to connect to server ($e)',
        );
      }
    }
    return {'_ok': false, 'success': false, 'message': lastError};
  }

  static Future<Map<String, dynamic>> _postJson(
    String subPath,
    Map<String, dynamic> payload, {
    bool syncAllReachable = false,
  }) async {
    bool anySuccess = false;
    Map<String, dynamic> bestResponse = {};
    String lastError = AppLocale.t(
      'Không thể kết nối tới máy chủ.',
      'Unable to connect to the server.',
    );

    for (final root in _apiRoots) {
      final url = Uri.parse('$root$subPath');
      try {
        final response = await _client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = await _decodeJsonBytes(response.bodyBytes);
          if (data is Map<String, dynamic>) {
            _cachedWorkingRoot = root;
            anySuccess = true;
            if (bestResponse.isEmpty) {
              bestResponse = {'_ok': true, ...data};
            }
            if (!syncAllReachable) {
              return bestResponse;
            }
          }
        } else if (response.statusCode == 404) {
          if (_cachedWorkingRoot == root) _cachedWorkingRoot = null;
        } else {
          try {
            final errData = await _decodeJsonBytes(response.bodyBytes);
            lastError = errData['message'] ??
                AppLocale.t(
                  'Lỗi máy chủ (${response.statusCode})',
                  'Server error (${response.statusCode})',
                );
          } catch (_) {
            lastError = AppLocale.t(
              'Lỗi máy chủ (${response.statusCode})',
              'Server error (${response.statusCode})',
            );
          }
        }
      } catch (e) {
        if (_cachedWorkingRoot == root) _cachedWorkingRoot = null;
        lastError = AppLocale.t(
          'Không thể kết nối máy chủ ($e)',
          'Unable to connect to server ($e)',
        );
      }
    }

    if (anySuccess) {
      return bestResponse;
    }
    return {'_ok': false, 'success': false, 'message': lastError};
  }

  // ---------------------------------------------------------------------------
  // 1. Allergens Profile (No fake fallback)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getAllergens(int userId) async {
    final res = await _getJson('/profile/allergens?user_id=$userId');
    if (res['_ok'] == true) {
      return {
        'success': true,
        'allergens': res['allergens'] ?? [],
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể tải hồ sơ dị ứng từ máy chủ.',
            'Unable to load allergy profile from server.',
          ),
    };
  }

  static Future<Map<String, dynamic>> saveAllergens({
    required int userId,
    required List<Map<String, dynamic>> allergens,
  }) async {
    final res = await _postJson(
      '/profile/allergens',
      {'user_id': userId, 'allergens': allergens},
      syncAllReachable: true,
    );
    if (res['_ok'] == true) {
      return {
        'success': true,
        'message': res['message'] ??
            AppLocale.t('Đã lưu hồ sơ dị ứng thành công.', 'Allergy profile saved successfully.'),
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t('Lưu hồ sơ dị ứng thất bại.', 'Failed to save allergy profile.'),
    };
  }

  // ---------------------------------------------------------------------------
  // 2. Chronic Conditions ("Tình trạng của tôi" — Persisted in SQLite DB)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getChronics(int userId) async {
    final res = await _getJson('/profile/chronics?user_id=$userId');
    if (res['_ok'] == true) {
      return {
        'success': true,
        'chronics': res['chronics'] ?? [],
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể tải tình trạng sức khỏe từ máy chủ.',
            'Unable to load health conditions from server.',
          ),
    };
  }

  static Future<Map<String, dynamic>> saveChronics({
    required int userId,
    required List<Map<String, dynamic>> chronics,
  }) async {
    final res = await _postJson(
      '/profile/chronics',
      {'user_id': userId, 'chronics': chronics},
      syncAllReachable: true,
    );
    if (res['_ok'] == true) {
      return {
        'success': true,
        'message': res['message'] ??
            AppLocale.t(
              'Đã lưu tình trạng sức khỏe thành công.',
              'Health conditions saved successfully.',
            ),
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Lưu tình trạng sức khỏe thất bại.',
            'Failed to save health conditions.',
          ),
    };
  }

  // ---------------------------------------------------------------------------
  // 3. Physical Metrics (No hardcoded fake 22yo/170cm/65kg fallback)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getMetrics(int userId) async {
    final res = await _getJson('/profile/metrics?user_id=$userId');
    if (res['_ok'] == true) {
      final metrics = res['metrics'];
      final isDefault = res['is_default'] == true;
      final hasMetrics = (res['has_metrics'] == true) || (metrics != null && !isDefault);
      return {
        'success': true,
        'has_metrics': hasMetrics,
        'metrics': hasMetrics ? metrics : null,
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể tải chỉ số thể trạng từ máy chủ.',
            'Unable to load body metrics from server.',
          ),
    };
  }

  static Future<Map<String, dynamic>> saveMetrics({
    required int userId,
    required int age,
    required String gender,
    required double height,
    required double weight,
    String activityLevel = 'moderate',
  }) async {
    final res = await _postJson(
      '/profile/metrics',
      {
        'user_id': userId,
        'age': age,
        'gender': gender,
        'height': height,
        'weight': weight,
        'activity_level': activityLevel,
      },
      syncAllReachable: true,
    );
    if (res['_ok'] == true) {
      return {
        'success': true,
        'message': res['message'] ??
            AppLocale.t(
              'Đã cập nhật chỉ số thể trạng thành công!',
              'Body metrics updated successfully!',
            ),
        'metrics': res['metrics'],
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể lưu chỉ số thể trạng lên máy chủ.',
            'Unable to save body metrics to server.',
          ),
    };
  }

  // ---------------------------------------------------------------------------
  // 4. User Settings ("Ngôn ngữ", "Chúc mừng huy hiệu", "Nhắc nhở nhẹ nhàng")
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getSettings(int userId) async {
    final res = await _getJson('/profile/settings?user_id=$userId');
    if (res['_ok'] == true) {
      return {
        'success': true,
        'settings': res['settings'] ?? {},
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể tải cài đặt từ máy chủ.',
            'Unable to load settings from server.',
          ),
    };
  }

  static Future<Map<String, dynamic>> saveSettings({
    required int userId,
    required String language,
    required bool notifyBadges,
    required bool notifyReminders,
    bool scanDerivatives = true,
    bool warnTraces = true,
  }) async {
    final res = await _postJson(
      '/profile/settings',
      {
        'user_id': userId,
        'language': AppLocale.normalize(language),
        'notify_badges': notifyBadges,
        'notify_reminders': notifyReminders,
        'scan_derivatives': scanDerivatives,
        'warn_traces': warnTraces,
      },
      syncAllReachable: true,
    );
    if (res['_ok'] == true) {
      return {
        'success': true,
        'message': res['message'] ?? AppLocale.t('Đã lưu cài đặt.', 'Settings saved.'),
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể lưu cài đặt lên máy chủ.',
            'Unable to save settings to server.',
          ),
    };
  }

  // ---------------------------------------------------------------------------
  // 5. Family Profiles ("Hồ sơ gia đình")
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getFamilyMembers(int userId) async {
    final res = await _getJson('/profile/family?user_id=$userId');
    if (res['_ok'] == true) {
      return {
        'success': true,
        'members': res['members'] ?? [],
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể tải danh sách hồ sơ gia đình.',
            'Unable to load family profiles.',
          ),
    };
  }

  static Future<Map<String, dynamic>> addFamilyMember({
    required int userId,
    required String memberName,
    String relationship = 'Người thân',
  }) async {
    final res = await _postJson('/profile/family', {
      'user_id': userId,
      'action': 'add',
      'member_name': memberName.trim(),
      'relationship': relationship.trim(),
    });
    if (res['_ok'] == true) {
      return {
        'success': true,
        'members': res['members'] ?? [],
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể thêm hồ sơ thành viên.',
            'Unable to add family member profile.',
          ),
    };
  }

  static Future<Map<String, dynamic>> deleteFamilyMember({
    required int userId,
    required int memberId,
  }) async {
    final res = await _postJson('/profile/family', {
      'user_id': userId,
      'action': 'delete',
      'member_id': memberId,
    });
    if (res['_ok'] == true) {
      return {
        'success': true,
        'members': res['members'] ?? [],
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể xóa hồ sơ thành viên.',
            'Unable to delete family member profile.',
          ),
    };
  }

  // ---------------------------------------------------------------------------
  // 6. Real Packaging Label Scans & History ("Quét nhãn" & "Lịch sử")
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getScans(int userId) async {
    final res = await _getJson('/scans?user_id=$userId');
    if (res['_ok'] == true) {
      return {
        'success': true,
        'scans': res['scans'] ?? [],
        'total_scans': res['total_scans'] ?? 0,
        'warning_scans': res['warning_scans'] ?? 0,
        'monthly_scans': res['monthly_scans'] ?? 0,
        'monthly_warnings': res['monthly_warnings'] ?? 0,
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể tải lịch sử quét nhãn.',
            'Unable to load scan history.',
          ),
    };
  }

  static Future<Map<String, dynamic>> createScan({
    required int userId,
    required String rawText,
    String? labelTitle,
    String memberName = '',
  }) async {
    final res = await _postJson('/scans', {
      'user_id': userId,
      'raw_text': rawText,
      'label_title': labelTitle ?? AppLocale.t('Kết quả quét', 'Scan result'),
      'member_name': memberName,
      'lang': AppLocale.code,
    });
    if (res['_ok'] == true) {
      return {
        'success': true,
        'latest_scan': res['latest_scan'],
        'scans': res['scans'] ?? [],
        'total_scans': res['total_scans'] ?? 0,
        'warning_scans': res['warning_scans'] ?? 0,
        'monthly_scans': res['monthly_scans'] ?? 0,
        'monthly_warnings': res['monthly_warnings'] ?? 0,
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể phân tích nhãn bao bì.',
            'Unable to analyze packaging label.',
          ),
    };
  }

  // ---------------------------------------------------------------------------
  // 7. Live FoodOn + Kala Ontology Endpoints ("Phụ gia" & Category Filters)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getAdditives({
    String query = '',
    String? lang,
    int limit = 60,
  }) async {
    final activeLang = AppLocale.normalize(lang ?? AppLocale.code);
    final qEnc = Uri.encodeQueryComponent(query);
    final res = await _getJson('/foodon/additives?q=$qEnc&lang=$activeLang&limit=$limit');
    if (res['_ok'] == true) {
      return {
        'success': true,
        'count': res['count'] ?? 0,
        'latency_ms': res['latency_ms'] ?? 0,
        'items': res['items'] ?? [],
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể truy vấn cơ sở dữ liệu FoodOn.',
            'Unable to query the FoodOn database.',
          ),
      'items': [],
    };
  }

  static Future<Map<String, dynamic>> getCategoryConcepts({
    required String category,
    List<String> allergens = const [],
    String? lang,
    int limit = 20,
  }) async {
    final activeLang = AppLocale.normalize(lang ?? AppLocale.code);
    final alParam = Uri.encodeQueryComponent(allergens.join(','));
    final res = await _getJson(
      '/foodon/category?category=$category&allergens=$alParam&lang=$activeLang&limit=$limit',
    );
    if (res['_ok'] == true) {
      return {
        'success': true,
        'category': res['category'] ?? category,
        'items': res['items'] ?? [],
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể tải danh mục FoodOn.',
            'Unable to load FoodOn category.',
          ),
      'items': [],
    };
  }

  static Future<Map<String, dynamic>> searchAllergyFoods({
    String query = '',
    String? lang,
    int limit = 12,
  }) async {
    final activeLang = AppLocale.normalize(lang ?? AppLocale.code);
    final qEnc = Uri.encodeQueryComponent(query);
    final res = await _getJson(
      '/foodon/allergy-lookup?q=$qEnc&lang=$activeLang&limit=$limit',
    );
    if (res['_ok'] == true) {
      return {
        'success': true,
        'count': res['count'] ?? 0,
        'items': res['items'] ?? [],
      };
    }
    return {
      'success': false,
      'message': res['message'] ??
          AppLocale.t(
            'Không thể tra cứu thực phẩm gây dị ứng.',
            'Unable to look up allergy foods.',
          ),
      'items': [],
    };
  }
}
