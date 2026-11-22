import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_locale.dart';
import 'profile_service.dart';

/// Authenticated Community Feed, Media Upload (Cloudflare Worker + D1),
/// and Hidden Admin Moderation API client.
class CommunityService {
  static final http.Client _client = http.Client();

  static String get _apiRoot => ProfileService.cloudApiRoot;

  static String get _originBase {
    final idx = _apiRoot.indexOf('/api/v1');
    return idx > 0 ? _apiRoot.substring(0, idx) : _apiRoot;
  }

  static String resolveMediaUrl(String rawUrl) {
    final clean = rawUrl.trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    if (clean.startsWith('/')) {
      return '$_originBase$clean';
    }
    return clean;
  }

  static List<String> get _roots => ProfileService.apiRoots;

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> _request(
    String method,
    String subPath, {
    required String token,
    Map<String, dynamic>? body,
  }) async {
    String lastError = AppLocale.t(
      'Không thể kết nối tới máy chủ cộng đồng.',
      'Unable to connect to the community server.',
    );
    int lastStatus = 0;

    for (final root in _roots) {
      final uri = Uri.parse('$root$subPath');
      try {
        final timeout = root.contains('127.0.0.1') || root.contains('10.0.2.2')
            ? const Duration(milliseconds: 1800)
            : const Duration(seconds: 12);
        final http.Response response;
        if (method == 'GET') {
          response = await _client.get(uri, headers: _headers(token)).timeout(timeout);
        } else {
          response = await _client
              .post(
                uri,
                headers: _headers(token),
                body: jsonEncode(body ?? const {}),
              )
              .timeout(timeout);
        }

        lastStatus = response.statusCode;
        Map<String, dynamic> decoded = {};
        try {
          final parsed = jsonDecode(utf8.decode(response.bodyBytes));
          if (parsed is Map) decoded = Map<String, dynamic>.from(parsed);
        } catch (_) {}

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {'success': true, ...decoded};
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          return {
            'success': false,
            'status': response.statusCode,
            'code': decoded['code'] ?? (response.statusCode == 401 ? 'AUTH_REQUIRED' : 'FORBIDDEN'),
            'message': decoded['message'] ??
                AppLocale.t(
                  'Bạn cần đăng nhập hoặc không đủ quyền thực hiện thao tác này.',
                  'Authentication required or insufficient permissions.',
                ),
          };
        }
        if (response.statusCode == 404) {
          // Try next backend root in case an older deployment lacks community routes
          lastError = decoded['message']?.toString() ?? lastError;
          continue;
        }
        return {
          'success': false,
          'status': response.statusCode,
          'message': decoded['message'] ??
              AppLocale.t(
                'Lỗi máy chủ (${response.statusCode}).',
                'Server error (${response.statusCode}).',
              ),
        };
      } catch (e) {
        lastError = AppLocale.t(
          'Không thể kết nối máy chủ ($e)',
          'Unable to reach server ($e)',
        );
      }
    }

    return {'success': false, 'status': lastStatus, 'message': lastError};
  }

  /// Uploads a compressed product photo directly to Cloudflare Worker
  /// `/api/v1/community/upload-image` (persisted in D1 `community_media`).
  static Future<Map<String, dynamic>> uploadProductImage({
    required String token,
    required Uint8List bytes,
    required String filename,
  }) async {
    final lower = filename.toLowerCase();
    final contentType = lower.endsWith('.png')
        ? 'image/png'
        : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');

    final res = await _request(
      'POST',
      '/community/upload-image',
      token: token,
      body: {
        'filename': filename,
        'content_type': contentType,
        'data_base64': base64Encode(bytes),
      },
    );
    if (res['success'] == true) {
      final rawUrl = (res['image_path'] ?? res['image_url'] ?? '').toString();
      return {
        'success': true,
        'image_url': resolveMediaUrl(rawUrl),
        'provider': 'cloudflare-d1',
      };
    }
    return res;
  }

  // ---------------------------------------------------------------------------
  // Community Endpoints (Authenticated Users & Admin)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getPosts({
    required String token,
    String verdict = 'ALL',
    String query = '',
    bool includeHidden = false,
    int limit = 30,
  }) {
    final qEnc = Uri.encodeQueryComponent(query);
    final hiddenFlag = includeHidden ? '1' : '0';
    return _request(
      'GET',
      '/community/posts?verdict=$verdict&q=$qEnc&include_hidden=$hiddenFlag&limit=$limit',
      token: token,
    );
  }

  static Future<Map<String, dynamic>> createPost({
    required String token,
    required String productName,
    String brand = '',
    String verdict = 'GREEN',
    String ingredientsText = '',
    String content = '',
    String imageUrl = '',
    String barcode = '',
  }) {
    return _request(
      'POST',
      '/community/posts',
      token: token,
      body: {
        'product_name': productName.trim(),
        'brand': brand.trim(),
        'verdict': verdict.toUpperCase(),
        'ingredients_text': ingredientsText.trim(),
        'content': content.trim(),
        'image_url': imageUrl.trim(),
        'barcode': barcode.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> toggleLike({
    required String token,
    required int postId,
  }) =>
      _request('POST', '/community/posts/$postId/like', token: token);

  static Future<Map<String, dynamic>> getComments({
    required String token,
    required int postId,
  }) =>
      _request('GET', '/community/posts/$postId/comments', token: token);

  static Future<Map<String, dynamic>> addComment({
    required String token,
    required int postId,
    required String content,
  }) =>
      _request(
        'POST',
        '/community/posts/$postId/comments',
        token: token,
        body: {'content': content.trim()},
      );

  static Future<Map<String, dynamic>> deletePost({
    required String token,
    required int postId,
  }) =>
      _request('POST', '/community/posts/$postId/delete', token: token);

  static Future<Map<String, dynamic>> deleteComment({
    required String token,
    required int commentId,
  }) =>
      _request('POST', '/community/comments/$commentId/delete', token: token);

  static Future<Map<String, dynamic>> reportContent({
    required String token,
    int? postId,
    int? commentId,
    required String reason,
  }) =>
      _request(
        'POST',
        '/community/reports',
        token: token,
        body: {
          if (postId != null) 'post_id': postId,
          if (commentId != null) 'comment_id': commentId,
          'reason': reason.trim(),
        },
      );

  // ---------------------------------------------------------------------------
  // Hidden Admin Moderation Endpoints (`role == 'admin'` strictly required)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getAdminOverview({required String token}) =>
      _request('GET', '/admin/overview', token: token);

  static Future<Map<String, dynamic>> moderatePost({
    required String token,
    required int postId,
    required String action,
    String reason = '',
  }) =>
      _request(
        'POST',
        '/admin/posts/$postId/moderate',
        token: token,
        body: {'action': action, 'reason': reason.trim()},
      );

  static Future<Map<String, dynamic>> getAdminReports({
    required String token,
    String status = 'pending',
  }) =>
      _request('GET', '/admin/reports?status=$status', token: token);

  static Future<Map<String, dynamic>> resolveReport({
    required String token,
    required int reportId,
    required String action,
    String note = '',
  }) =>
      _request(
        'POST',
        '/admin/reports/$reportId/resolve',
        token: token,
        body: {'action': action, 'note': note.trim()},
      );

  static Future<Map<String, dynamic>> getAdminUsers({required String token}) =>
      _request('GET', '/admin/users', token: token);

  static Future<Map<String, dynamic>> updateAdminUser({
    required String token,
    required int userId,
    String? role,
    bool? isBanned,
  }) =>
      _request(
        'POST',
        '/admin/users/$userId/update',
        token: token,
        body: {
          if (role != null) 'role': role,
          if (isBanned != null) 'is_banned': isBanned,
        },
      );
}
