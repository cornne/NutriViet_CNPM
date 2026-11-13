# Tasks: FG1 - Authentication & Authorization

**Feature**: `001-fg1-authentication`  
**Prerequisites**: [plan.md](plan.md) (approved), [spec.md](spec.md) (approved)  
**Deliverable**: PA3-2026 Section E Task Breakdown  

---

## Task Organization by User Story & Phase

```
Phase 1: Setup & Database Infrastructure
Phase 2: User Story 1 - Account Registration (Pending Verification)
Phase 3: User Story 2 - Account Authentication (Mandatory Verification Gate, No Demo, No Google)
Phase 4: User Story 3 - Password Recovery & Reset Flow (Forgot Password)
Phase 5: User Story 4 - Immediate Redirection to FG2 User Allergy Profile Setup
Phase 6: End-to-End Integration, Demonstration & Video Recording
```

---

### Phase 1: Setup & Database Infrastructure

- [x] **TASK-E01** `[Setup]` Initialize backend folder structure and create SQLite database management module (`src/backend/database.py`).
- [x] **TASK-E02** `[Setup]` Define `users` schema with primary key, unique email index, salted password hash column, `is_verified`, `verification_token`, `reset_token`, and timestamp.
- [x] **TASK-E03** `[Setup]` Initialize Flutter project configuration (`src/mobile/pubspec.yaml`) and Android networking permissions (`android/app/src/main/AndroidManifest.xml`).

---

### Phase 2: User Story 1 - Registration (P1)

- [x] **TASK-E04** `[Backend]` Implement cryptographic password salting and hashing utility (`src/backend/database.py`) using PBKDF2 HMAC-SHA256 with 100,000 rounds.
- [x] **TASK-E05** `[Backend]` Implement `POST /api/v1/auth/register` route handling JSON parsing, duplicate email validation (`409 Conflict`), and user insertion with `is_verified = 0`.
- [x] **TASK-E06** `[Mobile]` Create `AuthService.register()` in `src/mobile/lib/services/auth_service.dart` invoking cloud backend API.
- [x] **TASK-E07** `[Mobile]` Build `RegisterScreen` (`src/mobile/lib/screens/register_screen.dart`) with blank default inputs and password strength meter.

---

### Phase 3: User Story 2 - Authentication & Mandatory Verification Gate (P1)

- [x] **TASK-E08** `[Backend]` Implement `POST /api/v1/auth/login` validating password hash and enforcing mandatory verification check (`is_verified == 1`). If unverified, respond with `403 Forbidden` (`EMAIL_NOT_VERIFIED`).
- [x] **TASK-E09** `[Backend]` Implement `GET /api/v1/users` diagnostic endpoint allowing examiners/demo review of persistent SQLite records.
- [x] **TASK-E10** `[Mobile]` Create `AuthService.login()` in `src/mobile/lib/services/auth_service.dart` handling session token caching and error decoding.
- [x] **TASK-E11** `[Mobile]` Refactor `LoginScreen` (`src/mobile/lib/screens/login_screen.dart`):
  - Blank default inputs (no pre-filled credentials).
  - Remove Google Sign-In button completely.
  - Remove Demo auto-fill credentials shortcut button.
  - Trigger `_showUnverifiedEmailDialog()` when unverified account attempts login.

---

### Phase 4: User Story 3 - Password Recovery (Forgot Password) (P2)

- [x] **TASK-E12** `[Backend]` Implement `create_reset_token()` in `database.py` and route `POST /api/v1/auth/forgot-password` in `server.py`.
- [x] **TASK-E13** `[Mobile]` Add `AuthService.forgotPassword()` in `src/mobile/lib/services/auth_service.dart`.
- [x] **TASK-E14** `[Mobile]` Implement `_showForgotPasswordDialog()` in `LoginScreen` allowing consumers to request recovery instructions.

---

### Phase 5: User Story 4 - Post-Login Onboarding Redirection to FG2 Profile (P1)

- [x] **TASK-E15** `[Mobile]` Update `AllergyProfileScreen` to accept `isInitialSetup = true` flag.
- [x] **TASK-E16** `[Mobile]` In `LoginScreen`, redirect successful authentication directly to `AllergyProfileScreen(userId, userName, isInitialSetup: true)` to ensure dietary safety configurations are completed immediately.
- [x] **TASK-E17** `[Mobile]` In `AllergyProfileScreen`, upon saving initial profile, smoothly transition the user into the main `HomeScreen`.

---

### Phase 6: Integration, Verification & Video Recording

- [x] **TASK-E18** `[E2E]` Execute end-to-end integration test: Register with blank form, verify 403 blocking prior to activation, verify activation flow, and verify direct transition to FG2 Allergy Profile.
- [x] **TASK-E19** `[E2E]` Verify negative scenarios: unverified account rejection, duplicate email prevention, and forgot password dispatch.
- [x] **TASK-E26** `[Video]` Record and publish end-to-end live software video demonstration to [YouTube](https://www.youtube.com/watch?v=-LUs4PHV20Q) demonstrating zero-prefill login, email activation, security settings, body metrics, and allergen persistence.

---

### Phase 7: User Story 5 - Settings, Change Password & Body Nutrition Metrics (Standard Nutrition App)

- [x] **TASK-E20** `[Backend]` Implement `user_metrics` SQLite schema and endpoints (`GET/POST /api/v1/profile/metrics`) with automatic WHO/Asian BMI classification and Mifflin-St Jeor TDEE caloric calculation.
- [x] **TASK-E21** `[Mobile]` Add interactive Physical & Nutrition Metrics Card to `AllergyProfileScreen` letting consumers enter age, gender, height, and weight with real-time BMI and caloric feedback.
- [x] **TASK-E22** `[Mobile & Backend]` Create `SettingsScreen` (`src/mobile/lib/screens/settings_screen.dart`) and `POST /api/v1/auth/change-password` allowing users to change temporary passwords to permanent passwords and update account information.

---

### Phase 8: Mobile Ergonomics, Taskbar & Community Crowdsourcing (FG7 / UC15)

- [x] **TASK-E23** `[Mobile]` Re-organize mobile bottom taskbar into a modern 5-item layout with prominent center glowing QUÉT (Scan) button flanked by Trang chủ, Cộng đồng, Đăng tải, and Lịch sử.
- [x] **TASK-E24** `[Mobile]` Implement Crowdsourced Product & Packaging Photo Upload (`ContributeProductScreen`) with dual photo uploader (Front packaging & Ingredients OCR), barcode lookup, and allergen warning tags.
- [x] **TASK-E25** `[Mobile]` Implement Community Social Feed (`CommunityFeedScreen`) with allergen hazard alerts, packaging previews, likes, and comment interactions.
