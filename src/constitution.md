# NutriViet Project Constitution
<!-- Foundational Governance & Engineering Principles for NutriViet -->

## Core Principles

### I. User Health & Food Safety First (Zero Ambiguity)
NutriViet serves users with dietary restrictions, chronic health conditions, and potentially life-threatening food allergies. Accuracy and unambiguous hazard communication are non-negotiable. Allergen status must be communicated through an immediate visual hierarchy (RED dangerous / YELLOW cautionary / GREEN safe). Every dietary warning and ingredient analysis must rely on verified allergen dictionaries and ontology mappings (FoodOn / Vietnamese Food Standard). Medical disclaimers must be prominently accessible.

### II. Spec-Driven & Contract-First Engineering
All engineering activities adhere strictly to Spec-Driven Development (SDD). No production code or schema change shall be merged without an approved specification, API contract, or architectural plan. Development follows the structured pipeline:
1. `/speckit-specify` for functional behavior and acceptance criteria.
2. `/speckit-plan` for technical architecture and data schemas.
3. `/speckit-tasks` for fine-grained, testable task breakdown.
4. `/speckit-implement` for execution against ratified specs.

### III. Clean Architecture & High Cohesion
The codebase maintains clear boundaries across layers:
- **Mobile Frontend (Flutter):** Follows Clean Architecture (Domain, Data, Presentation layers) utilizing the BLoC pattern for predictable state management.
- **Backend & AI Services:** Modular micro-services or modular monolith (FastAPI / Node.js) exposing OpenAPI/Swagger specifications. OCR parsing, fuzzy matching, and profile management must be isolated into testable, independent modules.

### IV. Test-First Quality Assurance (NON-NEGOTIABLE)
Quality gates are enforced prior to code integration:
- Unit tests are mandatory for all domain logic, OCR text normalizers, and allergen-detection algorithms.
- Core algorithm test coverage must reach at least 80%.
- Regressions are prevented via automated CI/CD pipeline checks; no PR is merged with failing tests, unresolved lint errors, or unapproved schema migrations.

### V. Performance & Offline Resilience
Consumer grocery shopping often takes place in low-connectivity retail environments (e.g., supermarket basements):
- OCR label processing and preliminary hazard alert latency must remain under 3.0 seconds.
- User allergy profiles, core allergen rules, and recent scans must be cached locally (SQLite / Hive) to ensure baseline safety warnings function completely offline.

---

## Technical Constraints & Security Standards

### 1. Technology Stack
- **Client Application:** Flutter (Dart) targeting Android (min SDK 26) with cross-platform scalability.
- **Backend Services:** Python 3.12+ (FastAPI) with PostgreSQL for structured relational data.
- **OCR & AI Engine:** On-device Google ML Kit Text Recognition with backend fallback (Tesseract/PaddleOCR), fuzzy Levenshtein text matching, and FoodOn allergen ontology classification.
- **Infrastructure & Containerization:** Docker, Docker Compose, GitHub Actions CI/CD.

### 2. Privacy & Data Protection
- User health profiles, allergen lists, and scan histories are treated as confidential personal data.
- Sensitive data is encrypted in transit using TLS 1.3 and encrypted at rest.
- No production credentials, tokens, or API secrets may ever be committed to the Git repository. Configuration must rely exclusively on `.env` templates and secure environment variable injection.

---

## Team Governance & Workflow Rules

### 1. Agile / Scrum Cadence
- Development is organized into **5 Sprints** (2–3 weeks each) corresponding to course Project Assignments (PA1 through PA5).
- Regular Scrum ceremonies (Sprint Planning, Daily / Weekly Standups, Sprint Review, and Retrospectives) are documented in `docs/management/weekly-reports.md`.

### 2. Task Assignment & Peer Review
- **Single Assignee Rule:** Every task in the project management board (Jira / Trello) is assigned to exactly one primary performer.
- **Mandatory Peer Review:** Every task and Pull Request must be reviewed and approved by a designated reviewer before merging into `main`.
- In all submitted documentation and reports, each section must specify:
  > *Performed by:* [Member Name] | *Reviewed by:* [Member Name] | *Edited by:* [Member Name]

### 3. AI Assistance Policy
- Generative AI tools (GitHub Copilot, Cursor, Gemini, Claude) are leveraged for accelerated specification, boilerplate scaffolding, and unit test generation.
- All AI usage must be logged transparently and declared in the sprint AI Usage Report in compliance with course academic integrity guidelines.

---

## Governance & Evolution

This Constitution supersedes informal agreements and ad-hoc practices. Any architectural deviation, technical exception, or constitutional amendment requires:
1. Formal documentation and rationale submitted via Pull Request.
2. Unanimous consensus from Team Leads (Project Manager, Architecture Lead, QA Lead).
3. Update to the version and ratification metadata below.

**Version**: 1.0.0 | **Ratified**: 2026-10-21 | **Last Amended**: 2026-10-21
