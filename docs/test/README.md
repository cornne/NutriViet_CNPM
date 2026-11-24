# Test and Quality Assurance

This directory indexes NutriViet's automated test suites and quality verification checks across all active codebases.

## Automated Test Suites

| Layer | Location | Command | Tests |
| :--- | :--- | :--- | :---: |
| **Flutter Mobile** | [`src/mobile/test/`](../../src/mobile/test/) | `cd src/mobile && flutter analyze && flutter test` | **30** |
| **Cloudflare Worker** | [`src/cloudflare-worker/test/`](../../src/cloudflare-worker/test/) | `cd src/cloudflare-worker && npm run typecheck && npm test` | **15** |
