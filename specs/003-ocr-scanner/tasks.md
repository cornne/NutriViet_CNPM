# Tasks: FG3 - Packaging OCR Scanner

**Feature**: `003-fg3-ocr-scanner`  
**Prerequisites**: [plan.md](plan.md) (approved), [spec.md](spec.md) (approved)  
**Deliverable**: PA3-2026 Section E Task Breakdown  
**Lead Engineer (Performer)**: Le Tat Nam | **Reviewer**: Ngo Tien Binh & Nguyen Hoang Phuc Thinh  
**Timeline**: 16/11/2026 → 25/11/2026 (TASK-04 & TASK-05)  

---

## Task Organization by User Story & Phase

```
Phase 1: Setup & Database Infrastructure (scan_history schema in database.py)
Phase 2: Backend OCR Normalization & Additive Extraction Engine (ocr_normalizer.py)
Phase 3: Backend RESTful Scan & Normalization Endpoints (server.py & wsgi_app.py)
Phase 4: Mobile Client Alignment & Unified Contract Integration
Phase 5: Real-World Food Packaging Label Testing & Verification (test_ocr_scan.py)
```

---

### Phase 1: Setup & Database Infrastructure (TASK-04 / TASK-05)

- [x] **TASK-FG3-01** `[Setup]` Create `scan_history` table schema in `src/backend/database.py` with foreign key cascade to `users(id)`.
- [x] **TASK-FG3-02** `[Setup]` Add database index `idx_scan_history_user(user_id, id DESC)` for fast chronological query execution.
- [x] **TASK-FG3-03** `[Database]` Implement DAO functions: `save_scan_session()`, `get_user_scan_history()`, `get_scan_by_id()`, `delete_scan_session()`, and `get_scan_statistics()`.

---

### Phase 2: Backend OCR Normalization & Additive Engine (TASK-05)

- [x] **TASK-FG3-04** `[Backend]` Create `src/backend/ocr_normalizer.py` with regex noise filtering for packaging banners, dates, net weight, and manufacture markers.
- [x] **TASK-FG3-05** `[Backend]` Implement Unicode NFC form and Vietnamese diacritic tone mark standardization in `ocr_normalizer.py`.
- [x] **TASK-FG3-06** `[Backend]` Implement intelligent ingredient tokenization respecting parenthetical percentages (e.g. `Đậu phộng (12%)`).
- [x] **TASK-FG3-07** `[Backend]` Implement E-number / INS detection and taxonomy lookup mapping codes (`E322`, `E621`, `E102`, `E471`, etc.) to functional categories.

---

### Phase 3: RESTful API Implementation (TASK-04 / TASK-05)

- [x] **TASK-FG3-08** `[Backend]` Expose `POST /api/v1/ocr/normalize` endpoint for standalone OCR cleaning in `src/backend/server.py`.
- [x] **TASK-FG3-09** `[Backend]` Expose `POST /api/v1/scans` endpoint integrating OCR normalization, allergy evaluation, and database persistence.
- [x] **TASK-FG3-10** `[Backend]` Expose `GET /api/v1/scans` and `DELETE /api/v1/scans` endpoints for scan history retrieval and deletion.
- [x] **TASK-FG3-11** `[Backend]` Synchronize endpoints in `src/backend/wsgi_app.py` for PythonAnywhere cloud compatibility.

---

### Phase 4: Mobile Integration & Specification Alignment (TASK-04)

- [x] **TASK-FG3-12** `[Mobile]` Verify `ProfileService.createScan()` and `ProfileService.getScans()` payloads conform to unified contract.
- [x] **TASK-FG3-13** `[Mobile]` Connect `_PackagingScannerScreen` reticle and text preview modal to `POST /api/v1/scans`.
- [x] **TASK-FG3-14** `[Mobile]` Align History tab cards with chronological scan list and dynamic search filtering ($< 50\text{ ms}$).

---

### Phase 5: Verification & Real-World Testing (TASK-05)

- [x] **TASK-FG3-15** `[Testing]` Write `src/backend/test_ocr_scan.py` with real-world Vietnamese food labels (Hảo Hảo, Oreo, Chocopie, Vinamilk).
- [x] **TASK-FG3-16** `[Testing]` Verify 100% test pass rate for OCR normalization, E-number parsing, database transactions, and HTTP API endpoints.
