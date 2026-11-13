# Requirements Quality Checklist: FG1 - Authentication

**Purpose**: Review gate verifying specification adherence to NutriViet Constitution and PA3 guidelines.  
**Created**: 08/11/2026 (Updated: 10/11/2026)  
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md) | [tasks.md](../tasks.md)  
**Review Ownership**: Ngo Tien Binh (Project Manager & AI Lead)  

---

## 1. Specification Completeness Gate (Pre-Planning)

- [x] **CHK001** Feature has explicit priority assignment (`P1` for Register and Login).
- [x] **CHK002** User stories define clear Who, What, and Why in standard format.
- [x] **CHK003** Acceptance scenarios use formal **Given / When / Then** Gherkin syntax.
- [x] **CHK004** Alternative flows include error handling for duplicate emails (`409 Conflict`), unverified email (`403 Forbidden`), and wrong credentials (`401 Unauthorized`).
- [x] **CHK005** Traceability links exist to `UC01` and `UC02` in `docs/requirements/use-cases.md`.

---

## 2. Technical Architecture & Security Gate (Pre-Implementation)

- [x] **CHK006** Architecture adheres to the 3-tier boundary (Flutter UI ➔ Backend API ➔ Relational Database).
- [x] **CHK007** Passwords are salted and hashed using PBKDF2-HMAC-SHA256 (no plaintext storage).
- [x] **CHK008** Android Emulator networking address (`10.0.2.2:8000`) and Cloud Backend (`ngobinh2006.pythonanywhere.com`) are explicitly documented.
- [x] **CHK009** DDL schema contains primary key, unique constraint, verification flag (`is_verified`), and timestamp tracking.
- [x] **CHK010** UI error states follow WCAG 2.1 AA dual-coding (color + geometric icon).
- [x] **CHK011** Inputs initialize with clean, blank default strings (zero pre-fill policy). Google SSO and Demo accounts are removed.

---

## 3. Implementation Verification Gate (Post-Implementation)

- [x] **CHK012** Backend server executes and initializes database without manual schema scripts.
- [x] **CHK013** Flutter mobile application connects successfully to backend over HTTP.
- [x] **CHK014** Unverified users attempting login are blocked with HTTP 403 Forbidden and prompted to verify email.
- [x] **CHK015** Password recovery flow (`_showForgotPasswordDialog()`) dispatches reset token without exposing credential existence.
- [x] **CHK016** Authenticated session automatically navigates to `AllergyProfileScreen` (FG2) for immediate allergen onboarding.
- [x] **CHK017** Authenticated session tokens are cached persistently on device restart.
- [x] **CHK018** Source code is clean of binary dependencies (`node_modules`, `venv`, build caches).
- [x] **CHK019** User body physical metrics (Age, Gender, Height, Weight) calculate BMI and TDEE dynamically adhering to standard nutrition application UX.
- [x] **CHK020** Password change (`SettingsScreen`) accessible from top AppBar gear icon allows transitioning from temporary Gmail password to permanent password.
- [x] **CHK021** Bottom taskbar presents center prominent glowing QUÉT scanner button flanked symmetrically by Home, Community Social Feed, Crowdsource Upload, and History.
- [x] **CHK022** Crowdsource photo upload supports camera capture, gallery selection, and real-time community feed publishing.

---

## Reviewer Sign-Off
- **Status**: PASSED (22/22 Criteria Approved)
- **Reviewer**: Ngo Tien Binh (Lead Architect & PM)
- **Signature Date**: 10/11/2026
