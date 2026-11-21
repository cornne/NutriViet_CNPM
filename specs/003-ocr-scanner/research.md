# Research & Spikes: FG3 - Packaging OCR Scanner

**Feature**: `003-fg3-ocr-scanner`  
**Lead Researcher**: Le Tat Nam (Architecture) & Ngo Tien Binh (AI / Ontology)  
**Date**: 16/11/2026 → 21/11/2026  

---

## 1. On-Device (Google ML Kit) vs Cloud Vision OCR Architecture

* **Context:** Shoppers in Vietnamese grocery stores and wet markets often experience weak or congested 4G/5G mobile signals inside aisles. Sending high-resolution $4000\times3000$ camera images to a cloud OCR API causes unacceptable latency ($3\text{--}8\text{ seconds}$) and high network failure rates.
* **Architecture Decision (Hybrid Edge-Cloud):**
  - **Edge (On-Device via Google ML Kit):** Runs real-time text recognition on Android hardware utilizing Google ML Kit Vision Text Recognizer. Executes frame bounding box analysis at 30+ fps locally with zero network latency.
  - **Cloud/Backend API:** Only the compact, extracted text string ($< 2\text{ KB}$) is transmitted over HTTP to the backend for diacritic normalization, E-number taxonomy extraction, and FoodOn ontology evaluation.
  - **Outcome:** Total response latency reduced from $4.5\text{s}$ down to under $350\text{ ms}$, saving cellular data and ensuring resilient operation.

---

## 2. Vietnamese Diacritics Normalization & Unicode Decomposition

* **Problem Statement:** Food packaging typography in Vietnam employs varied fonts and printing presses. Curved cellophane packaging often causes OCR engines to return inconsistent Unicode representations (e.g., NFD composed vs NFC precomposed characters, misplaced tone marks, or broken diacritics).
* **Engineering Solution:**
  - Standardize all inbound strings to Unicode Normalization Form C (`unicodedata.normalize('NFC', text)`).
  - Implement regex substitution patterns for tone mark variations (`òa` vs `oà`, `hóa` vs `hoá`).
  - Repair common optical character confusion in Vietnamese ingredient lists:
    - Broken hyphenated words across label line breaks (`bột-\nmì` ➔ `bột mì`).
    - Stray pipes or semicolons mistaken for diacritics.

---

## 3. Food Additive Taxonomy (E-number & INS Mapping)

* **Context:** In Vietnam, Decree No. 15/2018/ND-CP and Circular 24/2019/TT-BYT mandate international numbering system (INS) markings on food labels. Packaging typically prints either `E322`, `E322i`, `INS 471`, `Chất nhũ hóa (322i)`, or `mã số quốc tế: 621`.
* **Standardization Matrix:**
  - Regex detects patterns: `E\d{3,4}[a-z]?`, `INS\s*\d{3,4}[a-z]?`, `\b(?:chất [a-z\s]+)\((\d{3,4}[a-z]?)\)`.
  - Normalizer maps `INS X` to canonical key `EX` (e.g. `INS 471` ➔ `E471`).
  - Enriched against internal dictionary of approved additives (preserving safety, functional class, and known health sensitivities).

---

## 4. History Storage Strategy: Relational Fields vs Result JSON Blob

* **Relational Fields:** Primary attributes (`id`, `user_id`, `label_title`, `verdict`, `risk_level`, `additive_count`, `warning_count`, `created_at`) are stored in strongly typed SQLite columns to enable fast indexed sorting, pagination, and count aggregations.
* **Structured JSON Payload:** The detailed FoodOn ontology response (ingredient trigger matches, lineage paths, and latency breakdown) is stored in `result_json`.
* **Result:** Blends optimal SQLite SQL query speeds for dashboard statistics with complete data fidelity for detailed report views.
