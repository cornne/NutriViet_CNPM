# NutriViet: Summary of Changes (PA3-2026 Submission)
**Course:** CS300 - CSC13002 - Introduction to Software Engineering  
**Project Assignment:** PA3-2026  
**Group:** Group 07 - NutriViet Team  
**Submission Date:** 14/11/2026  

---

## Overview
This `Changes.md` document provides a comprehensive, traceable record of all modifications, extensions, and refinements implemented in the NutriViet project artifacts for the **Project Assignment 3 (PA3-2026)** milestone compared to the previous PA2-2026 baseline. In accordance with PA3 guidelines, changes are systematically grouped by document section.

---

## Section A - Changes in Revised Project Plan (`docs/management/project-plan.md`)
*Performed by: Ngo Tien Binh | Reviewed by: Le Tat Nam | Edited by: Truong Gia Linh*

| # | Section / Component | Type of Change | Description & Academic Rationale |
|:---:|:---|:---:|:---|
| 1 | **Header & Metadata** | *Updated* | Promoted document status from PA2-2026 to **PA3-2026 (2nd Submission)**. |
| 2 | **Section 3.1 Team Structure** | *Refined* | Clarified Luong Hoang Nam's responsibilities to explicitly encompass high-fidelity interactive UI prototyping and screenshot evidence generation for PA3 Section D. |
| 3 | **Section 4.1 5-Sprint Roadmap** | *Updated* | Marked Sprint 2 (PA2) as **Completed** (18/10/2026 – 31/10/2026). Transitioned Sprint 3 (PA3: 01/11/2026 – 14/11/2026) to **Active Sprint**, detailing core objectives: Use-Case Modeling (Section C), Use-Case Specifications & UI Prototypes (Section D), Spec Kit End-to-End Implementation of 1 Functional Group (Section E), and Scrum/AI reporting (Section F). |
| 4 | **Section 4.2 Sprint 2 Archive** | *Restructured* | Formally archived the 14 completed tasks of Sprint 2 (`TASK-01` to `TASK-14`) as historical project evidence. |
| 5 | **Section 4.3 Sprint 3 Active Tasks** | *Added (Major)* | Created a granular 14-task work breakdown structure for Sprint 3 (`TASK-15` through `TASK-28`). In strict accordance with course rules, each task has **exactly 1 designated performer**, **1 designated reviewer**, start/due dates, and synchronized progress status (*In Progress* / *To Do*). Tasks directly map to PA3 grading sections A through F. |
| 6 | **Section 4.4 Later Sprints** | *Refined* | Refined planned activities for Sprint 4 (core system integration & test coverage $\ge 80\%$) and Sprint 5 (crowdsourcing, admin moderation, and live demonstration). |

---

## Section B - Changes in Detailed Vision Document (`docs/requirements/vision.md`)
*Performed by: Le Tat Nam | Reviewed by: Truong Gia Linh | Edited by: Nguyen Hoang Phuc Thinh*

| # | Section / Component | Type of Change | Description & Academic Rationale |
|:---:|:---|:---:|:---|
| 1 | **Header & References** | *Updated* | Updated document header to **PA3-2026 (2nd Submission)**. Added formal academic references to **WCAG 2.1 Guidelines** for accessibility standards. |
| 2 | **Section 3.3 User Environment** | *Expanded (Major)* | Substantially expanded the user environment specification into 4 exhaustive dimensions: <br/>1. *Physical Retail Environments:* Illumination variations (150 to 600 lux), cellophane/tin packaging reflections, packaging curvature, and one-handed mobile ergonomic constraints in grocery store aisles.<br/>2. *Mobile Hardware Diversity:* Android fragmentation (API 26 to 35), camera sensor specs (8MP fixed-focus to 50MP OIS), and RAM capacities (2GB entry-level to 12GB flagship).<br/>3. *Network Infrastructure:* Supermarket basement connectivity drops (cellular packet loss down to 0 kbps) and the necessity of autonomous local offline fallback.<br/>4. *Administrative Desktop Environment:* Desktop browser requirements (Chrome 120+, Firefox, Safari, Edge on 1080p+ viewports). |
| 3 | **Section 3.5 Alternatives & Competition** | *Expanded (Major)* | Formulated a comprehensive **8-dimension comparative evaluation matrix** benchmarking NutriViet against 4 primary alternatives: Yuko App (EU), Soosee App (NL), Open Food Facts, and MyFitnessPal. Added MyFitnessPal to the positioning chart to evaluate general dietary tracking apps. |
| 4 | **Section 5.1 Feature Descriptions** | *Refined (Major)* | Decomposed each of the 8 Functional Groups (FG1 through FG8) into concrete sub-capabilities with explicit 1:1 traceability tags mapping directly to Use Cases `UC01` through `UC18` in Section C & D. |
| 5 | **Section 6 Non-Functional Requirements** | *Refined & Added* | Appended formal **Verification Methods** (automated benchmarks, packet inspection, Locust stress test, Firebase Test Lab) to all existing performance, scalability, security, platform, and reliability requirements to ensure testability. |
| 6 | **Section 6.6 Usability & Accessibility** | *Added (New)* | Added `NFR-USAB-01` mandating WCAG 2.1 AA dual-coding for the tri-tier safety alerts: every color indicator (RED/YELLOW/GREEN) must be paired with distinct geometric glyphs (`[!X]`, `[!?]`, `[OK]`) and enforce a minimum 4.5:1 contrast ratio to protect color-blind consumers. |

---

## Section C - Changes in Use-Case Model (`docs/requirements/use-cases.md`)
*Performed by: Luong Hoang Nam | Reviewed by: Ngo Tien Binh | Edited by: Le Tat Nam*

| # | Section / Component | Type of Change | Description & Academic Rationale |
|:---:|:---|:---:|:---|
| 1 | **System-Level Mermaid Diagram** | *Added (New)* | Created a comprehensive system-level Use-Case diagram visualizing all 18 use cases across FG1–FG8 mapped to primary actors (Consumer, System Administrator specializing User) and secondary technical actors (Google ML Kit, FoodOn Semantic Ontology Engine). |
| 2 | **Subsystem Mermaid Diagrams & Relationship Analysis** | *Added (New)* | Constructed 4 detailed subsystem diagrams and relationship analysis table illustrating `<<include>>`, `<<extend>>` (with explicit conditions), and generalization (actor & use case variants) across core functional workflows. |
| 3 | **Use Case Categorization Table** | *Added (New)* | Mapped all 18 use cases directly to Functional Groups FG1 through FG8 with formal IDs (`UC01` to `UC18`). |

---

## Section D - Changes in Use-Case Specifications & Prototypes (`docs/requirements/use-cases.md`)
*Performed by: Truong Gia Linh & Nguyen Hoang Phuc Thinh | Reviewed by: Luong Hoang Nam*

| # | Section / Component | Type of Change | Description & Academic Rationale |
|:---:|:---|:---:|:---|
| 1 | **18 Detailed Use-Case Specs** | *Added (Major)* | Formulated formal use-case specifications for all 18 use cases featuring Preconditions, Basic Flow, Alternative Flows (covering exception states, bad camera focus, network failure), and Postconditions. |
| 2 | **High-Fidelity UI Prototypes** | *Added (Major)* | Engineered and embedded **17 high-resolution prototype screens** (`assets/prototypes/`) illustrating consumer interfaces, hazard alert dual-coding, scanning viewfinders, diary logging, crowdsource photo upload, and admin moderation. |

---

## Section E - Spec Kit Full-Stack Implementation (`specs/` & `src/`)
*Performed by: Le Tat Nam, Luong Hoang Nam, Ngo Tien Binh | Reviewed by: Truong Gia Linh*

| # | Section / Component | Type of Change | Description & Academic Rationale |
|:---:|:---|:---:|:---|
| 1 | **Spec Kit Lifecycle Artifacts** | *Added (Major)* | Authored complete Spec-Driven Development cycle in `specs/001-authentication/` and `specs/002-allergy-profile/`: `spec.md`, `plan.md`, `data-model.md`, `openapi.json`, `tasks.md`, `research.md`, and `requirements.md` (22/22 gates passed). |
| 2 | **Backend Microservice** | *Added (Major)* | Built production Python WSGI microservice (`wsgi_app.py`) deployed live on PythonAnywhere (`ngobinh2006.pythonanywhere.com`) with PBKDF2 HMAC-SHA256 crypto, password change, body physical metrics (BMI/TDEE), and SQLite relational persistence. |
| 3 | **Mobile Client Application** | *Added (Major)* | Developed responsive Flutter mobile application (`src/mobile/`) with zero-prefill login, email activation gate, dedicated password change screen, BMI/TDEE physical metrics, modern 5-tab taskbar with glowing center QUÉT button, and crowdsourced product photo upload. |
| 4 | **Video Demonstration** | *Added (Major)* | Recorded and published full-stack video demonstration on [YouTube](https://www.youtube.com/watch?v=-LUs4PHV20Q) accompanied by structured bilingual narration script (`video-demo-script.md`). |

---

## Section F - Changes in Weekly Scrum & AI Logs (`docs/management/weekly-reports.md`)
*Performed by: Truong Gia Linh | Reviewed by: Ngo Tien Binh*

| # | Section / Component | Type of Change | Description & Academic Rationale |
|:---:|:---|:---:|:---|
| 1 | **Scrum Meeting Minutes** | *Added (New)* | Documented 4 sprint ceremonies across Sprint 3 (01/11 – 14/11/2026): Sprint 3 Planning (02/11), Mid-Sprint Standup (08/11), Mid-Sprint Progress & Spec Kit Checkpoint (12/11), and Sprint Review & Retrospective (14/11). |
| 2 | **Trello Progress Tracking** | *Updated* | Embedded 3 sequential Trello board progression checkpoints across Sprint 3: Mid-sprint (08/11: 3 Done, 6 In Progress, 5 To Do - Figure 1.1), Spec Kit Checkpoint (12/11: 9 Done, 5 In Progress, 0 To Do - Figure 1.2), and Final Sprint Delivery (14/11: 14/14 Done (100%), 0 In Progress, 0 To Do - Figure 1.3) verifying rigorous 1:1 member task assignments and 100% completion. |
| 3 | **Generative AI Disclosures** | *Added (New)* | Articulated formal human intellectual ownership boundaries (>85% human engineering: 100% student-designed Use Cases, UML diagrams, prototypes, and architecture). Documented granular AI log demonstrating strictly auxiliary use (grammar proofreading, Mermaid syntax error troubleshooting) with an Academic Integrity Declaration. |

---

## Summary of Completed Stage 1 & Stage 2 Deliverables
- [x] **Section A:** Revised Project Plan ([project-plan.md](docs/management/project-plan.md)) + `Changes.md`
- [x] **Section B:** Detailed Vision Document ([vision.md](docs/requirements/vision.md)) + `Changes.md`
- [x] **Section C:** Use-Case Model with Mermaid Diagrams ([use-cases.md](docs/requirements/use-cases.md))
- [x] **Section D:** Use-Case Specifications & High-Fidelity UI Prototypes ([use-cases.md](docs/requirements/use-cases.md))
- [x] **Section E:** Full-Stack Implementation using Spec Kit - FG1 Authentication & FG2 Profile ([specs/](specs/))
- [x] **Section F:** Weekly Scrum Reports & Generative AI Tool Disclosures ([weekly-reports.md](docs/management/weekly-reports.md))

