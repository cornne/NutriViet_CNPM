"""End-to-end WSGI & Pure-English FoodOn regression tests (PythonAnywhere + Kaggle ready)."""

import csv
import io
import json
import os
import re
import sqlite3
import sys
import tempfile
import unittest

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

# Characters unique to Vietnamese (excluding Western European loanword accents like é/à/â in "crème", "pâté", "chrétien")
VI_EXCLUSIVE_RE = re.compile(
    r"[ăắằẳẵặấầẩẫậđếềểễệốồổỗộơớờởỡợưứừửữựảạỷỹỵỉịỏọủụẻẹ]",
    flags=re.IGNORECASE,
)


def _call_wsgi(app, method: str, path: str, query: str = "", body_dict=None):
    payload = b""
    if body_dict is not None:
        payload = json.dumps(body_dict).encode("utf-8")

    status_holder = []

    def start_response(status, headers):
        status_holder.append((status, headers))

    environ = {
        "REQUEST_METHOD": method,
        "PATH_INFO": path,
        "QUERY_STRING": query,
        "CONTENT_LENGTH": str(len(payload)),
        "wsgi.input": io.BytesIO(payload),
    }
    raw_chunks = app(environ, start_response)
    body = b"".join(raw_chunks).decode("utf-8")
    code = int(status_holder[0][0].split(" ", 1)[0])
    return code, status_holder[0][1], body


class PureEnglishFoodOnTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Prove runtime works cleanly without PyYAML installed (100% stdlib at runtime).
        cls._prev_yaml = sys.modules.get("yaml")
        sys.modules["yaml"] = None

        cls._tmpdir = tempfile.TemporaryDirectory()
        cls._db_path = os.path.join(cls._tmpdir.name, "test_nutriviet.db")
        os.environ["NUTRIVIET_DB_PATH"] = cls._db_path

        import wsgi_app
        cls.wsgi_app = wsgi_app
        cls.app = staticmethod(wsgi_app.application)

    @classmethod
    def tearDownClass(cls):
        if cls._prev_yaml is not None:
            sys.modules["yaml"] = cls._prev_yaml
        else:
            sys.modules.pop("yaml", None)
        os.environ.pop("NUTRIVIET_DB_PATH", None)
        cls._tmpdir.cleanup()

    def test_database_is_pure_english_foodon(self):
        from hybrid_ontology import HYBRID_DB_PATH

        conn = sqlite3.connect(HYBRID_DB_PATH)
        conn.row_factory = sqlite3.Row
        try:
            cur = conn.cursor()

            # 1. Zero non-English terms in lexical_bridge
            non_en = cur.execute(
                "SELECT COUNT(*) AS c FROM lexical_bridge WHERE lang != 'en'"
            ).fetchone()["c"]
            self.assertEqual(non_en, 0)

            # 2. Required Kaggle-ready schema columns on foodon_concepts
            cols = {
                r["name"]
                for r in cur.execute("PRAGMA table_info(foodon_concepts)").fetchall()
            }
            for required in (
                "curie",
                "label_en",
                "parent_curie",
                "parent_label_en",
                "definition_en",
                "food_type",
                "allergen_codes",
                "chronic_codes",
                "ecodes",
            ):
                self.assertIn(required, cols)

            # 3. Metadata confirms pure English official FoodOn build
            meta = {
                r["key"]: r["value"]
                for r in cur.execute("SELECT key, value FROM db_metadata").fetchall()
            }
            self.assertEqual(meta.get("language"), "en")
            self.assertEqual(meta.get("total_vi_terms"), "0")

            total_concepts = cur.execute(
                "SELECT COUNT(*) AS c FROM foodon_concepts"
            ).fetchone()["c"]
            total_ecodes = cur.execute(
                "SELECT COUNT(*) AS c FROM ecode_bridge"
            ).fetchone()["c"]
            with_defs = cur.execute(
                "SELECT COUNT(*) AS c FROM foodon_concepts WHERE definition_en != ''"
            ).fetchone()["c"]
            self.assertGreater(total_concepts, 20000)
            self.assertGreater(total_ecodes, 500)
            self.assertGreater(with_defs, 5000)

            # 4. Zero Vietnamese-exclusive characters in foodon_concepts.label_en or lexical_bridge
            sample_vi_labels = [
                r["label_en"]
                for r in cur.execute("SELECT label_en FROM foodon_concepts").fetchall()
                if VI_EXCLUSIVE_RE.search(r["label_en"] or "")
            ]
            self.assertEqual(sample_vi_labels, [])
        finally:
            conn.close()

    def test_no_hardcoded_vietnamese_fallbacks(self):
        import hybrid_ontology
        import monolingual_catalog

        forbidden_catalog_attrs = (
            "CONCEPT_CATALOG",
            "EVERYDAY_ALLERGY_FOODS",
            "ECODE_VI_CATALOG",
            "EN_TO_VI_PHRASE_RULES",
            "EN_WORD_TO_VI",
            "LINEAGE_PARENT_VI",
            "ALLERGEN_DISPLAY_NAMES_VI",
            "CHRONIC_DISPLAY_NAMES_VI",
            "BAD_KALA_VI_TERMS",
            "CURATED_CATEGORY_CURIES",
            "translate_en_phrase_to_vi",
        )
        for attr in forbidden_catalog_attrs:
            self.assertFalse(
                hasattr(monolingual_catalog, attr),
                f"monolingual_catalog should not contain hardcoded fallback {attr}",
            )

        for attr in (
            "ALLERGEN_DISPLAY_NAMES_VI",
            "CHRONIC_DISPLAY_NAMES_VI",
            "decode_kala_blob",
        ):
            self.assertFalse(
                hasattr(hybrid_ontology, attr),
                f"hybrid_ontology should not contain legacy/hardcoded {attr}",
            )

    def test_health_and_foodon_ui(self):
        code, _, raw = _call_wsgi(self.app, "GET", "/health")
        self.assertEqual(code, 200)
        data = json.loads(raw)
        self.assertEqual(data["status"], "healthy")
        self.assertEqual(data["version"], "2.0.0")
        self.assertTrue(data["foodon_hybrid"])

        html_code, _, html = _call_wsgi(self.app, "GET", "/foodon-test")
        self.assertEqual(html_code, 200)
        self.assertIn("<html", html.lower())

    def test_foodon_endpoints_pure_english_without_yaml(self):
        # Butter -> milk family via FoodOn ontology
        c_but, _, r_but = _call_wsgi(
            self.app, "GET", "/api/v1/foodon/allergy-lookup", "q=butter&lang=en&limit=8"
        )
        self.assertEqual(c_but, 200)
        but_data = json.loads(r_but)
        self.assertGreater(but_data["count"], 0)
        self.assertTrue(
            any(item["allergen_code"] == "milk" for item in but_data["items"])
        )

        # Meat -> mammalian meat family via FoodOn ontology
        c_meat, _, r_meat = _call_wsgi(
            self.app, "GET", "/api/v1/foodon/allergy-lookup", "q=meat&lang=en&limit=8"
        )
        self.assertEqual(c_meat, 200)
        meat_data = json.loads(r_meat)
        self.assertGreater(meat_data["count"], 0)
        self.assertTrue(
            any(
                item["allergen_code"] == "curie:FOODON:00001006"
                for item in meat_data["items"]
            )
        )

        # Empty browse query works from DB without EVERYDAY_ALLERGY_FOODS hardcode
        c_empty, _, r_empty = _call_wsgi(
            self.app, "GET", "/api/v1/foodon/allergy-lookup", "q=&limit=8"
        )
        self.assertEqual(c_empty, 200)
        self.assertGreater(json.loads(r_empty)["count"], 0)

        # Additives return crisp non-null English cards
        c_add, _, r_add = _call_wsgi(
            self.app, "GET", "/api/v1/foodon/additives", "lang=en&limit=10"
        )
        self.assertEqual(c_add, 200)
        add_items = json.loads(r_add)["items"]
        self.assertTrue(len(add_items) > 0)
        for item in add_items:
            self.assertTrue(item["title_en"])
            self.assertEqual(item["title_vi"], item["title_en"])
            self.assertFalse(VI_EXCLUSIVE_RE.search(item["title_en"]))

        # Categories driven strictly from FoodOn DB
        for cat in ("sugar", "salt", "fat", "allergen"):
            c_cat, _, r_cat = _call_wsgi(
                self.app,
                "GET",
                "/api/v1/foodon/category",
                f"category={cat}&lang=en&limit=8",
            )
            self.assertEqual(c_cat, 200)
            cat_data = json.loads(r_cat)
            self.assertEqual(cat_data["category"], cat)
            self.assertGreater(cat_data["count"], 0)

        # Search reports 0 VI terms and matches English FoodOn
        c_srch, _, r_srch = _call_wsgi(
            self.app, "GET", "/api/v1/foodon/search", "q=peanut&lang=en&limit=10"
        )
        self.assertEqual(c_srch, 200)
        srch_data = json.loads(r_srch)
        self.assertEqual(srch_data["db_stats"]["total_vi_terms"], 0)
        self.assertGreater(srch_data["returned_count"], 0)

        # Packaging label evaluation in pure English + E-code
        c_ev, _, r_ev = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/foodon/evaluate",
            body_dict={
                "ingredients": ["powdered milk", "E621", "butter"],
                "allergens": ["milk"],
                "chronics": ["hypertension"],
            },
        )
        self.assertEqual(c_ev, 200)
        ev_data = json.loads(r_ev)
        self.assertEqual(ev_data["verdict"], "RED")
        self.assertTrue(len(ev_data["red_triggers"]) >= 1)
        self.assertTrue(len(ev_data["yellow_triggers"]) >= 1)

    def test_profile_chronics_and_allergens_roundtrip(self):
        conn = self.wsgi_app.get_db()
        try:
            conn.execute(
                "INSERT INTO users (id, full_name, email, password_hash, salt, is_verified, created_at) "
                "VALUES (501, 'Test User', 'test@nutriviet.vn', 'h', 's', 1, '2026-01-01')"
            )
            conn.commit()
        finally:
            conn.close()

        c_post, _, r_post = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/profile/chronics",
            body_dict={
                "user_id": 501,
                "chronics": [{"code": "diabetes", "name": "Diabetes"}],
            },
        )
        self.assertEqual(c_post, 200)
        self.assertTrue(json.loads(r_post)["success"])

        c_get, _, r_get = _call_wsgi(
            self.app, "GET", "/api/v1/profile/chronics", "user_id=501"
        )
        self.assertEqual(c_get, 200)
        self.assertEqual(
            [c["code"] for c in json.loads(r_get)["chronics"]], ["diabetes"]
        )

        c_al_post, _, _ = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/profile/allergens",
            body_dict={
                "user_id": 501,
                "allergens": [{"code": "milk", "name": "Butter", "severity": "high"}],
            },
        )
        self.assertEqual(c_al_post, 200)

        c_al_get, _, r_al_get = _call_wsgi(
            self.app, "GET", "/api/v1/profile/allergens", "user_id=501"
        )
        self.assertEqual(c_al_get, 200)
        self.assertEqual(len(json.loads(r_al_get)["allergens"]), 1)

    def test_kaggle_csv_export(self):
        from hybrid_ontology import HYBRID_DB_PATH, export_concepts_for_kaggle

        out_csv = os.path.join(self._tmpdir.name, "foodon_en.csv")
        count = export_concepts_for_kaggle(out_csv, db_path=HYBRID_DB_PATH)
        self.assertGreater(count, 20000)

        with open(out_csv, "r", encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            self.assertEqual(
                reader.fieldnames,
                [
                    "curie",
                    "label_en",
                    "parent_curie",
                    "parent_label_en",
                    "definition_en",
                    "food_type",
                    "allergen_codes",
                    "chronic_codes",
                    "ecodes",
                    "synonyms_en",
                ],
            )
            first = next(reader)
            self.assertTrue(first["curie"])
            self.assertTrue(first["label_en"])


if __name__ == "__main__":
    unittest.main()
