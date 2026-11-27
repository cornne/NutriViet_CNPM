# Implementation Plan: FG3 - Packaging OCR Scanner & Scan History

**Branch**: `003-fg3-ocr-scanner` | **Date**: 16/11/2026 (Updated 25/11/2026) | **Spec**: [spec.md](spec.md)  
**Deliverable**: PA4-2026 Section E (Full-Stack Implementation)  
**Lead Architect**: Le Tat Nam | **Mobile Lead**: Luong Hoang Nam | **Scan History & QA Lead**: Truong Gia Linh | **Reviewer**: Ngo Tien Binh

---

## 1. Technical Architecture & Data Flow

```text
+-----------------------------------------------------------------------------+
|                         FLUTTER + KOTLIN MOBILE CLIENT                      |
|                                                                             |
|  PackagingScannerScreen (CameraX + ImagePicker + PackagingScannerMath)      |
|        |                                                                    |
|        v  MethodChannel("com.nutriviet/image_opt")                          |
|  MainActivity.kt -> compressForOcr (EXIF rotate, crop, JPEG <= 180 KB)      |
|        |                                                                    |
|        v  PaddleOcrVlService (Multipart POST + Async Poll + CancelToken)    |
+--------|--------------------------------------------------------------------+
         | HTTPS POST /api/v1/ocr/jobs
         v
+-----------------------------------------------------------------------------+
|                    CLOUDFLARE WORKERS API (src/cloudflare-worker/)          |
|                                                                             |
|  ocr_proxy.ts  -->  OcrProviderRouter (ocr_router.ts, 5-tier failover)      |
|       |                  |-- Tier 1: kilo-particle-1                        |
|       |                  |-- Tier 2: cf-mistral-vision (Workers AI)         |
|       |                  |-- Tier 3: baidu-paddleocr (PaddleOCR-VL-1.6)     |
|       |                  |-- Tier 4: kilo-nemotron-vl                       |
|       |                  |-- Tier 5: cf-llama4-vision (Workers AI)          |
|       v                                                                     |
|  extractCleanOcrText() + extractIngredientsSection() (ingredient_extractor) |
|       |                                                                     |
|       v  auth_profile.ts (/api/v1/scans CRUD)                               |
+-------|---------------------------------------------------------------------+
        | Cloudflare D1 Binding (APP_DB)
        v
+-----------------------------------------------------------------------------+
|                   CLOUDFLARE D1: nutriviet-app (APAC)                       |
|  - ocr_provider_state (persistent provider cooldowns & metrics)             |
|  - scan_history (owner-scoped persisted scans & verdicts)                   |
+-----------------------------------------------------------------------------+
```

---

## 2. Physical Code Layout (Implemented)

```text
src/
├── cloudflare-worker/
│   ├── src/
│   │   ├── index.ts                 # Rate limiter & route registration
│   │   ├── ocr_proxy.ts             # /api/v1/ocr/jobs, /providers, text cleaner
│   │   ├── ocr_router.ts            # 5-tier OcrProviderRouter + D1 cooldowns
│   │   ├── ingredient_extractor.ts  # Fuzzy Ingredients-only section extractor
│   │   └── auth_profile.ts          # /api/v1/scans GET/POST/DELETE
│   └── test/worker.test.ts          # Vitest cases for OCR, extractor & router
└── mobile/
    ├── android/app/src/main/kotlin/com/nutriviet/nutriviet_mobile/
    │   └── MainActivity.kt          # MethodChannel('com.nutriviet/image_opt')
    ├── lib/
    │   ├── screens/
    │   │   ├── packaging_scanner_screen.dart
    │   │   └── home_screen.dart     # History tab & SWR cache
    │   └── services/
    │       ├── paddle_ocr_vl_service.dart
    │       ├── profile_service.dart
    │       └── local_guest_store.dart
    └── test/
        ├── paddle_ocr_vl_service_test.dart
        └── widget_test.dart
```
