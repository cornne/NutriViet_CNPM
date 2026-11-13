# NutriViet: Weekly Scrum & AI Usage Reports (Sprint 3)
**Agile Meeting Minutes, Trello Tracking & Generative AI Disclosure**  
**Course:** CS300 - CSC13002 - Introduction to Software Engineering  
**Project Assignment:** PA3-2026 (Section F Deliverable)  
**Group:** Group 07 - NutriViet Team  
**Sprint 3 Cadence:** 01/11/2026 – 14/11/2026  

---

## 1. Weekly Scrum Meeting Minutes
*Performed by: Truong Gia Linh | Reviewed by: Ngo Tien Binh | Edited by: Le Tat Nam*

---

### =========== Meeting 1: Sprint 3 Planning (02/11/2026) ===========

**Date & Time:** Monday, 02/11/2026 | 20:00 – 21:15  
**Location:** Google Meet (Online)  
**Team members present:**
- Ngo Tien Binh (PM & AI Lead)
- Le Tat Nam (Backend & Architecture Lead)
- Luong Hoang Nam (UI/UX & Flutter Lead)
- Nguyen Hoang Phuc Thinh (Database & DevOps Lead)
- Truong Gia Linh (QA & Documentation Lead)

**Team members absent:** None (100% Attendance)

---

#### Status Reports & Sprint Kickoff:

#### Ngo Tien Binh (PM & AI Lead)
* **Completed tasks:**
  - Synthesized teaching assistant (TA) feedback on the PA2 submission.
  - Decomposed PA3 requirements into 14 concrete sprint tasks (`TASK-15` through `TASK-28`).
  - Configured team Trello Kanban board with strict **1 Performer (Assignee) + 1 Reviewer** mapping per task.
* **To-do Tasks:**
  - Task `TASK-15`: Update Project Plan with Sprint 3 milestones and author Section A of `Changes.md`.
  - Task `TASK-22`: Initialize Spec Kit workflow for the target functional group (**FG1: Authentication & Authorization** and **FG2: Personal Allergy Profile Management**).
* **Issues/Obstacles:**
  - Need to ensure all 5 members strictly record Git commits with standardized conventional commit prefixes (`docs:`, `feat:`, `chore:`).

#### Le Tat Nam (Backend & Architecture Lead)
* **Completed tasks:**
  - Analyzed TA remarks regarding Vision Document NFR testability and competitive positioning.
* **To-do Tasks:**
  - Task `TASK-16`: Refine `vision.md` with 4-dimensional user environment specifications, 8-criteria competitor benchmark, and quantifiable NFR verification methods.
  - Task `TASK-23`: Formulate technical plan (`plans/`) and data contract schemas for FG1 & FG2.
  - Cross-review `TASK-15` (Project Plan & `Changes.md`).
* **Issues/Obstacles:**
  - Ensuring cryptographic password salting and SQLite persistence latency remain well below the 300ms threshold.

#### Luong Hoang Nam (UI/UX & Flutter Lead)
* **Completed tasks:**
  - Outlined UI wireframe requirements covering all 18 system use cases (UC01–UC18).
* **To-do Tasks:**
  - Task `TASK-17`: Model system use cases using Mermaid syntax (global diagram and module-level sub-diagrams).
  - Task `TASK-20`: Develop high-fidelity interactive UI prototype demonstrating both basic flows and alternative flows.
* **Issues/Obstacles:**
  - Dual-coding alert designs (combining distinct geometric glyphs with colors) must strictly adhere to WCAG 2.1 AA accessibility guidelines.

#### Nguyen Hoang Phuc Thinh (Database & DevOps Lead)
* **Completed tasks:**
  - Verified repository health, tagged `PA2-v1.0` release tag, and set up feature branch protection.
* **To-do Tasks:**
  - Task `TASK-19`: Author Use-Case Specifications for extended scenarios (UC11–UC18: Diary, Shopping, Crowdsource, Admin).
  - Task `TASK-28`: Oversee sprint packaging, Git tree audit, and PDF exports.
* **Issues/Obstacles:**
  - Coordinating database schema design for user credentials and allergen flags with backend API endpoints.

#### Truong Gia Linh (QA & Documentation Lead)
* **Completed tasks:**
  - Set up Sprint 3 Scrum tracking log templates and document review checklist in `/docs/management`.
* **To-do Tasks:**
  - Task `TASK-18`: Author Use-Case Specifications for core scenarios (UC01–UC10: Auth, Profiles, Scanner, Hazard Alerts).
  - Task `TASK-21`: Capture high-resolution prototype screenshots and embed them into `use-cases.md`.
  - Task `TASK-27`: Maintain meeting minutes and Trello progress tracking logs.
* **Issues/Obstacles:**
  - Checking that all 18 use cases exhaustively cover alternative/exception flows (network failure, unreadable packaging, blurred camera frames).

---

#### Actions & Decisions:
1. Formalized **FG1 (Authentication & Authorization)** and **FG2 (Personal Allergy Profile Management)** as the target functional groups for the full-stack Spec Kit implementation (Section E).
2. Established an internal documentation milestone for **Sunday, 08/11/2026** to freeze use-case specifications and prototypes before heavy full-stack coding begins.
3. Next ceremony: Mid-Sprint Standup on Sunday, 08/11/2026.

#### Summary of Meeting 1:
The Sprint 3 Planning meeting ran smoothly on Google Meet. The team ratified the Sprint 3 backlog, confirmed the 14-task division on Trello, and aligned on the priority of completing the Use-Case Model (Section C) and Use-Case Specifications (Section D) early in the sprint to guide the Spec Kit implementation (Section E).

---

### =========== Meeting 2: Mid-Sprint Standup & Progress Review (08/11/2026) ===========

**Date & Time:** Sunday, 08/11/2026 | 20:30 – 21:40  
**Location:** Google Meet (Online)  
**Team members present:**
- Ngo Tien Binh (PM & AI Lead)
- Le Tat Nam (Backend & Architecture Lead)
- Luong Hoang Nam (UI/UX & Flutter Lead)
- Nguyen Hoang Phuc Thinh (Database & DevOps Lead)
- Truong Gia Linh (QA & Documentation Lead)

**Team members absent:** None (100% Attendance)

---

#### Status Reports:

#### Ngo Tien Binh (PM & AI Lead)
* **Completed tasks:**
  - Task `TASK-15`: **DONE.** Updated `project-plan.md` to PA3-2026 2nd submission status; updated 5-sprint roadmap; authored Section A in `Changes.md` with complete rationale.
  - Initiated Task `TASK-22`: Initialized Spec Kit feature specifications for FG1 & FG2 (`specs/` directory).
* **To-do Tasks:**
  - Finalize `TASK-22` specifications by 09/11/2026.
  - Review `TASK-17` (Mermaid Diagrams) and `TASK-20` (UI Prototype).
  - Prepare video demonstration narration script for `TASK-26`.
* **Issues/Obstacles:**
  - Resolving Spec Kit CLI schema validation warnings during specification compilation.

#### Le Tat Nam (Backend & Architecture Lead)
* **Completed tasks:**
  - Task `TASK-16`: **DONE.** Expanded `vision.md` with 4-dimensional user environments (retail lighting, camera hardware, supermarket basement network drops, desktop admin portal), 8-dimension competitor matrix, and quantitative NFR verification methods. Documented in Section B of `Changes.md`.
  - Reviewed `TASK-15` (`project-plan.md` and `Changes.md`).
* **To-do Tasks:**
  - Task `TASK-23`: Formulate technical plan (`plans/`) and task breakdown (`tasks/`) for FG1 & FG2.
  - Task `TASK-25`: Implement backend RESTful API endpoints and database schema.
* **Issues/Obstacles:**
  - Ensuring cryptographic password salting and SQLite persistence latency remain well below 300ms.

#### Luong Hoang Nam (UI/UX & Flutter Lead)
* **Completed tasks:**
  - Task `TASK-17`: **DONE.** Constructed system-level and sub-module use-case diagrams in Mermaid syntax covering all 8 Functional Groups with actors, `<<include>>`, `<<extend>>`, and generalization hierarchies.
  - Advanced Task `TASK-20`: Built interactive UI prototype covering all 18 use cases in HTML5/CSS3/JavaScript (`prototype/index.html`).
* **To-do Tasks:**
  - Complete `TASK-20` and hand over prototype screens to Linh for embedding into specifications.
  - Task `TASK-24`: Implement frontend UI & client-side state management for FG1 & FG2.
* **Issues/Obstacles:**
  - None; prototype renders cleanly on both mobile viewport and desktop browsers.

#### Nguyen Hoang Phuc Thinh (Database & DevOps Lead)
* **Completed tasks:**
  - Advanced Task `TASK-19`: Completed draft specifications for extended use cases (UC11–UC18: Dietary Log, Reaction Incidents, Shopping Lists, Community Submissions, and Admin Moderation).
* **To-do Tasks:**
  - Finalize `TASK-19` specifications with exhaustive alternative flows by 09/11/2026.
  - Assist Le Tat Nam with database schema migrations for FG1 & FG2 (`TASK-25`).
* **Issues/Obstacles:**
  - Coordinating database schema design for user credentials and allergen flags with backend API endpoints.

#### Truong Gia Linh (QA & Documentation Lead)
* **Completed tasks:**
  - Advanced Task `TASK-18`: Completed draft specifications for core use cases (UC01–UC10: Auth, Profiles, Camera Scanner, Hazard Alerts, Safe Alternatives).
  - Initiated Task `TASK-21`: Exported 17 high-resolution prototype screenshots into `docs/requirements/assets/prototypes/`.
  - Maintained Task `TASK-27`: Documented Scrum meeting minutes and updated Trello Board progress.
* **To-do Tasks:**
  - Finalize `TASK-18` and complete screenshot embedding for `TASK-21` into `use-cases.md`.
  - Review `TASK-16` (Vision Document) and `TASK-24` (Frontend UI implementation).
* **Issues/Obstacles:**
  - Verifying relative image paths so that figures render seamlessly in both Markdown and converted PDF exports.

---

#### Actions & Decisions:
1. Mid-Sprint checkpoint confirmed: **3 tasks completed in Done** (`TASK-15`, `TASK-16`, `TASK-17`), **6 tasks actively In Progress** (`TASK-18`, `TASK-19`, `TASK-20`, `TASK-21`, `TASK-22`, `TASK-27`), and **5 tasks queued in To Do** (`TASK-23`, `TASK-24`, `TASK-25`, `TASK-26`, `TASK-28`).
2. Confirmed that Section A, B, C, and D documentation is on track to freeze by Monday, 09/11/2026.
3. Full-stack development team (Nam, Nam, Thinh, Binh) to begin coding FG1 & FG2 (Section E) following the Spec Kit SDD workflow.
4. Next ceremony: Mid-Sprint Progress & Spec Kit Checkpoint Meeting on Tuesday, 10/11/2026.

#### Summary of Meeting 2:
Weekly Scrum Meeting 2 verified that the project is on track. All foundational documentation and modeling deliverables (Sections A, B, C) are finalized. The remaining use-case specifications and prototype screenshots (Section D) are in their final review stages. The team is well-positioned to begin the full-stack Spec Kit implementation phase.

---

### Trello Board Progress Evidence (Mid-Sprint Checkpoint - 08/11/2026)

![NutriViet Sprint 3 Trello Board Mid-Sprint](../assets/setup/trello-sprint3-meeting2.jpg)

*Figure 1.1: NutriViet Sprint 3 Scrum Board on Trello as of Sunday, 08/11/2026, displaying 3 tasks completed in Done, 6 tasks In Progress, and 5 queued tasks in To Do with explicit 1:1 member assignments and deadlines.*

---

### =========== Meeting 3: Mid-Sprint Progress & Spec Kit Checkpoint (12/11/2026) ===========

**Date & Time:** Thursday, 12/11/2026 | 20:30 – 21:45  
**Location:** Google Meet (Online)  
**Team members present:**
- Ngo Tien Binh (PM & AI Lead)
- Le Tat Nam (Backend & Architecture Lead)
- Luong Hoang Nam (UI/UX & Flutter Lead)
- Nguyen Hoang Phuc Thinh (Database & DevOps Lead)
- Truong Gia Linh (QA & Documentation Lead)

**Team members absent:** None (100% Attendance)

---

#### Status Reports:

#### Ngo Tien Binh (PM & AI Lead)
* **Completed tasks:**
  - Task `TASK-15`: **DONE.** Updated `project-plan.md` to PA3-2026 2nd submission status; updated 5-sprint roadmap (Sprint 3: 01/11 – 14/11/2026); authored Section A in `Changes.md`.
  - Task `TASK-22`: **DONE.** Completed Spec Kit specifications for FG1 (Authentication) and FG2 (Allergy Profile) with full Gherkin acceptance criteria in `specs/001-authentication/spec.md` and `specs/002-allergy-profile/spec.md`.
* **To-do Tasks:**
  - Task `TASK-26`: **IN PROGRESS (Nov 12 - Nov 14).** Finalize narration script (`video-demo-script.md`) and record end-to-end video demonstration of the live running application for YouTube.
* **Issues/Obstacles:**
  - Configured Android Emulator DNS to `dns.google` to resolve network routing conflicts when host machines use Cloudflare WARP.

#### Le Tat Nam (Backend & Architecture Lead)
* **Completed tasks:**
  - Task `TASK-16`: **DONE.** Expanded `vision.md` with 4-dimensional user environments, 8-dimension competitor matrix, and quantitative NFR verification methods.
  - Task `TASK-23`: **DONE.** Formulated Spec Kit implementation plan (`plan.md`), data contracts (`openapi.json`), and granular task breakdown (`tasks.md`).
* **To-do Tasks:**
  - Task `TASK-25`: **IN PROGRESS (Nov 10 - Nov 14).** Finalize backend WSGI API endpoints for password change (`/api/v1/auth/change-password`) and user physical metrics (`/api/v1/profile/metrics`) on PythonAnywhere.
* **Issues/Obstacles:**
  - Enforced SQLite table schema migrations on the remote PythonAnywhere cloud instance.

#### Luong Hoang Nam (UI/UX & Flutter Lead)
* **Completed tasks:**
  - Task `TASK-17`: **DONE.** Constructed system-level and sub-module use-case diagrams in Mermaid syntax covering all 8 Functional Groups with actors and relationships.
  - Task `TASK-20`: **DONE.** Finalized high-fidelity interactive prototype covering all 18 use cases.
* **To-do Tasks:**
  - Task `TASK-24`: **IN PROGRESS (Nov 10 - Nov 14).** Finalize Flutter frontend: modern bottom taskbar with center glowing QUÉT button, profile card navigation, crowdsource packaging photo uploader, and community feed.
* **Issues/Obstacles:**
  - Streamlined `SettingsScreen` to eliminate layout overflow and focus strictly on password update.

#### Nguyen Hoang Phuc Thinh (Database & DevOps Lead)
* **Completed tasks:**
  - Task `TASK-19`: **DONE.** Finalized Use-Case Specifications for extended scenarios (UC11–UC18: Dietary Log, Reaction Incidents, Shopping Lists, Community Submissions, and Admin Moderation).
* **To-do Tasks:**
  - Task `TASK-28`: **IN PROGRESS (Nov 12 - Nov 14).** Prepare AI usage disclosure documentation, audit git commit logs, and assemble `PA3-Group07.zip`.
* **Issues/Obstacles:**
  - Ensuring the repository remains clean of binary artifacts and temporary build caches.

#### Truong Gia Linh (QA & Documentation Lead)
* **Completed tasks:**
  - Task `TASK-18`: **DONE.** Finalized Use-Case Specifications for core scenarios (UC01–UC10: Auth, Profiles, Camera Scanner, Hazard Alerts, Safe Alternatives).
  - Task `TASK-21`: **DONE.** Successfully embedded all 17 prototype screenshots into `use-cases.md`.
* **To-do Tasks:**
  - Task `TASK-27`: **IN PROGRESS (Nov 2 - Nov 14).** Maintain meeting minutes and synchronize Trello Board progress checkpoint evidence.
* **Issues/Obstacles:**
  - Verifying relative image paths so that figures render seamlessly in both Markdown and converted PDF exports.

---

#### Actions & Decisions:
1. Mid-Sprint checkpoint confirmed: **9 tasks completed in Done** (`TASK-15` through `TASK-23`), **5 tasks actively In Progress** (`TASK-24`, `TASK-25`, `TASK-26`, `TASK-27`, `TASK-28`), and **0 tasks remaining in To Do**.
2. Confirmed that all Section A, B, C, and D documentation and prototype assets are 100% frozen.
3. Full-stack development team (Nam, Nam, Thinh, Binh) advancing the final integration of the live running Flutter client with the Cloud PythonAnywhere backend.
4. Final sprint timeline confirmed: Sprint 3 concludes on **Saturday, 14/11/2026**. Next ceremony: Sprint Review & Retrospective on Saturday, 14/11/2026.

#### Summary of Meeting 3:
Weekly Scrum Meeting 3 verified outstanding sprint momentum. 9 out of 14 tasks are fully completed in Done, while the remaining 5 tasks for implementation, demonstration, and final submission packaging are actively progressing toward the November 14 deadline. The team is on schedule to finalize all Section E and Section F deliverables.

---

### Trello Board Progress Evidence (Sprint 3 Checkpoint - 12/11/2026)

![NutriViet Sprint 3 Trello Board Checkpoint](../assets/setup/trello-sprint3-meeting3.jpg)

*Figure 1.2: NutriViet Sprint 3 Scrum Board on Trello as of 12/11/2026, displaying 9 tasks completed in Done, 5 tasks actively In Progress, and 0 queued tasks in To Do with explicit 1:1 member assignments and deadlines leading to final sprint delivery on 14/11/2026.*

---

### =========== Meeting 4: Sprint 3 Review & Retrospective (14/11/2026) ===========

**Date & Time:** Saturday, 14/11/2026 | 20:00 – 21:30  
**Location:** Google Meet (Online)  
**Team members present:**
- Ngo Tien Binh (PM & AI Lead)
- Le Tat Nam (Backend & Architecture Lead)
- Luong Hoang Nam (UI/UX & Flutter Lead)
- Nguyen Hoang Phuc Thinh (Database & DevOps Lead)
- Truong Gia Linh (QA & Documentation Lead)

**Team members absent:** None (100% Attendance)

---

#### Status Reports:

#### Ngo Tien Binh (PM & AI Lead)
* **Completed tasks:**
  - Task `TASK-22`: **DONE.** Completed Spec Kit specifications (`specs/`) for FG1 (Authentication) and FG2 (Allergy Profile) with full acceptance criteria.
  - Task `TASK-26`: **DONE.** Recorded 5-minute video demonstration with voiceover narration walking through the live running FG1 & FG2 features; uploaded to [YouTube (https://www.youtube.com/watch?v=-LUs4PHV20Q)](https://www.youtube.com/watch?v=-LUs4PHV20Q) and embedded link in `README.md`.
  - Conducted end-to-end sanity audit of all course deliverables.
* **To-do Tasks:**
  - None (All 14 Sprint 3 tasks 100% completed, verified, and archived for final PA3 delivery).

#### Le Tat Nam (Backend & Architecture Lead)
* **Completed tasks:**
  - Task `TASK-23`: **DONE.** Formulated Spec Kit architecture plan (`plans/`) and task breakdown (`tasks/`).
  - Task `TASK-25`: **DONE.** Implemented backend RESTful API with SQLite relational persistence on PythonAnywhere for FG1 & FG2; verified API contracts against OpenAPI specs.

#### Luong Hoang Nam (UI/UX & Flutter Lead)
* **Completed tasks:**
  - Task `TASK-20`: **DONE.** Finalized high-fidelity interactive prototype for all 18 use cases.
  - Task `TASK-24`: **DONE.** Implemented Flutter frontend with modern taskbar, glowing QUÉT button, profile metrics, and community crowdsource upload integrated with the backend API.

#### Nguyen Hoang Phuc Thinh (Database & DevOps Lead)
* **Completed tasks:**
  - Task `TASK-19`: **DONE.** Finalized Use-Case Specifications for UC11–UC18.
  - Task `TASK-28`: **DONE.** Compiled AI usage logs, exported clean Git commit log, converted all Markdown artifacts to PDF format, cleaned repository dependencies (`node_modules`, `venv`), and generated `PA3-Group07.zip`.

#### Truong Gia Linh (QA & Documentation Lead)
* **Completed tasks:**
  - Task `TASK-18`: **DONE.** Finalized Use-Case Specifications for UC01–UC10.
  - Task `TASK-21`: **DONE.** Successfully embedded all 17 prototype screenshots into `use-cases.md`.
  - Task `TASK-27`: **DONE.** Finalized Sprint 3 meeting minutes and archived Trello board progress.

---

#### Actions & Decisions:
1. Final Sprint 3 Delivery Audit confirmed: **14 out of 14 tasks (100%) completed in Done**, **0 tasks in In Progress**, and **0 tasks in To Do**.
2. Live running demonstration of FG1 (Authentication) and FG2 (Allergy Profile & Health Metrics) formally approved and ratified by all members.
3. Final Git commit history audited and exported to `git-log.txt`. Cleaned repository builds and generated final delivery archive `PA3-Group07.zip`.
4. Sprint 3 formally signed off. Backlog refinement for Sprint 4 scheduled for Sunday, 15/11/2026.

#### Summary of Meeting 4:
The Sprint 3 Review & Retrospective meeting concluded successfully on Saturday, 14/11/2026. All 14 assigned tasks across Sections A through F are 100% complete with rigorous cross-peer review. The live Flutter application seamlessly communicates with the Cloud PythonAnywhere backend, and all Spec Kit specifications, plans, and task matrices meet university standards.

---

### Trello Board Final Evidence (Sprint 3 Delivery - 14/11/2026)

![NutriViet Sprint 3 Final Trello Board](../assets/setup/trello-sprint3-meeting4.jpg)

*Figure 1.3: NutriViet Sprint 3 Final Scrum Board on Trello as of Saturday, 14/11/2026, displaying all 14/14 tasks (100%) completed in Done, 0 In Progress, and 0 To Do with full verification and sign-off.*

---

#### Sprint 3 Retrospective Analysis:
* **What went well:**
  - Using Spec Kit to specify features before coding prevented scope creep and gave clear implementation boundaries for FG1 & FG2.
  - Having high-fidelity UI prototypes before implementing frontend components accelerated client development.
  - Strict enforcement of the 1 Performer + 1 Reviewer rule caught edge cases in alternative flows early.
* **What could be improved:**
  - Coordinating database schema migrations with frontend data models required an extra sync session; future sprints will establish OpenAPI schemas earlier.
* **Actions for Sprint 4 (PA4):**
  - Integrate live Google ML Kit camera OCR scanning into the mobile client.
  - Expand FoodOn semantic matching service to cover 100+ common Vietnamese packaged food additives.

---

## 2. Generative AI Usage & Tool Disclosures
*Performed by: Ngo Tien Binh | Reviewed by: Truong Gia Linh | Edited by: Nguyen Hoang Phuc Thinh*

In accordance with course academic integrity guidelines, the team explicitly discloses the strict, limited boundaries within which Generative AI tools were used during Sprint 3. The team maintains full intellectual ownership over all deliverables, with the vast majority of engineering effort (over 85%) carried out entirely by human team members.

### 2.1. Core Human Intellectual Ownership vs. AI Boundaries

| Core Engineering Deliverable | Human Authorship & Ownership (Student Team) | Role of Generative AI (Strictly Limited) |
|:---|:---|:---|
| **Use-Case Model & Diagrams (Section C)** | **100% Human Designed & Authored.** All 18 Use Cases, actors (Consumer, Admin, ML Kit, FoodOn), boundary definitions, and UML relationships (`<<include>>`, `<<extend>>`, generalization) were brainstormed on paper/whiteboard and manually coded into Mermaid syntax by Luong Hoang Nam. | **Zero modeling contribution.** AI was NOT used to generate or design use cases. Only consulted for Mermaid syntax debugging (e.g., verifying subgraphs and dotted arrow connector rendering in Markdown). |
| **Use-Case Specifications (Section D)** | **100% Human Authored.** All preconditions, step-by-step basic flows, complex alternative flows (network drop, bad camera focus, blurred labels), and postconditions were derived directly from our Vision Document by Truong Gia Linh & Nguyen Hoang Phuc Thinh. | Secondary proofreading assistant strictly for English grammatical polish and passive voice consistency. |
| **High-Fidelity UI Prototypes (Section D)** | **100% Human Designed.** All 17 interactive prototype screens were conceived, wireframed, and styled by Luong Hoang Nam using Figma/design tools to reflect Vietnamese FMCG packaging ergonomics. | **None.** No generative image/UI models were used for the prototypes. |
| **System Architecture & Database Schema (Section E)** | **100% Human Architected.** Database tables (`users`, `user_allergens`, `user_metrics`), PBKDF2 salting crypto, and REST API contract designs were formulated by Le Tat Nam & Ngo Tien Binh. | Editor-level auto-complete (GitHub Copilot) for repetitive typing of SQL boilerplate fields and type hints. |
| **Full-Stack Implementation (Section E)** | **100% Human Engineered & Debugged.** Flutter state management, custom UI widgets, biometric calculations, and Python WSGI cloud deployment were hand-coded and tested by the team on Android Emulator and live cloud servers. | None for core business logic; only utilized standard official documentation and CLI scaffolding tools (`specify-cli`). |

---

### 2.2. Tool Inventory & Scope of Use
1. **GitHub Spec Kit (`specify-cli`):** An official open-source methodology tool used strictly to scaffold standardized folder directories (`specs/`, `plans/`, `tasks/`) for Spec-Driven Development compliance.
2. **Generative Language Models (Gemini / Claude):** Restricted solely to documentation editorial assistance—proofreading technical English grammar and diagnosing Markdown / Mermaid syntax quirks.
3. **GitHub Copilot:** Restricted strictly to editor-level code-completion for standard boilerplate syntax (e.g., Python dictionaries, Flutter widget constructor parameters).

---

### 2.3. Granular AI Interaction Log (Sprint 3)

| Date | Team Member | AI Tool | Prompt / Objective | AI Generated Output | Human Review, Intellectual Effort & Customization Applied |
|:---:|:---|:---:|:---|:---|:---|
| **03/11/2026** | Luong Hoang Nam | Google Gemini | *"How to fix Mermaid syntax error when nesting subgraphs with dotted extend arrows in Markdown?"* | Explained Mermaid syntax rules for line syntax (`-.->|text|`). | The entire Use-Case architecture, 18 Use Cases, actor generalizations, and relationship semantics were already 100% hand-drawn and designed by the team; AI only provided syntax troubleshooting advice for Markdown rendering. |
| **05/11/2026** | Truong Gia Linh | Claude 3.5 | *"Proofread English grammar and passive voice phrasing for the step-by-step descriptions in food hazard evaluation."* | Suggested grammatical adjustments and refined technical vocabulary. | Team verified all domain logic manually against supermarket scenarios; all functional steps (camera lux thresholds, OCR tokenization, FoodOn ontology derivation) remained 100% original human work. |
| **07/11/2026** | Ngo Tien Binh | Spec Kit CLI | `specify init --template sdd` to generate SDD folder scaffolds for Functional Groups FG1 & FG2. | Generated empty folder structure (`specs/`, `plans/`, `tasks/`) with blank template files. | Team manually authored all domain user stories, Gherkin acceptance criteria, database entities, and OpenAPI contract endpoints from scratch. |
| **11/11/2026** | Le Tat Nam | GitHub Copilot | Tab auto-completion for Python type hints and standard error handler structure. | Suggested basic `try/except` boilerplate and JSON serialization code. | Core security logic, PBKDF2 HMAC-SHA256 password salting, database schema reconciliation, and Vietnamese allergen dictionary mapping were 100% written and verified by human engineers. |

---

### 2.4. Formal Academic Integrity Declaration
> **Academic Integrity Statement:**  
> All system architectures, use-case models, UML diagrams, functional specifications, UI prototypes, domain algorithms, and full-stack software code presented in this PA3 submission represent original intellectual work independently conceived, designed, hand-coded, and validated by the members of Group 07. Generative AI tools were strictly confined to minor auxiliary roles (grammar proofreading and syntax validation) and never substituted for human critical thinking, architectural design, or engineering problem-solving.
