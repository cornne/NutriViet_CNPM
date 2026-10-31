# NutriViet: Project Plan
**Software Engineering Project Plan & Scrum Cadence Specification**  
**Course:** CS300 - CSC13002 - Introduction to Software Engineering  
**Project Assignment:** PA2-2026  
**Group:** Group 07 - NutriViet Team  

---

## 1. Introduction
*Performed by: Ngo Tien Binh | Reviewed by: Truong Gia Linh | Edited by: Le Tat Nam*

### 1.1. Project Overview
**NutriViet** is an intelligent, camera-driven mobile application engineered for the Android platform that delivers personalized food allergen warnings and comprehensive nutrition management for Vietnamese consumers. By integrating on-device Optical Character Recognition (OCR), Levenshtein fuzzy matching, and the FoodOn semantic food ontology, NutriViet empowers individuals suffering from severe allergies (peanuts, seafood, gluten, cow's milk) and chronic metabolic conditions to instantly evaluate packaged food labels in retail environments. The application eliminates the dependency on pre-existing barcode databases through direct camera text extraction, while providing structured daily nutritional logging, safe product alternative recommendations, and a moderated crowdsourcing ecosystem for local food products.

### 1.2. Purpose of the Project Plan
This Project Plan defines the operational roadmap, organizational structure, agile Scrum schedule, and risk mitigation protocols for the NutriViet development lifecycle across the semester. It coordinates the efforts of the 5 engineering team members, aligns task dependencies with the course milestones (PA1 through PA5), establishes transparent quality gates, and guarantees delivery of a fully validated, production-ready mobile application and demonstration by Sprint 5.

---

## 2. Project Overview
*Performed by: Ngo Tien Binh | Reviewed by: Le Tat Nam | Edited by: Nguyen Hoang Phuc Thinh*

### 2.1. Project Goals
1. **Primary Safety Goal:** Deliver an instant (< 2.0s), unambiguous color-coded visual warning system (RED/YELLOW/GREEN) on mobile devices that achieves $\ge 98\%$ recall for primary declared food allergens on packaged labels.
2. **Architectural Goal:** Implement a robust Clean Architecture in Flutter (BLoC pattern) for the client application paired with a modular, containerized Python FastAPI backend and PostgreSQL database.
3. **Engineering Rigor Goal:** Maintain Spec-Driven Development (SDD) via GitHub Spec Kit, achieving $\ge 80\%$ automated unit test coverage across core domain algorithms and zero critical security vulnerabilities.
4. **Agile Process Goal:** Execute 5 disciplined Scrum Sprints, ensuring complete traceability between requirements, Trello task boards, Git commits, peer code reviews, and weekly status reports.

### 2.2. Project Scope
* **In-Scope Capabilities:**
  * Real-time mobile camera capture, image contrast preprocessing, and on-device text token extraction (Google ML Kit OCR).
  * Backend and offline fuzzy text matching against Vietnamese ingredient and additive dictionaries.
  * Hierarchical allergen relationship derivation via the FoodOn ontology graph (e.g., Casein $\rightarrow$ Milk).
  * Customizable personal health profiles (allergens, medical conditions, dietary goals).
  * Daily dietary diary tracking macro/micronutrients (sugar, sodium, purine, calories).
  * Contextual safe food alternative recommendation engine.
  * Community product crowdsourcing and OCR discrepancy reporting.
  * Web-based administrative moderation portal for crowdsourced catalog verification and audit trails.
* **Out-of-Scope Capabilities:**
  * Direct e-commerce purchasing or payment gateway integrations within the application.
  * Automated medical diagnosis or prescription writing (NutriViet provides decision support, not medical treatment).
  * Native iOS build distribution during the academic semester (development focuses exclusively on Android; Flutter ensures cross-platform readiness for future releases).

### 2.3. Project Assumptions
1. **Developer Tooling & Access:** All 5 team members have functional Android development environments (Flutter SDK, Android Studio, VS Code, Git) and active GitHub student accounts.
2. **Camera Hardware Availability:** Testing physical devices have operational autofocus cameras running Android 8.0 (API 26) or higher.
3. **Scrum Discipline:** Every team member participates in required sprint ceremonies and logs task effort transparently on the shared Trello board.

---

## 3. Project Organization
*Performed by: Le Tat Nam | Reviewed by: Nguyen Hoang Phuc Thinh | Edited by: Truong Gia Linh*

### 3.1. Team Structure and Roles
NutriViet adopts a collaborative Agile team structure where all 5 members act as Full-Stack Software Engineers while assuming designated functional leadership roles:

| Member Name | Student ID | Functional Leadership Role | Primary Responsibilities |
|:---|:---:|:---|:---|
| **Ngo Tien Binh** | **24127004** | **Project Manager (PM) & AI Lead** / Full-Stack Engineer | Overall sprint coordination, liaison with Course TAs, Spec Kit management; AI algorithm development (Levenshtein fuzzy matching in Python/Dart, FoodOn ontology graph queries), and algorithm test verification. |
| **Le Tat Nam** | **23127432** | **Backend & System Architecture Lead** / Full-Stack Engineer | System architecture specifications; FastAPI backend services implementation, RESTful API endpoints, user authentication/RBAC (User/Admin), and Docker service containerization. |
| **Luong Hoang Nam** | **24127456** | **UI/UX & Flutter Lead** / Full-Stack Engineer | Mobile UI/UX Figma design; Flutter client development (Clean Architecture + BLoC), camera OCR text recognition pipeline (Google ML Kit integration), and visual hazard alert rendering (RED/YELLOW/GREEN). |
| **Nguyen Hoang Phuc Thinh** | **24127242** | **Database & DevOps Lead** / Full-Stack Engineer | PostgreSQL schema design and migrations; client-side encrypted offline caching layer (SQLite/Hive in Flutter), Git workflow management, and automated GitHub Actions CI/CD pipelines. |
| **Truong Gia Linh** | **24127438** | **QA & Test Automation Lead** / Full-Stack Engineer | Automated test suite development (Flutter unit & widget test scripts, backend pytest integration tests targeting $\ge 80\%$ coverage), Daily Dietary Diary feature development (FG5 logging & nutritional accumulation logic), and Scrum QA documentation. |

### 3.2. Risk Management
The team has identified 4 critical project risks spanning technical, operational, and scope dimensions, and formulated concrete mitigation strategies for each:

```mermaid
quadrantChart
    title Project Risk Assessment Matrix
    x-axis Low Likelihood --> High Likelihood
    y-axis Low Impact --> High Impact
    quadrant-1 Critical Risk
    quadrant-2 Contingency Plan
    quadrant-3 Low Risk
    quadrant-4 Actionable Risk
    "R-01 Glossy Label OCR": [0.78, 0.86]
    "R-02 Midterm Exam Crunch": [0.68, 0.68]
    "R-03 Scope Creep": [0.60, 0.78]
    "R-04 FoodOn Latency": [0.35, 0.55]
```

| Risk ID | Risk Category | Risk Description | Severity | Likelihood | Mitigation & Contingency Strategy |
|:---:|:---:|:---|:---:|:---:|:---|
| **R-01** | Technical | **Degraded OCR Accuracy on Real-World Packaging:** Glossy cellophane, curved cans, and crinkled bags cause character dropouts and noise in text recognition. | **High** | **High** | 1. Implement client-side image contrast preprocessing and adaptive binarization before OCR.<br/>2. Apply Levenshtein fuzzy matching with a 75% similarity threshold against verified ingredient dictionaries.<br/>3. Provide an intuitive on-screen manual text correction interface so users can amend ambiguous tokens in 1 tap. |
| **R-02** | Operational | **Team Member Unavailability during Midterms:** Illness or academic midterm examination crunches could stall critical task paths. | **High** | **Medium** | 1. Strict adherence to the **"1 Doer + 1 Reviewer"** rule ensures at least 2 members are fully familiar with every piece of code and documentation.<br/>2. All work-in-progress code must be committed to Git feature branches daily to prevent progress lockup.<br/>3. Re-allocate non-critical research tasks if a member experiences an emergency. |
| **R-03** | Scope | **Scope Creep / Feature Bloat:** Expanding into e-commerce, meal ordering, or complex medical lab data could prevent on-time project completion. | **High** | **Medium** | 1. Strictly enforce the boundaries defined in the Project Scope (Section 2.2).<br/>2. Freeze feature specifications at the conclusion of Sprint 2 (PA2).<br/>3. Classify all "nice-to-have" enhancements (e.g., social feed, gamification badges) as *Priority-3 Backlog* items that will only be touched if core deliverables pass QA ahead of schedule. |
| **R-04** | Technical / Architecture | **FoodOn Ontology Query Latency:** Complex recursive graph lookups for hidden allergen lineage could exceed the 2.0s latency threshold over the network. | **Medium** | **Low** | 1. Flatten and precompute primary allergen lineage paths into indexed relational lookup tables in PostgreSQL.<br/>2. Cache the top 500 most frequent Vietnamese packaged food additives directly in Redis and local device storage.<br/>3. Bound recursive ontology lookups to a maximum depth of 4 relationship hops. |

---

## 4. Project Plan & Scrum Cadence
*Performed by: Ngo Tien Binh | Reviewed by: Le Tat Nam | Edited by: Luong Hoang Nam*

The project is structured into **5 consecutive Scrum Sprints**, each spanning 2 to 3 weeks and corresponding directly to course project assignments.

### 4.1. 5-Sprint High-Level Roadmap

1. **Sprint 1 (PA1 - Project Proposal & Setup):** *Completed (25/09/2026 – 12/10/2026)*
   * Established team roster, leadership roles, and working agreement contract.
   * Defined initial 8 Functional Groups, 2 system actors, and AI fuzzy matching concepts.
   * Conducted comprehensive competitive survey of Yuko and Soosee.
   * Configured Git repository, Trello Kanban board, and AI tooling disclosures.
2. **Sprint 2 (PA2 - Vision Document, Project Plan & Spec Kit):** *Completed (18/10/2026 – 31/10/2026)*
   * Author initial Vision Document (`vision.md`) with standardized tables and Mermaid workflows.
   * Author initial Project Plan (`project-plan.md`) with 5-Sprint schedule and risk management.
   * Integrate GitHub Spec Kit, ratify `constitution.md`, and complete member training.
   * Execute technical spikes on Flutter ML Kit camera capture and FoodOn schema design.
3. **Sprint 3 (PA3 - Software Architecture & UI Prototype):** *Planned (01/11/2026 – 18/11/2026)*
   * Author Software Architecture Document (SAD) with C4 component and deployment models.
   * Design high-fidelity UI/UX interactive wireframes in Figma.
   * Implement foundational Flutter Clean Architecture scaffolding (BLoC, Network, Dependency Injection).
   * Refine Vision Document and Project Plan based on TA evaluation feedback.
4. **Sprint 4 (PA4 - Core Implementation & Integration):** *Planned (19/11/2026 – 05/12/2026)*
   * Implement functional camera OCR pipeline and visual hazard alert rendering (RED/YELLOW/GREEN).
   * Implement FastAPI backend microservices for fuzzy matching and FoodOn ontology queries.
   * Implement user health profile configuration and local SQLite/Hive offline storage.
   * Author unit tests and integration tests achieving $\ge 80\%$ domain code coverage.
5. **Sprint 5 (PA5 - Verification, Polish & Comprehensive Demo):** *Planned (06/12/2026 – 22/12/2026)*
   * Implement Community Crowdsourcing and Admin Moderation portal.
   * Execute end-to-end user acceptance testing (UAT) and load testing (150 concurrent requests).
   * Fix bugs, optimize battery and memory usage, compile production release APK.
   * Deliver live end-to-end product demonstration covering all 8 Functional Groups.

---

### 4.2. Sprint 2 Completed Tasks (PA2)
*Duration: 18/10/2026 – 31/10/2026 (Synchronized with Trello Board)*

In accordance with course guidelines, every task represents a concrete project activity, has **exactly one assigned performer**, and is **reviewed by another designated member**.

| Task ID | Task Title & Specific Activity | Performer (Assignee) | Reviewer | Start Date | Due Date | Status |
|:---:|:---|:---:|:---:|:---:|:---:|:---:|
| **TASK-01** | **Spec Kit Repository Integration:** Install `specify-cli`, configure `.specify/` infrastructure, author NutriViet `constitution.md`, verify clean Git synchronization. | **Ngo Tien Binh** | Nguyen Hoang Phuc Thinh | 18/10 | 21/10 | **Done** |
| **TASK-02** | **Spec Kit Training & Learning Notes:** Complete YouTube tutorial series on Spec-Driven Development; document individual learning takeaways. | **All 5 Members** *(Subtasks 02.1 - 02.5)* | Peer Cross-Review | 19/10 | 23/10 | **Done** |
| **TASK-03** | **Vision Doc - Positioning Tables:** Formulate Problem Statement and Product Position Statement tables adhering to course formats. | **Le Tat Nam** | Ngo Tien Binh | 21/10 | 24/10 | **Done** |
| **TASK-04** | **Vision Doc - Stakeholders & Survey:** Detail user personas, supermarket environmental constraints, update competitive analysis of Yuko & Soosee. | **Truong Gia Linh** | Luong Hoang Nam | 21/10 | 25/10 | **Done** |
| **TASK-05** | **Vision Doc - Features & Mermaid:** Author detailed 3–5 sentence paragraphs for FG1–FG8 (What, Why, Who); draw 2 Mermaid workflow diagrams. | **Luong Hoang Nam** | Ngo Tien Binh | 22/10 | 26/10 | **Done** |
| **TASK-06** | **Vision Doc - Quantifiable NFRs:** Define measurable thresholds for latency (< 2.0s), security (AES-256, TLS 1.3), scalability, and reliability. | **Nguyen Hoang Phuc Thinh** | Le Tat Nam | 22/10 | 26/10 | **Done** |
| **TASK-07** | **Project Plan - Goals & Scope:** Draft project goals, boundaries, assumptions, deliverables, and team organization matrix. | **Ngo Tien Binh** | Truong Gia Linh | 24/10 | 27/10 | **Done** |
| **TASK-08** | **Project Plan - Risk Management:** Analyze 4 technical and operational risks (OCR degradation, midterm absences, scope creep, ontology latency) + mitigations. | **Le Tat Nam** | Nguyen Hoang Phuc Thinh | 24/10 | 29/10 | **Done** |
| **TASK-09** | **Project Plan - Schedule & Sprint Roadmap:** Formalize 5-Sprint schedule, milestone deliverables, and task rules; align with Trello board. | **Ngo Tien Binh** | Le Tat Nam | 25/10 | 28/10 | **Done** |
| **TASK-10** | **Tech Spike - Flutter Camera OCR:** Benchmark Google ML Kit Text Recognition on sample Vietnamese packaged foods; measure token extraction speed. | **Luong Hoang Nam** | Ngo Tien Binh | 21/10 | 28/10 | **Done** |
| **TASK-11** | **Tech Spike - FoodOn Schema Design:** Analyze FoodOn OWL graph structures and draft normalized relational schema for ingredients and allergen hierarchies. | **Nguyen Hoang Phuc Thinh** | Le Tat Nam | 23/10 | 28/10 | **Done** |
| **TASK-12** | **Weekly Report - Scrum Documentation:** Document Sprint Planning (18/10), standup meetings, and Sprint Review agendas in `weekly-reports.md`. | **Truong Gia Linh** | Ngo Tien Binh | 20/10 | 29/10 | **Done** |
| **TASK-13** | **AI Usage Logging & Disclosure:** Compile transparent log of AI tool queries (Copilot, Spec Kit, Gemini) for Sprint 2 with academic integrity statements. | **Ngo Tien Binh** | Truong Gia Linh | 28/10 | 30/10 | **Done** |
| **TASK-14** | **Packaging, Jira Export & PDF Assembly:** Capture final Trello screenshots, export Git commit history, convert documents to PDF, build `PA2-Group07.zip`. | **Nguyen Hoang Phuc Thinh** | Ngo Tien Binh | 30/10 | 31/10 | **Done** |

---

### 4.3. Planned Tasks for Later Sprints (Sprints 3 to 5)

#### Sprint 3 Planned Tasks (Architecture & UI Prototype)
* Author Software Architecture Document (SAD): Architectural patterns, C4 component diagrams, physical deployment architecture.
* Build high-fidelity Figma interactive prototype for all 8 Functional Groups; conduct heuristic evaluation.
* Set up Flutter Clean Architecture folder structure: `core/`, `features/scanner/`, `features/profile/`, `features/history/`.
* Set up FastAPI backend boilerplate with Docker Compose, PostgreSQL container, and health check endpoints.
* Establish automated CI/CD pipeline on GitHub Actions for automated linting and testing.
* Review and update Vision Document and Project Plan based on TA feedback from PA2.

#### Sprint 4 Planned Tasks (Core Implementation & Unit Testing)
* Implement on-device camera scanner UI with live bounding box overlays and flashlight toggle.
* Integrate ML Kit OCR text parser with hyphenated word reconstruction and whitespace normalization.
* Implement Levenshtein fuzzy matching algorithm with benchmarked similarity thresholds.
* Implement FoodOn hierarchical allergen query engine in FastAPI.
* Implement local offline storage using SQLite/Hive for encrypted health profile caching.
* Author comprehensive Unit Test suites targeting $\ge 80\%$ code coverage across all business logic.
* Implement Daily Dietary Diary food logging and nutritional accumulation widgets.

#### Sprint 5 Planned Tasks (Verification, Polish & Live Demonstration)
* Implement Community Food Product Crowdsourcing submission flow and Admin Moderation web portal.
* Implement Safe Food Alternative recommendation algorithm.
* Conduct end-to-end integration testing and user acceptance testing across varying retail packaging types.
* Perform load and stress testing on FastAPI backend simulating 150 concurrent scanning requests.
* Profile and optimize mobile memory footprint, frame rate (stable $\ge 30\text{ fps}$), and battery consumption.
* Finalize comprehensive user guide, API documentation, and presentation slide deck.
* Conduct live product demonstration covering all 8 Functional Groups for course evaluation.
