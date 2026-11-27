# NutriViet: Summary of Changes (PA4-2026 Submission)
**Course:** CS300 - CSC13002 - Introduction to Software Engineering  
**Project Assignment:** PA4-2026  
**Group:** Group 07 - NutriViet Team  
**Submission Date:** 25/11/2026  

---

## Overview
*Performed by: Nguyen Hoang Phuc Thinh | Reviewed by: Ngo Tien Binh | Edited by: Truong Gia Linh*

This `Changes.md` document provides a traceable record of all modifications, extensions, and refinements implemented in the NutriViet project artifacts for the **Project Assignment 4 (PA4-2026)** milestone compared to the previous **PA3-2026** baseline. In accordance with PA4 guidelines, changes are grouped by revised document.

---

## Section A - Changes in Revised Use-Case Model & Specifications (`docs/requirements/use-cases.md`)
*Performed by: Luong Hoang Nam | Reviewed by: Ngo Tien Binh | Edited by: Le Tat Nam*

| # | Section / Component | Type of Change | Description & Codebase Alignment Rationale |
|:---:|:---|:---:|:---|
| 1 | **Header & Submission Metadata** | *Updated* | Promoted document status from PA3-2026 (`14/11/2026`) to **PA4-2026 (Section A Revised Submission, `25/11/2026`)**. |
| 2 | **Section 2.1 System Actors** | *Refined (Major)* | Replaced `Google ML Kit OCR Engine` with **Edge OCR Vision Router** (Cloudflare Workers proxy + 5-tier failover chain incl. `PaddleOCR-VL-1.6`). Updated `Consumer` to encompass local-first **Guest Mode** (`LocalGuestStore`), `System Administrator` to reflect hidden RBAC `AdminModerationScreen` (`/api/v1/admin/*`), and `FoodOn Semantic Ontology Engine` to reflect **Cloudflare D1 (`nutriviet-foodon`: 33,688 concepts, 53,242 lexical terms, 742 E-codes)**. Removed OAuth identity from `User`. |
| 3 | **Section 2.2 & 2.3 Mermaid Diagrams** | *Updated* | Updated Global Use-Case Diagram and Subsystem 1 & 2 Mermaid diagrams: replaced `UC02b: Google OAuth 2.0 Login` with `UC02b: Local-First Guest Mode Entry`, and replaced `Google ML Kit` secondary actor nodes with `Edge OCR Vision Router (Cloudflare Proxy)` and `FoodOn Semantic Ontology (D1)`. |
| 4 | **Section 2.4 Relationship Analysis** | *Updated* | Updated `UC02a`/`UC02b` generalization semantics to reflect Email/Password Cloud Login and Local-First Guest Mode Entry. |
| 5 | **UC01 & UC02 Specifications** | *Refined (Major)* | Removed decommissioned Google OAuth (`A4` in `UC01`) and Argon2id/JWT refresh flows. Aligned with `src/cloudflare-worker/src/auth_profile.ts` and `src/mobile/lib/services/auth_service.dart`: **PBKDF2-HMAC-SHA256** (100,000 iterations), **Cloudflare D1 (`nutriviet-app`)**, email verification gate (`VerifyEmailScreen`, Brevo/Resend), 32-byte Bearer `user_sessions` in `SharedPreferences`, IP rate limiting (`SlidingWindowRateLimiter`), 6-digit OTP password reset, and Guest Mode entry. |
| 6 | **UC03 & UC04 Specifications** | *Refined* | Updated `UC03` to use `POST /api/v1/auth/change-password` (revoking other active sessions) and `update-profile`. Updated `UC04` to persist profiles in **Cloudflare D1** or `LocalGuestStore` (`SharedPreferences`) and reflect automatic re-evaluation of up to 25 recent `scan_history` records when allergens change. |
| 7 | **UC06 & UC07 Specifications** | *Refined (Major)* | Replaced `Google ML Kit` and `Otsu thresholding` with the implemented pipeline: Flutter `CameraController` (CameraX) + `image_picker`, `PackagingScannerMath` crop mapping, native Android EXIF-aware JPEG compression (`MainActivity.kt` `com.nutriviet/image_opt`), and `POST /api/v1/ocr/jobs` on Cloudflare Workers (`ocr_proxy.ts` + `ocr_router.ts` + `ingredient_extractor.ts`). |
| 8 | **UC08 & UC09 Specifications** | *Refined* | Updated `UC08` to query Cloudflare D1 `scan_history` or `LocalGuestStore` with individual and bulk delete (`DELETE /api/v1/scans/:id`, `DELETE /api/v1/scans`). Updated `UC09` to document the 4-stage `D1FoodOnEngine` pipeline (`ecode_bridge`, `lexical_bridge`, 1–4 word n-grams, Levenshtein fuzzy threshold $\ge 82\%$). |
| 9 | **UC17 Specification** | *Refined* | Aligned admin moderation workflow with the implemented RBAC-protected `AdminModerationScreen` (Reports, Posts, Users tabs) and `/api/v1/admin/*` endpoints. |

---

## Section B, C & D - Architecture & Deployment Documentation (`docs/analysis-and-design/architecture.md`)
*Performed by: Le Tat Nam, Luong Hoang Nam & Nguyen Hoang Phuc Thinh | Reviewed by: Ngo Tien Binh | Edited by: Truong Gia Linh*

| # | Section / Component | Type of Change | Description & Codebase Alignment Rationale |
|:---:|:---|:---:|:---|
| 1 | **Tech Stack Specification (Section B)** | *Added (New)* | Documented the full production technology stack matching `src/mobile/` (Flutter 3.x / Dart 3, Kotlin native `MainActivity.kt`, CameraX, `SharedPreferences`) and `src/cloudflare-worker/` (Cloudflare Workers, Hono 4.7.4, TypeScript 5.7, Cloudflare D1 APAC `nutriviet-app` & `nutriviet-foodon`, Workers AI, 5-tier OCR Router, Brevo/Resend HTTP Email). |
| 2 | **C4 Level 1: System Context Diagram (Section B)** | *Added (New)* | Authored Mermaid System Context diagram and narrative explanation covering `Consumer / Guest`, `System Administrator`, `NutriViet System`, and external systems (Kilo/OpenAI-compatible Vision APIs, Baidu AI Studio `PaddleOCR-VL-1.6`, Cloudflare Workers AI, and Brevo/Resend Email Service). |
| 3 | **C4 Level 2: Container Diagram (Section C)** | *Added (New)* | Authored Mermaid Container diagram and container specification table covering `Mobile Application`, `Cloudflare Workers API`, `nutriviet-app` D1 (`APP_DB`), `nutriviet-foodon` D1 (`FOODON_DB`), and `FoodOn Graph Explorer` (`/foodon-graph`). |
| 4 | **C4 Level 3: Component Diagrams (Section C)** | *Added (New)* | Authored both **Frontend** (`src/mobile/lib/` screens, services, `LocalGuestStore`, `MainActivity.kt`) and **Backend** (`src/cloudflare-worker/src/` Hono router, `SlidingWindowRateLimiter`, `auth_profile.ts`, `community.ts`, `D1FoodOnEngine`, `ocr_proxy.ts`, `OcrProviderRouter`) Mermaid component diagrams and tables. |
| 5 | **Deployment Diagram (Section D)** | *Added (New)* | Authored Mermaid Deployment diagram and infrastructure node table mapping containers to the User Android Device, Cloudflare Edge (Workers APAC, D1 APAC, Workers AI), and external cloud nodes (Kilo, Baidu AI Studio, Brevo/Resend). |

---

## Section F - Management & Spec Kit Infrastructure Alignment (`docs/management/`, `specs/`)
*Performed by: Nguyen Hoang Phuc Thinh | Reviewed by: Le Tat Nam | Edited by: Truong Gia Linh*

| # | Document | Type of Change | Description & Rationale |
|:---:|:---|:---:|:---|
| 1 | `docs/management/project-plan.md` | *Updated* | Replaced legacy PythonAnywhere reference in `TASK-25` with **Cloudflare Workers + Cloudflare D1**. |
| 2 | `docs/management/weekly-reports.md` | *Updated* | Updated Sprint 4 Planning (`16/11/2026`) tasks and obstacles (`Le Tat Nam`, `Nguyen Hoang Phuc Thinh`) from PythonAnywhere (`wsgi_app.py`) to `src/cloudflare-worker/` and Cloudflare D1 schema migrations. |
| 3 | `specs/` & `src/speckit/specs/` | *Updated* | Fully aligned `001-authentication` (`spec.md`, `data-model.md`, `plan.md`, `tasks.md`, `research.md`, `requirements.md`, `openapi.json`), `002-allergy-profile` (`plan.md`, `tasks.md`, `research.md`), and `003-community-guest-rbac/spec.md` with Cloudflare Workers + D1 (`nutriviet-app`), Web Crypto PBKDF2-HMAC-SHA256, admin-protected `/api/v1/users`, decommissioned `user_metrics` (`/api/v1/profile/metrics` 404), and `vitest run`. |

---

## Section E - Spec Kit Artifacts for PA4 Functional Groups (`specs/003-ocr-scanner/`, `specs/004-allergen-evaluation/`)
*Performed by: Le Tat Nam, Ngo Tien Binh & Truong Gia Linh | Reviewed by: Luong Hoang Nam | Edited by: Nguyen Hoang Phuc Thinh*

| # | Spec Kit Suite | Type of Change | Description & Codebase Alignment Rationale |
|:---:|:---|:---:|:---|
| 1 | **`003-ocr-scanner` (FG3: `UC06`–`UC08`)** | *Added (New)* | Authored complete Spec Kit lifecycle (`spec.md`, `plan.md`, `data-model.md`, `research.md`, `contracts/openapi.json`, `tasks.md`, `checklists/requirements.md`) documenting `PackagingScannerScreen`, `MainActivity.kt` (`compressForOcr`), `PaddleOcrVlService`, `OcrProviderRouter` (5-tier failover), `extractIngredientsSection`, and `/api/v1/scans` + `LocalGuestStore`. |
| 2 | **`004-allergen-evaluation` (FG4: `UC09`)** | *Added (New)* | Authored complete Spec Kit lifecycle (`spec.md`, `plan.md`, `data-model.md`, `research.md`, `contracts/openapi.json`, `tasks.md`, `checklists/requirements.md`) documenting `D1FoodOnEngine` (`nutriviet-foodon` 33,688 concepts, 53,242 lexical terms, 742 E-codes), Levenshtein $\ge 82\%$, `scan_derivatives`/`warn_traces`, `/foodon-graph`, and `worker.test.ts`. |
| 3 | **PA4 Narrated Video Demo (`video-demo-script.md`)** | *Added (New)* | Recorded and published end-to-end FG3 & FG4 narrated video demonstration on [YouTube](https://www.youtube.com/watch?v=p96107Qfwzk) accompanied by bilingual narration script (`docs/management/video-demo-script.md`). |
