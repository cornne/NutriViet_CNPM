# Research & Architectural Spikes: FG3 - Packaging OCR Scanner

**Feature**: `003-fg3-ocr-scanner`  
**Lead Researchers**: Le Tat Nam (Backend) & Luong Hoang Nam (Mobile)  
**Date**: 16/11/2026 (Updated 25/11/2026)

---

## 1. Edge OCR Proxy vs. On-Device ML Kit
* **Context:** Vietnamese packaging labels contain dense diacritics, glossy reflections, and small E/INS additive codes where on-device ML Kit Latin/Vietnamese models frequently drop diacritics or split tables improperly.
* **Decision:** Route compressed packaging images through Cloudflare Workers (`/api/v1/ocr/jobs`) to a **5-tier fastest-to-slowest Vision/OCR failover chain** (`OcrProviderRouter` in `src/cloudflare-worker/src/ocr_router.ts`), with `PaddleOCR-VL-1.6` as Tier 3 layout-parsing anchor and Cloudflare Workers AI + Kilo Vision models for sub-3s fast-path responses.
* **Security Benefit:** Zero third-party OCR API keys are bundled into the Android APK.

## 2. Native Kotlin EXIF-Aware Compression (`MainActivity.kt`)
* **Context:** Uploading raw 12MP–50MP camera photos over 4G in supermarkets causes high latency and exceeds worker payload limits.
* **Decision:** Implement `compressForOcr` on `MethodChannel("com.nutriviet/image_opt")` in `MainActivity.kt` using a dedicated background thread executor (`compressJpegForOcr`), reducing images to `maxSide = 1280` and `<= 180 KB` in ~35 ms while respecting EXIF orientation and normalized crop rectangles from `PackagingScannerMath`.

## 3. Ingredients-Only Section Extraction (`ingredient_extractor.ts`)
* **Context:** Photos often capture both the *Nutrition Facts* table and *Storage Instructions* alongside *Ingredients*, causing false positives or noise.
* **Decision:** Implement `extractIngredientsSection` using Levenshtein fuzzy header matching (`fuzzyHeaderSimilarity`) to isolate `INGREDIENT_START_HEADERS` + `ALLERGEN_KEEP_HEADERS` and terminate before `NUTRITION_STOP_HEADERS` / `GENERAL_STOP_HEADERS`.
