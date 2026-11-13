# Research & Spikes: FG2 - Personal Allergy Profile Management

**Feature**: `002-fg2-allergy-profile`  
**Lead Researcher**: Le Tat Nam (Architecture) & Luong Hoang Nam (UI/UX)  
**Date**: 08/11/2026  

---

## 1. Relational Table vs. JSON Blob Storage Decision

* **Context:** A user may configure between 0 and 20 allergens.
* **Option A: Store JSON string in `users.allergens_json` column (Rejected):**
  * *Disadvantages:* Cannot easily perform cross-user aggregate queries (e.g., *"How many users in District 1 are allergic to peanuts?"*), harder to enforce referential integrity.
* **Option B: Normalized relational table `user_allergens` (Selected):**
  * *Advantages:* Third Normal Form (3NF), indexed lookups by `user_id`, atomic delete/insert within a single SQLite transaction, seamless migration to PostgreSQL in Sprint 4.

---

## 2. Multi-tier Severity Threshold Engineering

* **Medical Context:** True IgE-mediated food allergies carry fatal anaphylaxis risk (requiring Epinephrine/EpiPen), whereas food intolerances (such as lactose intolerance) cause digestive discomfort without airway collapse.
* **Architecture Solution:** We model three distinct sensitivity tiers:
  * **`high` (Nghiêm trọng):** Triggers `RED ALERT` + siren glyph `[!X]` in camera scanner `FG4`.
  * **`moderate` (Trung bình):** Triggers `YELLOW CAUTION` + warning glyph `[!?]`.
  * **`mild` (Nhẹ):** Triggers informative blue note.

---

## 3. Atomic Profile Synchronization Strategy

* When saving updated profiles, the client sends the entire active set of allergens.
* Backend executes:
  ```python
  cursor.execute("DELETE FROM user_allergens WHERE user_id = ?", (user_id,))
  cursor.executemany("INSERT INTO user_allergens ...", records)
  conn.commit()
  ```
* This pattern guarantees idempotency and eliminates race conditions.
