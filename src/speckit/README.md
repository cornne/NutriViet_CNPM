# Spec Kit Artifacts (PA2 & PA3 - 2026)

This directory contains the governance and execution artifacts for **GitHub Spec Kit** for the **NutriViet** project, in full compliance with Part C of PA2 and **Section E of Project Assignment 3 (PA3-2026)**.

---

## 🎯 PA3 Section E: Spec-Driven Implementation of FG1 (Authentication)

In accordance with PA3-2026 requirements (*"Use Spec Kit to drive the implementation process: create specifications, generate plans, break down tasks, and implement following the spec-driven workflow"*), the team executed the complete SDD lifecycle for **FG1: Authentication & Authorization**:

| Stage | Spec Kit Artifact | Path | Description & Traceability |
|:---:|:---|:---|:---|
| **1. Specify** | **Feature Specification** | [`specs/001-authentication/spec.md`](./specs/001-authentication/spec.md) | User Stories (`US1: Register`, `US2: Login`, `US3: Validation`), Gherkin acceptance criteria, traceable to `UC01` & `UC02`. |
| **2. Research** | **Spikes & Tech Decisions** | [`specs/001-authentication/research.md`](./specs/001-authentication/research.md) | Technical investigation on PBKDF2 HMAC-SHA256 crypto, Android emulator networking (`10.0.2.2:8000`), and session caching. |
| **3. Plan** | **Implementation Plan** | [`specs/001-authentication/plan.md`](./specs/001-authentication/plan.md) | 3-tier architecture (Flutter + Python REST API + SQLite), component boundaries, and security constraints. |
| **4. Data Model**| **Schema & Data Dictionary** | [`specs/001-authentication/data-model.md`](./specs/001-authentication/data-model.md) | ER diagram, SQLite DDL schema for table `users`, data dictionary, and state transition machine. |
| **5. Contracts** | **RESTful API Contracts** | [`specs/001-authentication/contracts/openapi.json`](./specs/001-authentication/contracts/openapi.json) | OpenAPI 3.0 contract specification for registration, login, and user inspection endpoints. |
| **6. Tasks** | **Task Breakdown Structure**| [`specs/001-authentication/tasks.md`](./specs/001-authentication/tasks.md) | 25 fine-grained implementation tasks organized across 8 phases with 100% completion tracking (including Settings, Password Change, Body Metrics, Modern Taskbar, and Community Crowdsourcing). |
| **7. Gate** | **Quality Review Gate** | [`specs/001-authentication/checklists/requirements.md`](./specs/001-authentication/checklists/requirements.md) | 22/22 quality criteria verified and approved by PM & AI Lead (Ngo Tien Binh). |
| **8. Code** | **Full-Stack Source Code** | `src/mobile/` & `src/backend/` | Live running Flutter mobile client, Python backend service, and persistent SQLite database. |

---

## 🎯 PA3 Section E Extension: Spec-Driven Implementation of FG2 (Allergy Profile)

The team extended the implementation to cover **FG2: Personal Allergy Profile Management**, demonstrating cross-module integration:

| Stage | Spec Kit Artifact | Path | Description & Traceability |
|:---:|:---|:---|:---|
| **1. Specify** | **Feature Specification** | [`specs/002-allergy-profile/spec.md`](./specs/002-allergy-profile/spec.md) | User Stories (`US1: Select Allergens`, `US2: Severity Thresholds`, `US3: Restore`), Gherkin scenarios, traceable to `UC04` & `UC05`. |
| **2. Research** | **Spikes & Tech Decisions** | [`specs/002-allergy-profile/research.md`](./specs/002-allergy-profile/research.md) | Relational 3NF table vs JSON blob decision, atomic sync strategy, multi-tier severity mapping (High, Moderate, Mild). |
| **3. Plan** | **Implementation Plan** | [`specs/002-allergy-profile/plan.md`](./specs/002-allergy-profile/plan.md) | 3-tier architecture, data flow diagram, REST endpoints (`GET/POST /api/v1/profile/allergens`). |
| **4. Data Model**| **Schema & Data Dictionary** | [`specs/002-allergy-profile/data-model.md`](./specs/002-allergy-profile/data-model.md) | ER diagram, `user_allergens` table DDL, compound index `idx_user_allergen`, state machine. |
| **5. Contracts** | **RESTful API Contracts** | [`specs/002-allergy-profile/contracts/openapi.json`](./specs/002-allergy-profile/contracts/openapi.json) | OpenAPI 3.0 specification for profile allergen endpoints. |
| **6. Tasks** | **Task Breakdown Structure**| [`specs/002-allergy-profile/tasks.md`](./specs/002-allergy-profile/tasks.md) | 10 actionable engineering tasks across 4 phases. |
| **7. Gate** | **Quality Review Gate** | [`specs/002-allergy-profile/checklists/requirements.md`](./specs/002-allergy-profile/checklists/requirements.md) | 8/8 quality criteria verified and approved. |
| **8. Code** | **Full-Stack Source Code** | `src/mobile/` & `src/backend/` | `AllergyProfileScreen`, `ProfileService`, and SQLite `user_allergens` table. |


---

## Baseline Spec Kit Infrastructure

| Artifact | File Path | Description |
|---|---|---|
| **Project Constitution** | [constitution.md](./constitution.md) | The ratified project constitution detailing core engineering principles, health safety standards, Clean Architecture, test-first requirements, and team governance. |
| **Constitution Template** | [constitution-template.md](./constitution-template.md) | Baseline template generated by `specify init` for project constitutions. |
| **Specification Template** | [spec-template.md](./spec-template.md) | Standard template for writing functional specifications (`/speckit-specify`). |
| **Plan Template** | [plan-template.md](./plan-template.md) | Standard template for drafting technical implementation architecture plans (`/speckit-plan`). |
| **Tasks Template** | [tasks-template.md](./tasks-template.md) | Standard template for actionable task breakdowns and assignment (`/speckit-tasks`). |
| **Checklist Template** | [checklist-template.md](./checklist-template.md) | Quality validation and readiness checklist (`/speckit-checklist`). |

## Spec Kit Integration Summary
- **CLI Tool:** `specify-cli` (v0.3.x)
- **Integration Profile:** GitHub Copilot (`copilot`)
- **Root Configuration:** `.specify/` and `.github/skills/`
- **Script Engine:** PowerShell (`ps`)

