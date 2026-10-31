# NutriViet: Weekly Scrum & AI Usage Reports (Sprint 2)
**Agile Meeting Minutes, Trello Tracking & Generative AI Disclosure**  
**Course:** CS300 - CSC13002 - Introduction to Software Engineering  
**Project Assignment:** PA2-2026 (Part D Deliverable)  
**Group:** Group 07 - NutriViet Team  
**Sprint 2 Cadence:** 18/10/2026 – 31/10/2026  

---

## 1. Weekly Scrum Meeting Minutes
*Performed by: Truong Gia Linh | Reviewed by: Ngo Tien Binh | Edited by: Le Tat Nam*

### =========== 18/10, Sprint 2 ===========

**Team members present:**
- Ngo Tien Binh
- Le Tat Nam
- Luong Hoang Nam
- Nguyen Hoang Phuc Thinh
- Truong Gia Linh

**Team members absent:**
- None

---

### Status reports:

#### Ngo Tien Binh (PM & AI Lead)
* **Completed tasks:**
  - Reviewed PA2 requirements and decomposed assignment scope into 14 distinct sprint tasks.
  - Initialized team Trello Kanban board with Scrum columns: *In Progress*, *To Do*, and *Done*.
* **To-do Tasks:**
  - Task TASK-01: Set up GitHub Spec Kit repository scaffolding (`specify init`), configure `.specify/`, and author `constitution.md`.
  - Task TASK-07: Draft Project Plan goals, boundaries, scope, and deliverables (`project-plan.md`).
  - Task TASK-09: Define the 5-Sprint schedule and 4-tier software build plan.
  - Task TASK-13: Consolidate AI usage disclosures for Sprint 2.
* **Issues/Obstacles:**
  - Need to ensure Spec Kit installation works cleanly on Windows PowerShell environments without path permission issues.

#### Le Tat Nam (Backend & Architecture Lead)
* **Completed tasks:**
  - Analyzed PA1 feedback and reviewed required Vision Document positioning table structures.
* **To-do Tasks:**
  - Task TASK-03: Draft Problem Statement and Product Position Statement tables for `vision.md` (Section 2).
  - Task TASK-08: Author the Project Plan risk management section with 4 categorized risks and concrete mitigation plans.
  - Cross-review TASK-06 (Quantifiable NFRs) and TASK-11 (FoodOn schema design).
* **Issues/Obstacles:**
  - Need to strictly adhere to the exact required table formats (`the problem of / affects / ...` and `For / Who / ...`).

#### Luong Hoang Nam (UI/UX & Flutter Lead)
* **Completed tasks:**
  - Outlined Flutter Android project structure and reviewed Google ML Kit Flutter integration docs.
* **To-do Tasks:**
  - Task TASK-05: Write detailed 3–5 sentence explanatory paragraphs for FG1–FG8 and construct 2 Mermaid workflow diagrams in `vision.md`.
  - Task TASK-10: Conduct technical spike testing Google ML Kit camera text recognition on physical food packages.
* **Issues/Obstacles:**
  - Need physical packaging samples with curved and glossy surfaces to test optical character recognition boundaries.

#### Nguyen Hoang Phuc Thinh (Database & Git Lead)
* **Completed tasks:**
  - Verified Git repository synchronization and clean `main` branch state.
* **To-do Tasks:**
  - Task TASK-06: Formulate quantifiable, measurable Non-Functional Requirements in `vision.md`.
  - Task TASK-11: Investigate FoodOn OWL ontology graph structures and draft preliminary PostgreSQL schemas.
  - Task TASK-14: Manage Trello evidence captures, Git log exports, and final `PA2-Group07.zip` packaging.
* **Issues/Obstacles:**
  - Avoiding subjective NFR metrics (e.g., "fast") by ensuring all performance and scalability items are numeric.

#### Truong Gia Linh (QA & Documentation Lead)
* **Completed tasks:**
  - Established document templates for `vision.md` and `project-plan.md` in `/docs`.
* **To-do Tasks:**
  - Task TASK-04: Author stakeholder personas, supermarket environmental constraints, and competitor quadrant chart in `vision.md`.
  - Task TASK-12: Document meeting minutes and maintain Scrum records.
  - Coordinate the Spec Kit training completion log (`training-log.md`) across all 5 members.
* **Issues/Obstacles:**
  - Verifying that all section headers include the mandatory Author/Reviewer/Editor metadata.

---

### Actions (if any)
1. Ngo Tien Binh to execute `specify init` and commit the ratified `constitution.md` to GitHub.
2. All members to watch the official Spec Kit YouTube tutorials and submit 3–4 sentence takeaways for `training-log.md`.
3. Le Tat Nam and Luong Hoang Nam to begin initial drafting of `vision.md` sections.
4. Next sync: Mid-Sprint Progress Check (Weekly Scrum 1) on Wednesday, 21/10/2026.

### Summary of the meeting
The team held the Sprint 2 Planning meeting on Google Meet from 20:00 to 21:00 on Sunday, 18/10/2026. All 5 members attended. The group reviewed the PA2 assignment guidelines, enforced the mandatory **1 Doer + 1 Reviewer** rule, and populated 14 task cards on Trello (`TASK-01` to `TASK-14`). An internal milestone of Friday, 30/10/2026 was established to guarantee a 24-hour buffer before the official 31/10/2026 deadline.

---

### Trello Board Progress Evidence (Sprint 2)
![NutriViet Sprint 2 Trello Kanban Board](../assets/setup/trello-board.png)

*Figure 1.1: NutriViet Sprint 2 Scrum Board on Trello showing active task assignments and workflow progression across In Progress, To Do, and Done columns.*

---

### =========== 26/10, Sprint 2 ===========

**Team members present:**
- Ngo Tien Binh
- Le Tat Nam
- Luong Hoang Nam
- Nguyen Hoang Phuc Thinh
- Truong Gia Linh

**Team members absent:**
- None

---

### Status reports:

#### Ngo Tien Binh (PM & AI Lead)
* **Completed tasks:**
  - Task TASK-01: Completed GitHub Spec Kit setup, initialized `.specify/` infrastructure, and ratified `constitution.md`.
  - Task TASK-02: Completed Spec Kit YouTube training tutorial and authored personal learning log.
  - Reviewed and approved TASK-03 (Vision Doc Positioning) and TASK-05 (Vision Doc Features & Mermaid).
* **To-do Tasks:**
  - Task TASK-07: Finalize Project Plan goals, boundaries, scope, and deliverables (currently In Progress).
  - Task TASK-09: Draft 5-Sprint Scrum schedule and 4-tier software build plan.
  - Review TASK-10 (Flutter Camera OCR spike).
* **Issues/Obstacles:**
  - Balancing mid-sprint documentation review with Project Plan drafting; on track to meet internal deadline on 30/10.

#### Le Tat Nam (Backend & Architecture Lead)
* **Completed tasks:**
  - Task TASK-02: Completed Spec Kit self-training module on `/speckit-plan`.
  - Task TASK-03: Completed Section 2 of Vision Document (Problem Statement & Product Position Statement tables).
  - Reviewed TASK-06 (Quantifiable NFRs) authored by Thinh.
* **To-do Tasks:**
  - Task TASK-08: Author Project Plan Risk Management section with 4 categorized risks and concrete mitigation strategies.
  - Review TASK-09 (5-Sprint schedule) and TASK-11 (FoodOn schema design).
* **Issues/Obstacles:**
  - Ensuring ontology lookup query latency risk is properly quantified and paired with indexed relational caching.

#### Luong Hoang Nam (UI/UX & Flutter Lead)
* **Completed tasks:**
  - Task TASK-02: Completed Spec Kit training on `/speckit-specify` and acceptance criteria.
  - Task TASK-05: Completed Section 5 of Vision Document (8 refined feature descriptions with 3–5 sentence paragraphs and 2 Mermaid workflow diagrams).
  - Reviewed TASK-04 (Stakeholders & Survey) authored by Linh.
* **To-do Tasks:**
  - Task TASK-10: Continue Flutter ML Kit camera OCR text recognition spike (currently In Progress).
  - Measure extraction latency on physical packaging under varying lighting conditions.
* **Issues/Obstacles:**
  - High-reflection cellophane packaging occasionally causes character drops; tuning contrast preprocessing parameters in ML Kit sandbox.

#### Nguyen Hoang Phuc Thinh (Database & Git Lead)
* **Completed tasks:**
  - Task TASK-02: Completed Spec Kit training on `/speckit-tasks` decomposition.
  - Task TASK-06: Completed Section 6 of Vision Document (Quantifiable Non-Functional Requirements covering latency, security, and scalability).
  - Reviewed TASK-01 (Spec Kit setup and Git sync) by Binh.
* **To-do Tasks:**
  - Task TASK-11: Draft preliminary PostgreSQL relational schema for FoodOn allergen lineages and ingredient lexicons.
  - Task TASK-13: Compile Sprint 2 AI usage disclosure logs.
  - Task TASK-14: Prepare PDF conversion scripts and packaging checklist.
* **Issues/Obstacles:**
  - None; Git repository is clean and synchronized.

#### Truong Gia Linh (QA & Documentation Lead)
* **Completed tasks:**
  - Task TASK-02: Completed Spec Kit training on `/speckit-clarify` and QA checklist quality gates.
  - Task TASK-04: Completed Section 3 of Vision Document (Stakeholder personas, supermarket constraints, and competitor quadrant chart).
  - Consolidated member training summaries into `src/speckit/training-log.md`.
* **To-do Tasks:**
  - Task TASK-12: Document meeting minutes for Meeting 2 (26/10) and prepare final sprint review templates.
  - Review TASK-07 (Project Plan Scope) authored by Binh.
* **Issues/Obstacles:**
  - Need to ensure all Markdown tables and Mermaid diagrams render without overflow in PDF export.

---

### Actions (if any)
1. Ngo Tien Binh to finalize TASK-07 (Project Plan Scope) and advance to TASK-09 (5-Sprint Schedule).
2. Le Tat Nam to begin TASK-08 (Risk Management) and Nguyen Hoang Phuc Thinh to begin TASK-11 (FoodOn Schema Design).
3. Luong Hoang Nam to complete ML Kit benchmark measurements for TASK-10.
4. Next sync: Pre-submission Integration Check on Friday, 30/10/2026.

### Summary of the meeting
The team held Weekly Scrum Meeting 2 via Google Meet on Monday, 26/10/2026 from 20:00 to 20:35 with all 5 members present. The team reviewed mid-sprint progress: 6 out of 14 tasks are fully completed (all Vision Document and Spec Kit setup tasks), 2 tasks are actively In Progress (Project Plan Scope and Flutter OCR Spike), and the remaining 6 tasks are queued in To Do. The project is well ahead of schedule and fully on track to achieve the internal freeze milestone on 30/10/2026.

---

### Trello Board Progress Evidence (Mid-Sprint - 26/10)
![NutriViet Sprint 2 Trello Board (26/10)](../assets/setup/trello-meeting2.png)

*Figure 1.2: NutriViet Sprint 2 Scrum Board on Trello as of 26/10/2026 showing 6 completed tasks in Done, 2 tasks In Progress, and 6 remaining tasks in To Do.*

---

### =========== 30/10, Sprint 2 ===========

**Team members present:**
- Ngo Tien Binh
- Le Tat Nam
- Luong Hoang Nam
- Nguyen Hoang Phuc Thinh
- Truong Gia Linh

**Team members absent:**
- None

---

### Status reports:

#### Ngo Tien Binh (PM & AI Lead)
* **Completed tasks:**
  - Task TASK-07: Completed Section 1, 2, and 3 of Project Plan (`project-plan.md`) covering Project Goals, Boundaries, In-scope/Out-of-scope capabilities, Course Deliverables, Assumptions, and Team Organization Matrix.
  - Task TASK-09: Completed Section 4 and 5 of Project Plan (`project-plan.md`) formalizing the 5-Sprint high-level roadmap, Mermaid Gantt timeline, 14 Sprint 2 tasks, later sprint tasks, and 4-tier Software Build Plan (Build 0.1 to Build 1.0 Demo).
  - Task TASK-13: Compiled Sprint 2 Generative AI tool disclosures and prompt logs in compliance with course academic integrity guidelines.
  - Reviewed and approved TASK-10 (Flutter Camera OCR spike), TASK-12 (Scrum documentation), and TASK-14 (packaging and Git audit).
* **To-do Tasks (Sprint 3 / PA3 Preparation):**
  - Task: Decompose PA3 requirements into backlog user stories and tasks for Software Architecture Document (SAD), Figma UI prototyping, and Flutter Clean Architecture scaffolding.
  - Schedule Sprint 3 Planning meeting for Sunday, 01/11/2026.
* **Issues/Obstacles:**
  - None; all 14 sprint tasks are 100% completed, peer-reviewed, and merged into `main` 24 hours ahead of the official deadline.

#### Le Tat Nam (Backend & Architecture Lead)
* **Completed tasks:**
  - Task TASK-08: Authored Risk Management section in `project-plan.md` (Section 3.2), analyzing 4 critical risks (OCR accuracy on glossy packaging, midterm absences, scope creep, FoodOn ontology query latency) with concrete mitigation plans and Mermaid quadrant chart.
  - Reviewed and approved TASK-09 (5-Sprint Schedule & Build Plan) and TASK-11 (FoodOn Schema Design).
* **To-do Tasks (Sprint 3 / PA3 Preparation):**
  - Draft backend system architecture specifications for the SAD (FastAPI microservices, C4 container diagram, RESTful API endpoints).
  - Set up FastAPI project repository boilerplate with Docker Compose and health check endpoints.
* **Issues/Obstacles:**
  - None; FoodOn schema and indexing strategy confirmed with Thinh to keep query response latency under 200ms.

#### Luong Hoang Nam (UI/UX & Flutter Lead)
* **Completed tasks:**
  - Task TASK-10: Completed Flutter camera OCR technical spike (`Build 0.1`). Benchmarked Google ML Kit Text Recognition on 15 real-world Vietnamese packaged food items under varying retail lighting conditions; validated image contrast preprocessing and achieved average recognition latency of ~780ms.
  - Documented spike findings and recommendations for hyphenated word reconstruction in `vision.md` and `project-plan.md`.
  - Reviewed and approved TASK-07 (Project Plan Scope).
* **To-do Tasks (Sprint 3 / PA3 Preparation):**
  - Draft high-fidelity Figma interactive wireframes covering all 8 Functional Groups (FG1–FG8).
  - Scaffold Flutter Clean Architecture folder structure (`core/`, `features/scanner/`, `features/profile/`, `features/history/`).
* **Issues/Obstacles:**
  - None; spike confirmed ML Kit on-device model fulfills the sub-2.0s latency requirement without requiring cloud OCR overhead.

#### Nguyen Hoang Phuc Thinh (Database & Git Lead)
* **Completed tasks:**
  - Task TASK-11: Completed FoodOn ontology schema design spike. Formulated normalized relational PostgreSQL schema mapping FoodOn OWL classes (allergens, food derivatives, scientific terms) to indexed lookup tables.
  - Task TASK-14: Managed sprint packaging, Jira/Trello evidence captures, Git commit tree audit, document PDF conversions, and compiled the `PA2-Group07.zip` archive checklist.
  - Reviewed and approved TASK-08 (Risk Management).
* **To-do Tasks (Sprint 3 / PA3 Preparation):**
  - Set up PostgreSQL and Redis database containers in Docker Compose.
  - Configure automated GitHub Actions CI workflow for Flutter and Python linting and testing.
* **Issues/Obstacles:**
  - None; all Git commits adhere to Conventional Commits and the repository working tree is clean.

#### Truong Gia Linh (QA & Documentation Lead)
* **Completed tasks:**
  - Task TASK-12: Documented weekly Scrum meeting minutes across all sprint ceremonies (Sprint Planning 18/10, Standup 26/10, Sprint Review & Retrospective 30/10) in `weekly-reports.md`.
  - Verified that all Markdown documentation sections strictly adhere to academic author/reviewer attribution rules (`Performed by / Reviewed by / Edited by`).
  - Verified cross-links and formatting across `vision.md`, `project-plan.md`, `training-log.md`, and `README.md`.
  - Reviewed and approved TASK-13 (AI Usage Disclosure).
* **To-do Tasks (Sprint 3 / PA3 Preparation):**
  - Formulate test plan templates for Sprint 3 (SAD architectural verification, heuristic evaluation of Figma wireframes).
  - Maintain audit logs and weekly Scrum templates for Sprint 3.
* **Issues/Obstacles:**
  - None; all tables and diagrams render cleanly in Markdown and PDF export.

---

### Actions (if any)
1. Nguyen Hoang Phuc Thinh to finalize and archive `PA2-Group07.zip` deliverable package containing all documentation, Spec Kit setup, and Git history.
2. Ngo Tien Binh to perform final sanity verification and submit the PA2 package to the course submission portal prior to the 31/10/2026 deadline.
3. Luong Hoang Nam and Le Tat Nam to prepare design briefs and backend boilerplate for Sprint 3 kickoff.
4. Next sync: Sprint 3 Planning Meeting on Sunday, 01/11/2026 at 20:00 via Google Meet.

### Summary of the meeting
The team held the Sprint 2 Review & Retrospective meeting via Google Meet on Friday, 30/10/2026 from 20:00 to 21:00 with all 5 members present. The team evaluated final sprint deliverables against the initial sprint backlog: all 14 out of 14 tasks are fully completed in the Done column (0 In Progress, 0 To Do), fulfilling the 100% completion target ahead of the course deadline. The team reviewed the working artifacts (Vision Document, Project Plan, Spec Kit training log, and technical spikes) and held a Sprint Retrospective:
- **What went well:** Strict enforcement of the "1 Doer + 1 Reviewer" rule ensured high quality and caught documentation discrepancies early; Spec Kit adoption provided a standardized constitution and clear task breakdowns; early technical spikes (ML Kit OCR and FoodOn schema) successfully validated technical feasibility for Sprint 3 and Sprint 4.
- **What could be improved:** Markdown-to-PDF formatting adjustments should be scheduled earlier in the sprint to avoid dense end-of-sprint rendering checks.
- **Action for next sprint:** Maintain daily Git commits and initiate Figma prototyping and Flutter Clean Architecture scaffolding immediately at the start of Sprint 3.

---

### Trello Board Progress Evidence (Sprint 2 Final - 30/10)
![NutriViet Sprint 2 Trello Board Final (30/10)](../assets/setup/trello-meeting3.png)

*Figure 1.3: NutriViet Sprint 2 Scrum Board on Trello as of 30/10/2026 showing 100% sprint completion with all 14 tasks in the Done column (0 To Do, 0 In Progress).*

---

## 2. Generative AI Usage & Tool Disclosures
*Performed by: Ngo Tien Binh | Reviewed by: Truong Gia Linh | Edited by: Le Tat Nam*

In accordance with course academic integrity guidelines, the team declares the assistive developer tooling utilized during Sprint 2:

* **GitHub Spec Kit (`specify-cli`):** Utilized for Spec-Driven Development (SDD) self-training and workspace initialization in direct compliance with Part C assignment specifications.
* **GitHub Copilot / IDE Extensions:** Utilized strictly as editor-level productivity aids for syntax auto-completion, Markdown table formatting, and code linting within VS Code.

> **Academic Integrity Statement:** All functional requirements, architectural designs, data schemas, risk evaluations, and technical spike findings in this submission are 100% original work authored, reviewed, and finalized by the team members. Generative AI tools were not used to synthesize domain decisions or replace human engineering analysis.
