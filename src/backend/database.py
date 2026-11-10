"""
NutriViet Authentication Database Module (SQLite)
PA3-2026 Deliverable - Section E Data Persistence with Email Verification
"""

import sqlite3
import hashlib
import os
import secrets
import datetime

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
    now = datetime.datetime.utcnow().isoformat()
    
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
    now = datetime.datetime.utcnow().isoformat()
    
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

def get_all_users() -> list[dict]:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, full_name, email, is_verified, created_at FROM users ORDER BY id ASC")
    rows = cursor.fetchall()
    conn.close()
    return [dict(r) for r in rows]

if __name__ == "__main__":
    init_db()
    print("Database ready at:", DB_PATH)
    print("Existing users:", get_all_users())
