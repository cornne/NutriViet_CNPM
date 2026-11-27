# Research & Architectural Spikes: FG4 - FoodOn Ontology Engine

**Feature**: `004-fg4-allergen-evaluation`  
**Lead Researcher**: Ngo Tien Binh (AI & Ontology Lead)  
**Date**: 16/11/2026 (Updated 25/11/2026)

---

## 1. Precomputed D1 FoodOn Relational Graph vs. Runtime OWL Parsing
* **Context:** Parsing the full FoodOn OWL/RDF XML graph at runtime exceeds Cloudflare Workers CPU and memory budgets.
* **Decision:** Flatten 33,688 FoodOn concepts, 53,242 lexical terms, 742 E-codes, and precomputed allergen/chronic mappings into a dedicated read-optimized Cloudflare D1 database (`nutriviet-foodon`) with 8 B-tree indexes and request-scoped `conceptCache` / `synCache` in `D1FoodOnEngine` (`src/cloudflare-worker/src/foodon.ts`).

## 2. False-Positive Prevention in Levenshtein Fuzzy Matching
* **Context:** Early fuzzy thresholds (`0.75`) caused false matches between unrelated Vietnamese additive terms and English seafood names (e.g., `chat dieu vi` matching `european hake`).
* **Decision:** Raise fuzzy similarity threshold to **`>= 0.82`**, skip ASCII fuzzy fallback when `hasVietnameseDiacritics` is true, and constrain D1 candidate scans using 3-char and 2-char `term_ascii` prefix range queries.

## 3. Bare Parenthesized INS Code Extraction
* **Context:** Vietnamese labels frequently write `Chất ổn định (471, 460i)` without the `E` or `INS` prefix.
* **Decision:** `extractBareAdditiveCodes` detects functional additive class keywords before parenthesized number lists (100–1599) while ignoring weights/percentages (e.g., `28%`, `50g`).
