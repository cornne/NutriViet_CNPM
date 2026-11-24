# NutriViet Cloudflare Workers + D1 Backend

Serverless production backend for **NutriViet**, running 100% on **Cloudflare Workers + Cloudflare D1 (Free Tier)** with Smart Placement in APAC.

---

## Live Production Endpoints

- **Base URL:** `https://nutriviet.nutriviet-api.workers.dev`
- **Health Check:** https://nutriviet.nutriviet-api.workers.dev/health
- **Interactive FoodOn Ontology Graph:** https://nutriviet.nutriviet-api.workers.dev/foodon-graph

### REST API Overview

| Group | Methods & Endpoints | Purpose |
| :--- | :--- | :--- |
| **System & Web** | `GET /health`, `GET /`, `GET /foodon-graph` | Health telemetry (`ocr_proxy`, `email_verification` status), security headers, and Edge-cached FoodOn Graph HTML visualizer |
| **Auth & Account** | `POST /api/v1/auth/register`, `login`, `logout`, `resend-verification`, `forgot-password`, `reset-password`, `change-password`, `update-profile`, `GET /verify-email` | PBKDF2-HMAC-SHA256 (100,000 iterations) auth, Bearer session tokens, 6-digit 15-min OTP password reset, IP rate limiting |
| **Health Profile** | `GET/POST /api/v1/profile/allergens`, `chronics`, `settings`, `family` | Strictly Bearer-authenticated personalized allergens (triggers scan re-evaluation), chronics, `scan_derivatives`/`warn_traces` settings, family profiles |
| **Scan History** | `GET/POST /api/v1/scans`, `DELETE /api/v1/scans/:id`, `DELETE /api/v1/scans` | Strictly Bearer-authenticated owner-scoped label analysis persisted per user, individual delete and clear-all history |
| **FoodOn Ontology** | `GET /api/v1/foodon/graph`, `graph/expand`, `graph/path`, `allergy-lookup`, `additives`, `category`, `search`, `POST /api/v1/foodon/evaluate` | Indexed D1 queries across 33,688 pure-English FoodOn concepts, 53,242 lexical terms, 742 E-codes (incl. bare parenthesized INS codes), Levenshtein fuzzy matching, `scan_derivatives`/`warn_traces` evaluation |
| **Community & Admin** | `GET/POST /api/v1/community/posts`, `like`, `comments`, `report`, `upload-image`, `GET /api/v1/community/media/:filename`, `GET/POST /api/v1/admin/*` | Authenticated community feed, D1-backed image storage (`community_media`), strict server-side `role === 'admin'` moderation |
| **OCR Edge Proxy** | `POST /api/v1/ocr/jobs`, `GET /api/v1/ocr/jobs/:jobId` | Proxies packaging images to `PaddleOCR-VL-1.6` using Worker Secrets and cleans Markdown/HTML tables on Edge |

---

## Provisioned Cloudflare D1 Databases (APAC)

| Binding | Database Name | UUID | Contents |
| :--- | :--- | :--- | :--- |
| `APP_DB` | `nutriviet-app` | `dcdf8df6-7f4e-4efc-8e9c-0b94bdaf5894` | Users, sessions, allergens, chronics, metrics, settings, family, scan history, community posts/likes/comments/reports/media, `static_pages` (`foodon-graph`) |
| `FOODON_DB` | `nutriviet-foodon` | `357c1fdd-c26c-4771-a120-70e98bb24c74` | Full 33,688 FoodOn concepts, 53,242 `lexical_bridge` rows, 742 `ecode_bridge` rows, precomputed allergen/chronic lookup maps, and 8 B-tree indexes |

---

## Module Architecture

```text
src/cloudflare-worker/
├── cloudflare.config.ts    # Worker name, compatibility_date, D1 bindings & Smart Placement
├── package.json            # Scripts: typecheck, test, build (esbuild -> dist/worker.js)
├── src/
│   ├── index.ts            # Hono router, CORS, security headers, IP rate limiter, /health, /api/v1/foodon/*
│   ├── auth_profile.ts     # Auth, 6-digit OTP reset, Bearer-guarded profile, family & scan history CRUD
│   ├── community.ts        # Bearer/Admin auth guards, Community posts, D1 media upload/serve & Admin RBAC
│   ├── foodon.ts           # D1FoodOnEngine: Levenshtein fuzzy, bare E-codes, scan_derivatives/warn_traces
│   ├── ingredient_extractor.ts # Fuzzy Ingredients-only section extractor (strips Nutrition Facts & storage)
│   ├── ocr_proxy.ts        # PaddleOCR-VL-1.6 proxy & server-side Markdown/HTML text cleaner
│   ├── rate_limit.ts       # Per-isolate sliding-window IP rate limiter for auth & OCR submit endpoints
│   ├── crypto.ts           # Web Crypto PBKDF2-HMAC-SHA256, SHA-256 & unbiased 6-digit OTP generator
│   ├── email.ts            # HTTP Email dispatcher (Resend / Brevo) for verification & OTP reset
│   └── types.ts            # Cloudflare Env bindings & typed D1 row interfaces
├── static/
│   └── foodon_graph.html   # Interactive FoodOn Ontology Graph HTML source (seeded into D1 static_pages)
└── test/
    └── worker.test.ts      # Vitest unit tests
```

---

## Commands

| Command | Description |
| :--- | :--- |
| `npm install` | Install TypeScript, Hono, esbuild, Vitest, and Workers types |
| `npm run typecheck` | Run strict TypeScript check (`tsc --noEmit`) |
| `npm test` | Run Vitest unit test suite (`vitest run`) |
| `npm run build` | Bundle minified ESM Worker to `dist/worker.js` (~106 KB) |

---

## Secrets & Environment Variables

Secrets are stored encrypted in Cloudflare Workers (never committed to Git or bundled into APKs). When redeploying via the Workers REST API, pass `keep_bindings: ["secret_text"]` so existing secrets stay attached.

| Name | Type | Status | Purpose |
| :--- | :--- | :--- | :--- |
| `PADDLEOCR_VL_TOKEN` | Secret | Configured | Baidu AI Studio access token for `/api/v1/ocr/jobs` (can be overridden per request via `X-PaddleOCR-Token`) |
| `PUBLIC_BASE_URL` | Plain Text | `https://nutriviet.nutriviet-api.workers.dev` | Base URL for email verification links |
| `EMAIL_FROM` | Plain Text | `NutriViet <trienchill@mondk.com>` | Verified transactional sender address |
| `AUTO_VERIFY_EMAIL` | Plain Text | `"false"` | Requires real email verification link click before first sign-in |
| `BREVO_API_KEY` | Secret | Configured | Brevo transactional HTTP API key (300 free emails/day) for account verification & password recovery |
| `RESEND_API_KEY` | Secret | Optional | Optional alternative transactional HTTP email provider (takes precedence if configured) |
