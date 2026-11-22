"""TDD integration tests for Community Feed, Guest Stateless Scan & Admin/User RBAC."""

import base64
import io
import json
import os
import sys
import tempfile
import unittest

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

# Minimal valid 1x1 PNG bytes for image upload verification
TINY_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)


def _call_wsgi(app, method: str, path: str, query: str = "", body_dict=None, token: str = ""):
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
    if token:
        environ["HTTP_AUTHORIZATION"] = f"Bearer {token}"

    raw_chunks = app(environ, start_response)
    body_bytes = b"".join(raw_chunks)
    code = int(status_holder[0][0].split(" ", 1)[0])
    return code, dict(status_holder[0][1]), body_bytes


class CommunityAndRbacTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmpdir = tempfile.TemporaryDirectory()
        cls._db_path = os.path.join(cls._tmpdir.name, "community_test.db")
        cls._upload_dir = os.path.join(cls._tmpdir.name, "uploads")
        os.environ["NUTRIVIET_DB_PATH"] = cls._db_path
        os.environ["NUTRIVIET_UPLOAD_DIR"] = cls._upload_dir
        os.environ["NUTRIVIET_ADMIN_EMAIL"] = "admin@nutriviet.vn"
        os.environ["NUTRIVIET_ADMIN_PASSWORD"] = "AdminNutri2026!"

        # Force fresh module state bound to temp DB
        for mod in ("wsgi_app", "community_service"):
            sys.modules.pop(mod, None)
        import wsgi_app

        cls.wsgi_app = wsgi_app
        cls.app = staticmethod(wsgi_app.application)

        # Seed two verified standard users directly in temp DB
        conn = wsgi_app.get_db()
        for uid, name, email in [
            (101, "Alice User", "alice@nutriviet.vn"),
            (102, "Bob User", "bob@nutriviet.vn"),
        ]:
            h, s = wsgi_app.hash_pwd("Secret123!")
            conn.execute(
                "INSERT INTO users (id, full_name, email, password_hash, salt, is_verified, role, is_banned, created_at) "
                "VALUES (?, ?, ?, ?, ?, 1, 'user', 0, '2026-01-01T00:00:00')",
                (uid, name, email, h, s),
            )
        conn.commit()
        conn.close()

        cls.admin_token, cls.admin_user = cls._login("admin@nutriviet.vn", "AdminNutri2026!")
        cls.alice_token, cls.alice_user = cls._login("alice@nutriviet.vn", "Secret123!")
        cls.bob_token, cls.bob_user = cls._login("bob@nutriviet.vn", "Secret123!")

    @classmethod
    def tearDownClass(cls):
        os.environ.pop("NUTRIVIET_DB_PATH", None)
        os.environ.pop("NUTRIVIET_UPLOAD_DIR", None)
        cls._tmpdir.cleanup()

    @classmethod
    def _login(cls, email: str, password: str):
        code, _, raw = _call_wsgi(
            cls.app,
            "POST",
            "/api/v1/auth/login",
            body_dict={"email": email, "password": password},
        )
        assert code == 200, f"Login failed for {email}: {code} {raw}"
        data = json.loads(raw.decode("utf-8"))
        return data["token"], data["user"]

    def test_01_login_issues_real_tokens_and_roles(self):
        self.assertEqual(self.admin_user["role"], "admin")
        self.assertEqual(self.alice_user["role"], "user")
        self.assertNotIn("nv_token_", self.admin_token)
        self.assertGreaterEqual(len(self.admin_token), 32)
        self.assertNotEqual(self.alice_token, self.bob_token)

    def test_02_guest_cannot_access_community_or_admin_but_can_scan_stateless(self):
        # Guest (no token) blocked from Community & Admin
        for method, path in [
            ("GET", "/api/v1/community/posts"),
            ("POST", "/api/v1/community/posts"),
            ("GET", "/api/v1/admin/overview"),
            ("GET", "/api/v1/admin/users"),
        ]:
            code, _, _ = _call_wsgi(self.app, method, path, body_dict={})
            self.assertEqual(code, 401, f"Expected 401 for guest {method} {path}")

        # Forged legacy token rejected
        code_forged, _, _ = _call_wsgi(
            self.app, "GET", "/api/v1/community/posts", token="nv_token_1_verified"
        )
        self.assertEqual(code_forged, 401)

        # Guest CAN scan packaging labels statelessly via /api/v1/foodon/evaluate (zero cloud DB rows written)
        c_eval, _, raw_eval = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/foodon/evaluate",
            body_dict={
                "raw_text": "Wheat flour, powdered milk (8%), E621, salt",
                "allergens": ["milk"],
                "chronics": ["hypertension"],
            },
        )
        self.assertEqual(c_eval, 200)
        ev = json.loads(raw_eval.decode("utf-8"))
        self.assertEqual(ev["verdict"], "RED")
        self.assertIn("detected_additives", ev)
        self.assertGreaterEqual(len(ev["red_triggers"]), 1)
        self.assertGreaterEqual(len(ev["yellow_triggers"]), 1)

        conn = self.wsgi_app.get_db()
        cnt = conn.execute("SELECT COUNT(*) AS c FROM scan_history").fetchone()["c"]
        conn.close()
        self.assertEqual(cnt, 0)

    def test_03_community_post_like_comment_report_and_verbatim_language(self):
        # Alice creates a post with Vietnamese + English mixed user text
        original_content = "Bánh này ghi có whey protein, bé nhà mình uống bị mẩn đỏ nha!"
        c_create, _, r_create = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/community/posts",
            token=self.alice_token,
            body_dict={
                "product_name": "Bánh Quy Bơ Sữa ABC",
                "brand": "ABC Foods",
                "verdict": "RED",
                "ingredients_text": "Wheat flour, butter, whey protein, E322",
                "content": original_content,
                "image_url": "https://firebasestorage.googleapis.com/v0/b/demo/o/test.jpg?alt=media",
            },
        )
        self.assertEqual(c_create, 201)
        post = json.loads(r_create.decode("utf-8"))["post"]
        post_id = post["id"]
        self.assertEqual(post["content"], original_content)
        self.assertEqual(post["verdict"], "RED")

        # Bob fetches feed with lang=en — user content MUST stay verbatim (never translated!)
        c_feed, _, r_feed = _call_wsgi(
            self.app, "GET", "/api/v1/community/posts", "lang=en", token=self.bob_token
        )
        self.assertEqual(c_feed, 200)
        posts = json.loads(r_feed.decode("utf-8"))["posts"]
        fetched = next(p for p in posts if p["id"] == post_id)
        self.assertEqual(fetched["content"], original_content)
        self.assertFalse(fetched["can_delete"])
        self.assertFalse(fetched["can_moderate"])

        # Bob likes & unlikes
        c_l1, _, r_l1 = _call_wsgi(
            self.app, "POST", f"/api/v1/community/posts/{post_id}/like", token=self.bob_token
        )
        self.assertEqual(c_l1, 200)
        self.assertEqual(json.loads(r_l1.decode("utf-8"))["likes_count"], 1)

        # Bob comments in Vietnamese — stays verbatim even when queried with lang=en
        comment_text = "Cảm ơn bạn đã cảnh báo! Mình cũng dị ứng sữa bò."
        c_cm, _, r_cm = _call_wsgi(
            self.app,
            "POST",
            f"/api/v1/community/posts/{post_id}/comments",
            token=self.bob_token,
            body_dict={"content": comment_text},
        )
        self.assertEqual(c_cm, 201)
        cm_id = json.loads(r_cm.decode("utf-8"))["comment"]["id"]

        c_list_cm, _, r_list_cm = _call_wsgi(
            self.app,
            "GET",
            f"/api/v1/community/posts/{post_id}/comments",
            "lang=en",
            token=self.alice_token,
        )
        self.assertEqual(c_list_cm, 200)
        cms = json.loads(r_list_cm.decode("utf-8"))["comments"]
        self.assertEqual(cms[0]["content"], comment_text)

        # Bob CANNOT delete Alice's post (403)
        c_del_forbid, _, _ = _call_wsgi(
            self.app, "POST", f"/api/v1/community/posts/{post_id}/delete", token=self.bob_token
        )
        self.assertEqual(c_del_forbid, 403)

        # Bob reports Alice's post
        c_rep, _, _ = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/community/reports",
            token=self.bob_token,
            body_dict={"post_id": post_id, "reason": "Spam or misleading ingredients"},
        )
        self.assertEqual(c_rep, 201)

        # Regular user CANNOT access Admin endpoints (403)
        for method, path in [
            ("GET", "/api/v1/admin/overview"),
            ("GET", "/api/v1/admin/reports"),
            ("GET", "/api/v1/admin/users"),
            ("POST", f"/api/v1/admin/posts/{post_id}/moderate"),
        ]:
            c_no, _, _ = _call_wsgi(
                self.app, method, path, token=self.bob_token, body_dict={"action": "hide"}
            )
            self.assertEqual(c_no, 403, f"Regular user must get 403 on {method} {path}")

        # Admin sees report & hides post
        c_reps, _, r_reps = _call_wsgi(
            self.app, "GET", "/api/v1/admin/reports", "status=pending", token=self.admin_token
        )
        self.assertEqual(c_reps, 200)
        rep_list = json.loads(r_reps.decode("utf-8"))["reports"]
        self.assertEqual(len(rep_list), 1)
        rep_id = rep_list[0]["id"]

        c_res, _, _ = _call_wsgi(
            self.app,
            "POST",
            f"/api/v1/admin/reports/{rep_id}/resolve",
            token=self.admin_token,
            body_dict={"action": "hide_post", "note": "Hidden for verification"},
        )
        self.assertEqual(c_res, 200)

        # Hidden post disappears from Bob's feed (even if Bob tries include_hidden=1!)
        _, _, r_bob_feed = _call_wsgi(
            self.app, "GET", "/api/v1/community/posts", "include_hidden=1", token=self.bob_token
        )
        bob_ids = [p["id"] for p in json.loads(r_bob_feed.decode("utf-8"))["posts"]]
        self.assertNotIn(post_id, bob_ids)

        # Admin CAN see hidden post when include_hidden=1 and unhide it
        _, _, r_adm_feed = _call_wsgi(
            self.app, "GET", "/api/v1/community/posts", "include_hidden=1", token=self.admin_token
        )
        adm_post = next(
            p for p in json.loads(r_adm_feed.decode("utf-8"))["posts"] if p["id"] == post_id
        )
        self.assertEqual(adm_post["status"], "hidden")
        self.assertTrue(adm_post["can_moderate"])

        # Admin deletes Bob's comment
        c_del_cm, _, _ = _call_wsgi(
            self.app, "POST", f"/api/v1/community/comments/{cm_id}/delete", token=self.admin_token
        )
        self.assertEqual(c_del_cm, 200)

    def test_04_admin_user_management_and_ban_enforcement(self):
        # Admin cannot ban or demote themselves
        c_self, _, _ = _call_wsgi(
            self.app,
            "POST",
            f"/api/v1/admin/users/{self.admin_user['id']}/update",
            token=self.admin_token,
            body_dict={"is_banned": True},
        )
        self.assertEqual(c_self, 400)

        # Admin bans Bob
        c_ban, _, _ = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/admin/users/102/update",
            token=self.admin_token,
            body_dict={"is_banned": True},
        )
        self.assertEqual(c_ban, 200)

        # Banned Bob's existing tokens are immediately revoked (401) and login is blocked (403)
        c_comm, _, _ = _call_wsgi(
            self.app, "GET", "/api/v1/community/posts", token=self.bob_token
        )
        self.assertEqual(c_comm, 401)
        c_login, _, _ = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/auth/login",
            body_dict={"email": "bob@nutriviet.vn", "password": "Secret123!"},
        )
        self.assertEqual(c_login, 403)

        # Admin unbans Bob & promotes Alice to admin
        c_unban, _, _ = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/admin/users/102/update",
            token=self.admin_token,
            body_dict={"is_banned": False},
        )
        self.assertEqual(c_unban, 200)

        c_promo, _, _ = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/admin/users/101/update",
            token=self.admin_token,
            body_dict={"role": "admin"},
        )
        self.assertEqual(c_promo, 200)
        c_ov, _, _ = _call_wsgi(
            self.app, "GET", "/api/v1/admin/overview", token=self.alice_token
        )
        self.assertEqual(c_ov, 200)

    def test_05_community_image_upload_validation(self):
        # Reject invalid non-image bytes
        c_bad, _, _ = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/community/upload-image",
            token=self.alice_token,
            body_dict={
                "filename": "evil.txt",
                "content_type": "image/png",
                "data_base64": base64.b64encode(b"not an image").decode("ascii"),
            },
        )
        self.assertEqual(c_bad, 400)

        # Valid PNG upload succeeds and can be fetched via media endpoint
        c_ok, _, r_ok = _call_wsgi(
            self.app,
            "POST",
            "/api/v1/community/upload-image",
            token=self.alice_token,
            body_dict={
                "filename": "snack.png",
                "content_type": "image/png",
                "data_base64": base64.b64encode(TINY_PNG).decode("ascii"),
            },
        )
        self.assertEqual(c_ok, 201)
        media_path = json.loads(r_ok.decode("utf-8"))["image_path"]
        self.assertTrue(media_path.startswith("/api/v1/community/media/"))

        c_get, hdrs, img_bytes = _call_wsgi(self.app, "GET", media_path)
        self.assertEqual(c_get, 200)
        self.assertEqual(img_bytes, TINY_PNG)
        self.assertEqual(hdrs.get("Content-Type"), "image/png")

        # Path traversal attempt rejected
        c_trav, _, _ = _call_wsgi(
            self.app, "GET", "/api/v1/community/media/../../wsgi_app.py"
        )
        self.assertEqual(c_trav, 404)


if __name__ == "__main__":
    unittest.main()
