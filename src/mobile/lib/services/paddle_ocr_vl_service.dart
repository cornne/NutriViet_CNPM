import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_locale.dart';
import 'profile_service.dart';

enum PaddleOcrStage { uploading, queued, processing, parsing }

class PaddleOcrProgress {
  final PaddleOcrStage stage;
  final int elapsedMs;
  final int pollCount;
  final String message;

  const PaddleOcrProgress({
    required this.stage,
    required this.elapsedMs,
    required this.pollCount,
    required this.message,
  });
}

class PaddleOcrCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Cloud Vision-Language OCR client for `PaddleOCR-VL-1.6` via NutriViet
/// Cloudflare Workers Edge Proxy (`/api/v1/ocr/jobs`).
///
/// Routing uploads through Cloudflare Edge eliminates cross-border mobile
/// throttling to AI Studio and keeps the AI Studio secret safely encrypted in
/// Cloudflare Worker Secrets (zero API tokens embedded in APK or source).
/// Users may optionally save a personal AI Studio token in `SharedPreferences`
/// which is forwarded via the `X-PaddleOCR-Token` header.
class PaddleOcrVlService {
  static String get jobEndpoint => '${ProfileService.cloudApiRoot}/ocr/jobs';
  static const String modelName = 'PaddleOCR-VL-1.6';
  static const String _prefTokenKey = 'nutriviet_paddleocr_vl_token';
  static const String _buildTimeToken =
      String.fromEnvironment('PADDLEOCR_VL_TOKEN');
  static const MethodChannel _imageOptChannel =
      MethodChannel('com.nutriviet/image_opt');

  static Map<dynamic, dynamic>? _asMap(dynamic value) =>
      value is Map ? value : null;

  /// Compresses large camera JPEGs (~1.5-3MB) on Android natively down to
  /// <= 110KB (maxSide=1080) in ~35ms for instant edge uploads.
  static Future<Uint8List> optimizeBytesForUpload(
    Uint8List rawBytes, {
    int maxSide = 1080,
    int targetMaxBytes = 110 * 1024,
  }) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        rawBytes.length <= targetMaxBytes) {
      return rawBytes;
    }
    try {
      final optimized = await _imageOptChannel.invokeMethod<Uint8List>(
        'compressForOcr',
        {
          'bytes': rawBytes,
          'maxSide': maxSide,
          'targetMaxBytes': targetMaxBytes,
        },
      );
      if (optimized != null && optimized.isNotEmpty) {
        return optimized;
      }
    } catch (e) {
      debugPrint('[PaddleOCR-VL-1.6 COMPRESS FALLBACK] $e');
    }
    return rawBytes;
  }

  /// Resolves an optional user-supplied AI Studio token override.
  /// Empty string means use the server-side Cloudflare Worker Secret.
  static Future<String> resolveToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = (prefs.getString(_prefTokenKey) ?? '').trim();
      if (saved.isNotEmpty) return saved;
    } catch (_) {
      // Ignore storage read error and fall back to build-time override if any.
    }
    return _buildTimeToken.trim();
  }

  /// Always ready via Cloudflare Worker Edge proxy (or optional user token).
  static Future<bool> hasToken() async => true;

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefTokenKey);
    } else {
      await prefs.setString(_prefTokenKey, trimmed);
    }
  }

  /// Submits an image to the NutriViet Cloudflare Worker OCR proxy
  /// (`PaddleOCR-VL-1.6`), polls job progress smoothly with transient-timeout
  /// retries, and returns cleaned ingredient text.
  static Future<Map<String, dynamic>> recognizeImage({
    String? imagePath,
    Uint8List? imageBytes,
    String? fileName,
    String? tokenOverride,
    String? endpointOverride,
    bool useDocOrientationClassify = true,
    bool useDocUnwarping = false,
    Duration submitTimeout = const Duration(seconds: 45),
    Duration pollTimeout = const Duration(seconds: 25),
    Duration downloadTimeout = const Duration(seconds: 35),
    Duration pollInterval = const Duration(milliseconds: 1400),
    Duration maxWait = const Duration(seconds: 120),
    int maxSubmitAttempts = 2,
    int maxConsecutivePollErrors = 3,
    int maxDownloadAttempts = 2,
    PaddleOcrCancelToken? cancelToken,
    void Function(PaddleOcrProgress progress)? onProgress,
    http.Client? client,
  }) async {
    final endpoint = (endpointOverride ?? jobEndpoint).trim();
    final optionalToken = (tokenOverride ?? await resolveToken()).trim();

    if ((imageBytes == null || imageBytes.isEmpty) &&
        (imagePath == null || imagePath.trim().isEmpty)) {
      return {
        'success': false,
        'message': AppLocale.t(
          'Không có dữ liệu ảnh để nhận dạng.',
          'No image data provided for OCR.',
        ),
      };
    }

    final sw = Stopwatch()..start();
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;
    final resolvedName = _resolveFilename(fileName ?? imagePath);
    final payloadJson = jsonEncode({
      'useDocOrientationClassify': useDocOrientationClassify,
      'useDocUnwarping': useDocUnwarping,
      'useChartRecognition': false,
    });

    void emit(PaddleOcrStage stage, String vi, String en, {int pollCount = 0}) {
      onProgress?.call(
        PaddleOcrProgress(
          stage: stage,
          elapsedMs: sw.elapsedMilliseconds,
          pollCount: pollCount,
          message: AppLocale.t(vi, en),
        ),
      );
    }

    try {
      Uint8List? uploadBytes = imageBytes;
      if (uploadBytes != null && uploadBytes.isNotEmpty) {
        uploadBytes = await optimizeBytesForUpload(uploadBytes);
      }
      final sizeKbLabel = uploadBytes != null
          ? ' (${(uploadBytes.length / 1024).round()} KB)'
          : '';

      // -----------------------------------------------------------------------
      // Stage 1: Upload image & submit async OCR job via Cloudflare Edge Proxy
      // -----------------------------------------------------------------------
      http.Response? submitResp;
      Object? lastSubmitErr;
      for (int attempt = 1; attempt <= maxSubmitAttempts; attempt++) {
        if (cancelToken?.isCancelled == true) return _cancelledResult();
        emit(
          PaddleOcrStage.uploading,
          attempt == 1
              ? 'Đang tải ảnh lên Cloudflare Edge$sizeKbLabel...'
              : 'Đang thử gửi ảnh lại ($attempt/$maxSubmitAttempts)$sizeKbLabel...',
          attempt == 1
              ? 'Uploading photo to Cloudflare Edge$sizeKbLabel...'
              : 'Retrying upload ($attempt/$maxSubmitAttempts)$sizeKbLabel...',
        );

        try {
          final request = http.MultipartRequest('POST', Uri.parse(endpoint));
          if (optionalToken.isNotEmpty) {
            request.headers['X-PaddleOCR-Token'] = optionalToken;
          }
          request.headers['Connection'] = 'keep-alive';
          request.fields['model'] = modelName;
          request.fields['optionalPayload'] = payloadJson;

          if (uploadBytes != null && uploadBytes.isNotEmpty) {
            request.files.add(
              http.MultipartFile.fromBytes(
                'file',
                uploadBytes,
                filename: resolvedName,
              ),
            );
          } else {
            request.files.add(
              await http.MultipartFile.fromPath(
                'file',
                imagePath!,
                filename: resolvedName,
              ),
            );
          }

          final streamed = await httpClient.send(request).timeout(submitTimeout);
          submitResp = await http.Response.fromStream(streamed).timeout(submitTimeout);
          lastSubmitErr = null;
          break;
        } catch (e) {
          lastSubmitErr = e;
          debugPrint('[PaddleOCR-VL-1.6 SUBMIT attempt=$attempt] $e');
          if (attempt < maxSubmitAttempts && cancelToken?.isCancelled != true) {
            await Future<void>.delayed(const Duration(milliseconds: 800));
          }
        }
      }

      if (cancelToken?.isCancelled == true) return _cancelledResult();

      if (submitResp == null) {
        final isTimeout = lastSubmitErr is TimeoutException;
        return {
          'success': false,
          'message': isTimeout
              ? AppLocale.t(
                  'Tải ảnh lên PaddleOCR-VL-1.6 bị quá hạn. Kiểm tra mạng và thử lại.',
                  'Uploading photo to PaddleOCR-VL-1.6 timed out. Please retry.',
                )
              : AppLocale.t(
                  'Không thể gửi ảnh tới PaddleOCR-VL-1.6. Kiểm tra kết nối mạng và thử lại.',
                  'Unable to upload photo to PaddleOCR-VL-1.6. Check network and retry.',
                ),
        };
      }

      final submitBody = utf8.decode(submitResp.bodyBytes, allowMalformed: true);
      if (submitResp.statusCode == 401 ||
          submitResp.statusCode == 403 ||
          submitResp.statusCode == 503) {
        return {
          'success': false,
          'auth_error': true,
          'message': AppLocale.t(
            'AI Studio Token không hợp lệ hoặc chưa được cấu hình (HTTP ${submitResp.statusCode}). Bạn có thể nhập token riêng bằng biểu tượng chìa khóa.',
            'Invalid or unconfigured AI Studio token (HTTP ${submitResp.statusCode}). Tap the key icon to set a custom token.',
          ),
        };
      }

      if (submitResp.statusCode != 200) {
        return {
          'success': false,
          'message': AppLocale.t(
            'Không thể gửi ảnh tới PaddleOCR-VL-1.6 (HTTP ${submitResp.statusCode}).',
            'Failed to submit image to PaddleOCR-VL-1.6 (HTTP ${submitResp.statusCode}).',
          ),
          'detail': submitBody.length > 240 ? submitBody.substring(0, 240) : submitBody,
        };
      }

      final submitJson = _asMap(jsonDecode(submitBody));
      final submitData = _asMap(submitJson?['data']);
      final jobId =
          (submitJson?['jobId'] ?? submitData?['jobId'] ?? '').toString().trim();
      if (jobId.isEmpty) {
        return {
          'success': false,
          'message': AppLocale.t(
            'PaddleOCR-VL-1.6 không trả về mã tác vụ (jobId).',
            'PaddleOCR-VL-1.6 did not return a job ID.',
          ),
        };
      }

      // -----------------------------------------------------------------------
      // Stage 2: Poll async job status (Worker parses JSONL on Cloudflare Edge)
      // -----------------------------------------------------------------------
      String jsonlUrl = '';
      String? directText;
      String? directRawMarkdown;
      int pollCount = 0;
      int consecutivePollErrors = 0;
      final pollUri = Uri.parse('$endpoint/$jobId');
      final pollHeaders = <String, String>{
        'Connection': 'keep-alive',
        if (optionalToken.isNotEmpty) 'X-PaddleOCR-Token': optionalToken,
      };

      while (sw.elapsed < maxWait) {
        if (cancelToken?.isCancelled == true) return _cancelledResult();
        pollCount++;
        final sec = (sw.elapsedMilliseconds / 1000).toStringAsFixed(1);

        http.Response pollResp;
        try {
          pollResp = await httpClient
              .get(pollUri, headers: pollHeaders)
              .timeout(pollTimeout);
          consecutivePollErrors = 0;
        } catch (e) {
          consecutivePollErrors++;
          debugPrint('[PaddleOCR-VL-1.6 POLL #$pollCount err=$consecutivePollErrors] $e');
          if (consecutivePollErrors >= maxConsecutivePollErrors) {
            return {
              'success': false,
              'message': AppLocale.t(
                'Mất kết nối khi kiểm tra kết quả PaddleOCR-VL-1.6 (${sec}s). Kiểm tra mạng và thử lại.',
                'Lost connection while checking PaddleOCR-VL-1.6 progress (${sec}s). Please retry.',
              ),
            };
          }
          emit(
            PaddleOcrStage.processing,
            'Mạng hơi chậm, đang chờ kết quả PaddleOCR-VL-1.6... (${sec}s)',
            'Slow network, retrying PaddleOCR-VL-1.6 status... (${sec}s)',
            pollCount: pollCount,
          );
          await Future<void>.delayed(pollInterval);
          continue;
        }

        if (cancelToken?.isCancelled == true) return _cancelledResult();

        final pollBody = utf8.decode(pollResp.bodyBytes, allowMalformed: true);
        if (pollResp.statusCode == 401 ||
            pollResp.statusCode == 403 ||
            pollResp.statusCode == 503) {
          return {
            'success': false,
            'auth_error': true,
            'message': AppLocale.t(
              'Token AI Studio bị từ chối khi kiểm tra kết quả OCR.',
              'AI Studio token rejected while checking OCR status.',
            ),
          };
        }

        if (pollResp.statusCode != 200) {
          return {
            'success': false,
            'message': AppLocale.t(
              'Lỗi kiểm tra trạng thái PaddleOCR-VL-1.6 (HTTP ${pollResp.statusCode}).',
              'Failed polling PaddleOCR-VL-1.6 status (HTTP ${pollResp.statusCode}).',
            ),
          };
        }

        final pollJson = _asMap(jsonDecode(pollBody));
        final data = _asMap(pollJson?['data']);
        final state =
            (pollJson?['state'] ?? data?['state'] ?? '').toString().toLowerCase();

        if (state == 'done') {
          if (pollJson?.containsKey('text') == true) {
            directText = (pollJson?['text'] ?? '').toString();
            directRawMarkdown = (pollJson?['raw_markdown'] ?? '').toString();
            emit(
              PaddleOcrStage.parsing,
              'Đang tổng hợp danh sách thành phần...',
              'Finalizing extracted ingredient text...',
              pollCount: pollCount,
            );
            break;
          }
          final resultUrl = _asMap(data?['resultUrl']);
          jsonlUrl = (resultUrl?['jsonUrl'] ?? '').toString().trim();
          break;
        } else if (state == 'failed') {
          final errMsg =
              (pollJson?['message'] ?? data?['errorMsg'] ?? '').toString().trim();
          return {
            'success': false,
            'message': errMsg.isNotEmpty
                ? AppLocale.t(
                    'PaddleOCR-VL-1.6 xử lý thất bại: $errMsg',
                    'PaddleOCR-VL-1.6 failed: $errMsg',
                  )
                : AppLocale.t(
                    'PaddleOCR-VL-1.6 không thể xử lý ảnh này.',
                    'PaddleOCR-VL-1.6 could not process this image.',
                  ),
          };
        } else if (state == 'running') {
          emit(
            PaddleOcrStage.processing,
            'PaddleOCR-VL-1.6 đang đọc chữ trên nhãn... (${sec}s)',
            'PaddleOCR-VL-1.6 reading packaging text... (${sec}s)',
            pollCount: pollCount,
          );
        } else {
          emit(
            PaddleOcrStage.queued,
            'Đang xếp hàng trên máy chủ AI Vision... (${sec}s)',
            'Queued on AI Vision server... (${sec}s)',
            pollCount: pollCount,
          );
        }

        await Future<void>.delayed(pollInterval);
      }

      if (cancelToken?.isCancelled == true) return _cancelledResult();

      // Fast path: Cloudflare Worker already fetched & parsed the JSONL payload on Edge!
      if (directText != null) {
        final cleaned = directText.trim();
        final nonEmptyLines = cleaned
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return {
          'success': true,
          'text': cleaned,
          'raw_markdown': directRawMarkdown ?? '',
          'line_count': nonEmptyLines.length,
          'total_ms': sw.elapsedMilliseconds,
          'job_id': jobId,
          'engine': modelName,
        };
      }

      if (jsonlUrl.isEmpty) {
        return {
          'success': false,
          'message': AppLocale.t(
            'Quá thời gian chờ xử lý từ PaddleOCR-VL-1.6. Hãy thử chụp lại ảnh gọn hơn.',
            'Timed out waiting for PaddleOCR-VL-1.6 processing. Please retry.',
          ),
        };
      }

      // -----------------------------------------------------------------------
      // Stage 3 (Legacy fallback): Download & parse JSONL directly if returned
      // -----------------------------------------------------------------------
      emit(
        PaddleOcrStage.parsing,
        'Đang tải và tổng hợp danh sách thành phần...',
        'Downloading and extracting ingredient text...',
        pollCount: pollCount,
      );

      http.Response? resultResp;
      for (int attempt = 1; attempt <= maxDownloadAttempts; attempt++) {
        if (cancelToken?.isCancelled == true) return _cancelledResult();
        try {
          resultResp = await httpClient
              .get(Uri.parse(jsonlUrl))
              .timeout(downloadTimeout);
          break;
        } catch (e) {
          debugPrint('[PaddleOCR-VL-1.6 DOWNLOAD attempt=$attempt] $e');
          if (attempt < maxDownloadAttempts) {
            await Future<void>.delayed(const Duration(milliseconds: 800));
          }
        }
      }

      if (cancelToken?.isCancelled == true) return _cancelledResult();

      if (resultResp == null || resultResp.statusCode != 200) {
        final code = resultResp?.statusCode;
        return {
          'success': false,
          'message': code == null
              ? AppLocale.t(
                  'Tải tệp kết quả OCR bị quá hạn. Hãy thử quét lại.',
                  'Downloading OCR result timed out. Please retry.',
                )
              : AppLocale.t(
                  'Không thể tải tệp kết quả OCR (HTTP $code).',
                  'Unable to download OCR result payload (HTTP $code).',
                ),
        };
      }

      final jsonlText = utf8.decode(resultResp.bodyBytes, allowMalformed: true);
      final markdownChunks = <String>[];

      for (final rawLine in const LineSplitter().convert(jsonlText)) {
        final trimmed = rawLine.trim();
        if (trimmed.isEmpty) continue;
        final decoded = _asMap(jsonDecode(trimmed));
        final resultObj = _asMap(decoded?['result']);
        final layoutResults = resultObj?['layoutParsingResults'];
        if (layoutResults is List) {
          for (final item in layoutResults) {
            final itemMap = _asMap(item);
            final mdMap = _asMap(itemMap?['markdown']);
            final md = mdMap?['text']?.toString().trim();
            if (md != null && md.isNotEmpty) {
              markdownChunks.add(md);
            }
          }
        }
      }

      final rawMarkdown = markdownChunks.join('\n\n').trim();
      final cleaned = extractCleanText(rawMarkdown);
      final nonEmptyLines = cleaned
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      return {
        'success': true,
        'text': cleaned,
        'raw_markdown': rawMarkdown,
        'line_count': nonEmptyLines.length,
        'total_ms': sw.elapsedMilliseconds,
        'job_id': jobId,
        'engine': modelName,
      };
    } catch (e) {
      debugPrint('[PaddleOCR-VL-1.6 ERROR] $e');
      return {
        'success': false,
        'message': AppLocale.t(
          'Không thể kết nối PaddleOCR-VL-1.6. Kiểm tra kết nối internet và thử lại.',
          'Unable to reach PaddleOCR-VL-1.6. Check your internet connection and retry.',
        ),
      };
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Cleans Markdown / HTML table markup returned by PaddleOCR-VL-1.6 into crisp
  /// ingredient text while preserving every Vietnamese diacritic, percentage,
  /// parenthesis, and additive E-code / INS code.
  static String extractCleanText(String markdown) {
    if (markdown.trim().isEmpty) return '';

    var s = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
    s = s.replaceAll(RegExp(r'<img\b[^>]*>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(
      RegExp(r'</(p|div|tr|li|h[1-6])>', caseSensitive: false),
      '\n',
    );
    s = s.replaceAll(RegExp(r'</(td|th)>', caseSensitive: false), ', ');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '');
    s = s.replaceAll(RegExp(r'\*\*|__|`'), '');
    s = s.replaceAll(RegExp(r'^\s*\|?[\s:\-|]+\|?\s*$', multiLine: true), '');
    s = s.replaceAll(RegExp(r'\s*\|\s*'), ', ');
    s = s
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    final out = <String>[];
    String? prevNormalized;
    for (final rawLine in s.split('\n')) {
      final line = rawLine
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .replaceAll(RegExp(r'(,\s*){2,}'), ', ')
          .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
          .trim();
      if (line.isEmpty) continue;
      final norm = line.toLowerCase();
      if (norm == prevNormalized) continue;
      out.add(line);
      prevNormalized = norm;
    }
    return out.join('\n');
  }

  static String _resolveFilename(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty) return 'label.jpg';
    final normalized = rawPath.replaceAll('\\', '/');
    final base = normalized.split('/').last.trim();
    return base.isEmpty ? 'label.jpg' : base;
  }

  static Map<String, dynamic> _cancelledResult() => {
        'success': false,
        'cancelled': true,
        'message': AppLocale.t(
          'Đã hủy nhận dạng ảnh.',
          'OCR scan cancelled.',
        ),
      };
}
