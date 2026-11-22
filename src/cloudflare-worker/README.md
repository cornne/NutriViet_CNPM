# NutriViet Cloudflare Workers + D1 Backend

Serverless full-stack backend for **NutriViet**, running 100% on **Cloudflare Workers + Cloudflare D1 (Free Tier)** with Smart Placement in APAC.

## Live Production Endpoints

- **Base URL**: `https://nutriviet.nutriviet-api.workers.dev`
- **Health Check**: `GET /health`
- **Interactive FoodOn Ontology Graph**: `GET /foodon-graph`
- **FoodOn Ontology REST API (33,688 concepts)**: `/api/v1/foodon/*`
- **Auth, Profile, Family & Scan History**: `/api/v1/auth/*`, `/api/v1/profile/*`, `/api/v1/scans`
- **Community & Admin Moderation (RBAC)**: `/api/v1/community/*`, `/api/v1/admin/*`
- **PaddleOCR-VL-1.6 Edge Proxy**: `POST /api/v1/ocr/jobs`, `GET /api/v1/ocr/jobs/:jobId`

## Provisioned Cloudflare D1 Databases (APAC)

| Binding | Database Name | UUID | Contents |
| :--- | :--- | :--- | :--- |
| `APP_DB` | `nutriviet-app` | `dcdf8df6-7f4e-4efc-8e9c-0b94bdaf5894` | Users (PBKDF2 hashes), allergens, chronics, family, scan history, community posts/media, static web pages |
| `FOODON_DB` | `nutriviet-foodon` | `357c1fdd-c26c-4771-a120-70e98bb24c74` | Full 33,688 FoodOn concepts, 53,242 lexical bridge entries, 742 E-codes, precomputed allergen/chronic indexes |

## Local Development & Verification

```bash
cd src/cloudflare-worker
npm install
npm run typecheck
npm test
npm run build
```

## Managing Secrets (OCR & Optional Email Verification)

Secrets are stored encrypted in Cloudflare Workers (never committed to git or bundled into the Flutter APK):

- `PADDLEOCR_VL_TOKEN` *(configured)* — Baidu AI Studio token for `/api/v1/ocr/jobs` proxy.
- `RESEND_API_KEY` *(optional)* — Plug in a Resend API key + `EMAIL_FROM` + set `AUTO_VERIFY_EMAIL=false` to enable real verification & password-recovery emails.
- `BREVO_API_KEY` *(optional)* — Alternative HTTP email provider (300 emails/day free tier).

