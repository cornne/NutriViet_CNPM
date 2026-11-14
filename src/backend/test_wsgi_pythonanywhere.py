"""End-to-end WSGI smoke & FoodOn regression tests for PythonAnywhere deployment."""

import io
import json
import os
import sys
import tempfile
import unittest

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)


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


class PythonAnywhereWsgiTests(unittest.TestCase):
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

    def test_foodon_endpoints_without_yaml(self):
        # Monolingual everyday allergy lookup ("bơ" in Vietnamese -> milk)
        code, _, raw = _call_wsgi(
            self.app, "GET", "/api/v1/foodon/allergy-lookup", "q=bo&lang=vi&limit=8"
        )
        self.assertEqual(code, 200)
        res = json.loads(raw)
        self.assertGreater(res["count"], 0)

        # English lookup ("meat")
        code_en, _, raw_en = _call_wsgi(
            self.app, "GET", "/api/v1/foodon/allergy-lookup", "q=meat&lang=en&limit=8"
        )
        self.assertEqual(code_en, 200)
        self.assertGreater(json.loads(raw_en)["count"], 0)

        # Additives, category, search, evaluate
        c_add, _, r_add = _call_wsgi(
            self.app, "GET", "/api/v1/foodon/additives", "lang=vi&limit=10"
        )
        self.assertEqual(c_add, 200)
        self.assertTrue(len(json.loads(r_add)["items"]) > 0)

        c_cat, _, r_cat = _call_wsgi(
            self.app, "GET", "/api/v1/foodon/category", "category=sugar&lang=vi&limit=10"
        )
        self.assertEqual(c_cat, 200)
        self.assertEqual(json.loads(r_cat)["category"], "sugar")

        c_ev, _, r_ev = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/foodon/evaluate",
            body_dict={
                "ingredients": ["sữa bột tách kem", "E621", "bơ"],
                "allergens": ["milk"],
                "chronics": ["hypertension"],
            },
        )
        self.assertEqual(c_ev, 200)
        ev_data = json.loads(r_ev)
        self.assertEqual(ev_data["verdict"], "RED")

    def test_profile_chronics_sqlite_roundtrip_in_isolated_db(self):
        # Seed a test user inside isolated temp DB cleanly
        conn = self.wsgi_app.get_db()
        conn.execute(
            "INSERT INTO users (id, full_name, email, password_hash, salt, is_verified, created_at) "
            "VALUES (1, 'Test User', 'test@nutriviet.vn', 'h', 's', 1, '2026-01-01')"
        )
        conn.commit()
        conn.close()

        c_post, _, r_post = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/profile/chronics",
            body_dict={
                "user_id": 1,
                "chronics": [{"code": "diabetes", "name": "Tiểu đường"}],
            },
        )
        self.assertEqual(c_post, 200)
        self.assertTrue(json.loads(r_post)["success"])

        c_get, _, r_get = _call_wsgi(
            self.app, "GET", "/api/v1/profile/chronics", "user_id=1"
        )
        self.assertEqual(c_get, 200)
        chronics = json.loads(r_get)["chronics"]
        self.assertEqual([c["code"] for c in chronics], ["diabetes"])


if __name__ == "__main__":
    unittest.main()
