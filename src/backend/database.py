"""
NutriViet Authentication Database Module (SQLite)
PA3-2026 Deliverable - Section E Data Persistence
"""

import sqlite3
import hashlib
import os
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
        created_at TEXT NOT NULL
    )
    """)
    conn.commit()

    # Seed an initial demo account if empty
    cursor.execute("SELECT COUNT(*) FROM users")
    if cursor.fetchone()[0] == 0:
        create_user("Nguyen Van Nutri", "demo@nutriviet.vn", "NutriPass123!")
        print("[DB] Initialized database and seeded demo user: demo@nutriviet.vn (NutriPass123!)")
    else:
        print("[DB] Database connected successfully.")
    conn.close()

def hash_password(password: str, salt: str = None) -> tuple[str, str]:
    if not salt:
        salt = os.urandom(16).hex()
    pwd_bytes = password.encode('utf-8')
    salt_bytes = salt.encode('utf-8')
    # Use PBKDF2 HMAC SHA-256 with 100,000 iterations
    key = hashlib.pbkdf2_hmac('sha256', pwd_bytes, salt_bytes, 100000)
    return key.hex(), salt

def verify_password(password: str, stored_hash: str, salt: str) -> bool:
    new_hash, _ = hash_password(password, salt)
    return new_hash == stored_hash

def create_user(full_name: str, email: str, password: str) -> tuple[dict, str]:
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
    now = datetime.datetime.utcnow().isoformat()
    
    cursor.execute("""
        INSERT INTO users (full_name, email, password_hash, salt, created_at)
        VALUES (?, ?, ?, ?, ?)
    """, (full_name, email, pwd_hash, salt, now))
    conn.commit()
    user_id = cursor.lastrowid
    conn.close()
    
    return {
        "id": user_id,
        "full_name": full_name,
        "email": email,
        "created_at": now
    }, None

def authenticate_user(email: str, password: str) -> tuple[dict, str]:
    email = email.strip().lower()
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, full_name, email, password_hash, salt, created_at FROM users WHERE email = ?", (email,))
    row = cursor.fetchone()
    conn.close()
    
    if not row:
        return None, "INVALID_CREDENTIALS"
    
    if not verify_password(password, row["password_hash"], row["salt"]):
        return None, "INVALID_CREDENTIALS"
    
    return {
        "id": row["id"],
        "full_name": row["full_name"],
        "email": row["email"],
        "created_at": row["created_at"]
    }, None

def get_all_users() -> list[dict]:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, full_name, email, created_at FROM users ORDER BY id ASC")
    rows = cursor.fetchall()
    conn.close()
    return [dict(r) for r in rows]

if __name__ == "__main__":
    init_db()
    print("Database ready at:", DB_PATH)
    print("Existing users:", get_all_users())

