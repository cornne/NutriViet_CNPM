# Implementation Plan: FG4 - FoodOn Allergen & Chronic Hazard Evaluation

**Branch**: `004-fg4-allergen-evaluation` | **Date**: 16/11/2026 (Updated 25/11/2026) | **Spec**: [spec.md](spec.md)  
**Deliverable**: PA4-2026 Section E (Full-Stack Implementation)  
**AI & Ontology Lead**: Ngo Tien Binh | **Backend Lead**: Le Tat Nam | **Mobile Lead**: Luong Hoang Nam | **QA & Verification Lead**: Truong Gia Linh

---

## 1. Technical Architecture & Data Flow

```text
+-----------------------------------------------------------------------------+
|                        FLUTTER MOBILE & WEB CLIENTS                         |
|  - PackagingScannerScreen -> ProfileService.createScan / evaluateStateless  |
|  - AllergyProfileScreen -> ProfileService.searchAllergyFoods / getCategory  |
|  - FoodOn Graph Explorer (/foodon-graph) -> /api/v1/foodon/*                |
+--------------------------------------|--------------------------------------+
                                       | HTTPS / JSON
                                       v
+-----------------------------------------------------------------------------+
|                    CLOUDFLARE WORKERS API (src/cloudflare-worker/)          |
|                                                                             |
|  index.ts -> /foodon-graph, /api/v1/foodon/* (evaluate, graph, search...)   |
|  auth_profile.ts -> POST /api/v1/scans & allergen-change re-evaluation      |
|                                      |                                      |
|                                      v                                      |
|  D1FoodOnEngine (src/foodon.ts)                                             |
|   1. repairOcrEcodes & repairOcrWordHomoglyphs                              |
|   2. splitRawIngredients & extractBareAdditiveCodes                         |
|   3. 4-Stage Recognition: ecode -> lexical -> 1-4 n-gram -> fuzzy (>= 0.82) |
|   4. evaluatePackagingLabel (scan_derivatives, warn_traces, chronics)       |
+--------------------------------------|--------------------------------------+
                                       | Cloudflare D1 Binding (FOODON_DB)
                                       v
+-----------------------------------------------------------------------------+
|                  CLOUDFLARE D1: nutriviet-foodon (APAC)                     |
|  - foodon_concepts (33,688 rows)   - lexical_bridge (53,242 rows)           |
|  - ecode_bridge (742 rows)         - foodon_allergen_map & chronic_map      |
+-----------------------------------------------------------------------------+
```

---

## 2. Physical Code Layout (Implemented)

```text
src/
├── cloudflare-worker/
│   ├── src/
│   │   ├── foodon.ts          # D1FoodOnEngine, 4-stage matching, graph & evaluation
│   │   ├── index.ts           # /foodon-graph & /api/v1/foodon/* routes
│   │   └── auth_profile.ts    # /api/v1/scans & profile allergen re-evaluation
│   ├── static/
│   │   └── foodon_graph.html  # Bilingual FoodOn Graph Explorer UI
│   └── test/worker.test.ts    # Vitest suites for splitting, E-codes, fuzzy & settings
└── mobile/
    ├── lib/
    │   ├── screens/
    │   │   ├── packaging_scanner_screen.dart
    │   │   └── allergy_profile_screen.dart
    │   └── services/
    │       ├── profile_service.dart      # FoodOn REST client + 5-min category cache
    │       └── local_guest_store.dart    # Stateless Guest evaluation wrapper
    └── test/widget_test.dart
```
