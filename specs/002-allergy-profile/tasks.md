# Tasks: FG2 - Personal Allergy Profile Management

**Feature**: `002-fg2-allergy-profile`  
**Prerequisites**: [plan.md](plan.md) (approved), [spec.md](spec.md) (approved)  
**Deliverable**: PA3-2026 Section E Extended Task Breakdown  

---

## Task Organization by User Story & Phase

```
Phase 1: Setup & Data Modeling (user_allergens schema)
Phase 2: Backend API Implementation (GET & POST profile endpoints)
Phase 3: Mobile UI & State Integration (AllergyProfileScreen)
Phase 4: End-to-End Verification & Synchronized Persistence
```

---

### Phase 1: Setup & Database Infrastructure

- [x] **TASK-FG2-01** `[Setup]` Create `user_allergens` table schema in `src/backend/database.py` with foreign key to `users`.
- [x] **TASK-FG2-02** `[Setup]` Add compound unique index `idx_user_allergen(user_id, allergen_code)` for idempotent profile updates.

---

### Phase 2: Backend API Implementation

- [x] **TASK-FG2-03** `[Backend]` Implement `get_user_allergens(user_id)` DAO function returning active list.
- [x] **TASK-FG2-04** `[Backend]` Implement `save_user_allergens(user_id, allergens_list)` with atomic delete/insert transaction.
- [x] **TASK-FG2-05** `[Backend]` Expose `GET /api/v1/profile/allergens` and `POST /api/v1/profile/allergens` in `src/backend/server.py` and PythonAnywhere WSGI handler.

---

### Phase 3: Mobile Client (Flutter UI)

- [x] **TASK-FG2-06** `[Mobile]` Create `ProfileService` in `src/mobile/lib/services/profile_service.dart` with HTTP get/save methods.
- [x] **TASK-FG2-07** `[Mobile]` Build `AllergyProfileScreen` (`src/mobile/lib/screens/allergy_profile_screen.dart`) with master 8-allergen catalog, severity segmented buttons, and save confirmation.
- [x] **TASK-FG2-08** `[Mobile]` Connect `HomeScreen` feature tile button to navigate directly into `AllergyProfileScreen`.

---

### Phase 4: Verification & Live Cloud Integration

- [x] **TASK-FG2-09** `[E2E]` Test end-to-end flow: Select allergens on Flutter app ➔ Save ➔ Inspect SQLite records on PythonAnywhere.
- [x] **TASK-FG2-10** `[E2E]` Reopen screen and verify persistent pre-population of previously selected allergens.
