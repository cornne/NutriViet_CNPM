"""
NutriViet Authentication Database Module (SQLite)
PA3-2026 Deliverable - Section E Data Persistence with Email Verification
"""

import sqlite3
import hashlib
import os
import secrets
import datetime
import json

DB_PATH = os.path.join(os.path.dirname(__file__), "nutriviet.db")

def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL COLLATE NOCASE,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        is_verified INTEGER DEFAULT 0,
        verification_token TEXT,
        created_at TEXT NOT NULL
    )
    """)
    conn.commit()

    # Migration check for existing databases without is_verified / verification_token
    cursor.execute("PRAGMA table_info(users)")
    columns = [row[1] for row in cursor.fetchall()]
    if "is_verified" not in columns:
        cursor.execute("ALTER TABLE users ADD COLUMN is_verified INTEGER DEFAULT 0")
    if "verification_token" not in columns:
        cursor.execute("ALTER TABLE users ADD COLUMN verification_token TEXT")
    if "reset_token" not in columns:
        cursor.execute("ALTER TABLE users ADD COLUMN reset_token TEXT")
    conn.commit()

    # 2. User Allergens Table (FG2 Deliverable)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_allergens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        allergen_code TEXT NOT NULL,
        allergen_name TEXT NOT NULL,
        severity TEXT NOT NULL DEFAULT 'high',
        updated_at TEXT NOT NULL
    )
    """)
    cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_user_allergen ON user_allergens(user_id, allergen_code)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_user_allergens_user_id ON user_allergens(user_id)")
    conn.commit()

    # 3. User Physical / Nutrition Metrics Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_metrics (
        user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        age INTEGER DEFAULT 22,
        gender TEXT DEFAULT 'male',
        height REAL DEFAULT 170.0,
        weight REAL DEFAULT 65.0,
        activity_level TEXT DEFAULT 'moderate',
        target_calories INTEGER DEFAULT 2100,
        updated_at TEXT NOT NULL
    )
    """)
    conn.commit()

    # 4. Packaging OCR Scan History Table (FG3 Deliverable)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS scan_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        member_name TEXT NOT NULL DEFAULT '',
        label_title TEXT NOT NULL DEFAULT 'Kết quả quét',
        raw_text TEXT NOT NULL,
        normalized_text TEXT NOT NULL DEFAULT '',
        tokens_json TEXT NOT NULL DEFAULT '[]',
        additives_json TEXT NOT NULL DEFAULT '[]',
        verdict TEXT NOT NULL DEFAULT 'GREEN',
        risk_level TEXT NOT NULL DEFAULT 'safe',
        risk_label_vi TEXT NOT NULL DEFAULT 'An toàn',
        additive_count INTEGER NOT NULL DEFAULT 0,
        warning_count INTEGER NOT NULL DEFAULT 0,
        result_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL
    )
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_scan_history_user ON scan_history(user_id, id DESC)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_scan_history_created ON scan_history(user_id, created_at DESC)")
    conn.commit()

    # Auto-migration for existing scan_history tables
    cursor.execute("PRAGMA table_info(scan_history)")
    sh_cols = [row[1] for row in cursor.fetchall()]
    if "normalized_text" not in sh_cols:
        cursor.execute("ALTER TABLE scan_history ADD COLUMN normalized_text TEXT NOT NULL DEFAULT ''")
    if "tokens_json" not in sh_cols:
        cursor.execute("ALTER TABLE scan_history ADD COLUMN tokens_json TEXT NOT NULL DEFAULT '[]'")
    if "additives_json" not in sh_cols:
        cursor.execute("ALTER TABLE scan_history ADD COLUMN additives_json TEXT NOT NULL DEFAULT '[]'")
    conn.commit()

    # Seed an initial demo account if empty
    cursor.execute("SELECT COUNT(*) FROM users")
    if cursor.fetchone()[0] == 0:
        create_user("Nguyen Van Nutri", "demo@nutriviet.vn", "NutriPass123!", is_verified=1)
        print("[DB] Initialized database and seeded verified demo user: demo@nutriviet.vn (NutriPass123!)")
    else:
        print("[DB] Database connected successfully.")
    conn.close()

def hash_password(password: str, salt: str = None) -> tuple[str, str]:
    if not salt:
        salt = os.urandom(16).hex()
    pwd_bytes = password.encode('utf-8')
    salt_bytes = salt.encode('utf-8')
    key = hashlib.pbkdf2_hmac('sha256', pwd_bytes, salt_bytes, 100000)
    return key.hex(), salt

def verify_password(password: str, stored_hash: str, salt: str) -> bool:
    new_hash, _ = hash_password(password, salt)
    return new_hash == stored_hash

def create_user(full_name: str, email: str, password: str, is_verified: int = 0) -> tuple[dict, str]:
    full_name = full_name.strip()
    email = email.strip().lower()
    
    if not full_name or not email or not password:
        return None, "All fields are required"
    if len(password) < 6:
        return None, "Password must be at least 6 characters"
    
    conn = get_connection()
    cursor = conn.cursor()
    
    # Check duplicate
    cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
    if cursor.fetchone():
        conn.close()
        return None, "EMAIL_ALREADY_EXISTS"
    
    pwd_hash, salt = hash_password(password)
    verification_token = secrets.token_urlsafe(32)
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    
    cursor.execute("""
        INSERT INTO users (full_name, email, password_hash, salt, is_verified, verification_token, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (full_name, email, pwd_hash, salt, is_verified, verification_token, now))
    conn.commit()
    user_id = cursor.lastrowid
    conn.close()
    
    return {
        "id": user_id,
        "full_name": full_name,
        "email": email,
        "is_verified": bool(is_verified),
        "verification_token": verification_token,
        "created_at": now
    }, None

def verify_user_token(token: str) -> tuple[dict, str]:
    if not token:
        return None, "Invalid token"

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, full_name, email, is_verified FROM users WHERE verification_token = ?", (token,))
    row = cursor.fetchone()

    if not row:
        conn.close()
        return None, "TOKEN_NOT_FOUND"

    cursor.execute("UPDATE users SET is_verified = 1 WHERE id = ?", (row["id"],))
    conn.commit()
    conn.close()

    return {
        "id": row["id"],
        "full_name": row["full_name"],
        "email": row["email"],
        "is_verified": True
    }, None

def resend_token_for_email(email: str) -> tuple[dict, str]:
    email = email.strip().lower()
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, full_name, email, is_verified FROM users WHERE email = ?", (email,))
    row = cursor.fetchone()

    if not row:
        conn.close()
        return None, "USER_NOT_FOUND"
    if row["is_verified"] == 1:
        conn.close()
        return None, "ALREADY_VERIFIED"

    new_token = secrets.token_urlsafe(32)
    cursor.execute("UPDATE users SET verification_token = ? WHERE id = ?", (new_token, row["id"]))
    conn.commit()
    conn.close()

    return {
        "id": row["id"],
        "full_name": row["full_name"],
        "email": row["email"],
        "verification_token": new_token
    }, None

def create_reset_token(email: str) -> tuple[dict, str]:
    email = email.strip().lower()
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, full_name, email FROM users WHERE email = ?", (email,))
    row = cursor.fetchone()

    if not row:
        conn.close()
        return None, "USER_NOT_FOUND"

    new_token = secrets.token_urlsafe(32)
    cursor.execute("UPDATE users SET reset_token = ? WHERE id = ?", (new_token, row["id"]))
    conn.commit()
    conn.close()

    return {
        "id": row["id"],
        "full_name": row["full_name"],
        "email": row["email"],
        "reset_token": new_token
    }, None

def authenticate_user(email: str, password: str) -> tuple[dict, str]:
    email = email.strip().lower()
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, full_name, email, password_hash, salt, is_verified, created_at FROM users WHERE email = ?", (email,))
    row = cursor.fetchone()
    conn.close()
    
    if not row:
        return None, "INVALID_CREDENTIALS"
    
    if not verify_password(password, row["password_hash"], row["salt"]):
        return None, "INVALID_CREDENTIALS"

    if row["is_verified"] != 1:
        return None, "EMAIL_NOT_VERIFIED"

    return {
        "id": row["id"],
        "full_name": row["full_name"],
        "email": row["email"],
        "created_at": row["created_at"]
    }, None

def reset_user_password(email: str, new_password: str) -> tuple[dict, str]:
    email = email.strip().lower()
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, full_name, email FROM users WHERE email = ?", (email,))
    row = cursor.fetchone()
    if not row:
        conn.close()
        return None, "USER_NOT_FOUND"

    pwd_hash, salt = hash_password(new_password)
    cursor.execute("UPDATE users SET password_hash = ?, salt = ?, is_verified = 1 WHERE id = ?", (pwd_hash, salt, row["id"]))
    conn.commit()
    conn.close()

    return {
        "id": row["id"],
        "full_name": row["full_name"],
        "email": row["email"],
    }, None

def get_user_allergens(user_id: int) -> list:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT allergen_code as code, allergen_name as name, severity, updated_at
        FROM user_allergens 
        WHERE user_id = ? 
        ORDER BY id ASC
    """, (user_id,))
    rows = cursor.fetchall()
    conn.close()
    return [dict(r) for r in rows]

def save_user_allergens(user_id: int, allergens: list) -> tuple:
    if not user_id:
        return False, "User ID is required"
    
    conn = get_connection()
    cursor = conn.cursor()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    
    try:
        # Atomic transaction: delete existing and insert new
        cursor.execute("DELETE FROM user_allergens WHERE user_id = ?", (user_id,))
        for item in allergens:
            code = item.get("code") or item.get("allergen_code", "")
            name = item.get("name") or item.get("allergen_name", "")
            severity = item.get("severity", "high").lower()
            if code and name:
                cursor.execute("""
                    INSERT INTO user_allergens (user_id, allergen_code, allergen_name, severity, updated_at)
                    VALUES (?, ?, ?, ?, ?)
                """, (user_id, code, name, severity, now))
        conn.commit()
        conn.close()
        return True, None
    except Exception as e:
        conn.rollback()
        conn.close()
        return False, str(e)

def change_user_password(user_id: int, current_pwd: str, new_pwd: str) -> tuple[bool, str]:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, password_hash, salt FROM users WHERE id = ?", (user_id,))
    row = cursor.fetchone()
    if not row:
        conn.close()
        return False, "Không tìm thấy tài khoản người dùng."
    if not verify_password(current_pwd, row["password_hash"], row["salt"]):
        conn.close()
        return False, "Mật khẩu hiện tại (hoặc mật khẩu tạm) không chính xác."
    
    pwd_hash, salt = hash_password(new_pwd)
    cursor.execute("UPDATE users SET password_hash = ?, salt = ?, is_verified = 1 WHERE id = ?", (pwd_hash, salt, user_id))
    conn.commit()
    conn.close()
    return True, None

def get_user_metrics(user_id: int) -> dict:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT age, gender, height, weight, activity_level, updated_at FROM user_metrics WHERE user_id = ?", (user_id,))
    row = cursor.fetchone()
    conn.close()
    if row:
        return dict(row)
    return {"age": 22, "gender": "male", "height": 170.0, "weight": 65.0, "activity_level": "moderate"}

def save_user_metrics(user_id: int, age: int, gender: str, height: float, weight: float, activity_level: str = 'moderate') -> tuple[bool, str]:
    conn = get_connection()
    cursor = conn.cursor()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    try:
        cursor.execute("""
        INSERT INTO user_metrics (user_id, age, gender, height, weight, activity_level, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
            age = excluded.age,
            gender = excluded.gender,
            height = excluded.height,
            weight = excluded.weight,
            activity_level = excluded.activity_level,
            updated_at = excluded.updated_at
        """, (user_id, age, gender, height, weight, activity_level, now))
        conn.commit()
        conn.close()
        return True, None
    except Exception as e:
        conn.rollback()
        conn.close()
        return False, str(e)

def get_all_users() -> list[dict]:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, full_name, email, is_verified, created_at FROM users ORDER BY id ASC")
    rows = cursor.fetchall()
    conn.close()
    return [dict(r) for r in rows]

# -------------------------------------------------------------
# Packaging OCR Scan History DAO (FG3: UC06, UC07, UC08)
# -------------------------------------------------------------

def save_scan_session(
    user_id: int,
    raw_text: str,
    label_title: str = "Kết quả quét",
    member_name: str = "",
    normalized_text: str = "",
    tokens: list = None,
    additives: list = None,
    verdict: str = "GREEN",
    risk_level: str = "safe",
    risk_label_vi: str = "An toàn",
    additive_count: int = 0,
    warning_count: int = 0,
    result_json: dict = None
) -> tuple[dict, str]:
    if not user_id:
        return None, "user_id is required"
    if not raw_text:
        return None, "raw_text is required"

    tokens_str = json.dumps(tokens or [], ensure_ascii=False)
    additives_str = json.dumps(additives or [], ensure_ascii=False)
    eval_str = json.dumps(result_json or {}, ensure_ascii=False) if isinstance(result_json, dict) else str(result_json or "{}")
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
        INSERT INTO scan_history (
            user_id, member_name, label_title, raw_text, normalized_text,
            tokens_json, additives_json, verdict, risk_level, risk_label_vi,
            additive_count, warning_count, result_json, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            user_id,
            member_name or "",
            label_title or "Kết quả quét",
            raw_text,
            normalized_text or raw_text,
            tokens_str,
            additives_str,
            verdict,
            risk_level,
            risk_label_vi,
            additive_count,
            warning_count,
            eval_str,
            now
        ))
        conn.commit()
        scan_id = cursor.lastrowid
        conn.close()

        saved_record = {
            "id": scan_id,
            "user_id": user_id,
            "member_name": member_name or "",
            "label_title": label_title or "Kết quả quét",
            "raw_text": raw_text,
            "normalized_text": normalized_text or raw_text,
            "tokens": tokens or [],
            "additives": additives or [],
            "verdict": verdict,
            "risk_level": risk_level,
            "risk_label_vi": risk_label_vi,
            "additive_count": additive_count,
            "warning_count": warning_count,
            "evaluation": result_json if isinstance(result_json, dict) else {},
            "created_at": now
        }
        return saved_record, None
    except Exception as e:
        conn.rollback()
        conn.close()
        return None, str(e)

def get_user_scan_history(user_id: int, limit: int = 50) -> list[dict]:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, user_id, member_name, label_title, raw_text, normalized_text,
               tokens_json, additives_json, verdict, risk_level, risk_label_vi,
               additive_count, warning_count, result_json, created_at
        FROM scan_history
        WHERE user_id = ?
        ORDER BY id DESC
        LIMIT ?
    """, (user_id, limit))
    rows = cursor.fetchall()
    conn.close()

    scans = []
    for r in rows:
        d = dict(r)
        try:
            d["tokens"] = json.loads(d.pop("tokens_json", "[]"))
        except Exception:
            d["tokens"] = []
        try:
            d["additives"] = json.loads(d.pop("additives_json", "[]"))
        except Exception:
            d["additives"] = []
        try:
            d["evaluation"] = json.loads(d.pop("result_json", "{}"))
        except Exception:
            d["evaluation"] = {}
        scans.append(d)
    return scans

def get_scan_by_id(scan_id: int, user_id: int = None) -> dict:
    conn = get_connection()
    cursor = conn.cursor()
    if user_id:
        cursor.execute("SELECT * FROM scan_history WHERE id = ? AND user_id = ?", (scan_id, user_id))
    else:
        cursor.execute("SELECT * FROM scan_history WHERE id = ?", (scan_id,))
    row = cursor.fetchone()
    conn.close()
    if not row:
        return None

    d = dict(row)
    try:
        d["tokens"] = json.loads(d.pop("tokens_json", "[]"))
    except Exception:
        d["tokens"] = []
    try:
        d["additives"] = json.loads(d.pop("additives_json", "[]"))
    except Exception:
        d["additives"] = []
    try:
        d["evaluation"] = json.loads(d.pop("result_json", "{}"))
    except Exception:
        d["evaluation"] = {}
    return d

def delete_scan_session(scan_id: int, user_id: int = None) -> tuple[bool, str]:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        if user_id:
            cursor.execute("DELETE FROM scan_history WHERE id = ? AND user_id = ?", (scan_id, user_id))
        else:
            cursor.execute("DELETE FROM scan_history WHERE id = ?", (scan_id,))
        deleted_count = cursor.rowcount
        conn.commit()
        conn.close()
        if deleted_count > 0:
            return True, None
        return False, "SCAN_NOT_FOUND"
    except Exception as e:
        conn.rollback()
        conn.close()
        return False, str(e)

def get_scan_statistics(user_id: int) -> dict:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, verdict, risk_level, warning_count, created_at
        FROM scan_history
        WHERE user_id = ?
        ORDER BY id DESC
    """, (user_id,))
    rows = cursor.fetchall()
    conn.close()

    total_scans = len(rows)
    warning_scans = 0
    monthly_scans = 0
    monthly_warnings = 0
    month_prefix = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m")

    for r in rows:
        is_warn = (r["warning_count"] > 0) or (r["verdict"] == "RED") or (r["risk_level"] == "high")
        if is_warn:
            warning_scans += 1
        created_str = str(r["created_at"])
        if created_str.startswith(month_prefix):
            monthly_scans += 1
            if is_warn:
                monthly_warnings += int(r["warning_count"] or 1)

    return {
        "total_scans": total_scans,
        "warning_scans": warning_scans,
        "monthly_scans": monthly_scans,
        "monthly_warnings": monthly_warnings
    }

if __name__ == "__main__":
    init_db()
    print("Database ready at:", DB_PATH)
    print("Existing users:", get_all_users())
