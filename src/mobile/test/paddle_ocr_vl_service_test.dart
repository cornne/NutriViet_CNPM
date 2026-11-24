import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriviet_mobile/l10n/app_locale.dart';
import 'package:nutriviet_mobile/screens/packaging_scanner_screen.dart';
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

  test('recognizeImage propagates has_ingredients=false when only Nutrition Facts detected', () async {
    final mockClient = MockClient((http.Request req) async {
      if (req.method == 'POST') {
        return http.Response(jsonEncode({'success': true, 'jobId': 'job-nut-only'}), 200);
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'success': true,
            'state': 'done',
            'has_ingredients': false,
            'text': '',
            'raw_text': 'Nutrition Facts\nCalories 200 kcal\nSodium 120mg',
            'nutrition_detected': true,
            'reason': 'NO_INGREDIENTS_FOUND',
            'line_count': 0,
          }),
        ),
        200,
      );
    });

    final res = await PaddleOcrVlService.recognizeImage(
      imageBytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
      tokenOverride: '',
      pollInterval: const Duration(milliseconds: 5),
      client: mockClient,
    );

    expect(res['success'], isTrue);
    expect(res['has_ingredients'], isFalse);
    expect(res['nutrition_detected'], isTrue);
    expect(res['text'], isEmpty);
    expect(res['reason'], 'NO_INGREDIENTS_FOUND');
  });

  test('recognizeImage completes immediately on synchronous Worker fast-path with ZERO polling', () async {
    int getPollCalls = 0;
    final mockClient = MockClient((http.Request req) async {
      if (req.method == 'POST' && req.url.toString() == PaddleOcrVlService.jobEndpoint) {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'success': true,
              'state': 'done',
              'job_id': 'sync-kilo-particle-1-123',
              'engine': 'Kilo Particle-1',
              'provider_id': 'kilo-particle-1',
              'has_ingredients': true,
              'text': 'Water, Sugar, Milk Powder (12%), Soy Lecithin (E322).',
              'raw_text': 'INGREDIENTS: Water, Sugar, Milk Powder (12%), Soy Lecithin (E322).',
              'matched_header': 'INGREDIENTS',
              'fuzzy_score': 1.0,
              'nutrition_detected': false,
              'reason': 'OK',
              'line_count': 1,
            }),
          ),
          200,
        );
      }
      if (req.method == 'GET') getPollCalls++;
      return http.Response('Unexpected poll', 500);
    });

    final res = await PaddleOcrVlService.recognizeImage(
      imageBytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
      fileName: 'label.png',
      tokenOverride: '',
      client: mockClient,
    );

    expect(res['success'], isTrue);
    expect(getPollCalls, 0);
    expect(res['engine'], 'Kilo Particle-1');
    expect(res['provider_id'], 'kilo-particle-1');
    expect(res['has_ingredients'], isTrue);
    expect(res['text'], contains('Milk Powder (12%)'));
  });

  test('PackagingScannerMath maps BoxFit.cover camera cutout and BoxFit.contain bounds accurately', () {
    // Modern tall phone (1096x2560) with 3:4 portrait camera preview
    final coverNorm = PackagingScannerMath.mapCoverFrameToImageNormRect(
      viewportSize: const Size(1096, 2560),
      previewImageAspect: 0.75,
      frameRect: const Rect.fromLTWH(20, 900, 1056, 600),
    );
    // Horizontally centered inside renderedW=1920 -> dx=412 -> left=(20+412)/1920=0.225
    expect(coverNorm.left, closeTo(0.225, 0.005));
    expect(coverNorm.right, closeTo(0.775, 0.005));
    expect(coverNorm.top, closeTo(900 / 2560, 0.005));
    expect(coverNorm.bottom, closeTo(1500 / 2560, 0.005));

    // Wide 2:1 landscape image inside 300x500 container must fit horizontally without overflow
    final containRect = PackagingScannerMath.computeContainImageRect(
      containerSize: const Size(300, 500),
      imageAspect: 2.0,
    );
    expect(containRect.width, closeTo(300, 0.5));
    expect(containRect.height, closeTo(150, 0.5));
    expect(containRect.left, closeTo(0, 0.5));
    expect(containRect.top, closeTo(175, 0.5));
  });

  testWidgets('PackagingScannerScreen toggles live framing mode and bounded gallery crop without overflow', (tester) async {
    // 1x1 valid transparent PNG bytes for gallery crop review test
    final png1x1 = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: PackagingScannerScreen(
          userId: 0,
          memberName: 'Khách',
          isGuest: true,
          skipCameraInitForTest: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Trong khung'), findsOneWidget);
    expect(find.text('Toàn màn hình'), findsOneWidget);
    expect(find.textContaining('Chỉ quét trong khung'), findsOneWidget);

    await tester.tap(find.text('Toàn màn hình'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Quét toàn màn hình'), findsOneWidget);

    // Switch to gallery crop review stage and verify bounded toggle without overflow
    await tester.pumpWidget(
      MaterialApp(
        home: PackagingScannerScreen(
          key: const ValueKey('gallery-crop-review-test'),
          userId: 0,
          memberName: 'Khách',
          isGuest: true,
          skipCameraInitForTest: true,
          initialGalleryBytesForTest: png1x1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quét toàn ảnh'), findsOneWidget);
    expect(find.text('Cắt vùng Thành phần'), findsOneWidget);
    expect(find.text('Nhận dạng Thành phần'), findsOneWidget);

    await tester.tap(find.text('Cắt vùng Thành phần'));
    await tester.pumpAndSettle();
    expect(find.text('Quét vùng đã cắt'), findsOneWidget);
  });
}
