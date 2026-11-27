# Feature Specification: FG3 - Packaging OCR Scanner & Scan History

**Feature Branch**: `003-fg3-ocr-scanner`  
**Created**: 16/11/2026  
**Updated**: 25/11/2026  
**Status**: Approved & Implemented  
**Use Cases**: `UC06` (Scan Label via Camera), `UC07` (Preprocess & Crop Label Image), `UC08` (View & Filter Scan History)  
**Author / Reviewer**: Le Tat Nam (Backend), Luong Hoang Nam (Mobile) & Truong Gia Linh (Scan History & QA) | Reviewed by: Ngo Tien Binh

---

## 1. Purpose & Scope
This specification defines the end-to-end **Packaging OCR Scanner & Scan History (FG3)** pipeline for **NutriViet**. It covers live Android CameraX capture, gallery import with interactive crop bounds, native Kotlin EXIF-aware JPEG compression, a 5-tier Cloudflare Workers Edge OCR Router (`PaddleOCR-VL-1.6` + Vision failover), Ingredients-only text extraction, and persistent Scan History management across both Cloud accounts (Cloudflare D1) and Guest Mode (`LocalGuestStore`).

---

## 2. User Scenarios & Testing *(mandatory)*

### User Story 1 - Live CameraX Capture & Native Image Optimization (`UC06`) (Priority: P1)
**As a** shopper in a retail aisle,  
**I want to** point my Android camera at a packaged food label with flash and framing guidance,  
**So that** the ingredient panel is captured clearly and compressed quickly without burning mobile data or storing API keys on my phone.

**Acceptance Scenarios**:
1. **Scenario 1.1 (Live CameraX Viewfinder):**
   - **Given** the user taps the center Scan Orb on `NutriVietFloatingBottomBar`,
   - **When** `PackagingScannerScreen` initializes `CameraController` (`_ScannerStage.liveCamera`),
   - **Then** the app renders a full-screen live viewfinder with `NutriVietScannerReticle`, torch toggle, and gallery picker button.
2. **Scenario 1.2 (Native EXIF-Aware Compression):**
   - **Given** a captured or cropped packaging photo,
   - **When** `PaddleOcrVlService.optimizeBytesForUpload` invokes `MethodChannel('com.nutriviet/image_opt')` (`compressForOcr` in `MainActivity.kt`),
   - **Then** the native background executor rotates by EXIF, applies normalized crop coordinates, downscales (`maxSide = 1280`), and compresses the JPEG to `<= 180 KB`.

---

### User Story 2 - Gallery Crop Review & 5-Tier Edge OCR Extraction (`UC07`) (Priority: P1)
**As a** shopper scanning cluttered or curved packaging,  
**I want to** crop to the Ingredients paragraph and rely on fast cloud OCR failover that strips Nutrition Facts noise,  
**So that** only relevant ingredient text is extracted reliably.

**Acceptance Scenarios**:
1. **Scenario 2.1 (Bounded Gallery Crop Math):**
   - **Given** a user imports a photo via `image_picker` (`_ScannerStage.cropReview`),
   - **When** `PackagingScannerMath.mapCoverFrameToImageNormRect` / `computeContainImageRect` computes the crop rectangle,
   - **Then** normalized `(cropLeft, cropTop, cropWidth, cropHeight)` coordinates are passed to `compressForOcr`.
2. **Scenario 2.2 (Cloudflare Edge OCR Proxy & 5-Tier Failover):**
   - **Given** the mobile client uploads a compressed JPEG (`<= 5 MB`) to `POST /api/v1/ocr/jobs`,
   - **When** `OcrProviderRouter` processes the job,
   - **Then** it tries providers fastest-to-slowest (`kilo-particle-1` -> `cf-mistral-vision` -> `baidu-paddleocr` -> `kilo-nemotron-vl` -> `cf-llama4-vision`), returning either a synchronous `state: "done"` result or an async `jobId` for `GET /api/v1/ocr/jobs/:jobId` polling (cancellable via `PaddleOcrCancelToken`).
3. **Scenario 2.3 (Ingredients-Only Extraction & Nutrition Facts Guard):**
   - **Given** raw OCR Markdown/HTML output,
   - **When** `extractCleanOcrText` and `extractIngredientsSection` run on Cloudflare Workers,
   - **Then** Markdown/HTML tables are stripped while preserving Vietnamese diacritics and E/INS codes; if only Nutrition Facts were captured, `has_ingredients: false` is returned and the UI transitions to `_ScannerStage.notFound`.

---

### User Story 3 - Persistent Scan History & Deletion (`UC08`) (Priority: P1)
**As a** consumer or Guest user,  
**I want to** view my past scans, delete individual records, or clear my history,  
**So that** I can revisit previous product verdicts anytime.

**Acceptance Scenarios**:
1. **Scenario 3.1 (Authenticated Cloud History):**
   - **Given** a signed-in user on the History tab of `HomeScreen`,
   - **When** `ProfileService.getScans` queries `GET /api/v1/scans`,
   - **Then** owner-scoped records from Cloudflare D1 `scan_history` are rendered chronologically, with delete (`DELETE /api/v1/scans/:id`) and clear-all (`DELETE /api/v1/scans`) support.
2. **Scenario 3.2 (Local-First Guest History):**
   - **Given** a Guest user,
   - **When** a label is scanned,
   - **Then** `LocalGuestStore.createLocalScan` persists up to 50 scans in `SharedPreferences` with individual `deleteScan` and `clearScans` support.

---

## 3. Non-Functional & Security Constraints
* **Zero Client Secrets**: Third-party OCR keys (`PADDLEOCR_VL_TOKEN`, Kilo key) live exclusively in Cloudflare Worker Secrets (optional user override supported via `X-PaddleOCR-Token`).
* **Rate Limiting**: `POST /api/v1/ocr/jobs` is rate-limited to `20 requests / 60s` per IP (`SlidingWindowRateLimiter`).
* **Payload Safety**: Server sniffs the image MIME type from magic bytes and enforces a `<= 5 MB` upload limit; `SAFE_JOB_ID_RE` prevents path traversal on `GET /api/v1/ocr/jobs/:jobId`.
