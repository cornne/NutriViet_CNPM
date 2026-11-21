# Feature Specification: FG3 - Packaging OCR Scanner

**Feature Branch**: `003-fg3-ocr-scanner`  
**Date**: 16/11/2026 → 21/11/2026  
**Status**: Approved & Active  
**Target Delivery**: PA3-2026 (Section E Deliverable)  
**Lead Engineer (Performer)**: Le Tat Nam  
**Reviewer**: Ngo Tien Binh (PM & AI Lead)  

---

## 1. Feature Overview & Business Value

The **Packaging OCR Scanner** functional group (`FG3`) is the optical perception and text intelligence gateway of NutriViet. It enables consumers in supermarket aisles and grocery stores to capture ingredient lists from physical food packaging using their smartphone cameras, automatically cleans and parses complex Vietnamese food label text, extracts international food additive numbers (E-numbers / INS), and maintains an indexed scan history.

This specification maps directly to the system requirements defined in the [Vision Document](../../docs/requirements/vision.md) and [Use-Case Model](../../docs/requirements/use-cases.md):
- **`UC06: Scan Food Packaging Label via Camera`** (Critical Priority)
- **`UC07: Preprocess & Crop Label Image`** (High Priority)
- **`UC08: View & Filter Scan History`** (Medium Priority)

### 1.1 Traceability Matrix

| Use Case ID | Use Case Name | Primary Actor | Priority | Business Objective |
|:---|:---|:---|:---:|:---|
| **UC06** | Scan Food Packaging Label via Camera | Consumer | Critical | Real-time camera viewfinder, targeting corners, flashlight toggle, and capture to eliminate visual strain. |
| **UC07** | Preprocess & Crop Label Image | Consumer, ML Kit | High | Boundary detection, noise elimination, Vietnamese diacritics normalization, and additive/token extraction. |
| **UC08** | View & Filter Scan History | Consumer | Medium | Persistent chronological log of scanned items, instant search by product name, and filtering by safety alert outcome. |

---

## 2. Architecture & Processing Pipeline

```
+---------------------------------------------------------------------------------------+
|                                FLUTTER MOBILE CLIENT                                  |
|                                                                                       |
|   +-----------------------+     +-----------------------+     +-------------------+   |
|   |   UC06: Camera Live   | --> |  UC07: Image Crop &   | --> | UC08: Scan History|   |
|   |  Viewfinder + ML Kit  |     | Boundary Adjustment   |     | Search & Filter   |   |
|   +-----------+-----------+     +-----------+-----------+     +---------^---------+   |
|               |                             |                           |             |
|               +-----------------------------+                           |             |
|                                             | Raw OCR Text String       | Scans List  |
+---------------------------------------------|---------------------------|-------------+
                                              | HTTP POST /api/v1/scans   | HTTP GET    |
                                              v                           |             |
+---------------------------------------------------------------------------------------+
|                                PYTHON BACKEND SERVER                                  |
|                                                                                       |
|   +-------------------------------------------------------------------------------+   |
|   |                       OCR Text Normalization Engine                           |   |
|   |  1. Regex Noise Filtering (Remove packaging headers, weights, dates, barcodes)|   |
|   |  2. Vietnamese Diacritics Normalization (Unicode NFC form & accent repair)    |   |
|   |  3. Additive Tokenizer (E-number / INS detection & standardized mapping)      |   |
|   |  4. Semantic Ingredient Segmentation (Splits commas, semicolons, brackets)    |   |
|   +---------------------------------------+---------------------------------------+   |
|                                           | Normalized Tokens                         |
|                                           v                                           |
|   +-------------------------------------------------------------------------------+   |
|   |                  FoodOn & Allergy Cross-Reference Engine                      |   |
|   |  Evaluates tokens against user profile (RED: Allergen, YELLOW, GREEN: Safe)   |   |
|   +---------------------------------------+---------------------------------------+   |
+-------------------------------------------|-------------------------------------------+
                                            | SQL INSERT & SELECT
                                            v
+---------------------------------------------------------------------------------------+
|                         DATABASE LAYER (SQLite: nutriviet.db)                         |
|                                                                                       |
|   TABLE scan_history (                                                                |
|       id INTEGER PRIMARY KEY AUTOINCREMENT,                                           |
|       user_id INTEGER NOT NULL REFERENCES users(id),                                  |
|       member_name TEXT NOT NULL,                                                      |
|       label_title TEXT NOT NULL,                                                      |
|       raw_text TEXT NOT NULL,                                                         |
|       normalized_text TEXT NOT NULL,                                                  |
|       tokens_json TEXT NOT NULL,                                                      |
|       additives_json TEXT NOT NULL,                                                   |
|       verdict TEXT NOT NULL,                                                          |
|       risk_level TEXT NOT NULL,                                                       |
|       risk_label_vi TEXT NOT NULL,                                                    |
|       additive_count INTEGER NOT NULL,                                                |
|       warning_count INTEGER NOT NULL,                                                 |
|       result_json TEXT NOT NULL,                                                      |
|       created_at TEXT NOT NULL                                                        |
|   );                                                                                  |
+---------------------------------------------------------------------------------------+
```

---

## 3. User Stories & Gherkin Scenarios

### User Story 1 - Live Packaging Label Scan via Camera (UC06, Priority: P1)
**As a** consumer shopping for packaged foods,  
**I want to** point my smartphone camera at the packaging ingredient panel with real-time guides and flashlight assistance,  
**So that** the application captures high-resolution label imagery without requiring manual typing.

* **Why this priority**: Core interaction point of FG3; primary mechanism for feeding packaging data into the system.
* **Independent Test**: Open camera scanner viewfinder, position food label within targeting corners, tap capture button, and verify frame is frozen with haptic feedback.

**Acceptance Scenarios**:
1. **Scenario 1.1 (Successful Camera Capture & Viewfinder Guides):**
   - **Given** an authenticated user grants camera permissions (`android.permission.CAMERA`),
   - **When** the user taps the central floating **QUÉT** button on the bottom navigation bar,
   - **Then** the system launches the camera viewfinder at $\ge 30\text{ fps}$,
   - **And** displays high-contrast targeting corners with an animated laser scanning reticle,
   - **When** the user positions the ingredient panel in the reticle and taps the **Shutter Button**,
   - **Then** the system captures an uncompressed image frame, triggers haptic feedback, and proceeds to preprocessing (`UC07`).

2. **Scenario 1.2 (Low-Light Environment Flashlight Toggle):**
   - **Given** the camera viewfinder is active in a low-light aisle ($< 100\text{ lux}$),
   - **When** the user taps the **Torch / Đèn Flash** icon,
   - **Then** the device camera LED illuminates the packaging surface immediately,
   - **And** the icon toggles to an active glowing amber state.

3. **Scenario 1.3 (Camera Permission Denied Exception Flow):**
   - **Given** camera permission is rejected by the user,
   - **When** the user attempts to open the scanner screen,
   - **Then** the app presents an explanatory modal: *"NutriViet cần quyền truy cập camera để quét nhãn thành phần thực phẩm."*,
   - **And** provides a button linking directly to App System Settings alongside a manual text input option.

---

### User Story 2 - Preprocess & Normalize OCR Ingredient Text (UC07, Priority: P1)
**As a** consumer reviewing captured packaging text,  
**I want** the system to clean optical noise, standardize Vietnamese diacritics, and extract food additive numbers (E-numbers / INS),  
**So that** the extracted ingredients can be accurately evaluated against my personal allergy profile (`FG4`).

* **Why this priority**: Raw OCR text from mobile cameras contains cellophane glare, broken diacritics, hyphenated line wraps, and non-ingredient noise (Net weight, expiry dates). Normalization is critical for zero false negatives.
* **Independent Test**: Send noisy OCR string with Vietnamese accents and E-numbers to `POST /api/v1/ocr/normalize` and verify cleaned tokens and structured additive metadata.

**Acceptance Scenarios**:
1. **Scenario 2.1 (Noise Removal & Vietnamese Diacritics Standardization):**
   - **Given** raw OCR text containing prefix noise: *"Thành phần: Bột mì (65%), Dầu cọ, Đậu phộng (5%), Đường, Muối i-ốt. HSD: 12/2027. KLT: 150g"*,
   - **When** the normalization pipeline processes the text,
   - **Then** packaging prefixes (`Thành phần:`) and trailing metadata (`HSD:...`, `KLT:...`) are removed,
   - **And** Vietnamese characters are normalized to standard Unicode NFC form,
   - **And** the resulting tokens list contains: `["Bột mì (65%)", "Dầu cọ", "Đậu phộng (5%)", "Đường", "Muối i-ốt"]`.

2. **Scenario 2.2 (Additive Code E-number & INS Recognition):**
   - **Given** raw text containing additive codes: *"Chất nhũ hóa (E322i, INS 471), Chất điều vị (E621), Phẩm màu (E102)"*,
   - **When** the OCR normalizer parses the string,
   - **Then** `E322i`, `INS 471` (standardized to `E471`), `E621`, and `E102` are extracted into a structured `extracted_e_numbers` array,
   - **And** each additive is enriched with standard Vietnamese functional name (e.g. `E322i: Lecithin - Chất nhũ hóa`, `E621: Monosodium glutamate - Bột ngọt`).

3. **Scenario 2.3 (Manual Crop & Text Correction):**
   - **Given** the user inspects the extracted OCR text preview in the bottom sheet,
   - **When** the user notices an unread word or wishes to add an ingredient,
   - **Then** the user can tap the inline text editor, edit the ingredient tokens, and re-trigger instant evaluation.

---

### User Story 3 - View, Search & Filter Scan History (UC08, Priority: P2)
**As a** consumer who frequently shops for groceries,  
**I want to** view my chronological history of scanned products, search by name, and filter by safety alert outcome,  
**So that** I can recall safe food choices without having to rescan the same packaging repeatedly.

* **Why this priority**: Enhances consumer productivity and provides an audit trail of safe vs hazardous food items.
* **Independent Test**: Query `GET /api/v1/scans?user_id=1`, verify returned cards, filter by search keyword, and delete a scan via `DELETE /api/v1/scans`.

**Acceptance Scenarios**:
1. **Scenario 3.1 (Chronological Scan History Retrieval):**
   - **Given** an authenticated user with previous scans opens the **Lịch sử** tab,
   - **When** the screen loads,
   - **Then** the client requests `GET /api/v1/scans?user_id={id}`,
   - **And** renders cards in descending order of creation, each displaying: Product Title, Timestamp, Verdict Badge (RED / YELLOW / GREEN), Flagged Allergens, and Additive Count.

2. **Scenario 3.2 (Search & Outcome Filtering):**
   - **Given** a list of 10 historical scans with mixed verdicts,
   - **When** the user types *"Bánh"* in the search field,
   - **Then** the list updates within $< 50\text{ ms}$ showing only matching titles,
   - **When** the user taps the filter chip *"Cảnh báo Đỏ (Nguy cơ)"*,
   - **Then** only scans containing active allergen triggers (`verdict == "RED"`) remain visible.

3. **Scenario 3.3 (Delete Scan Record):**
   - **Given** an existing scan record in the history list,
   - **When** the user swipes left or taps the trash icon and confirms deletion,
   - **Then** the client sends `DELETE /api/v1/scans?scan_id={id}&user_id={user_id}`,
   - **And** the record is deleted from SQLite `scan_history`,
   - **And** the UI removes the card and recalculates scan counters (`total_scans`, `warning_scans`).

---

## 4. Unified JSON Interface Contract

To guarantee seamless interoperability between the Flutter mobile application and Python backend, both tiers adhere to the following unified JSON contracts:

### 4.1 OCR Normalization Endpoint (`POST /api/v1/ocr/normalize`)
* **Request Payload**:
  ```json
  {
    "raw_text": "Thành phần: Bột mì, Đường, Đậu phộng (12%), Dầu thực vật, Chất nhũ hóa (E322i, INS 471), Muối, Hương vani.",
    "lang": "vi"
  }
  ```
* **Response Payload (`200 OK`)**:
  ```json
  {
    "success": true,
    "raw_text": "Thành phần: Bột mì, Đường, Đậu phộng (12%), Dầu thực vật, Chất nhũ hóa (E322i, INS 471), Muối, Hương vani.",
    "cleaned_text": "Bột mì, Đường, Đậu phộng (12%), Dầu thực vật, Chất nhũ hóa (E322i, INS 471), Muối, Hương vani.",
    "normalized_text": "Bột mì, Đường, Đậu phộng (12%), Dầu thực vật, Chất nhũ hóa (E322i, INS 471), Muối, Hương vani.",
    "tokens": [
      "Bột mì",
      "Đường",
      "Đậu phộng (12%)",
      "Dầu thực vật",
      "Chất nhũ hóa",
      "E322i",
      "INS 471",
      "Muối",
      "Hương vani"
    ],
    "extracted_e_numbers": [
      {
        "code": "E322i",
        "standard_code": "E322",
        "name": "Lecithin",
        "category": "Chất nhũ hóa (Emulsifier)",
        "risk": "safe"
      },
      {
        "code": "INS 471",
        "standard_code": "E471",
        "name": "Mono- and diglycerides of fatty acids",
        "category": "Chất nhũ hóa (Emulsifier)",
        "risk": "safe"
      }
    ],
    "token_count": 9,
    "additive_count": 2
  }
  ```

---

### 4.2 Create & Analyze Scan Session (`POST /api/v1/scans`)
* **Request Payload**:
  ```json
  {
    "user_id": 1,
    "raw_text": "Bột mì, đường, đậu phộng, dầu cọ, chất điều vị E621",
    "label_title": "Bánh quy bơ đậu phộng",
    "member_name": "Lê Tất Nam",
    "lang": "vi"
  }
  ```
* **Response Payload (`200 OK`)**:
  ```json
  {
    "success": true,
    "latest_scan": {
      "id": 101,
      "user_id": 1,
      "member_name": "Lê Tất Nam",
      "label_title": "Bánh quy bơ đậu phộng",
      "raw_text": "Bột mì, đường, đậu phộng, dầu cọ, chất điều vị E621",
      "normalized_text": "Bột mì, đường, đậu phộng, dầu cọ, chất điều vị E621",
      "verdict": "RED",
      "risk_level": "high",
      "risk_label_vi": "Nguy cơ cao",
      "additive_count": 1,
      "warning_count": 1,
      "evaluation": {
        "verdict": "RED",
        "wcag_glyph": "[!X]",
        "title": "NGUY HIỂM: PHÁT HIỆN DỊ ỨNG - KHÔNG NÊN SỬ DỤNG",
        "red_triggers": [
          {
            "token": "đậu phộng",
            "allergen_code": "peanuts",
            "allergen_name": "Đậu phộng (Lạc)",
            "severity": "high"
          }
        ],
        "yellow_triggers": [],
        "detected_additives": [
          {
            "code": "E621",
            "name": "Bột ngọt (Monosodium glutamate)",
            "category": "Chất điều vị"
          }
        ]
      },
      "created_at": "2026-11-21T14:15:00"
    },
    "scans": [ ... ],
    "total_scans": 1,
    "warning_scans": 1,
    "monthly_scans": 1,
    "monthly_warnings": 1
  }
  ```

---

### 4.3 Get User Scan History (`GET /api/v1/scans?user_id=1`)
* **Response Payload (`200 OK`)**:
  ```json
  {
    "success": true,
    "user_id": 1,
    "scans": [
      {
        "id": 101,
        "member_name": "Lê Tất Nam",
        "label_title": "Bánh quy bơ đậu phộng",
        "raw_text": "Bột mì, đường, đậu phộng, dầu cọ, chất điều vị E621",
        "verdict": "RED",
        "risk_level": "high",
        "risk_label_vi": "Nguy cơ cao",
        "additive_count": 1,
        "warning_count": 1,
        "evaluation": { ... },
        "created_at": "2026-11-21T14:15:00"
      }
    ],
    "total_scans": 1,
    "warning_scans": 1,
    "monthly_scans": 1,
    "monthly_warnings": 1
  }
  ```

---

## 5. Non-Functional Constraints

* **Latency**: Shutter click to structured normalized token list must complete in $\le 1.5\text{ seconds}$ (NFR-PERF-01).
* **Viewfinder Smoothness**: Camera preview framerate must sustain $\ge 30\text{ fps}$ on standard mid-range Android hardware (NFR-PERF-04).
* **Diacritics Fidelity**: Vietnamese diacritic tokenization accuracy must exceed $\ge 95\%$ on standard retail packaging labels.
* **Offline Resilience**: Captured label images and raw text can be cached locally via SQLite when network connectivity is disrupted.
* **Accessibility & Safety**: High-contrast targeting corners (amber/emerald) with haptic feedback pulses on capture and color-coded status pills compliant with WCAG 2.1 AA.
