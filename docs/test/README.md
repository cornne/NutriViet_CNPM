# Test and Quality Assurance

This directory indexes NutriViet's automated test suites and quality verification checks across all active codebases.

## Automated Test Suites

| Layer | Location | Command | Tests |
| :--- | :--- | :--- | :---: |
| **Flutter Mobile** | [`src/mobile/test/`](../../src/mobile/test/) | `cd src/mobile && flutter analyze && flutter test` | **22** |
| **Cloudflare Worker** | [`src/cloudflare-worker/test/`](../../src/cloudflare-worker/test/) | `cd src/cloudflare-worker && npm run typecheck && npm test` | **4** |
| **Python Reference & FoodOn** | [`src/backend/`](../../src/backend/) | `cd src/backend && python -B -m unittest test_wsgi_pythonanywhere.py test_community_rbac.py test_foodon_graph.py -v` | **17** |
| **FoodOn Accuracy Benchmark** | [`src/backend/evaluate_hybrid.py`](../../src/backend/evaluate_hybrid.py) | `cd src/backend && python -B evaluate_hybrid.py` | Benchmark |
