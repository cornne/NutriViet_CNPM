# Tasks: FG3 - Packaging OCR Scanner & Scan History

**Feature**: `003-fg3-ocr-scanner`  
**Prerequisites**: [plan.md](plan.md) (approved), [spec.md](spec.md) (approved)  
**Deliverable**: PA4-2026 Section E Task Breakdown

---

### Phase 1: Native Image Optimization & CameraX UI (`UC06`, `UC07`)
- [x] **TASK-FG3-01** `[Native]` Implement `MethodChannel("com.nutriviet/image_opt")` (`compressForOcr`) in `MainActivity.kt` with EXIF rotation, normalized crop, and adaptive JPEG compression (`<= 180 KB`).
- [x] **TASK-FG3-02** `[Mobile]` Build `PackagingScannerScreen` (`src/mobile/lib/screens/packaging_scanner_screen.dart`) with CameraX viewfinder, torch, `image_picker` gallery crop review, and `PackagingScannerMath`.
- [x] **TASK-FG3-03** `[Mobile]` Implement `PaddleOcrVlService` (`src/mobile/lib/services/paddle_ocr_vl_service.dart`) with multipart upload, sync fast-path, async polling, and `PaddleOcrCancelToken`.

### Phase 2: Cloudflare Edge OCR Proxy & Extractor (`UC07`)
- [x] **TASK-FG3-04** `[Backend]` Implement `ocr_router.ts` (`OcrProviderRouter`) with 5-tier fastest-to-slowest failover and persistent `APP_DB.ocr_provider_state` cooldowns.
- [x] **TASK-FG3-05** `[Backend]` Implement `ocr_proxy.ts` (`POST /api/v1/ocr/jobs`, `GET /api/v1/ocr/jobs/:jobId`, `GET /api/v1/ocr/providers`) and `extractCleanOcrText`.
- [x] **TASK-FG3-06** `[Backend]` Implement `ingredient_extractor.ts` (`extractIngredientsSection`) with fuzzy header matching and Nutrition Facts exclusion (`has_ingredients`).

### Phase 3: Scan History Persistence & Tests (`UC08`)
- [x] **TASK-FG3-07** `[Backend]` Implement owner-scoped `/api/v1/scans` (`GET`, `POST`, `DELETE`) in `src/cloudflare-worker/src/auth_profile.ts` backed by D1 `scan_history`.
- [x] **TASK-FG3-08** `[Mobile]` *(Truong Gia Linh)* Implement History tab in `HomeScreen` (`home_screen.dart`), `ProfileService` scan CRUD, and `LocalGuestStore` local scan persistence/deletion.
- [x] **TASK-FG3-09** `[Test]` *(Truong Gia Linh)* Verify OCR proxy, ingredient extraction, failover router, and scanner math via `vitest run` (`worker.test.ts`) and `flutter test` (`paddle_ocr_vl_service_test.dart`, `widget_test.dart`).
