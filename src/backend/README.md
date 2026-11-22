# NutriViet Local Python Reference Backend & FoodOn Engine

> **Production Note:** NutriViet's live production API, databases, and OCR proxy now run on **Cloudflare Workers + Cloudflare D1** (see [`src/cloudflare-worker/README.md`](../cloudflare-worker/README.md)).  
> This `src/backend/` directory serves as the **zero-dependency local development server**, the **FoodOn ontology compiler/benchmark toolkit**, and the **Python automated regression test suite**.

---

## Key Components

| File | Description |
| :--- | :--- |
| `wsgi_app.py` | Pure Python stdlib WSGI application mirroring Auth, Profile, Scan History, FoodOn Graph (`/foodon-graph`), and FoodOn REST API (`/api/v1/foodon/*`). |
| `foodon_ui_server.py` | Threaded local HTTP dev server on port `8050` (redirects `/` → `/foodon-graph` and configures `adb reverse tcp:8050` if an Android device is attached). |
| `hybrid_ontology.py` | Core pure-English FoodOn ontology engine (33,688 concepts, 53,242 lexical terms, 742 E-codes), ancestor allergen inference, graph traversal, and Kaggle CSV exporter. |
| `community_service.py` | Community feed, media upload/serve, and strict Admin RBAC moderation logic. |
| `monolingual_catalog.py` | Pure-English FoodOn formatting and code-label utilities (zero hardcoded Vietnamese fallback tables). |
| `data/nutriviet_hybrid.db` | Pre-compiled FoodOn SQLite database (`16.1 MB`) used by local tests and benchmarks. |
| `static/foodon_graph.html` | Interactive FoodOn Ontology Graph web visualizer served at `/foodon-graph`. |
| `evaluate_hybrid.py` | Accuracy, compaction, and latency benchmark suite for the FoodOn recognition engine. |

---

## Quick Start (Local Development)

Requires **Python 3.10+** (standard library only at runtime — no `pip install` needed):

```bash
cd src/backend

# Start local dev server at http://127.0.0.1:8050/foodon-graph
python -B foodon_ui_server.py
```

### Key Local Endpoints
- `GET /health` — Service health & ontology status
- `GET /foodon-graph` — Interactive FoodOn Graph Visualizer
- `GET /api/v1/foodon/*` & `POST /api/v1/foodon/evaluate` — FoodOn ontology search, graph, additives, allergy lookup & label evaluation
- `/api/v1/auth/*`, `/api/v1/profile/*`, `/api/v1/scans`, `/api/v1/community/*`, `/api/v1/admin/*` — Full API parity with Cloudflare Worker

---

## Running Tests & Benchmarks

Use `python -B` to avoid generating `__pycache__/` artifacts:

```bash
cd src/backend

# Run all 17 backend unit & integration tests (isolated temporary SQLite DBs)
python -B -m unittest test_wsgi_pythonanywhere.py test_community_rbac.py test_foodon_graph.py -v

# Run FoodOn recognition & latency benchmark
python -B evaluate_hybrid.py
```

| Test File | Coverage |
| :--- | :--- |
| `test_wsgi_pythonanywhere.py` | Pure-English FoodOn DB integrity, zero hardcoded fallback checks, profile roundtrips, scan delete/clear isolation, Kaggle export |
| `test_community_rbac.py` | Token auth, Guest gate, Community posts/likes/comments/reports, image upload validation, Admin RBAC & ban enforcement |
| `test_foodon_graph.py` | Ontology children map, neighborhood graph, expansion pagination, shortest ontology path, and `/foodon-graph` HTML route |
