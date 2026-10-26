# GitHub Spec Kit: Team Training Completion Log
**Spec-Driven Development (SDD) Self-Training Evidence**  
**Course:** CS300 - CSC13002 - Introduction to Software Engineering  
**Project Assignment:** PA2-2026 (Part C Deliverable)  
**Group:** Group 07 - NutriViet Team  

---

## 1. Overview of Training Activity
In compliance with Section C of the Project Assignment 2 (PA2-2026) specification, all 5 members of the NutriViet engineering team completed the official GitHub Spec Kit video tutorial curriculum on Spec-Driven Development (SDD) between **19/10/2026** and **23/10/2026**.

The training covered:
1. The transition from informal "vibe coding" to structured, reproducible **Spec-Driven Development (SDD)**.
2. The role of the **Constitution (`constitution.md`)** as an authoritative, long-term memory governance file for AI coding agents (GitHub Copilot, Cursor, Claude).
3. The core command lifecycle: `/speckit-constitution` $\rightarrow$ `/speckit-specify` $\rightarrow$ `/speckit-clarify` $\rightarrow$ `/speckit-plan` $\rightarrow$ `/speckit-tasks` $\rightarrow$ `/speckit-implement`.
4. Integration with Git repositories and local command execution via `specify-cli`.

---

## 2. Individual Member Training Completion & Key Learnings

### Member 1: Ngo Tien Binh (24127004) - Project Manager & AI Lead
* **Training Status:** Completed (20/10/2026)
* **Modules Covered:** Overview of Spec Kit, Repository Scaffolding, and Constitution Formulation.
* **Key Learning Takeaways:**
  > *"I learned how Spec Kit prevents AI drift by establishing an immutable Constitution in `.specify/memory/constitution.md`. In NutriViet, by anchoring our food safety rules, 80% test coverage minimum, and Clean Architecture standards into the constitution, any subsequent command executed by team members or AI agents will automatically enforce these quality gates without repetitive manual prompt engineering."*

---

### Member 2: Le Tat Nam (23127432) - Backend & System Architecture Lead
* **Training Status:** Completed (21/10/2026)
* **Modules Covered:** `/speckit-plan` Architectural Scaffolding, Data Modeling, and API Contract Definitions.
* **Key Learning Takeaways:**
  > *"The `/speckit-plan` workflow demonstrated how to translate user-facing specifications into concrete architectural decisions (such as FastAPI endpoints, PostgreSQL schemas, and Docker configs) before writing a single line of application code. This ensures our backend data models and FoodOn graph lookups are fully architected upfront, reducing expensive refactoring downstream."*

---

### Member 3: Luong Hoang Nam (24127456) - UI/UX & Flutter Lead
* **Training Status:** Completed (21/10/2026)
* **Modules Covered:** `/speckit-specify` Requirements Capture and Acceptance Criteria Structuring.
* **Key Learning Takeaways:**
  > *"The tutorial emphasized that specs must focus purely on user value and observable behaviors rather than technical implementation details. Writing clear User Scenarios and Given-When-Then acceptance criteria using `/speckit-specify` will allow me to design Flutter BLoC states and camera scanner interactions that map directly to verified user requirements."*

---

### Member 4: Nguyen Hoang Phuc Thinh (24127242) - Database & Git Lead
* **Training Status:** Completed (22/10/2026)
* **Modules Covered:** `/speckit-tasks` Decomposition and Git Integration.
* **Key Learning Takeaways:**
  > *"I observed how `/speckit-tasks` systematically breaks a high-level technical plan into ordered, atomic, and testable tasks with defined file paths. This directly streamlines our Scrum workflow: we can convert these tasks straight into our Trello board cards with explicit assignees, ensuring every Git commit and PR maps to a verified spec task."*

---

### Member 5: Truong Gia Linh (24127438) - Quality Assurance & Documentation Lead
* **Training Status:** Completed (22/10/2026)
* **Modules Covered:** `/speckit-clarify` Ambiguity Reduction and `/speckit-checklist` Quality Gates.
* **Key Learning Takeaways:**
  > *"The `/speckit-clarify` and `/speckit-checklist` skills are powerful QA mechanisms. Before implementation starts, the AI acts as a devil's advocate, identifying blind spots, edge cases (such as offline handling or poor camera lighting), and conflicting constraints. This will allow our team to eliminate ambiguities during the design phase rather than finding defects during final testing."*

---

## 3. Verification & Artifact Repository References
* **Repository Spec Kit Scaffolding:** `.specify/` and `.github/skills/`
* **Ratified Project Constitution:** [src/constitution.md](../constitution.md)
* **Bundled Markdown Templates:** [src/speckit/](.)
