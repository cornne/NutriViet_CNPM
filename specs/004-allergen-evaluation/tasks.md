# Tasks: FG4 - FoodOn Allergen & Chronic Hazard Evaluation

**Feature**: `004-fg4-allergen-evaluation`  
**Prerequisites**: [plan.md](plan.md) (approved), [spec.md](spec.md) (approved)  
**Deliverable**: PA4-2026 Section E Task Breakdown

---

### Phase 1: Cloudflare D1 Ontology Database & Core Engine (`UC09`)
- [x] **TASK-FG4-01** `[Database]` Provision `nutriviet-foodon` D1 (`FOODON_DB`) with 33,688 `foodon_concepts`, 53,242 `lexical_bridge` terms, 742 `ecode_bridge` rows, and 8 B-tree indexes.
- [x] **TASK-FG4-02** `[Backend]` Implement OCR homoglyph & E-code repair (`repairOcrEcodes`, `repairOcrWordHomoglyphs`, `extractBareAdditiveCodes`, `splitRawIngredients`) in `src/cloudflare-worker/src/foodon.ts`.
- [x] **TASK-FG4-03** `[Backend]` Implement 4-stage `recognizeIngredient` (E-code -> lexical -> 1–4 word n-gram -> Levenshtein fuzzy `>= 0.82`) and `evaluatePackagingLabel` (`scan_derivatives`, `warn_traces`, `RED`/`YELLOW`/`GREEN`).

### Phase 2: Endpoints, Profile Re-Evaluation & Graph Explorer
- [x] **TASK-FG4-04** `[Backend]` Expose `/api/v1/foodon/*` routes and `/foodon-graph` (`static/foodon_graph.html` served from `APP_DB.static_pages`) in `src/cloudflare-worker/src/index.ts`.
- [x] **TASK-FG4-05** `[Backend]` Trigger automatic re-evaluation of up to 25 recent `scan_history` records when user allergens update (`auth_profile.ts`).
- [x] **TASK-FG4-06** `[Mobile]` Integrate `ProfileService` (`evaluateLabelStateless`, `searchAllergyFoods`, 5-min `getCategoryConcepts` cache, `Isolate.run` JSON parsing) with `PackagingScannerScreen` and `AllergyProfileScreen`.

### Phase 3: Automated Verification
- [x] **TASK-FG4-07** `[Test]` *(Truong Gia Linh)* Verify ingredient splitting, bare E-code extraction, Levenshtein false-positive prevention, `scan_derivatives`/`warn_traces` logic, and OCR homoglyph repair in `src/cloudflare-worker/test/worker.test.ts` (`vitest run`).
