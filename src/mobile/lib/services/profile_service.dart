import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_locale.dart';
import 'auth_service.dart';

class ProfileService {
  static const String cloudApiRoot = String.fromEnvironment(
    'NUTRIVIET_API_ROOT',
    defaultValue: 'https://nutriviet.nutriviet-api.workers.dev/api/v1',
  );

  // Persistent HTTP client for TCP/keep-alive reuse across tabs and API calls.
  static final http.Client _client = http.Client();
  static const Duration _requestTimeout = Duration(seconds: 12);

  /// Resolves backend API roots.
  /// All build modes target Cloudflare Workers HTTPS exclusively (configurable
  /// via `--dart-define=NUTRIVIET_API_ROOT=...`), with zero localhost probes.
  @visibleForTesting
  static List<String> buildApiRoots({
    required bool isReleaseMode,
    required TargetPlatform platform,
    required bool isWeb,
    String? cachedWorkingRoot,
  }) {
    return <String>[cloudApiRoot];
  }

  static List<String> get apiRoots => <String>[cloudApiRoot];

  static Future<Map<String, String>> _buildHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _decodeJsonBytes(Uint8List bytes) {
    // Offload large JSON payloads (e.g., FoodOn/additive lists) off the 120Hz UI isolate.
    if (!kIsWeb && bytes.length > 4096) {
      return Isolate.run(() => jsonDecode(utf8.decode(bytes)));
    }
    return Future.value(jsonDecode(utf8.decode(bytes)));
  }

  static Future<Map<String, dynamic>> _getJson(String subPath) async {
    final url = Uri.parse('$cloudApiRoot$subPath');
    try {
      final headers = await _buildHeaders();
      final response = await _client.get(url, headers: headers).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final data = await _decodeJsonBytes(response.bodyBytes);
        if (data is Map<String, dynamic>) {
          return {'_ok': true, ...data};
        }
      }
      try {
        final errData = await _decodeJsonBytes(response.bodyBytes);
        return {
          '_ok': false,
          'success': false,
          'status_code': response.statusCode,
          'message': errData['message'] ??
              AppLocale.t(
                'Lỗi máy chủ (${response.statusCode})',
                'Server error (${response.statusCode})',
              ),
        };
      } catch (_) {
        return {
          '_ok': false,
          'success': false,
          'status_code': response.statusCode,
          'message': AppLocale.t(
            'Lỗi máy chủ (${response.statusCode})',
            'Server error (${response.statusCode})',
          ),
        };
      }
    } catch (e) {
      return {
        '_ok': false,
        'success': false,
        'message': AppLocale.t(
          'Không thể kết nối máy chủ ($e)',
          'Unable to connect to server ($e)',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> _postJson(
    String subPath,
    Map<String, dynamic> payload,
  ) async {
    final url = Uri.parse('$cloudApiRoot$subPath');
    try {
      final headers = await _buildHeaders();
      final response = await _client
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(_requestTimeout);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = await _decodeJsonBytes(response.bodyBytes);
        if (data is Map<String, dynamic>) {
          return {'_ok': true, ...data};
        }
      }
      try {
        final errData = await _decodeJsonBytes(response.bodyBytes);
        return {
          '_ok': false,
          'success': false,
          'status_code': response.statusCode,
          'message': errData['message'] ??
              AppLocale.t(
                'Lỗi máy chủ (${response.statusCode})',
                'Server error (${response.statusCode})',
              ),
        };
      } catch (_) {
        return {
          '_ok': false,
          'success': false,
          'status_code': response.statusCode,
          'message': AppLocale.t(
            'Lỗi máy chủ (${response.statusCode})',
            'Server error (${response.statusCode})',
          ),
        };
      }
    } catch (e) {
      return {
        '_ok': false,
        'success': false,
        'message': AppLocale.t(
          'Không thể kết nối máy chủ ($e)',
          'Unable to connect to server ($e)',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> _deleteJson(String subPath) async {
    final url = Uri.parse('$cloudApiRoot$subPath');
    try {
      final headers = await _buildHeaders();
      final response = await _client.delete(url, headers: headers).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final data = await _decodeJsonBytes(response.bodyBytes);
        if (data is Map<String, dynamic>) {
          return {'_ok': true, ...data};
        }
      }
      try {
        final errData = await _decodeJsonBytes(response.bodyBytes);
        return {
          '_ok': false,
          'success': false,
          'status_code': response.statusCode,
          'message': errData['message'] ??
              AppLocale.t(
                'Lỗi máy chủ (${response.statusCode})',
                'Server error (${response.statusCode})',
              ),
        };
      } catch (_) {
        return {
          '_ok': false,
          'success': false,
          'status_code': response.statusCode,
          'message': AppLocale.t(
            'Lỗi máy chủ (${response.statusCode})',
            'Server error (${response.statusCode})',
          ),
        };
      }
    } catch (e) {
      return {
        '_ok': false,
        'success': false,
        'message': AppLocale.t(
          'Không thể kết nối máy chủ ($e)',
          'Unable to connect to server ($e)',
        ),
      };
    }
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
  // 2. Chronic Conditions ("Tình trạng của tôi" — Persisted in D1 DB)
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
  // 3. User Settings ("Ngôn ngữ", "Chúc mừng huy hiệu", "Nhắc nhở nhẹ nhàng")
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
      'lang': 'en',
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

  static Future<Map<String, dynamic>> deleteScan({
    required int userId,
    required int scanId,
  }) async {
    final res = await _deleteJson('/scans/$scanId?user_id=$userId');
    if (res['_ok'] == true) {
      return {
        'success': true,
        'deleted_id': res['deleted_id'] ?? scanId,
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
            'Không thể xóa bản ghi lịch sử quét trên máy chủ.',
            'Unable to delete scan history entry on server.',
          ),
    };
  }

  static Future<Map<String, dynamic>> clearScans({
    required int userId,
  }) async {
    final res = await _deleteJson('/scans?user_id=$userId');
    if (res['_ok'] == true) {
      return {
        'success': true,
        'deleted_count': res['deleted_count'] ?? 0,
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
            'Không thể xóa toàn bộ lịch sử quét trên máy chủ.',
            'Unable to clear scan history on server.',
          ),
    };
  }

  /// Stateless FoodOn packaging label evaluation for Guest mode (zero cloud writes).
  static Future<Map<String, dynamic>> evaluateLabelStateless({
    required String rawText,
    List<Map<String, dynamic>> allergens = const [],
    List<String> chronics = const [],
    bool scanDerivatives = true,
    bool warnTraces = true,
  }) async {
    final res = await _postJson('/foodon/evaluate', {
      'raw_text': rawText,
      'allergens': allergens,
      'chronics': chronics,
      'scan_derivatives': scanDerivatives,
      'warn_traces': warnTraces,
      'lang': 'en',
    });
    if (res['_ok'] == true) {
      final evaluation = Map<String, dynamic>.from(res)..remove('_ok');
      return {
        'success': true,
        'evaluation': evaluation,
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
  // 7. Live Official Pure-English FoodOn Ontology Endpoints (Zero Fallback)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getAdditives({
    String query = '',
    String? lang,
    int limit = 60,
  }) async {
    final qEnc = Uri.encodeQueryComponent(query);
    final res = await _getJson('/foodon/additives?q=$qEnc&lang=en&limit=$limit');
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
    final alParam = Uri.encodeQueryComponent(allergens.join(','));
    final res = await _getJson(
      '/foodon/category?category=$category&allergens=$alParam&lang=en&limit=$limit',
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
    final qEnc = Uri.encodeQueryComponent(query);
    final res = await _getJson(
      '/foodon/allergy-lookup?q=$qEnc&lang=en&limit=$limit',
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
