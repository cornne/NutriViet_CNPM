# Requirements Checklist: FG4 - FoodOn Allergen & Chronic Hazard Evaluation

**Feature**: `004-fg4-allergen-evaluation`  
**Status**: 8/8 Passed  

- [x] **CHK-FG4-01** `FOODON_DB` (`nutriviet-foodon`) indexes 33,688 FoodOn concepts, 53,242 lexical terms, and 742 E-codes.
- [x] **CHK-FG4-02** `repairOcrEcodes` and `repairOcrWordHomoglyphs` correct common OCR character confusions.
- [x] **CHK-FG4-03** `extractBareAdditiveCodes` extracts parenthesized INS/E-numbers while ignoring weights/percentages.
- [x] **CHK-FG4-04** Levenshtein fuzzy matching enforces `>= 0.82` threshold with Vietnamese diacritic guard.
- [x] **CHK-FG4-05** `evaluatePackagingLabel` respects `scan_derivatives` and `warn_traces` settings (`RED`/`YELLOW`/`GREEN`).
- [x] **CHK-FG4-06** `POST /api/v1/foodon/evaluate` runs statelessly for Guest Mode with zero cloud writes.
- [x] **CHK-FG4-07** `/foodon-graph` and `/api/v1/foodon/graph*` expose interactive concept exploration and LCA path finding.
- [x] **CHK-FG4-08** `vitest run` in `src/cloudflare-worker/test/worker.test.ts` passes all FoodOn & evaluation test cases.
