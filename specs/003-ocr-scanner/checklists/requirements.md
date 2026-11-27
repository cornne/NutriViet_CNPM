# Requirements Checklist: FG3 - Packaging OCR Scanner & Scan History

**Feature**: `003-fg3-ocr-scanner`  
**Status**: 10/10 Passed  

- [x] **CHK-FG3-01** `PackagingScannerScreen` supports both live CameraX capture and gallery import (`image_picker`).
- [x] **CHK-FG3-02** `MainActivity.kt` compresses images on a background thread with EXIF orientation correction (`<= 180 KB`).
- [x] **CHK-FG3-03** Zero third-party OCR API keys are stored in the Flutter APK.
- [x] **CHK-FG3-04** `POST /api/v1/ocr/jobs` enforces `<= 5 MB` size limit, magic-byte validation, and per-IP rate limiting (20/60s).
- [x] **CHK-FG3-05** `OcrProviderRouter` fails over across 5 providers and persists cooldown state in `APP_DB.ocr_provider_state`.
- [x] **CHK-FG3-06** `extractCleanOcrText` strips Markdown/HTML while preserving Vietnamese diacritics and E/INS codes.
- [x] **CHK-FG3-07** `extractIngredientsSection` returns `has_ingredients: false` when only Nutrition Facts are captured.
- [x] **CHK-FG3-08** `GET/POST/DELETE /api/v1/scans` require valid Bearer authentication and enforce user ownership.
- [x] **CHK-FG3-09** `LocalGuestStore` persists up to 50 Guest scans locally with individual delete and clear-all support.
- [x] **CHK-FG3-10** Automated tests in `worker.test.ts`, `paddle_ocr_vl_service_test.dart`, and `widget_test.dart` pass.
