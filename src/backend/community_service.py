"""
Community Social Network, Secure Session Auth, Media Upload & Admin RBAC Module
===============================================================================
100% Python standard library (`sqlite3`, `secrets`, `base64`, `os`, `re`, `json`)
for zero-dependency PythonAnywhere WSGI deployment.

Security invariants:
  - Every `/api/v1/community/*` route (except safe static media GET) requires a
    valid cryptographic `Authorization: Bearer <token>` session of a non-banned
    logged-in user. Guests receive `401 AUTH_REQUIRED`.
  - Every `/api/v1/admin/*` route strictly checks `user['role'] == 'admin'` on
    the server from SQLite. Standard users receive `403 ADMIN_REQUIRED`.
  - User-generated content (post titles, reviews, ingredients, comments) is
    stored and returned verbatim — UI language switching never mutates UGC.
"""

import base64
import json
import os
import re
import secrets
import sqlite3
import urllib.parse
from datetime import datetime, timezone

_BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
_VALID_VERDICTS = {"RED", "YELLOW", "GREEN"}
_SAFE_MEDIA_NAME_RE = re.compile(r"^[a-f0-9]{16,40}\.(jpg|jpeg|png|webp)$")
_MAX_IMAGE_BYTES = 2 * 1024 * 1024  # 2 MB compressed image cap


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _safe_int(value, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _get_upload_dir() -> str:
    override = os.environ.get("NUTRIVIET_UPLOAD_DIR", "").strip()
    base = override if override else os.path.join(_BACKEND_DIR, "uploads", "community")
    os.makedirs(base, exist_ok=True)
    return base


def _detect_image_ext_and_mime(raw: bytes) -> tuple[str, str] | None:
    if len(raw) < 12 or len(raw) > _MAX_IMAGE_BYTES:
        return None
    if raw[:8] == b"\x89PNG\r\n\x1a\n":
        return "png", "image/png"
    if raw[:3] == b"\xff\xd8\xff":
        return "jpg", "image/jpeg"
    if raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        return "webp", "image/webp"
    return None


def _sanitize_image_url(url: str) -> str:
    clean = (url or "").strip()
    if not clean:
        return ""
    if clean.startswith(("https://", "http://", "/api/v1/community/media/")):
        return clean[:1200]
    return ""


def init_community_and_rbac_tables(conn: sqlite3.Connection, hash_pwd_fn) -> None:
    """Idempotently migrates users RBAC columns, sessions, community tables, and default admin."""
    cur = conn.cursor()

    cur.execute("PRAGMA table_info(users)")
    user_cols = {row[1] for row in cur.fetchall()}
    if "role" not in user_cols:
        cur.execute("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'user'")
    if "is_banned" not in user_cols:
        cur.execute("ALTER TABLE users ADD COLUMN is_banned INTEGER NOT NULL DEFAULT 0")

    cur.execute("""
    CREATE TABLE IF NOT EXISTS user_sessions (
        token TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TEXT NOT NULL
    )
    """)
    cur.execute("CREATE INDEX IF NOT EXISTS idx_user_sessions_uid ON user_sessions(user_id)")

    cur.execute("""
    CREATE TABLE IF NOT EXISTS community_posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        product_name TEXT NOT NULL,
        brand TEXT NOT NULL DEFAULT '',
        verdict TEXT NOT NULL DEFAULT 'GREEN',
        ingredients_text TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        image_url TEXT NOT NULL DEFAULT '',
        barcode TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'visible',
        hidden_reason TEXT NOT NULL DEFAULT '',
        hidden_by INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    )
    """)
    cur.execute("CREATE INDEX IF NOT EXISTS idx_community_posts_status ON community_posts(status, id DESC)")

    cur.execute("""
    CREATE TABLE IF NOT EXISTS community_likes (
        post_id INTEGER NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TEXT NOT NULL,
        PRIMARY KEY (post_id, user_id)
    )
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS community_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id INTEGER NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'visible',
        created_at TEXT NOT NULL
    )
    """)
    cur.execute("CREATE INDEX IF NOT EXISTS idx_community_comments_post ON community_comments(post_id, id ASC)")

    cur.execute("""
    CREATE TABLE IF NOT EXISTS community_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id INTEGER REFERENCES community_posts(id) ON DELETE CASCADE,
        comment_id INTEGER REFERENCES community_comments(id) ON DELETE CASCADE,
        reporter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        reason TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        resolved_by INTEGER,
        resolved_note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        resolved_at TEXT
    )
    """)
    cur.execute("CREATE INDEX IF NOT EXISTS idx_community_reports_status ON community_reports(status, id DESC)")

    # Seed default Admin account (configurable via environment variables)
    admin_email = os.environ.get("NUTRIVIET_ADMIN_EMAIL", "admin@nutriviet.vn").strip().lower()
    admin_password = os.environ.get("NUTRIVIET_ADMIN_PASSWORD", "AdminNutri2026!")
    if admin_email and admin_password:
        cur.execute("SELECT id, role, is_verified FROM users WHERE email = ?", (admin_email,))
        existing = cur.fetchone()
        if not existing:
            pwd_hash, salt = hash_pwd_fn(admin_password)
            cur.execute(
                """
                INSERT INTO users (full_name, email, password_hash, salt, is_verified, role, is_banned, created_at)
                VALUES (?, ?, ?, ?, 1, 'admin', 0, ?)
                """,
                ("NutriViet Admin", admin_email, pwd_hash, salt, _utc_now_iso()),
            )
        elif existing["role"] != "admin" or existing["is_verified"] != 1:
            cur.execute(
                "UPDATE users SET role = 'admin', is_verified = 1, is_banned = 0 WHERE id = ?",
                (existing["id"],),
            )


def issue_session_token(conn: sqlite3.Connection, user_id: int) -> str:
    token = secrets.token_urlsafe(32)
    conn.execute(
        "INSERT INTO user_sessions (token, user_id, created_at) VALUES (?, ?, ?)",
        (token, int(user_id), _utc_now_iso()),
    )
    conn.commit()
    return token


def revoke_user_sessions(conn: sqlite3.Connection, user_id: int) -> None:
    conn.execute("DELETE FROM user_sessions WHERE user_id = ?", (int(user_id),))


def _extract_bearer_token(environ: dict) -> str:
    auth = (environ.get("HTTP_AUTHORIZATION") or "").strip()
    if auth.lower().startswith("bearer "):
        return auth[7:].strip()
    return (environ.get("HTTP_X_AUTH_TOKEN") or "").strip()


def authenticate_request(environ: dict, conn: sqlite3.Connection):
    """Returns `(user_dict, None)` or `(None, (status_str, error_payload))`."""
    token = _extract_bearer_token(environ)
    if not token:
        return None, (
            "401 Unauthorized",
            {
                "success": False,
                "code": "AUTH_REQUIRED",
                "message": "Authentication is required to access Community features.",
            },
        )
    row = conn.execute(
        """
        SELECT u.id, u.full_name, u.email, u.is_verified, u.role, u.is_banned
        FROM user_sessions s
        JOIN users u ON u.id = s.user_id
        WHERE s.token = ?
        """,
        (token,),
    ).fetchone()
    if not row:
        return None, (
            "401 Unauthorized",
            {
                "success": False,
                "code": "INVALID_TOKEN",
                "message": "Session expired or invalid. Please sign in again.",
            },
        )
    user = dict(row)
    if int(user.get("is_banned") or 0) == 1:
        return None, (
            "403 Forbidden",
            {
                "success": False,
                "code": "ACCOUNT_BANNED",
                "message": "This account has been suspended by an administrator.",
            },
        )
    return user, None


def _json_response(start_response, headers, status: str, payload: dict):
    start_response(status, headers)
    return [json.dumps(payload, ensure_ascii=False).encode("utf-8")]


def _serialize_post(row: sqlite3.Row, viewer: dict, liked_ids: set[int]) -> dict:
    is_admin = viewer["role"] == "admin"
    is_owner = int(row["user_id"]) == int(viewer["id"])
    return {
        "id": row["id"],
        "author_id": row["user_id"],
        "author_name": row["author_name"],
        "author_role": row["author_role"],
        "product_name": row["product_name"],
        "brand": row["brand"],
        "verdict": row["verdict"],
        "ingredients_text": row["ingredients_text"],
        "content": row["content"],
        "image_url": row["image_url"],
        "barcode": row["barcode"],
        "status": row["status"],
        "hidden_reason": row["hidden_reason"],
        "likes_count": int(row["likes_count"]),
        "comments_count": int(row["comments_count"]),
        "is_liked": row["id"] in liked_ids,
        "can_delete": is_owner or is_admin,
        "can_moderate": is_admin,
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _fetch_post_by_id(conn: sqlite3.Connection, post_id: int, viewer: dict) -> dict | None:
    row = conn.execute(
        """
        SELECT p.*, u.full_name AS author_name, u.role AS author_role,
               (SELECT COUNT(*) FROM community_likes l WHERE l.post_id = p.id) AS likes_count,
               (SELECT COUNT(*) FROM community_comments c WHERE c.post_id = p.id AND c.status = 'visible') AS comments_count
        FROM community_posts p
        JOIN users u ON u.id = p.user_id
        WHERE p.id = ?
        """,
        (post_id,),
    ).fetchone()
    if not row:
        return None
    liked = conn.execute(
        "SELECT 1 FROM community_likes WHERE post_id = ? AND user_id = ?",
        (post_id, viewer["id"]),
    ).fetchone()
    return _serialize_post(row, viewer, {post_id} if liked else set())


def handle_community_and_admin_route(
    method: str,
    path: str,
    query_string: str,
    body: dict,
    environ: dict,
    headers: list,
    start_response,
    get_db_fn,
    public_base_url: str,
):
    """Handles `/api/v1/community/*` and `/api/v1/admin/*`; returns None if unrelated."""
    if not (path.startswith("/api/v1/community/") or path.startswith("/api/v1/admin/")):
        return None

    # ------------------------------------------------------------------
    # Public static serving for verified uploaded community images
    # ------------------------------------------------------------------
    if path.startswith("/api/v1/community/media/") and method == "GET":
        filename = path[len("/api/v1/community/media/"):]
        if not _SAFE_MEDIA_NAME_RE.match(filename):
            return _json_response(start_response, headers, "404 Not Found", {"success": False, "message": "Not found"})
        file_path = os.path.join(_get_upload_dir(), filename)
        if not os.path.isfile(file_path):
            return _json_response(start_response, headers, "404 Not Found", {"success": False, "message": "Not found"})
        ext = filename.rsplit(".", 1)[1].lower()
        mime = "image/png" if ext == "png" else ("image/webp" if ext == "webp" else "image/jpeg")
        with open(file_path, "rb") as f:
            data = f.read()
        start_response(
            "200 OK",
            [
                ("Content-Type", mime),
                ("Cache-Control", "public, max-age=86400"),
                ("Access-Control-Allow-Origin", "*"),
            ],
        )
        return [data]

    conn = get_db_fn()
    try:
        viewer, err = authenticate_request(environ, conn)
        if err is not None:
            return _json_response(start_response, headers, err[0], err[1])

        query = urllib.parse.parse_qs(query_string or "")

        # ==============================================================
        # COMMUNITY ROUTES (Authenticated users + admins)
        # ==============================================================
        if path == "/api/v1/community/upload-image" and method == "POST":
            b64_data = (body.get("data_base64") or "").strip()
            if "," in b64_data and b64_data.lower().startswith("data:"):
                b64_data = b64_data.split(",", 1)[1]
            try:
                raw = base64.b64decode(b64_data, validate=True)
            except Exception:
                return _json_response(
                    start_response, headers, "400 Bad Request",
                    {"success": False, "message": "Invalid base64 image payload."},
                )
            detected = _detect_image_ext_and_mime(raw)
            if not detected:
                return _json_response(
                    start_response, headers, "400 Bad Request",
                    {"success": False, "message": "Unsupported image format or size exceeds 2MB (JPEG/PNG/WebP only)."},
                )
            ext, mime = detected
            filename = f"{secrets.token_hex(16)}.{ext}"
            full_path = os.path.join(_get_upload_dir(), filename)
            with open(full_path, "wb") as f:
                f.write(raw)
            rel_path = f"/api/v1/community/media/{filename}"
            return _json_response(
                start_response, headers, "201 Created",
                {
                    "success": True,
                    "image_path": rel_path,
                    "image_url": f"{public_base_url}{rel_path}",
                    "mime_type": mime,
                    "size_bytes": len(raw),
                },
            )

        if path == "/api/v1/community/posts" and method == "GET":
            verdict = (query.get("verdict", ["ALL"])[0] or "ALL").strip().upper()
            q_text = (query.get("q", [""])[0] or "").strip().lower()
            include_hidden = (
                viewer["role"] == "admin"
                and (query.get("include_hidden", ["0"])[0] or "0").strip() in ("1", "true", "yes")
            )
            limit = max(1, min(_safe_int(query.get("limit", ["30"])[0], 30), 100))
            offset = max(0, _safe_int(query.get("offset", ["0"])[0], 0))

            where = []
            params = []
            if not include_hidden:
                where.append("p.status = 'visible'")
            if verdict in _VALID_VERDICTS:
                where.append("p.verdict = ?")
                params.append(verdict)
            if q_text:
                like_q = f"%{q_text}%"
                where.append(
                    "(LOWER(p.product_name) LIKE ? OR LOWER(p.brand) LIKE ? OR LOWER(p.content) LIKE ? OR LOWER(p.ingredients_text) LIKE ?)"
                )
                params.extend([like_q, like_q, like_q, like_q])

            where_sql = ("WHERE " + " AND ".join(where)) if where else ""
            rows = conn.execute(
                f"""
                SELECT p.*, u.full_name AS author_name, u.role AS author_role,
                       (SELECT COUNT(*) FROM community_likes l WHERE l.post_id = p.id) AS likes_count,
                       (SELECT COUNT(*) FROM community_comments c WHERE c.post_id = p.id AND c.status = 'visible') AS comments_count
                FROM community_posts p
                JOIN users u ON u.id = p.user_id
                {where_sql}
                ORDER BY p.id DESC
                LIMIT ? OFFSET ?
                """,
                (*params, limit, offset),
            ).fetchall()

            post_ids = [r["id"] for r in rows]
            liked_ids: set[int] = set()
            if post_ids:
                placeholders = ",".join("?" for _ in post_ids)
                for lr in conn.execute(
                    f"SELECT post_id FROM community_likes WHERE user_id = ? AND post_id IN ({placeholders})",
                    (viewer["id"], *post_ids),
                ).fetchall():
                    liked_ids.add(lr["post_id"])

            posts = [_serialize_post(r, viewer, liked_ids) for r in rows]
            return _json_response(
                start_response, headers, "200 OK",
                {"success": True, "count": len(posts), "posts": posts},
            )

        if path == "/api/v1/community/posts" and method == "POST":
            product_name = (body.get("product_name") or "").strip()
            brand = (body.get("brand") or "").strip()
            verdict = (body.get("verdict") or "GREEN").strip().upper()
            if verdict not in _VALID_VERDICTS:
                verdict = "GREEN"
            ingredients_text = (body.get("ingredients_text") or "").strip()
            content = (body.get("content") or "").strip()
            image_url = _sanitize_image_url(body.get("image_url") or "")
            barcode = (body.get("barcode") or "").strip()[:64]

            if not product_name:
                return _json_response(
                    start_response, headers, "400 Bad Request",
                    {"success": False, "message": "Product name is required."},
                )

            now = _utc_now_iso()
            cur = conn.cursor()
            cur.execute(
                """
                INSERT INTO community_posts
                (user_id, product_name, brand, verdict, ingredients_text, content, image_url, barcode, status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'visible', ?, ?)
                """,
                (
                    viewer["id"], product_name[:180], brand[:120], verdict,
                    ingredients_text[:2000], content[:2000], image_url, barcode, now, now,
                ),
            )
            post_id = cur.lastrowid
            conn.commit()
            post = _fetch_post_by_id(conn, post_id, viewer)
            return _json_response(
                start_response, headers, "201 Created",
                {"success": True, "post": post},
            )

        m_like = re.match(r"^/api/v1/community/posts/(\d+)/like$", path)
        if m_like and method == "POST":
            post_id = int(m_like.group(1))
            exists = conn.execute("SELECT id, status FROM community_posts WHERE id = ?", (post_id,)).fetchone()
            if not exists or (exists["status"] != "visible" and viewer["role"] != "admin"):
                return _json_response(start_response, headers, "404 Not Found", {"success": False, "message": "Post not found."})
            already = conn.execute(
                "SELECT 1 FROM community_likes WHERE post_id = ? AND user_id = ?",
                (post_id, viewer["id"]),
            ).fetchone()
            if already:
                conn.execute("DELETE FROM community_likes WHERE post_id = ? AND user_id = ?", (post_id, viewer["id"]))
                is_liked = False
            else:
                conn.execute(
                    "INSERT INTO community_likes (post_id, user_id, created_at) VALUES (?, ?, ?)",
                    (post_id, viewer["id"], _utc_now_iso()),
                )
                is_liked = True
            conn.commit()
            cnt = conn.execute("SELECT COUNT(*) AS c FROM community_likes WHERE post_id = ?", (post_id,)).fetchone()["c"]
            return _json_response(
                start_response, headers, "200 OK",
                {"success": True, "post_id": post_id, "is_liked": is_liked, "likes_count": int(cnt)},
            )

        m_comments = re.match(r"^/api/v1/community/posts/(\d+)/comments$", path)
        if m_comments:
            post_id = int(m_comments.group(1))
            post_row = conn.execute("SELECT id, status FROM community_posts WHERE id = ?", (post_id,)).fetchone()
            if not post_row or (post_row["status"] != "visible" and viewer["role"] != "admin"):
                return _json_response(start_response, headers, "404 Not Found", {"success": False, "message": "Post not found."})

            if method == "GET":
                rows = conn.execute(
                    """
                    SELECT c.id, c.post_id, c.user_id, c.content, c.created_at,
                           u.full_name AS author_name, u.role AS author_role
                    FROM community_comments c
                    JOIN users u ON u.id = c.user_id
                    WHERE c.post_id = ? AND c.status = 'visible'
                    ORDER BY c.id ASC
                    """,
                    (post_id,),
                ).fetchall()
                is_admin = viewer["role"] == "admin"
                comments = [
                    {
                        "id": r["id"],
                        "post_id": r["post_id"],
                        "author_id": r["user_id"],
                        "author_name": r["author_name"],
                        "author_role": r["author_role"],
                        "content": r["content"],
                        "can_delete": is_admin or int(r["user_id"]) == int(viewer["id"]),
                        "created_at": r["created_at"],
                    }
                    for r in rows
                ]
                return _json_response(
                    start_response, headers, "200 OK",
                    {"success": True, "count": len(comments), "comments": comments},
                )

            if method == "POST":
                content = (body.get("content") or "").strip()
                if not content:
                    return _json_response(
                        start_response, headers, "400 Bad Request",
                        {"success": False, "message": "Comment content cannot be empty."},
                    )
                now = _utc_now_iso()
                cur = conn.cursor()
                cur.execute(
                    "INSERT INTO community_comments (post_id, user_id, content, status, created_at) VALUES (?, ?, ?, 'visible', ?)",
                    (post_id, viewer["id"], content[:1000], now),
                )
                cm_id = cur.lastrowid
                conn.commit()
                return _json_response(
                    start_response, headers, "201 Created",
                    {
                        "success": True,
                        "comment": {
                            "id": cm_id,
                            "post_id": post_id,
                            "author_id": viewer["id"],
                            "author_name": viewer["full_name"],
                            "author_role": viewer["role"],
                            "content": content[:1000],
                            "can_delete": True,
                            "created_at": now,
                        },
                    },
                )

        m_del_post = re.match(r"^/api/v1/community/posts/(\d+)/delete$", path)
        if m_del_post and method == "POST":
            post_id = int(m_del_post.group(1))
            row = conn.execute("SELECT id, user_id FROM community_posts WHERE id = ?", (post_id,)).fetchone()
            if not row:
                return _json_response(start_response, headers, "404 Not Found", {"success": False, "message": "Post not found."})
            if viewer["role"] != "admin" and int(row["user_id"]) != int(viewer["id"]):
                return _json_response(start_response, headers, "403 Forbidden", {"success": False, "message": "Not allowed to delete this post."})
            conn.execute("DELETE FROM community_posts WHERE id = ?", (post_id,))
            conn.commit()
            return _json_response(start_response, headers, "200 OK", {"success": True, "deleted_post_id": post_id})

        m_del_cm = re.match(r"^/api/v1/community/comments/(\d+)/delete$", path)
        if m_del_cm and method == "POST":
            cm_id = int(m_del_cm.group(1))
            row = conn.execute("SELECT id, user_id FROM community_comments WHERE id = ?", (cm_id,)).fetchone()
            if not row:
                return _json_response(start_response, headers, "404 Not Found", {"success": False, "message": "Comment not found."})
            if viewer["role"] != "admin" and int(row["user_id"]) != int(viewer["id"]):
                return _json_response(start_response, headers, "403 Forbidden", {"success": False, "message": "Not allowed to delete this comment."})
            conn.execute("DELETE FROM community_comments WHERE id = ?", (cm_id,))
            conn.commit()
            return _json_response(start_response, headers, "200 OK", {"success": True, "deleted_comment_id": cm_id})

        if path == "/api/v1/community/reports" and method == "POST":
            post_id = body.get("post_id")
            comment_id = body.get("comment_id")
            reason = (body.get("reason") or "").strip()
            if (not post_id and not comment_id) or not reason:
                return _json_response(
                    start_response, headers, "400 Bad Request",
                    {"success": False, "message": "Target post/comment and reason are required."},
                )
            cur = conn.cursor()
            cur.execute(
                """
                INSERT INTO community_reports (post_id, comment_id, reporter_id, reason, status, created_at)
                VALUES (?, ?, ?, ?, 'pending', ?)
                """,
                (int(post_id) if post_id else None, int(comment_id) if comment_id else None, viewer["id"], reason[:500], _utc_now_iso()),
            )
            rep_id = cur.lastrowid
            conn.commit()
            return _json_response(start_response, headers, "201 Created", {"success": True, "report_id": rep_id})

        # ==============================================================
        # ADMIN ROUTES (Strictly role == 'admin' server-side!)
        # ==============================================================
        if path.startswith("/api/v1/admin/"):
            if viewer["role"] != "admin":
                return _json_response(
                    start_response, headers, "403 Forbidden",
                    {"success": False, "code": "ADMIN_REQUIRED", "message": "Administrator privileges required."},
                )

            if path == "/api/v1/admin/overview" and method == "GET":
                stats = {
                    "total_users": conn.execute("SELECT COUNT(*) AS c FROM users").fetchone()["c"],
                    "admin_users": conn.execute("SELECT COUNT(*) AS c FROM users WHERE role = 'admin'").fetchone()["c"],
                    "banned_users": conn.execute("SELECT COUNT(*) AS c FROM users WHERE is_banned = 1").fetchone()["c"],
                    "visible_posts": conn.execute("SELECT COUNT(*) AS c FROM community_posts WHERE status = 'visible'").fetchone()["c"],
                    "hidden_posts": conn.execute("SELECT COUNT(*) AS c FROM community_posts WHERE status = 'hidden'").fetchone()["c"],
                    "pending_reports": conn.execute("SELECT COUNT(*) AS c FROM community_reports WHERE status = 'pending'").fetchone()["c"],
                }
                return _json_response(start_response, headers, "200 OK", {"success": True, "stats": stats})

            m_mod = re.match(r"^/api/v1/admin/posts/(\d+)/moderate$", path)
            if m_mod and method == "POST":
                post_id = int(m_mod.group(1))
                action = (body.get("action") or "").strip().lower()
                reason = (body.get("reason") or "").strip()[:300]
                row = conn.execute("SELECT id FROM community_posts WHERE id = ?", (post_id,)).fetchone()
                if not row:
                    return _json_response(start_response, headers, "404 Not Found", {"success": False, "message": "Post not found."})

                if action == "delete":
                    conn.execute("DELETE FROM community_posts WHERE id = ?", (post_id,))
                    conn.commit()
                    return _json_response(start_response, headers, "200 OK", {"success": True, "action": "delete", "post_id": post_id})
                if action in ("hide", "unhide"):
                    new_status = "hidden" if action == "hide" else "visible"
                    conn.execute(
                        "UPDATE community_posts SET status = ?, hidden_reason = ?, hidden_by = ?, updated_at = ? WHERE id = ?",
                        (new_status, reason if action == "hide" else "", viewer["id"] if action == "hide" else None, _utc_now_iso(), post_id),
                    )
                    conn.commit()
                    return _json_response(
                        start_response, headers, "200 OK",
                        {"success": True, "action": action, "post": _fetch_post_by_id(conn, post_id, viewer)},
                    )
                return _json_response(start_response, headers, "400 Bad Request", {"success": False, "message": "Invalid moderation action."})

            if path == "/api/v1/admin/reports" and method == "GET":
                st_filter = (query.get("status", ["pending"])[0] or "pending").strip().lower()
                where_sql = "WHERE r.status = ?" if st_filter in ("pending", "resolved", "dismissed") else ""
                params = (st_filter,) if where_sql else ()
                rows = conn.execute(
                    f"""
                    SELECT r.*, u.full_name AS reporter_name, u.email AS reporter_email,
                           p.product_name AS post_product_name, p.status AS post_status,
                           pu.full_name AS post_author_name
                    FROM community_reports r
                    JOIN users u ON u.id = r.reporter_id
                    LEFT JOIN community_posts p ON p.id = r.post_id
                    LEFT JOIN users pu ON pu.id = p.user_id
                    {where_sql}
                    ORDER BY r.id DESC
                    LIMIT 100
                    """,
                    params,
                ).fetchall()
                reports = [dict(r) for r in rows]
                return _json_response(start_response, headers, "200 OK", {"success": True, "count": len(reports), "reports": reports})

            m_rep_res = re.match(r"^/api/v1/admin/reports/(\d+)/resolve$", path)
            if m_rep_res and method == "POST":
                rep_id = int(m_rep_res.group(1))
                action = (body.get("action") or "dismiss").strip().lower()
                note = (body.get("note") or "").strip()[:300]
                rep = conn.execute("SELECT * FROM community_reports WHERE id = ?", (rep_id,)).fetchone()
                if not rep:
                    return _json_response(start_response, headers, "404 Not Found", {"success": False, "message": "Report not found."})

                now = _utc_now_iso()
                final_status = "dismissed" if action == "dismiss" else "resolved"
                if action == "hide_post" and rep["post_id"]:
                    conn.execute(
                        "UPDATE community_posts SET status = 'hidden', hidden_reason = ?, hidden_by = ?, updated_at = ? WHERE id = ?",
                        (note or rep["reason"], viewer["id"], now, rep["post_id"]),
                    )
                elif action == "delete_post" and rep["post_id"]:
                    conn.execute("DELETE FROM community_posts WHERE id = ?", (rep["post_id"],))

                conn.execute(
                    "UPDATE community_reports SET status = ?, resolved_by = ?, resolved_note = ?, resolved_at = ? WHERE id = ?",
                    (final_status, viewer["id"], note, now, rep_id),
                )
                conn.commit()
                return _json_response(start_response, headers, "200 OK", {"success": True, "report_id": rep_id, "status": final_status})

            if path == "/api/v1/admin/users" and method == "GET":
                rows = conn.execute(
                    "SELECT id, full_name, email, role, is_verified, is_banned, created_at FROM users ORDER BY id ASC"
                ).fetchall()
                return _json_response(start_response, headers, "200 OK", {"success": True, "users": [dict(r) for r in rows]})

            m_upd_u = re.match(r"^/api/v1/admin/users/(\d+)/update$", path)
            if m_upd_u and method == "POST":
                target_id = int(m_upd_u.group(1))
                target = conn.execute("SELECT id, full_name, email, role, is_verified, is_banned FROM users WHERE id = ?", (target_id,)).fetchone()
                if not target:
                    return _json_response(start_response, headers, "404 Not Found", {"success": False, "message": "User not found."})

                new_role = body.get("role")
                new_banned = body.get("is_banned")

                if target_id == int(viewer["id"]):
                    if (new_banned is not None and bool(new_banned)) or (
                        new_role is not None and str(new_role).strip().lower() != "admin"
                    ):
                        return _json_response(
                            start_response, headers, "400 Bad Request",
                            {"success": False, "message": "Administrators cannot ban or demote their own account."},
                        )

                if new_role is not None:
                    role_clean = str(new_role).strip().lower()
                    if role_clean not in ("user", "admin"):
                        return _json_response(start_response, headers, "400 Bad Request", {"success": False, "message": "Role must be 'user' or 'admin'."})
                    conn.execute("UPDATE users SET role = ? WHERE id = ?", (role_clean, target_id))

                if new_banned is not None:
                    ban_val = 1 if bool(new_banned) else 0
                    conn.execute("UPDATE users SET is_banned = ? WHERE id = ?", (ban_val, target_id))
                    if ban_val == 1:
                        revoke_user_sessions(conn, target_id)

                conn.commit()
                updated = conn.execute(
                    "SELECT id, full_name, email, role, is_verified, is_banned, created_at FROM users WHERE id = ?",
                    (target_id,),
                ).fetchone()
                return _json_response(start_response, headers, "200 OK", {"success": True, "user": dict(updated)})

        return _json_response(start_response, headers, "404 Not Found", {"success": False, "message": "Endpoint not found."})
    finally:
        conn.close()
