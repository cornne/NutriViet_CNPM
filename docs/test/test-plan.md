# Exercise 1 – Test Plan for NutriViet

**Project:** NutriViet – Personalized Food Allergy Warning & Nutrition Management Mobile Application  
**Course:** CS300 - CSC13002 - Introduction to Software Engineering  
**Group:** Group 07 (Ngo Tien Binh, Le Tat Nam, Luong Hoang Nam, Nguyen Hoang Phuc Thinh, Truong Gia Linh)  
**Platform:** Flutter Android App + Cloudflare Workers Backend + Cloudflare D1 Database (FoodOn Ontology)

---

## 1. Project Scope & Features to Be Tested
*Performed by: Truong Gia Linh | Reviewed by: Ngo Tien Binh | Edited by: Le Tat Nam*

Our Test Plan covers all **8 Functional Groups (FG1–FG8)** of NutriViet once fully implemented:
- **FG1 (Authentication & Guest Mode):** Sign up, email verification, login, password reset via 6-digit OTP, password change, and local Guest Mode without login.
- **FG2 (Personal Allergy & Health Profile):** Selecting allergens and severity levels (High/Moderate/Mild), chronic conditions (Diabetes, Gout, Hypertension), family member profiles, and derivative/trace warning settings.
- **FG3 (Packaging OCR Scanner & History):** Live camera scanning, gallery photo crop, reading Vietnamese/English ingredient labels via cloud OCR, ignoring Nutrition Facts-only images, and viewing/deleting scan history.
- **FG4 (Allergen Evaluation & Safe Alternatives):** Matching ingredients against the FoodOn database (33,688 food concepts and 742 E-codes), detecting hidden derivatives (e.g., Casein/Whey -> Milk), displaying Red / Yellow / Green alerts, and suggesting safe product alternatives.
- **FG5 (Dietary & Reaction Journal):** Logging daily meals, tracking nutrient/additive intake, and recording allergic symptom incidents.
- **FG6 (Favorites & Shopping List):** Saving safe products to Favorites and managing grocery checklists.
- **FG7 (Community Feed):** Posting scanned product reviews with photos, liking, commenting, and reporting inaccurate or inappropriate posts.
- **FG8 (Admin Moderation & Dictionary):** Hidden Admin tools to review reports, hide/delete posts, ban abusive users, and manage the additive/allergen dictionary.

---

## 2. Testing Phases, Responsibilities, Schedule & Strategies
*Performed by: Truong Gia Linh | Reviewed by: Le Tat Nam | Edited by: Nguyen Hoang Phuc Thinh*

| Testing Phase | What Will Be Tested | Responsible Member(s) | When (Schedule) | Testing Strategies & Techniques |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1: Unit Testing** | Individual core logic and UI screens across FG1–FG8: password/OTP validation (FG1); allergy profile & Guest local storage (FG2); cropping math & ingredient-section filtering (FG3); typo-tolerant allergen matching & E-code lookup (FG4); daily meal calorie/sodium totals (FG5); shopping list actions (FG6); post/report validation & role checks (FG7–FG8). | **Lead:** Truong Gia Linh (QA Lead). **Developers:** Ngo Tien Binh (FG4), Le Tat Nam (FG1, FG3, FG8), Luong Hoang Nam (Mobile UI, FG6), Nguyen Hoang Phuc Thinh (DB, FG7). | **Continuously during Sprints 3–5** (Nov 1 – Dec 22, 2026); run automatically on every Pull Request via GitHub Actions. | **White-box Automated Testing** using **Vitest** (backend) and **Flutter Test** (mobile). **Equivalence Partitioning:** Test valid vs. invalid emails, safe vs. hazardous ingredients, normal vs. admin roles. **Boundary Value Analysis:** Test password length limits, 50-item Guest history limit, 5 MB photo upload limit, 15-minute OTP expiry, and 82% fuzzy-matching threshold. |
| **Phase 2: Integration Testing** | Connections between app modules, backend APIs, and databases: Mobile Camera -> Cloud OCR -> FoodOn Evaluation -> Scan History (FG3–FG4); Hazard Alert -> Safe Alternatives & Meal Diary (FG4–FG5); Favorites -> Shopping List (FG6); User Post/Report -> Admin Moderation Queue & Dictionary updates -> Evaluation (FG7–FG8); Email verification & OTP delivery. | **Lead:** Le Tat Nam (Backend Lead) & Nguyen Hoang Phuc Thinh (Database Lead). **Reviewer:** Truong Gia Linh. | **Mid-to-end of Sprints 3, 4, and 5** (Nov 10–14, Nov 21–27, Dec 10–15, 2026) right after API and database changes are finished. | **Bottom-up & API Contract Testing:** Check API request/response formats against our Spec Kit OpenAPI contracts. Simulate OCR provider failures (timeout or rate limit) to verify automatic fallback to backup OCR providers. Test Guest-to-Cloud data sync when a Guest logs into an account. |
| **Phase 3: System, Performance & Security Testing** | The complete app running on real Android devices: **Performance:** End-to-end scan-to-alert time (<= 3.0s), image compression (<= 180 KB), smooth scrolling, and handling concurrent scans. **Compatibility & UI:** Different Android versions (Android 8–15), screen sizes, low-light/glossy packaging, and Vietnamese/English language switching. **Security & Access Control:** Blocking unverified/banned users, preventing users from seeing others' scans/diaries, and hiding/blocking Admin tools from regular users and Guests. | **Lead:** Luong Hoang Nam (Mobile Lead) & Le Tat Nam (Backend Lead). **Coordinator:** Truong Gia Linh & Nguyen Hoang Phuc Thinh. | **End of Sprint 4 & Mid Sprint 5** (Nov 25–27 and Dec 12–17, 2026), before building the release APK. | **Black-box System, Non-Functional & Negative Testing:** Test on multiple physical Android phones in supermarket-like lighting. Run negative security tests: try calling Admin APIs with a normal user token (must return 403), try logging in with wrong passwords repeatedly (must trigger rate limit 429), and confirm no API keys are stored inside the APK. |
| **Phase 4: User Acceptance Testing (UAT)** | End-to-end real-world validation of all 18 Use Cases (UC01–UC18): checking allergen detection accuracy (>= 98% on major allergens like peanuts, milk, seafood, gluten), clarity of Red/Yellow/Green warnings for color-blind users (color + icon), relevance of safe alternatives, and usability of meal logging and shopping lists. | **Lead:** Ngo Tien Binh (PM) & Truong Gia Linh (QA Lead), joined by 5–10 student beta testers. | **Final week of Sprint 5** (Dec 17–21, 2026), before final release APK and live class demo. | **Scenario-based & Exploratory Testing:** Use a real supermarket test basket (peanut snacks, dairy biscuits containing Casein/Whey, instant noodles with E621/INS codes, safe drinks, and Nutrition-Facts-only photos). Testers complete full daily tasks (scan -> check alert -> pick alternative -> log meal -> add to shopping list -> post review) and report any confusing UI or wording. |

---

## 3. Quality Targets & Pass/Fail Criteria
*Performed by: Nguyen Hoang Phuc Thinh | Reviewed by: Truong Gia Linh | Edited by: Ngo Tien Binh*

- **Entry Criteria:** Feature specifications are finalized, and code builds with zero syntax or lint errors.
- **Exit Criteria:**
  - 100% of automated Vitest and Flutter tests pass (currently 57 automated tests implemented in Sprints 3–4, expanding in Sprint 5 for FG5–FG8).
  - Core allergen evaluation achieves **>= 98% recall** on major allergens and **>= 80% unit test coverage**.
  - Zero open **Critical** or **High** bugs (especially no missed RED allergy warnings, no camera crashes, and no unauthorized Admin access).
