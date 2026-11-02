# NutriViet: Summary of Changes (PA3-2026 Submission)
**Course:** CS300 - CSC13002 - Introduction to Software Engineering  
**Project Assignment:** PA3-2026  
**Group:** Group 07 - NutriViet Team  
**Submission Date:** 02/11/2026  

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
| 3 | **Section 4.1 5-Sprint Roadmap** | *Updated* | Marked Sprint 2 (PA2) as **Completed** (18/10/2026 – 31/10/2026). Transitioned Sprint 3 (PA3: 01/11/2026 – 18/11/2026) to **Active Sprint**, detailing core objectives: Use-Case Modeling (Section C), Use-Case Specifications & UI Prototypes (Section D), Spec Kit End-to-End Implementation of 1 Functional Group (Section E), and Scrum/AI reporting (Section F). |
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

## Summary of Completed Stage 1 Deliverables
- [x] **Section A:** Revised Project Plan ([project-plan.md](docs/management/project-plan.md)) + `Changes.md`
- [x] **Section B:** Detailed Vision Document ([vision.md](docs/requirements/vision.md)) + `Changes.md`
- [x] **Section C:** Use-Case Model with Mermaid Diagrams ([use-cases.md](docs/requirements/use-cases.md))
- [x] **Section D:** Use-Case Specifications & High-Fidelity UI Prototypes ([use-cases.md](docs/requirements/use-cases.md))

