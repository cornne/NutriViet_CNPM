# NutriViet: Smart Personalized Nutrition & Food Allergy Warning Mobile Application

[![Course](https://img.shields.io/badge/Course-CS300%20Software%20Engineering-blue.svg)](https://www.fit.hcmus.edu.vn/)
[![Institution](https://img.shields.io/badge/Institution-VNU--HCM%20University%20of%20Science-green.svg)](https://hcmus.edu.vn/)
[![Methodology](https://img.shields.io/badge/Methodology-Scrum%20%2F%20Agile-orange.svg)]()
[![Development](https://img.shields.io/badge/Spec--Driven-GitHub%20Spec%20Kit-purple.svg)](https://github.com/github/spec-kit)

> **NutriViet** is an intelligent Android mobile application engineered to safeguard consumers with personalized food allergy hazard warnings and proactive nutrition management. By combining on-device Optical Character Recognition (OCR), Levenshtein fuzzy matching, and the FoodOn semantic ontology, NutriViet instantly translates complex packaging labels into unambiguous, color-coded safety alerts (RED dangerous / YELLOW caution / GREEN safe), while providing structured dietary logging, safe food alternative recommendations, and a verified community crowdsourcing ecosystem.

---

## 👥 Team Members & Leadership Roster

**Group:** Group 07 - NutriViet Team  
**Institution:** Faculty of Information Technology, VNU-HCM University of Science (HCMUS)

| No. | Student ID | Full Name | Project Role & Primary Responsibilities |
|:---:|:---:|:---|:---|
| 1 | **24127004** | **Ngo Tien Binh** | **Project Manager (PM) & AI Lead** / Full-Stack Engineer |
| 2 | **23127432** | **Le Tat Nam** | **Backend & System Architecture Lead** / Full-Stack Engineer |
| 3 | **24127456** | **Luong Hoang Nam** | **UI/UX & Flutter Lead** / Full-Stack Engineer |
| 4 | **24127242** | **Nguyen Hoang Phuc Thinh** | **Database & DevOps Lead** / Full-Stack Engineer |
| 5 | **24127438** | **Truong Gia Linh** | **QA & Test Automation Lead** / Full-Stack Engineer |

---

## 📅 Project Milestones & Semester Roadmap (5 Sprints)

The project is structured into **5 sequential Scrum Sprints**, each mapping to an official Project Assignment (PA) milestone:

| Sprint | Milestone | Status | Duration | Primary Focus & Deliverables |
|:---:|:---|:---:|:---:|:---|
| **Sprint 1** | **PA1-2026** | **Completed** | 25/09 – 17/10/2026 | Project Proposal, Existing App Survey (Yuko & Soosee), Team Contract, Scrum Setup |
| **Sprint 2** | **PA2-2026** | **In Progress** | 18/10 – 31/10/2026 | Vision Document, Project Plan, GitHub Spec Kit Integration, Sprint 2 Reports |
| **Sprint 3** | **PA3-2026** | *Planned* | 01/11 – 18/11/2026 | Software Architecture Document (SAD), Figma UI/UX Prototypes, Clean Architecture Setup |
| **Sprint 4** | **PA4-2026** | *Planned* | 19/11 – 05/12/2026 | Core OCR & Allergen Engine Implementation, API Contracts, Unit Testing ($\ge 80\%$ coverage) |
| **Sprint 5** | **PA5-2026** | *Planned* | 06/12 – 22/12/2026 | System Verification, Crowdsourcing Portal, Polish, Final Release APK, and Live Demo |

---

## 📂 Repository Directory Structure

```text
NutriViet/
├── .github/                           # GitHub workflows and Spec Kit AI agent skills
│   └── skills/                        # Prompts and skills for Spec-Driven Development
├── .specify/                          # GitHub Spec Kit root configuration
│   ├── memory/                        # Long-term memory governance (constitution.md)
│   ├── templates/                     # Standardized spec, plan, and task templates
│   └── scripts/                       # Automation scripts for SDD workflow
├── docs/                              # Project documentation across all milestones
│   ├── assets/                        # Diagrams, setup proofs, UI screenshots
│   │   ├── setup/                     # Tool setup & Trello board evidence
│   │   └── survey/                    # Empirical app survey screenshots
│   ├── requirements/                  # Requirements specifications
│   │   ├── README.md
│   │   └── vision.md                  # [PA2] Master Vision Document & NFRs
│   ├── management/                    # Agile Scrum management & governance
│   │   ├── README.md
│   │   ├── project-plan.md            # [PA2] 5-Sprint Project Plan & Risk Matrix
│   │   ├── team-contract.md           # [PA1] Working Agreements & Code of Conduct
│   │   └── weekly-reports.md          # [PA1-PA5] Scrum Meeting Minutes & AI Logs
│   ├── analysis-and-design/           # Architecture diagrams, C4 models, ERDs
│   └── test/                          # Test plans, test cases, and QA reports
├── src/                               # Application source code & assignment artifacts
│   ├── constitution.md                # [PA2] Ratified NutriViet Project Constitution
│   ├── speckit/                       # [PA2] Spec Kit templates & training logs
│   │   ├── README.md
│   │   └── training-log.md            # [PA2] Member training completion evidence
│   └── .gitkeep
├── proposal.md                        # [PA1] Master Project Proposal & App Survey
├── proposal.pdf                       # [PA1] Exported submission PDF
├── README.md                          # Repository overview & milestone navigator
└── .gitignore                         # Environment & build ignore patterns
```

---

## 📚 Deliverables & Documentation Index

### 🔹 Project Assignment 1 (PA1-2026) — *Completed*
* [Project Proposal (`proposal.md`)](./proposal.md): Comprehensive functional groups (FG1–FG8), system actors, AI feature proposal (Fuzzy Matching + FoodOn Ontology).
* [Existing App Survey](./proposal.md#c---existing-app-survey): Empirical analysis of Yuko and Soosee market applications.
* [Team Contract (`docs/management/team-contract.md`)](./docs/management/team-contract.md): 8 working agreements, communication policies, and peer review rules.
* [Setup Evidence](./proposal.md#e---development-environment--scrum-setup-evidence): Git repository, Trello Kanban board, and AI tooling disclosures.

### 🔹 Project Assignment 2 (PA2-2026) — *Current Sprint*
* [Vision Document (`docs/requirements/vision.md`)](./docs/requirements/vision.md):
  * Standardized **Problem Statement** & **Product Position Statement** tables.
  * Stakeholder personas, supermarket environmental constraints, and competitor quadrant chart.
  * 8 refined feature descriptions (What / Why / Who benefits) and **2 Mermaid workflow diagrams**.
  * Quantifiable, benchmarked Non-Functional Requirements (Performance, Security, Reliability).
* [Project Plan (`docs/management/project-plan.md`)](./docs/management/project-plan.md):
  * Goals, project boundaries (in-scope vs out-of-scope), and deliverables.
  * **Risk Management Matrix:** 4 categorized risks (OCR degradation, midterm crunch, scope creep, latency) + concrete mitigations.
  * **5-Sprint Scrum Schedule:** 14 detailed Sprint 2 tasks (1 doer + 1 reviewer) and upcoming sprint task roadmaps.
* [Spec Kit Initialization & Governance (`src/constitution.md`)](./src/constitution.md):
  * Ratified project constitution detailing Clean Architecture, food safety zero-ambiguity standards, and test-first policies.
  * [Spec Kit Training Completion Log (`src/speckit/training-log.md`)](./src/speckit/training-log.md): Individual learning takeaways for all 5 members.
* [Weekly Scrum & AI Usage Reports (`docs/management/weekly-reports.md`)](./docs/management/weekly-reports.md):
  * Sprint 2 Planning meeting minutes and Trello board progression screenshot.
  * Transparent AI interaction log (GitHub Spec Kit, Copilot, Gemini) with academic integrity statements.

---

## 💻 Technology Stack & Architecture

| Tier | Technologies & Frameworks | Description |
|:---|:---|:---|
| **Mobile Client** | **Flutter (Dart 3.x)** | Android native deployment (min SDK 26), Clean Architecture with BLoC state management. |
| **On-Device Vision** | **Google ML Kit Text Recognition** | Real-time camera OCR with local image contrast and adaptive threshold preprocessing. |
| **Backend Services** | **Python 3.12 / FastAPI** | High-performance asynchronous RESTful APIs, OpenAPI/Swagger contracts, containerized with Docker. |
| **AI & Knowledge** | **Levenshtein Fuzzy Matching & FoodOn** | Typo-tolerant text matching against Vietnamese dictionaries; semantic allergen ontology derivation. |
| **Data Persistence** | **PostgreSQL & SQLite/Hive** | Relational cloud storage for catalog/profiles; encrypted local SQLite for offline emergency fallback. |
| **Engineering Rigor** | **GitHub Spec Kit & GitHub Actions** | Spec-Driven Development (SDD), automated CI/CD linting, testing, and branch protection. |

---

## ⚙️ Development & Contribution Workflow

The team strictly follows Agile/Scrum and Spec-Driven Development standards:
1. **Branching Strategy:** Direct commits to `main` are restricted. All development occurs on feature branches (`feat/`, `fix/`, `docs/`) and merges require at least 1 approving peer review.
2. **Task Rule:** Every task is assigned to **1 Performer** and verified by **1 Reviewer** on Trello.
3. **Commit Discipline:** Conventional Commits standard (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`).
4. **Header Attribution:** Every documentation section includes:
   > `*Performed by: [Name] | Reviewed by: [Name] | Edited by: [Name]*`
