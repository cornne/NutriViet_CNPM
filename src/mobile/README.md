# NutriViet Mobile Application (Flutter)

Android-first mobile client for **NutriViet**, built with **Flutter (Dart 3.x)** and a lightweight **Kotlin native** image-optimization bridge. Out of the box, it connects directly to the live **Cloudflare Workers + D1** production backend (`https://nutriviet.nutriviet-api.workers.dev/api/v1`) — no local server or client API keys required.

---

## Key Capabilities

- **Live CameraX Packaging Scanner + Edge OCR:** Full-screen camera viewfinder with flash, focus, gallery picker, native Android EXIF-aware JPEG compression (`MainActivity.kt` `com.nutriviet/image_opt` down to `<= 110 KB`), and **PaddleOCR-VL-1.6** via Cloudflare Edge Proxy (`/api/v1/ocr/jobs`).
- **Personalized FoodOn Allergen & Chronic Alerts:** Instant **RED / YELLOW / GREEN** label evaluation backed by 33,688 FoodOn ontology concepts, dynamic everyday trigger food lookup, and body metrics (BMI/TDEE).
- **Local-First Guest Mode + Cloud Sync:** Guests can configure allergens, chronics, family members, and scan labels locally (`LocalGuestStore`), then seamlessly sync everything to a cloud account upon sign-in.
- **Scan History Management:** View detailed allergen/additive breakdowns, swipe or tap to delete individual scans, or clear full history (both Cloud & Guest).
- **Community Feed & Admin Moderation (RBAC):** Authenticated users share product reviews with photos stored on Cloudflare D1; `admin` accounts unlock hidden moderation controls.
- **Liquid Glass UI & Strict Monolingual VI / EN Toggle:** Reactive `AppLocale` switching with zero mixed-language strings.

---

## Project Structure

```text
src/mobile/
├── android/app/src/main/kotlin/com/nutriviet/nutriviet_mobile/
│   └── MainActivity.kt               # Native Android EXIF-aware JPEG compressor channel
├── lib/
│   ├── main.dart                     # App entrypoint & session bootstrap
│   ├── l10n/app_locale.dart          # Reactive VI / EN language controller
│   ├── screens/                      # Home (+ Live Scanner/History), Login, Register, Verify,
│   │                                 # AllergyProfile, Settings, CommunityFeed, AdminModeration
│   ├── services/
│   │   ├── auth_service.dart         # Cloud auth & SharedPreferences session store
│   │   ├── profile_service.dart      # Profile, scans, and FoodOn ontology REST client
│   │   ├── paddle_ocr_vl_service.dart# Cloudflare Edge OCR proxy client + native compression
│   │   ├── community_service.dart    # Community posts, D1 image upload & Admin RBAC API
│   │   └── local_guest_store.dart    # On-device Guest Mode storage & Cloud Sync
│   ├── theme/nutriviet_glass.dart    # Liquid Glass design tokens & backdrop
│   └── widgets/                      # Reusable glass modals, shimmer skeletons & scanner reticle
└── test/
    ├── paddle_ocr_vl_service_test.dart # Edge OCR proxy, retry, auth & cancellation tests
    └── widget_test.dart              # UI, localization, Guest store, profile & RBAC tests
```

---

## Quick Start

### Prerequisites
- Flutter SDK `>= 3.24` (Dart `>= 3.5`)
- Android SDK / Emulator or physical Android device (min SDK 26)

### Run & Verify
```bash
cd src/mobile

# 1. Install dependencies
flutter pub get

# 2. Static analysis & unit/widget tests (22 tests)
flutter analyze
flutter test

# 3. Run on a connected Android device or emulator
flutter run

# 4. Build a clean Release APK (no API token flags needed)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Backend URL Configuration

- **Release builds (`kReleaseMode == true`)** call `https://nutriviet.nutriviet-api.workers.dev/api/v1` exclusively (zero localhost probes).
- **Debug builds** check `http://127.0.0.1:8050/api/v1` first (for local testing with `src/backend/foodon_ui_server.py` + `adb reverse tcp:8050 tcp:8050`) and fall back to Cloudflare automatically.
- **Custom backend override:**
  ```bash
  flutter build apk --release --dart-define=NUTRIVIET_API_ROOT=https://your-worker.workers.dev/api/v1
  ```
- **Optional personal AI Studio OCR token:** By default, OCR uses the encrypted secret on Cloudflare Worker. Users can optionally enter a custom token via the Key icon on the Scanner screen (sent in `X-PaddleOCR-Token`).
