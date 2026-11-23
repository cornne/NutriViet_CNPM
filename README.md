# NutriViet: Smart Personalized Nutrition & Food Allergy Warning Mobile Application

[![Course](https://img.shields.io/badge/Course-CS300%20Software%20Engineering-blue.svg)](https://www.fit.hcmus.edu.vn/)
[![Institution](https://img.shields.io/badge/Institution-VNU--HCM%20University%20of%20Science-green.svg)](https://hcmus.edu.vn/)
[![Methodology](https://img.shields.io/badge/Methodology-Scrum%20%2F%20Agile-orange.svg)]()
[![Development](https://img.shields.io/badge/Spec--Driven-GitHub%20Spec%20Kit-purple.svg)](https://github.com/github/spec-kit)
[![Backend](https://img.shields.io/badge/Backend-Cloudflare%20Workers%20%2B%20D1-F38020.svg?logo=cloudflare&logoColor=white)](https://nutriviet.nutriviet-api.workers.dev/health)
[![Video Demo](https://img.shields.io/badge/YouTube-Video%20Demo-red.svg?logo=youtube)](https://www.youtube.com/watch?v=-LUs4PHV20Q)

> **NutriViet** is an Android mobile application engineered to protect consumers with personalized food allergy hazard alerts and proactive nutrition management. Combining a full-screen **Live CameraX** label scanner, **PaddleOCR-VL-1.6** via a secure **Cloudflare Workers Edge Proxy**, and the **FoodOn semantic ontology (33,688 concepts)** hosted on **Cloudflare D1 (APAC)**, NutriViet translates complex ingredient labels into unambiguous color-coded alerts (**RED** allergen hazard / **YELLOW** chronic condition caution / **GREEN** safe), alongside local-first Guest Mode, scan history management, and an RBAC-protected Community & Admin Moderation platform.

---

## Live Production Services (Cloudflare Free Tier — APAC)

| Service | URL |
| :--- | :--- |
| **API Health Check** | https://nutriviet.nutriviet-api.workers.dev/health |
| **Interactive FoodOn Ontology Graph** | https://nutriviet.nutriviet-api.workers.dev/foodon-graph |
| **REST API Base URL** | `https://nutriviet.nutriviet-api.workers.dev/api/v1` |

---

## Team Members & Leadership Roster

**Group:** Group 07 - NutriViet Team  
**Institution:** Faculty of Information Technology, VNU-HCM University of Science (HCMUS)

| No. | Student ID | Full Name | Project Role & Primary Responsibilities |
| :---: | :---: | :--- | :--- |
| 1 | **24127004** | **Ngo Tien Binh** | **Project Manager (PM) & AI Lead** / Full-Stack Engineer |
| 2 | **23127432** | **Le Tat Nam** | **Backend & System Architecture Lead** / Full-Stack Engineer |
| 3 | **24127456** | **Luong Hoang Nam** | **UI/UX & Flutter Lead** / Full-Stack Engineer |
| 4 | **24127242** | **Nguyen Hoang Phuc Thinh** | **Database & DevOps Lead** / Full-Stack Engineer |
| 5 | **24127438** | **Truong Gia Linh** | **QA & Test Automation Lead** / Full-Stack Engineer |

---

## Project Milestones & Semester Roadmap (5 Sprints)

| Sprint | Milestone | Status | Duration | Primary Focus & Deliverables |
| :---: | :--- | :---: | :---: | :--- |
| **Sprint 1** | **PA1-2026** | **Completed** | 25/09 – 17/10/2026 | Project Proposal, Existing App Survey (Yuko & Soosee), Team Contract, Scrum Setup |
| **Sprint 2** | **PA2-2026** | **Completed** | 18/10 – 31/10/2026 | Vision Document, Project Plan, GitHub Spec Kit Integration, Sprint 2 Reports |
| **Sprint 3** | **PA3-2026** | **Completed** | 01/11 – 14/11/2026 | Use-Case Model (Mermaid), 18 Use-Case Specs & 17 Prototypes, Full-Stack FG1 & FG2, Video Demo |
| **Sprint 4** | **PA4-2026** | **Active / Implemented** | 15/11 – 05/12/2026 | Full Cloudflare Workers + D1 Migration, FoodOn 33,688-Concept Engine & Graph UI, Live CameraX + PaddleOCR-VL-1.6 Edge Proxy, Guest Mode + RBAC Community/Admin, Automated Test Suites |
| **Sprint 5** | **PA5-2026** | *Upcoming* | 06/12 – 22/12/2026 | System Verification, Final Polish, Production APK Release, and Final Live Demo |

---

## Repository Directory Structure

```text
NutriViet_CNPM/
├── .github/skills/                    # Spec-Driven Development (Spec Kit) agent skills
├── .specify/                          # GitHub Spec Kit configuration, templates & scripts
├── docs/                              # Course documentation across all milestones
│   ├── assets/                        # Setup evidence, Trello boards & market survey screenshots
│   ├── analysis-and-design/           # Architecture & design documentation
│   ├── management/                    # Project Plan, Team Contract, Weekly Reports, Demo Script
│   ├── requirements/                  # Vision Document, Use-Case Specs & 17 UI Prototypes
│   └── test/                          # Test plans & automated test suite index
├── prototype/                         # Interactive HTML/CSS UI prototype
├── specs/                             # Active Spec Kit feature specifications
│   ├── 001-authentication/            # FG1: Authentication & Session Management
│   ├── 002-allergy-profile/           # FG2: Allergy Profile, Chronics & Body Metrics
│   └── 003-community-guest-rbac/      # Guest Mode, Community Feed & Admin RBAC Moderation
├── src/                               # Application source code
│   ├── cloudflare-worker/             # Production Serverless Backend (TypeScript / Hono / D1 + FoodOn Graph HTML)
│   ├── mobile/                        # Flutter Android Mobile Client (Dart 3 + Kotlin native)
│   ├── speckit/                       # Spec Kit governance templates & training log
│   └── constitution.md                # Ratified NutriViet Project Constitution
├── foodon_en_for_kaggle.csv           # 33,688 official FoodOn concepts export for NLP/translation
├── Changes.md                         # Traceable changes log (PA2 -> PA3)
├── proposal.md                        # Master Project Proposal & App Survey
└── README.md                          # Project overview & quick start
```

---

## Technology Stack & Architecture

| Layer | Technology | Role & Design Rationale |
| :--- | :--- | :--- |
| **Mobile Client** | **Flutter (Dart 3.x)** + **Kotlin Native** | Liquid Glass UI, strict monolingual **VI / EN** toggle (`AppLocale`), full-screen **CameraX** viewfinder, native Android EXIF-aware JPEG compressor (`MainActivity.kt` shrinks photos to `<= 110 KB` in ~35 ms), and local-first **Guest Mode** (`LocalGuestStore` via `SharedPreferences`). |
| **Vision OCR** | **PaddleOCR-VL-1.6** via **Cloudflare Edge Proxy** | Mobile uploads compressed packaging photos to `/api/v1/ocr/jobs`; Cloudflare Worker authenticates upstream using an encrypted Worker Secret (`PADDLEOCR_VL_TOKEN`) and cleans Markdown/HTML tables on the edge — zero API keys in the APK or repository. |
| **Cloud Backend** | **Cloudflare Workers** + **Hono** (TypeScript) | Serverless REST API with Smart Placement in APAC, Web Crypto PBKDF2-HMAC-SHA256 authentication, strict server-side Admin RBAC, and ready-to-plug HTTP email dispatch (Resend / Brevo). |
| **Cloud Databases** | **Cloudflare D1 (SQLite — APAC)** | Two dedicated D1 databases: `nutriviet-app` (users, profiles, scan history, community posts/media, static web UI) and `nutriviet-foodon` (33,688 FoodOn concepts, 53,242 lexical bridge terms, 742 E-codes, 8 B-tree indexes). |
| **Semantic Engine** | **FoodOn Ontology** + **Fuzzy Matching** | 4-stage ingredient recognition (exact match, E-code/INS lookup, stem/token match, typo-tolerant fuzzy match) with ancestor-chain inference from everyday foods (e.g., *butter*, *casein*, *whey*) to allergen families. |

---

## Quick Start & Commands

### 1. Flutter Mobile App (`src/mobile/`)
Works out-of-the-box against the live Cloudflare Workers backend (no local server or API key required):
```bash
cd src/mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
See [src/mobile/README.md](./src/mobile/README.md) for emulator setup, physical device deployment, and custom backend overrides.

### 2. Cloudflare Workers Production Backend (`src/cloudflare-worker/`)
```bash
cd src/cloudflare-worker
npm install
npm run typecheck
npm test
npm run build
```
See [src/cloudflare-worker/README.md](./src/cloudflare-worker/README.md) for D1 database IDs, API routes, and secret management.

---

## Automated Verification Summary

| Module | Command | Suite Coverage |
| :--- | :--- | :--- |
| **Flutter Mobile** | `cd src/mobile && flutter analyze && flutter test` | **22 tests** — UI/Glass widgets, VI/EN localization, Guest Mode & scan delete/clear, RBAC gates, Cloudflare OCR Proxy pipeline & retries |
| **Cloudflare Worker** | `cd src/cloudflare-worker && npm run typecheck && npm test` | **4 tests** — PBKDF2 parity, ingredient splitting, OCR Markdown/HTML cleaning, WHO/VN BMI & TDEE calculation |

---

## Deliverables & Documentation Index

- **PA1-2026:** [Project Proposal](./proposal.md) · [Team Contract](./docs/management/team-contract.md)
- **PA2-2026:** [Vision Document](./docs/requirements/vision.md) · [Project Plan](./docs/management/project-plan.md) · [Constitution](./src/constitution.md) · [Weekly Reports](./docs/management/weekly-reports.md)
- **PA3-2026:** [Use-Case Model & 18 Specs](./docs/requirements/use-cases.md) · [Changes Log](./Changes.md) · [Video Demo Script](./docs/management/video-demo-script.md) · [Spec Kit Artifacts](./src/speckit/README.md)
- **Active Specs:** [FG1 Auth](./specs/001-authentication/) · [FG2 Allergy Profile](./specs/002-allergy-profile/) · [Guest & Community RBAC](./specs/003-community-guest-rbac/spec.md)

---

## Development & Contribution Workflow

1. **Branching Strategy:** Work on feature branches (`feat/`, `fix/`, `docs/`, `refactor/`) and merge into `main` via Pull Request after verification.
2. **Commit Standard:** Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`).
3. **Security Hygiene:** Never commit API tokens, `.env` files, build outputs, or local SQLite databases. Secrets belong exclusively in Cloudflare Worker Secrets.
4. **Documentation Attribution:** Milestone documentation includes:
   > `*Performed by: [Name] | Reviewed by: [Name] | Edited by: [Name]*`
