import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriviet_mobile/l10n/app_locale.dart';
import 'package:nutriviet_mobile/services/paddle_ocr_vl_service.dart';
import 'package:nutriviet_mobile/services/profile_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocale.setLanguage('vi');
  });

  test('jobEndpoint points to Cloudflare Workers OCR proxy', () {
    expect(
      PaddleOcrVlService.jobEndpoint,
      '${ProfileService.cloudApiRoot}/ocr/jobs',
    );
    expect(PaddleOcrVlService.jobEndpoint, contains('workers.dev/api/v1/ocr/jobs'));
  });

  test('extractCleanText strips Markdown/HTML while preserving Vietnamese & E-codes', () {
    const raw = '''
## **THÀNH PHẦN (INGREDIENTS):**

![](imgs/crop_0.jpg)

Bột mì (48%), đường tinh luyện, sữa bột nguyên kem (6%), chất nhũ hóa (INS 322(i) / E322), chất điều vị (E621).

<table><tr><td>Phẩm màu</td><td>E102 &amp; E110</td></tr></table>

Cảnh báo dị ứng: Chứa lúa mì, sữa, đậu phộng.
Cảnh báo dị ứng: Chứa lúa mì, sữa, đậu phộng.
''';

    final cleaned = PaddleOcrVlService.extractCleanText(raw);
    expect(cleaned, contains('THÀNH PHẦN (INGREDIENTS):'));
    expect(cleaned, contains('Bột mì (48%), đường tinh luyện, sữa bột nguyên kem (6%)'));
    expect(cleaned, contains('INS 322(i) / E322'));
    expect(cleaned, contains('E621'));
    expect(cleaned, contains('Phẩm màu, E102 & E110'));
    expect(cleaned, isNot(contains('imgs/crop_0.jpg')));
    expect(cleaned, isNot(contains('<table>')));
    expect(cleaned, isNot(contains('**')));
    expect(
      'Cảnh báo dị ứng: Chứa lúa mì, sữa, đậu phộng.'.allMatches(cleaned).length,
      1,
    );
  });

  test('recognizeImage completes Cloudflare Worker proxy pipeline with ZERO client token', () async {
    int pollCalls = 0;
    final stages = <PaddleOcrStage>[];

    final mockClient = MockClient((http.Request req) async {
      if (req.method == 'POST' && req.url.toString() == PaddleOcrVlService.jobEndpoint) {
        // No client token header needed when using Cloudflare Worker Secret!
        expect(req.headers.containsKey('X-PaddleOCR-Token'), isFalse);
        expect(req.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          jsonEncode({
            'success': true,
            'jobId': 'job-cf-999',
            'engine': 'PaddleOCR-VL-1.6',
          }),
          200,
        );
      }

      if (req.method == 'GET' &&
          req.url.toString() == '${PaddleOcrVlService.jobEndpoint}/job-cf-999') {
        pollCalls++;
        if (pollCalls == 1) {
          return http.Response(jsonEncode({'success': true, 'state': 'pending'}), 200);
        }
        if (pollCalls == 2) {
          return http.Response(jsonEncode({'success': true, 'state': 'running'}), 200);
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'success': true,
              'state': 'done',
              'job_id': 'job-cf-999',
              'engine': 'PaddleOCR-VL-1.6',
              'text':
                  'THÀNH PHẦN: Bột mì, sữa bột (8%), đậu phộng, chất điều vị (E621).',
              'raw_markdown':
                  '**THÀNH PHẦN:** Bột mì, sữa bột (8%), đậu phộng, chất điều vị (E621).',
              'line_count': 1,
            }),
          ),
          200,
        );
      }

      return http.Response('Not found', 404);
    });

    final res = await PaddleOcrVlService.recognizeImage(
      imageBytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
      fileName: 'snack.jpg',
      tokenOverride: '',
      pollInterval: const Duration(milliseconds: 5),
      onProgress: (p) => stages.add(p.stage),
      client: mockClient,
    );

    expect(res['success'], isTrue);
    expect(res['engine'], 'PaddleOCR-VL-1.6');
    expect(res['job_id'], 'job-cf-999');
    expect(res['line_count'], 1);
    expect(
      res['text'],
      'THÀNH PHẦN: Bột mì, sữa bột (8%), đậu phộng, chất điều vị (E621).',
    );
    expect(
      stages,
      containsAllInOrder([
        PaddleOcrStage.uploading,
        PaddleOcrStage.queued,
        PaddleOcrStage.processing,
        PaddleOcrStage.parsing,
      ]),
    );
  });

  test('recognizeImage forwards optional X-PaddleOCR-Token override and retries poll timeout', () async {
    int pollCalls = 0;

    final mockClient = MockClient((http.Request req) async {
      expect(req.headers['X-PaddleOCR-Token'], 'custom-tok');
      if (req.method == 'POST') {
        return http.Response(jsonEncode({'success': true, 'jobId': 'job-retry'}), 200);
      }
      if (req.url.toString().endsWith('/job-retry')) {
        pollCalls++;
        if (pollCalls == 1) {
          throw TimeoutException('Transient network hiccup');
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'success': true,
              'state': 'done',
              'text': 'Thành phần: Đậu nành, muối i-ốt, đường.',
            }),
          ),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    final res = await PaddleOcrVlService.recognizeImage(
      imageBytes: Uint8List.fromList([1, 2, 3]),
      tokenOverride: 'custom-tok',
      pollInterval: const Duration(milliseconds: 5),
      client: mockClient,
    );

    expect(res['success'], isTrue);
    expect(pollCalls, 2);
    expect(res['text'], 'Thành phần: Đậu nành, muối i-ốt, đường.');
  });

  test('recognizeImage handles 401/503 auth_error and user cancellation cleanly', () async {
    final unauthClient = MockClient((_) async => http.Response('Unauthorized', 401));
    final unauthRes = await PaddleOcrVlService.recognizeImage(
      imageBytes: Uint8List.fromList([1, 2, 3]),
      tokenOverride: 'expired-tok',
      client: unauthClient,
    );
    expect(unauthRes['success'], isFalse);
    expect(unauthRes['auth_error'], isTrue);

    final cancelToken = PaddleOcrCancelToken();
    final cancelClient = MockClient((http.Request req) async {
      if (req.method == 'POST') {
        cancelToken.cancel();
        return http.Response(jsonEncode({'success': true, 'jobId': 'job-cancel'}), 200);
      }
      return http.Response(jsonEncode({'success': true, 'state': 'running'}), 200);
    });

    final cancelRes = await PaddleOcrVlService.recognizeImage(
      imageBytes: Uint8List.fromList([1, 2, 3]),
      tokenOverride: '',
      cancelToken: cancelToken,
      client: cancelClient,
    );
    expect(cancelRes['success'], isFalse);
    expect(cancelRes['cancelled'], isTrue);
  });

  test('saveToken persists optional override and clear falls back to empty (Worker default)', () async {
    await PaddleOcrVlService.saveToken('  custom-aistudio-token  ');
    expect(await PaddleOcrVlService.resolveToken(), 'custom-aistudio-token');
    expect(await PaddleOcrVlService.hasToken(), isTrue);

    await PaddleOcrVlService.saveToken('');
    expect(await PaddleOcrVlService.resolveToken(), isEmpty);
    expect(await PaddleOcrVlService.hasToken(), isTrue);
  });
}
