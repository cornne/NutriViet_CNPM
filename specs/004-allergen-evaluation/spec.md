# Feature Specification: FG4 - FoodOn Allergen & Chronic Hazard Evaluation

**Feature Branch**: `004-fg4-allergen-evaluation`  
**Created**: 16/11/2026  
**Updated**: 25/11/2026  
**Status**: Approved & Implemented  
**Use Cases**: `UC09` (Evaluate Ingredient Hazards)  
**Author / Reviewer**: Ngo Tien Binh (AI & Ontology Lead) | Reviewed by: Le Tat Nam & Truong Gia Linh

---

## 1. Purpose & Scope
This specification defines **FG4: FoodOn Allergen & Chronic Hazard Evaluation** in **NutriViet**. It covers the 4-stage `D1FoodOnEngine` (`src/cloudflare-worker/src/foodon.ts`) backed by Cloudflare D1 (`nutriviet-foodon`: **33,688** concepts, **53,242** lexical terms, **742** E-codes), OCR homoglyph & E-code repair, Levenshtein fuzzy matching ($\ge 82\%$ similarity), derivative/trace sensitivity flags (`scan_derivatives`, `warn_traces`), tri-tier **RED / YELLOW / GREEN** verdicts, automatic re-evaluation of recent scan history on profile updates, and the interactive **FoodOn Graph Explorer** (`/foodon-graph`).

---

## 2. User Scenarios & Testing *(mandatory)*

### User Story 1 - 4-Stage Ingredient Recognition & OCR Typo Repair (Priority: P1)
**As a** consumer scanning noisy retail packaging,  
**I want** the evaluation engine to repair common OCR confusions, decode parenthesized INS/E-numbers, and trace derivatives via FoodOn,  
**So that** hidden allergens like *Casein*, *Whey*, or *INS 322(i)* are never missed.

**Acceptance Scenarios**:
1. **Scenario 1.1 (OCR Homoglyph & E-Code Repair):**
   - **Given** raw text containing OCR errors (e.g., `E62l`, `IN5 322(I)`, `rnilk`, `s0y`),
   - **When** `repairOcrEcodes`, `repairOcrWordHomoglyphs`, and `extractBareAdditiveCodes` execute,
   - **Then** tokens normalize to `E621`, `INS322(i)`, `milk`, `soy`, and parenthesized INS codes after functional classes are extracted while weights/percentages are ignored.
2. **Scenario 1.2 (4-Stage FoodOn Recognition):**
   - **Given** up to 60 split ingredient tokens (`splitRawIngredients`),
   - **When** `recognizeIngredient` queries `FOODON_DB`,
   - **Then** it executes: (1) `ecode_bridge` lookup, (2) `lexical_bridge` exact/singular match, (3) 1–4 word n-gram decomposition with stopword & plant-milk guards, and (4) indexed ASCII Levenshtein fuzzy fallback ($\ge 82\%$ threshold).

---

### User Story 2 - Personalized Tri-Tier Hazard Evaluation & Settings (`UC09`) (Priority: P1)
**As a** user or Guest with configured allergens and chronic conditions,  
**I want** unambiguous **RED / YELLOW / GREEN** verdicts respecting my `scan_derivatives` and `warn_traces` preferences,  
**So that** I know immediately whether a product is dangerous, cautionary, or safe.

**Acceptance Scenarios**:
1. **Scenario 2.1 (Authenticated vs. Stateless Guest Evaluation):**
   - **Given** extracted ingredients,
   - **When** an authenticated user scans (`POST /api/v1/scans`), `D1FoodOnEngine.evaluatePackagingLabel` evaluates against their D1 profile and persists to `scan_history`; when a Guest scans (`POST /api/v1/foodon/evaluate`), evaluation runs statelessly with zero cloud writes.
2. **Scenario 2.2 (Derivatives, Traces & Automatic Re-Evaluation):**
   - **Given** `scan_derivatives` and `warn_traces` toggles (`user_settings`),
   - **When** `evaluatePackagingLabel` evaluates ingredients, `isDirectAllergenMatch` and `isTraceStatement` control whether indirect FoodOn derivatives and *"May contain traces"* clauses trigger alerts. Saving updated allergens (`POST /api/v1/profile/allergens`) automatically re-evaluates up to **25** recent `scan_history` records.

---

### User Story 3 - Interactive FoodOn Graph Explorer & Lookup APIs (Priority: P2)
**As a** user, researcher, or examiner,  
**I want to** search FoodOn concepts, look up everyday trigger foods, and visualize ontology ancestor/LCA paths,  
**So that** allergen derivations are transparent and explainable.

**Acceptance Scenarios**:
1. **Scenario 3.1 (Graph & Search Endpoints):**
   - **Given** `GET /foodon-graph` (served from `APP_DB.static_pages`) and `/api/v1/foodon/*` (`graph`, `graph/expand`, `graph/path`, `allergy-lookup`, `additives`, `category`, `search`),
   - **When** a client queries a concept or two concepts for LCA path finding,
   - **Then** `D1FoodOnEngine` returns ancestors, siblings, paginated children, or the Lowest Common Ancestor path in JSON.

---

## 3. Non-Functional Constraints
* **False-Positive Guard**: Levenshtein threshold $\ge 0.82$ (with 3-char/2-char ASCII range queries and Vietnamese diacritic guard) prevents unrelated matches (e.g., `chat dieu vi` $\neq$ `european hake`).
* **WCAG 2.1 AA Dual-Coding**: `NutriVietRiskPill` pairs RED/YELLOW/GREEN colors with distinct icons and labels.
