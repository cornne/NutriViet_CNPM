# Spec 003: Community Product Feed, Guest Local Mode & Admin/User RBAC

## Objective
1. **Community Social Feed (Replaces Additives Tab)**: Replace bottom-nav Tab 1 (`Phụ gia` / `Additives`) with **`Cộng đồng` / `Community`** so authenticated users can share scanned packaging products (name, brand, `RED`/`YELLOW`/`GREEN` verdict, ingredients, review notes, optional photo via Firebase Storage or backend media fallback), like, comment, report, and share directly from scan results.
2. **Strict Language Boundary on User-Generated Content**: UI language switching (`vi` ↔ `en`) translates app chrome only and **never alters, translates, or mutates user-authored posts or comments**.
3. **Guest Mode (Local-Only Persistence)**: Allow entering the app without logging in via **"Continue as Guest"**. Guests scan labels normally via stateless `POST /api/v1/foodon/evaluate` (zero cloud writes) and store scan history, allergens, chronic conditions, family profiles, and settings purely locally (`SharedPreferences`). Guests are blocked from accessing the Community feed (shown a sign-in gate) and offered one-tap local-to-cloud sync upon signing in later.
4. **Hidden Two-Role RBAC (`user` vs `admin`)**: Enforce server-side cryptographic session tokens and roles. Admin moderation tools (hide/unhide/delete any post, delete any comment, inspect & resolve abuse reports, list users, ban/unban, change roles) are strictly hidden in UI for non-admins and strictly rejected with `403` on the backend.

## Architecture & Data Model

### Backend (`src/backend/community_service.py` + `src/backend/wsgi_app.py`)
- Pure Python standard library (`sqlite3`, `secrets`, `base64`, `os`, `re`, `datetime`) — 100% PythonAnywhere WSGI compatible.
- `users`: add columns `role TEXT NOT NULL DEFAULT 'user'` and `is_banned INTEGER NOT NULL DEFAULT 0`. Auto-seed default admin (`NUTRIVIET_ADMIN_EMAIL` / `NUTRIVIET_ADMIN_PASSWORD`).
- `user_sessions(token PRIMARY KEY, user_id, created_at)` — cryptographic `secrets.token_urlsafe(32)` validated via `Authorization: Bearer <token>`.
- `community_posts(id, user_id, product_name, brand, verdict, ingredients_text, content, image_url, barcode, status, hidden_reason, hidden_by, created_at, updated_at)`
- `community_likes(post_id, user_id, created_at)`
- `community_comments(id, post_id, user_id, content, status, created_at)`
- `community_reports(id, post_id, comment_id, reporter_id, reason, status, resolved_by, resolved_note, created_at, resolved_at)`

### Mobile (`src/mobile/lib/`)
- `services/local_guest_store.dart`: local JSON persistence for Guest scans, allergens, chronics, family members, settings + `syncToCloudAccount(...)`.
- `services/community_service.dart`: authenticated Community & Admin API client + photo upload (Firebase Storage REST upload via `--dart-define=NUTRIVIET_FIREBASE_STORAGE_BUCKET=...` with clean fallback to backend `/api/v1/community/upload-image`).
- `screens/community_feed_screen.dart`: Liquid Glass Community tab (feed, verdict filters, search, compose sheet, comment sheet, report dialog, inline admin actions, Guest lock screen).
- `screens/admin_moderation_screen.dart`: Hidden Admin dashboard (`Reports`, `Posts`, `Users`), rendered solely when `role == 'admin'`.
- `screens/home_screen.dart`, `screens/login_screen.dart`, `screens/settings_screen.dart`, `screens/allergy_profile_screen.dart`: Guest mode routing, Tab 1 swapped from `Additives` → `Community`, Share-to-Community from scans, Guest-to-Cloud sync prompt on login.

## Verification & Success Criteria
- Backend unit & integration tests (`python src/backend/test_community_rbac.py -v` and `python src/backend/test_wsgi_pythonanywhere.py -v`): 100% pass, verifying auth gates (`401`), RBAC (`403`), verbatim UGC preservation, moderation flows, user ban enforcement, image upload validation, and stateless guest scanning.
- Mobile static analysis & widget tests (`flutter analyze`, `flutter test`): 0 issues, 100% pass covering Guest local store, Community guest gate, RBAC admin visibility, and tab navigation.
- Release APK builds cleanly (`flutter build apk --release`).

