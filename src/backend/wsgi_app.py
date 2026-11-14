"""
NutriViet Production WSGI Application for PythonAnywhere (v1.6.0)
100% Self-Contained Backend with Gmail SMTP SSL & SQLite Persistence
Includes Physical Metrics (Age, Height, Weight, BMI) & Change Password Settings
"""

import sys
import os
import json
import sqlite3
import hashlib
import secrets
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import urllib.parse
from datetime import datetime

# Path to database on PythonAnywhere
DB_PATH = '/home/ngobinh2006/NutriViet_CNPM/src/backend/nutriviet.db'

# Gmail SMTP Configuration (App Password)
GMAIL_USER = "tienbinhngo20@gmail.com"
GMAIL_PASS = "dcackhtcjpawiwjf"

# -------------------------------------------------------------
# Database Management
# -------------------------------------------------------------
def get_db():
    # Fallback to local if running outside PythonAnywhere
    db_file = DB_PATH if os.path.exists(os.path.dirname(DB_PATH)) else os.path.join(os.path.dirname(__file__), "nutriviet.db")
    conn = sqlite3.connect(db_file, timeout=15.0)
    conn.row_factory = sqlite3.Row
    return conn

def init_tables():
    try:
        conn = get_db()
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
            reset_token TEXT,
            created_at TEXT NOT NULL
        )
        """)
        # Auto-migration for existing database
        cursor.execute("PRAGMA table_info(users)")
        columns = [row[1] for row in cursor.fetchall()]
        if "is_verified" not in columns:
            cursor.execute("ALTER TABLE users ADD COLUMN is_verified INTEGER DEFAULT 0")
        if "verification_token" not in columns:
            cursor.execute("ALTER TABLE users ADD COLUMN verification_token TEXT")
        if "reset_token" not in columns:
            cursor.execute("ALTER TABLE users ADD COLUMN reset_token TEXT")

        # Allergens Table (FG2 Deliverable)
        cursor.execute("PRAGMA table_info(user_allergens)")
        al_cols = [row[1] for row in cursor.fetchall()]
        if al_cols and "allergen_code" not in al_cols:
            cursor.execute("DROP TABLE user_allergens")
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
        # User Physical / Nutrition Metrics Table (Age, Height, Weight, Activity, BMI)
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
        # User Chronic Conditions Table (Tình trạng sức khỏe / Bệnh lý nền)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_chronics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            chronic_code TEXT NOT NULL,
            chronic_name TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """)
        cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_user_chronic ON user_chronics(user_id, chronic_code)")

        # User Settings Table (Ngôn ngữ, Thông báo, Tùy chọn quét)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_settings (
            user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
            language TEXT NOT NULL DEFAULT 'system',
            notify_badges INTEGER NOT NULL DEFAULT 1,
            notify_reminders INTEGER NOT NULL DEFAULT 0,
            scan_derivatives INTEGER NOT NULL DEFAULT 1,
            warn_traces INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT NOT NULL
        )
        """)

        # Family Profiles Table (Hồ sơ gia đình)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS family_members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            member_name TEXT NOT NULL,
            relationship TEXT NOT NULL DEFAULT 'Bản thân',
            is_primary INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
        )
        """)

        # Label Scan History Table (Lịch sử quét nhãn thực tế)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS scan_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            member_name TEXT NOT NULL DEFAULT '',
            label_title TEXT NOT NULL DEFAULT 'Kết quả quét',
            raw_text TEXT NOT NULL,
            verdict TEXT NOT NULL,
            risk_level TEXT NOT NULL,
            risk_label_vi TEXT NOT NULL,
            additive_count INTEGER NOT NULL DEFAULT 0,
            warning_count INTEGER NOT NULL DEFAULT 0,
            result_json TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        """)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_scan_history_user ON scan_history(user_id, id DESC)")

        conn.commit()
        conn.close()
    except Exception as e:
        sys.stderr.write(f"[DB INIT ERROR] {e}\n")

# Run DB migration on startup
init_tables()

# -------------------------------------------------------------
# Physical & Nutrition Metrics Calculation (Standard WHO / Vietnam)
# -------------------------------------------------------------
def calculate_metrics_info(age: int, gender: str, height: float, weight: float, activity_level: str = 'moderate') -> dict:
    try:
        h_m = float(height) / 100.0
        bmi = round(float(weight) / (h_m * h_m), 1) if h_m > 0 else 22.0
    except Exception:
        bmi = 22.0

    # WHO & Asian BMI classification
    if bmi < 18.5:
        bmi_status = "Thiếu cân (Gầy)"
        bmi_color = "#3B82F6"
        bmi_advice = "Tăng cường năng lượng và đạm lành mạnh trong khẩu phần."
    elif bmi < 23.0:
        bmi_status = "Cân đối (Chuẩn WHO/VN)"
        bmi_color = "#10B981"
        bmi_advice = "Thể trạng lý tưởng! Duy trì chế độ ăn và vận động hiện tại."
    elif bmi < 25.0:
        bmi_status = "Tiền béo phì (Thừa cân)"
        bmi_color = "#F59E0B"
        bmi_advice = "Kiểm soát đường, tinh bột tinh chế và chất béo bão hòa."
    else:
        bmi_status = "Béo phì"
        bmi_color = "#EF4444"
        bmi_advice = "Cần chế độ ăn giảm calo và tăng cường vận động thể chất."

    # Mifflin-St Jeor BMR Formula
    try:
        if gender == 'female':
            bmr = 10 * float(weight) + 6.25 * float(height) - 5 * int(age) - 161
        else:
            bmr = 10 * float(weight) + 6.25 * float(height) - 5 * int(age) + 5
    except Exception:
        bmr = 1600.0

    multipliers = {
        'sedentary': 1.2,
        'light': 1.375,
        'moderate': 1.55,
        'active': 1.725,
        'very_active': 1.9
    }
    tdee = int(round(bmr * multipliers.get(activity_level, 1.55)))

    return {
        "age": int(age),
        "gender": gender,
        "height": float(height),
        "weight": float(weight),
        "activity_level": activity_level,
        "bmi": bmi,
        "bmi_status": bmi_status,
        "bmi_color": bmi_color,
        "bmi_advice": bmi_advice,
        "bmr": int(round(bmr)),
        "tdee": tdee
    }

# -------------------------------------------------------------
# Cryptography
# -------------------------------------------------------------
def hash_pwd(password: str, salt: str = None) -> tuple:
    if not salt:
        salt = os.urandom(16).hex()
    pwd_bytes = password.encode('utf-8')
    salt_bytes = salt.encode('utf-8')
    key = hashlib.pbkdf2_hmac('sha256', pwd_bytes, salt_bytes, 100000)
    return key.hex(), salt

def verify_pwd(password: str, stored_hash: str, salt: str) -> bool:
    new_hash, _ = hash_pwd(password, salt)
    return new_hash == stored_hash

# -------------------------------------------------------------
# Email Dispatching via Gmail SMTP SSL (Port 465)
# -------------------------------------------------------------
def send_verification_email(to_email: str, full_name: str, token: str) -> bool:
    verify_url = f"https://ngobinh2006.pythonanywhere.com/verify-email?token={token}"
    html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: -apple-system, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px;">
  <div style="max-width: 500px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.06);">
    <div style="font-size: 26px; font-weight: 800; color: #10B981; text-align: center; margin-bottom: 20px;">🌿 NutriViet</div>
    <h2 style="color: #0F172A; font-size: 20px; margin-top: 0;">Xác thực tài khoản NutriViet</h2>
    <p style="color: #334155; font-size: 14px; line-height: 1.6;">Xin chào <strong>{full_name}</strong>,</p>
    <p style="color: #475569; font-size: 14px; line-height: 1.6;">Cảm ơn bạn đã đăng ký tài khoản NutriViet. Vui lòng bấm vào nút bên dưới để xác thực địa chỉ email và kích hoạt tài khoản của bạn:</p>
    <div style="text-align: center; margin: 28px 0;">
      <a href="{verify_url}" style="background-color: #10B981; color: #ffffff !important; text-decoration: none; font-weight: 700; font-size: 15px; padding: 14px 28px; border-radius: 12px; display: inline-block;">Kích Hoạt Tài Khoản Ngay</a>
    </div>
    <p style="font-size: 12px; color: #94A3B8; word-break: break-all;">Hoặc truy cập: {verify_url}</p>
    <div style="font-size: 11px; color: #94A3B8; margin-top: 24px; border-top: 1px solid #E2E8F0; padding-top: 14px;">
      © 2026 NutriViet Team - CS300 Software Engineering Project.
    </div>
  </div>
</body>
</html>"""
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "🌿 [NutriViet] Xác thực địa chỉ email tài khoản của bạn"
    msg["From"] = f"NutriViet <{GMAIL_USER}>"
    msg["To"] = to_email
    msg.attach(MIMEText(html, "html", "utf-8"))

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=15) as s:
            s.login(GMAIL_USER, GMAIL_PASS)
            s.sendmail(GMAIL_USER, [to_email], msg.as_string())
        return True
    except Exception as e:
        sys.stderr.write(f"[SMTP VERIFICATION ERROR] {e}\n")
        return False

def send_password_reset_email(to_email: str, full_name: str, temp_password: str) -> bool:
    html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: -apple-system, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px;">
  <div style="max-width: 500px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.06);">
    <div style="font-size: 26px; font-weight: 800; color: #10B981; text-align: center; margin-bottom: 20px;">🌿 NutriViet</div>
    <h2 style="color: #0F172A; font-size: 20px; margin-top: 0;">Khôi phục mật khẩu tài khoản</h2>
    <p style="color: #334155; font-size: 14px; line-height: 1.6;">Xin chào <strong>{full_name}</strong>,</p>
    <p style="color: #475569; font-size: 14px; line-height: 1.6;">Chúng tôi nhận được yêu cầu khôi phục mật khẩu tài khoản NutriViet của bạn. Mật khẩu mới tạm thời của bạn là:</p>
    <div style="background: #F1F5F9; border: 1.5px dashed #10B981; border-radius: 12px; padding: 14px; text-align: center; font-size: 22px; font-weight: 800; letter-spacing: 2px; color: #0F172A; margin: 20px 0;">{temp_password}</div>
    <p style="color: #475569; font-size: 13px; line-height: 1.5;">Vui lòng mở ứng dụng NutriViet và đăng nhập bằng mật khẩu tạm này.</p>
    <div style="font-size: 11px; color: #94A3B8; margin-top: 24px; border-top: 1px solid #E2E8F0; padding-top: 14px;">
      © 2026 NutriViet Team - CS300 Software Engineering Project.
    </div>
  </div>
</body>
</html>"""
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "🔑 [NutriViet] Mật khẩu mới cho tài khoản của bạn"
    msg["From"] = f"NutriViet <{GMAIL_USER}>"
    msg["To"] = to_email
    msg.attach(MIMEText(html, "html", "utf-8"))

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=15) as s:
            s.login(GMAIL_USER, GMAIL_PASS)
            s.sendmail(GMAIL_USER, [to_email], msg.as_string())
        return True
    except Exception as e:
        sys.stderr.write(f"[SMTP RESET ERROR] {e}\n")
        return False

# -------------------------------------------------------------
# HTML Templates
# -------------------------------------------------------------
HTML_VERIFIED_SUCCESS = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Kích Hoạt Thành Công - NutriViet</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #F8FAFC; margin: 0; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 16px; }
    .card { background: white; border-radius: 20px; padding: 40px 24px; max-width: 420px; width: 100%; text-align: center; box-shadow: 0 10px 25px rgba(0,0,0,0.06); }
    .icon { width: 72px; height: 72px; background: #D1FAE5; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 32px; color: #10B981; }
    h1 { color: #0F172A; font-size: 22px; margin: 0 0 10px; font-weight: 800; }
    p { color: #475569; font-size: 14px; line-height: 1.5; margin: 0 0 24px; }
    .btn { display: inline-block; background: #10B981; color: white !important; text-decoration: none; padding: 12px 28px; border-radius: 12px; font-weight: 700; font-size: 14px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✓</div>
    <h1>Kích Hoạt Thành Công!</h1>
    <p>Tài khoản NutriViet của bạn đã được xác thực an toàn. Bây giờ bạn có thể mở ứng dụng trên điện thoại và đăng nhập ngay.</p>
    <a href="#" class="btn" onclick="window.close();">Xong - Đã Kích Hoạt</a>
  </div>
</body>
</html>"""

HTML_VERIFIED_FAIL = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Xác Thực Không Thành Công - NutriViet</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #F8FAFC; margin: 0; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 16px; }
    .card { background: white; border-radius: 20px; padding: 40px 24px; max-width: 420px; width: 100%; text-align: center; box-shadow: 0 10px 25px rgba(0,0,0,0.06); }
    .icon { width: 72px; height: 72px; background: #FEE2E2; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 32px; color: #EF4444; }
    h1 { color: #0F172A; font-size: 22px; margin: 0 0 10px; font-weight: 800; }
    p { color: #475569; font-size: 14px; line-height: 1.5; margin: 0; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✕</div>
    <h1>Liên Kết Không Hợp Lệ</h1>
    <p>Liên kết xác thực không tồn tại hoặc đã hết hạn. Vui lòng mở ứng dụng NutriViet và yêu cầu gửi lại email xác thực.</p>
  </div>
</body>
</html>"""

# -------------------------------------------------------------
# WSGI Application Handler
# -------------------------------------------------------------
def application(environ, start_response):
    method = environ.get('REQUEST_METHOD', 'GET')
    path = environ.get('PATH_INFO', '/')

    headers = [
        ('Content-Type', 'application/json; charset=utf-8'),
        ('Access-Control-Allow-Origin', '*'),
        ('Access-Control-Allow-Methods', 'GET, POST, OPTIONS'),
        ('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With')
    ]

    # Handle CORS Preflight
    if method == 'OPTIONS':
        start_response('204 No Content', headers)
        return [b'']

    # 1. Email Verification Web Click Route
    if path == '/verify-email' and method == 'GET':
        query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
        token = query.get('token', [None])[0]
        if token:
            conn = get_db()
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM users WHERE verification_token = ?", (token,))
            row = cursor.fetchone()
            if row:
                cursor.execute("UPDATE users SET is_verified = 1 WHERE id = ?", (row['id'],))
                conn.commit()
                conn.close()
                start_response('200 OK', [('Content-Type', 'text/html; charset=utf-8')])
                return [HTML_VERIFIED_SUCCESS.encode('utf-8')]
            conn.close()
        start_response('400 Bad Request', [('Content-Type', 'text/html; charset=utf-8')])
        return [HTML_VERIFIED_FAIL.encode('utf-8')]

    # Read JSON body for POST
    body = {}
    if method == 'POST':
        try:
            length = int(environ.get('CONTENT_LENGTH', 0))
            if length > 0:
                raw = environ['wsgi.input'].read(length)
                body = json.loads(raw.decode('utf-8'))
        except Exception:
            body = {}

    try:
        # 2. Health Check
        if path in ['/', '/health']:
            start_response('200 OK', headers)
            return [json.dumps({"status": "healthy", "service": "NutriViet", "version": "1.6.0"}).encode('utf-8')]

        # 3. List Users / Get Specific User by id or email
        if path == '/api/v1/users' and method == 'GET':
            query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
            user_id = query.get('id', [None])[0] or query.get('user_id', [None])[0]
            user_email = query.get('email', [None])[0]

            conn = get_db()
            cursor = conn.cursor()

            if user_id or user_email:
                if user_id:
                    cursor.execute("SELECT id, full_name, email, is_verified, created_at FROM users WHERE id = ?", (int(user_id),))
                else:
                    cursor.execute("SELECT id, full_name, email, is_verified, created_at FROM users WHERE email = ?", (user_email.strip().lower(),))
                row = cursor.fetchone()
                if not row:
                    conn.close()
                    start_response('404 Not Found', headers)
                    return [json.dumps({"success": False, "message": "Không tìm thấy người dùng."}).encode('utf-8')]

                u_dict = dict(row)
                target_uid = u_dict['id']

                # Fetch allergens
                cursor.execute("SELECT allergen_code as code, allergen_name as name, severity FROM user_allergens WHERE user_id = ? ORDER BY id ASC", (target_uid,))
                u_dict['allergens'] = [dict(r) for r in cursor.fetchall()]

                # Fetch metrics
                cursor.execute("SELECT age, gender, height, weight, activity_level FROM user_metrics WHERE user_id = ?", (target_uid,))
                m_row = cursor.fetchone()
                if m_row:
                    m = dict(m_row)
                    h_m = m['height'] / 100.0 if m['height'] > 0 else 1.0
                    m['bmi'] = round(m['weight'] / (h_m * h_m), 1)
                    u_dict['metrics'] = m
                else:
                    u_dict['metrics'] = None

                conn.close()
                start_response('200 OK', headers)
                return [json.dumps({"success": True, "user": u_dict}).encode('utf-8')]

            # If no specific user requested, list all users with allergen summary
            cursor.execute("SELECT id, full_name, email, is_verified, created_at FROM users ORDER BY id ASC")
            users = [dict(r) for r in cursor.fetchall()]
            for u in users:
                cursor.execute("SELECT allergen_name FROM user_allergens WHERE user_id = ?", (u['id'],))
                u['allergens'] = [r['allergen_name'] for r in cursor.fetchall()]

            conn.close()
            start_response('200 OK', headers)
            return [json.dumps({"users": users}).encode('utf-8')]

        # 4. User Registration
        if path == '/api/v1/auth/register' and method == 'POST':
            full_name = body.get('full_name', '').strip()
            email = body.get('email', '').strip().lower()
            password = body.get('password', '')

            if not full_name or not email or not password:
                start_response('400 Bad Request', headers)
                return [json.dumps({"success": False, "message": "Vui lòng nhập đầy đủ thông tin", "code": "MISSING_FIELDS"}).encode('utf-8')]
            if len(password) < 6:
                start_response('400 Bad Request', headers)
                return [json.dumps({"success": False, "message": "Mật khẩu phải từ 6 ký tự trở lên", "code": "WEAK_PASSWORD"}).encode('utf-8')]

            conn = get_db()
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
            if cursor.fetchone():
                conn.close()
                start_response('409 Conflict', headers)
                return [json.dumps({"success": False, "message": "Email này đã được sử dụng", "code": "EMAIL_ALREADY_EXISTS"}).encode('utf-8')]

            pwd_hash, salt = hash_pwd(password)
            token = secrets.token_urlsafe(32)
            now = datetime.utcnow().isoformat()

            cursor.execute("""
            INSERT INTO users (full_name, email, password_hash, salt, is_verified, verification_token, created_at)
            VALUES (?, ?, ?, ?, 0, ?, ?)
            """, (full_name, email, pwd_hash, salt, token, now))
            conn.commit()
            user_id = cursor.lastrowid
            conn.close()

            # Dispatch real email via Gmail SMTP
            send_verification_email(email, full_name, token)

            start_response('201 Created', headers)
            return [json.dumps({
                "success": True,
                "requires_verification": True,
                "message": "Đăng ký thành công! Vui lòng kiểm tra hộp thư Gmail để kích hoạt tài khoản.",
                "user": {
                    "id": user_id,
                    "full_name": full_name,
                    "email": email,
                    "is_verified": 0
                }
            }).encode('utf-8')]

        # 5. User Login (Strict Email Verification Gate)
        if path == '/api/v1/auth/login' and method == 'POST':
            email = body.get('email', '').strip().lower()
            password = body.get('password', '')

            conn = get_db()
            cursor = conn.cursor()
            cursor.execute("SELECT id, full_name, email, password_hash, salt, is_verified FROM users WHERE email = ?", (email,))
            user = cursor.fetchone()
            conn.close()

            if not user or not verify_pwd(password, user['password_hash'], user['salt']):
                start_response('401 Unauthorized', headers)
                return [json.dumps({"success": False, "code": "INVALID_CREDENTIALS", "message": "Email hoặc mật khẩu không chính xác."}).encode('utf-8')]

            # Email Verification Gate Check
            if user['is_verified'] != 1:
                start_response('403 Forbidden', headers)
                return [json.dumps({
                    "success": False,
                    "code": "EMAIL_NOT_VERIFIED",
                    "message": "Tài khoản chưa được kích hoạt qua email. Vui lòng kiểm tra hộp thư Gmail để kích hoạt tài khoản trước khi đăng nhập."
                }).encode('utf-8')]

            start_response('200 OK', headers)
            return [json.dumps({
                "success": True,
                "token": f"nv_token_{user['id']}_verified",
                "user": {
                    "id": user['id'],
                    "full_name": user['full_name'],
                    "email": user['email'],
                    "is_verified": 1
                }
            }).encode('utf-8')]

        # 6. Resend Verification Email
        if path == '/api/v1/auth/resend-verification' and method == 'POST':
            email = body.get('email', '').strip().lower()
            conn = get_db()
            cursor = conn.cursor()
            cursor.execute("SELECT id, full_name, email, is_verified FROM users WHERE email = ?", (email,))
            user = cursor.fetchone()
            if not user:
                conn.close()
                start_response('404 Not Found', headers)
                return [json.dumps({"success": False, "message": "Không tìm thấy tài khoản với email này."}).encode('utf-8')]

            if user['is_verified'] == 1:
                conn.close()
                start_response('200 OK', headers)
                return [json.dumps({"success": True, "message": "Tài khoản này đã được kích hoạt rồi. Bạn có thể đăng nhập ngay!"}).encode('utf-8')]

            new_token = secrets.token_urlsafe(32)
            cursor.execute("UPDATE users SET verification_token = ? WHERE id = ?", (new_token, user['id']))
            conn.commit()
            conn.close()

            send_verification_email(user['email'], user['full_name'], new_token)
            start_response('200 OK', headers)
            return [json.dumps({"success": True, "message": "Đã gửi lại email kích hoạt vào hộp thư Gmail của bạn."}).encode('utf-8')]

        # 7. Forgot Password (Dispatches temporary password to Gmail)
        if path == '/api/v1/auth/forgot-password' and method == 'POST':
            email = body.get('email', '').strip().lower()
            conn = get_db()
            cursor = conn.cursor()
            cursor.execute("SELECT id, full_name, email FROM users WHERE email = ?", (email,))
            user = cursor.fetchone()
            if user:
                temp_pwd = f"Nutri@{secrets.token_hex(3).upper()}"
                pwd_hash, salt = hash_pwd(temp_pwd)
                cursor.execute("UPDATE users SET password_hash = ?, salt = ?, is_verified = 1 WHERE id = ?", (pwd_hash, salt, user['id']))
                conn.commit()
                conn.close()

                send_password_reset_email(email, user['full_name'], temp_pwd)
                start_response('200 OK', headers)
                return [json.dumps({
                    "success": True,
                    "message": f"Mật khẩu mới đã được gửi vào hộp thư Gmail: {email}. Vui lòng mở Gmail để xem mật khẩu!"
                }).encode('utf-8')]

            conn.close()
            start_response('200 OK', headers)
            return [json.dumps({
                "success": True,
                "message": "Nếu email tồn tại trong hệ thống, mật khẩu mới đã được gửi vào hộp thư."
            }).encode('utf-8')]

        # 8. Change Password (Current/Temporary Password -> New Password)
        if path == '/api/v1/auth/change-password' and method == 'POST':
            user_id = body.get('user_id')
            email = body.get('email', '').strip().lower()
            current_pwd = body.get('current_password', '')
            new_pwd = body.get('new_password', '')

            if not current_pwd or not new_pwd:
                start_response('400 Bad Request', headers)
                return [json.dumps({"success": False, "message": "Vui lòng nhập mật khẩu hiện tại và mật khẩu mới."}).encode('utf-8')]
            if len(new_pwd) < 6:
                start_response('400 Bad Request', headers)
                return [json.dumps({"success": False, "message": "Mật khẩu mới phải từ 6 ký tự trở lên."}).encode('utf-8')]

            conn = get_db()
            cursor = conn.cursor()
            if user_id:
                cursor.execute("SELECT id, password_hash, salt FROM users WHERE id = ?", (int(user_id),))
            else:
                cursor.execute("SELECT id, password_hash, salt FROM users WHERE email = ?", (email,))
            user = cursor.fetchone()

            if not user or not verify_pwd(current_pwd, user['password_hash'], user['salt']):
                conn.close()
                start_response('400 Bad Request', headers)
                return [json.dumps({"success": False, "message": "Mật khẩu hiện tại (hoặc mật khẩu tạm) không chính xác."}).encode('utf-8')]

            pwd_hash, salt = hash_pwd(new_pwd)
            cursor.execute("UPDATE users SET password_hash = ?, salt = ?, is_verified = 1 WHERE id = ?", (pwd_hash, salt, user['id']))
            conn.commit()
            conn.close()

            start_response('200 OK', headers)
            return [json.dumps({"success": True, "message": "Đổi mật khẩu thành công! Hãy ghi nhớ mật khẩu mới của bạn."}).encode('utf-8')]

        # 9. Update User Profile Name
        if path == '/api/v1/auth/update-profile' and method == 'POST':
            user_id = body.get('user_id')
            full_name = body.get('full_name', '').strip()
            if not user_id or not full_name:
                start_response('400 Bad Request', headers)
                return [json.dumps({"success": False, "message": "Thông tin không hợp lệ."}).encode('utf-8')]

            conn = get_db()
            cursor = conn.cursor()
            cursor.execute("UPDATE users SET full_name = ? WHERE id = ?", (full_name, int(user_id)))
            conn.commit()
            cursor.execute("SELECT id, full_name, email, is_verified FROM users WHERE id = ?", (int(user_id),))
            user = cursor.fetchone()
            conn.close()

            start_response('200 OK', headers)
            return [json.dumps({
                "success": True,
                "message": "Cập nhật họ và tên thành công!",
                "user": dict(user) if user else {}
            }).encode('utf-8')]

        # 10. User Physical & Nutrition Metrics (Age, Height, Weight, Activity, BMI, TDEE)
        if path == '/api/v1/profile/metrics':
            if method == 'GET':
                query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
                uid = query.get('user_id', [None])[0]
                if uid:
                    conn = get_db()
                    cursor = conn.cursor()
                    cursor.execute("""
                    SELECT age, gender, height, weight, activity_level, updated_at
                    FROM user_metrics
                    WHERE user_id = ?
                    """, (int(uid),))
                    row = cursor.fetchone()
                    conn.close()

                    if row:
                        info = calculate_metrics_info(row['age'], row['gender'], row['height'], row['weight'], row['activity_level'])
                        start_response('200 OK', headers)
                        return [json.dumps({"success": True, "has_metrics": True, "metrics": info}).encode('utf-8')]

                start_response('200 OK', headers)
                return [json.dumps({"success": True, "has_metrics": False, "metrics": None}).encode('utf-8')]

            if method == 'POST':
                uid = body.get('user_id')
                if not uid:
                    start_response('400 Bad Request', headers)
                    return [json.dumps({"success": False, "message": "user_id is required"}).encode('utf-8')]

                age = int(body.get('age', 22))
                gender = body.get('gender', 'male').lower()
                height = float(body.get('height', 170.0))
                weight = float(body.get('weight', 65.0))
                activity = body.get('activity_level', 'moderate')
                now = datetime.utcnow().isoformat()

                info = calculate_metrics_info(age, gender, height, weight, activity)

                conn = get_db()
                cursor = conn.cursor()
                cursor.execute("""
                INSERT INTO user_metrics (user_id, age, gender, height, weight, activity_level, target_calories, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(user_id) DO UPDATE SET
                    age = excluded.age,
                    gender = excluded.gender,
                    height = excluded.height,
                    weight = excluded.weight,
                    activity_level = excluded.activity_level,
                    target_calories = excluded.target_calories,
                    updated_at = excluded.updated_at
                """, (int(uid), age, gender, height, weight, activity, info['tdee'], now))
                conn.commit()
                conn.close()

                start_response('200 OK', headers)
                return [json.dumps({
                    "success": True,
                    "message": "Đã cập nhật chỉ số thể trạng và dinh dưỡng thành công!",
                    "metrics": info
                }).encode('utf-8')]

        # 11. User Allergens Profile (FG2)
        if path == '/api/v1/profile/allergens':
            if method == 'GET':
                query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
                uid = query.get('user_id', [None])[0]
                allergens = []
                if uid:
                    conn = get_db()
                    cursor = conn.cursor()
                    cursor.execute("""
                    SELECT allergen_code as code, allergen_name as name, severity, updated_at
                    FROM user_allergens
                    WHERE user_id = ?
                    ORDER BY id ASC
                    """, (int(uid),))
                    allergens = [dict(r) for r in cursor.fetchall()]
                    conn.close()
                    sys.path.insert(0, os.path.dirname(__file__))
                    import monolingual_catalog as mono_cat
                    everyday_map = {}
                    for ef in mono_cat.EVERYDAY_ALLERGY_FOODS:
                        pair = (ef["food_name_vi"], ef["food_name_en"])
                        everyday_map[ef["food_name_vi"].lower()] = pair
                        everyday_map[ef["food_name_en"].lower()] = pair
                        for kw in ef["keywords"]:
                            everyday_map[kw.lower()] = pair
                    for a in allergens:
                        rn = (a.get("name") or "").strip().lower()
                        if rn in everyday_map:
                            a["source_food_vi"], a["source_food_en"] = everyday_map[rn]
                start_response('200 OK', headers)
                return [json.dumps({"success": True, "allergens": allergens}).encode('utf-8')]

            if method == 'POST':
                uid = body.get('user_id')
                al_list = body.get('allergens', [])
                now = datetime.utcnow().isoformat()
                if uid:
                    if not hasattr(application, '_foodon_engine'):
                        sys.path.insert(0, os.path.dirname(__file__))
                        from hybrid_ontology import HybridFoodOnEngine
                        application._foodon_engine = HybridFoodOnEngine()
                    eng = application._foodon_engine

                    conn = get_db()
                    cursor = conn.cursor()
                    cursor.execute("DELETE FROM user_allergens WHERE user_id = ?", (int(uid),))
                    for item in al_list:
                        if isinstance(item, dict):
                            code = item.get('code') or item.get('allergen_code') or ''
                            name = item.get('name') or item.get('allergen_name') or code
                            sev = item.get('severity', 'high').lower()
                        else:
                            code = str(item)
                            name = code
                            sev = 'high'
                        if code:
                            cursor.execute("""
                            INSERT INTO user_allergens (user_id, allergen_code, allergen_name, severity, updated_at)
                            VALUES (?, ?, ?, ?, ?)
                            """, (int(uid), code, name, sev, now))
                    # Re-evaluate existing scan_history rows so previously scanned labels immediately reflect new allergy profile
                    cursor.execute("SELECT allergen_code as code, allergen_name as name, severity FROM user_allergens WHERE user_id = ?", (int(uid),))
                    user_als = [dict(r) for r in cursor.fetchall()]
                    cursor.execute("SELECT chronic_code FROM user_chronics WHERE user_id = ?", (int(uid),))
                    user_chs = [r["chronic_code"] for r in cursor.fetchall()]
                    cursor.execute("SELECT id, raw_text FROM scan_history WHERE user_id = ?", (int(uid),))
                    import re as _re
                    for srow in cursor.fetchall():
                        sid = srow["id"]
                        rtxt = srow["raw_text"] or ""
                        cleaned = _re.sub(r"^(?:thành phần|ingredients)\s*[:\-]\s*", "", rtxt, flags=_re.IGNORECASE)
                        toks = [t.strip(" .") for t in _re.split(r"[,;\n]+", cleaned) if t.strip(" .")]
                        ev = eng.evaluate_packaging_label(toks, user_als, user_chs, lang="vi")
                        det_add = []
                        highest_rk = "safe"
                        for td in ev.get("details", []):
                            for m in td.get("matches", []):
                                c = m["curie"]
                                rk = eng.classify_concept_risk(c)["risk_level"]
                                if rk == "high":
                                    highest_rk = "high"
                                elif rk == "low" and highest_rk == "safe":
                                    highest_rk = "low"
                                if m.get("ecodes") or "FOODON:03412972" in m.get("lineage", ""):
                                    det_add.append(eng._build_concept_card(c, lang="vi"))
                        ev["detected_additives"] = det_add
                        w_cnt = len(ev.get("red_triggers", [])) + len(ev.get("yellow_triggers", []))
                        if ev["verdict"] == "RED" or highest_rk == "high":
                            rk_lvl, rk_vi = "high", "Nguy cơ cao"
                        elif ev["verdict"] == "YELLOW" or highest_rk == "low":
                            rk_lvl, rk_vi = "low", "Nguy cơ thấp"
                        else:
                            rk_lvl, rk_vi = "safe", "An toàn"
                        cursor.execute(
                            "UPDATE scan_history SET verdict = ?, risk_level = ?, risk_label_vi = ?, warning_count = ?, result_json = ? WHERE id = ?",
                            (ev["verdict"], rk_lvl, rk_vi, w_cnt, json.dumps(ev, ensure_ascii=False), sid),
                        )
                    conn.commit()
                    conn.close()
                start_response('200 OK', headers)
                return [json.dumps({"success": True, "message": "Đã lưu hồ sơ dị ứng thành công."}).encode('utf-8')]

        # 11b. User Chronic Conditions Profile ("Tình trạng của tôi")
        if path == '/api/v1/profile/chronics':
            if method == 'GET':
                query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
                uid = query.get('user_id', [None])[0]
                chronics = []
                if uid:
                    conn = get_db()
                    cursor = conn.cursor()
                    cursor.execute("""
                    SELECT chronic_code as code, chronic_name as name, updated_at
                    FROM user_chronics
                    WHERE user_id = ?
                    ORDER BY id ASC
                    """, (int(uid),))
                    chronics = [dict(r) for r in cursor.fetchall()]
                    conn.close()
                start_response('200 OK', headers)
                return [json.dumps({"success": True, "chronics": chronics}).encode('utf-8')]

            if method == 'POST':
                uid = body.get('user_id')
                ch_list = body.get('chronics', [])
                now = datetime.utcnow().isoformat()
                if uid:
                    conn = get_db()
                    cursor = conn.cursor()
                    cursor.execute("DELETE FROM user_chronics WHERE user_id = ?", (int(uid),))
                    for item in ch_list:
                        if isinstance(item, dict):
                            code = item.get('code') or item.get('chronic_code') or ''
                            name = item.get('name') or item.get('chronic_name') or code
                        else:
                            code = str(item)
                            name = code
                        if code:
                            cursor.execute("""
                            INSERT INTO user_chronics (user_id, chronic_code, chronic_name, updated_at)
                            VALUES (?, ?, ?, ?)
                            """, (int(uid), code, name, now))
                    conn.commit()
                    conn.close()
                start_response('200 OK', headers)
                return [json.dumps({"success": True, "message": "Đã lưu tình trạng sức khỏe thành công."}).encode('utf-8')]

        # 11c. User Settings ("Ngôn ngữ", "Chúc mừng huy hiệu", "Nhắc nhở nhẹ nhàng")
        if path == '/api/v1/profile/settings':
            if method == 'GET':
                query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
                uid = query.get('user_id', [None])[0]
                settings = {
                    "language": "system",
                    "notify_badges": True,
                    "notify_reminders": False,
                    "scan_derivatives": True,
                    "warn_traces": True,
                }
                if uid:
                    conn = get_db()
                    cursor = conn.cursor()
                    cursor.execute("""
                    SELECT language, notify_badges, notify_reminders, scan_derivatives, warn_traces
                    FROM user_settings
                    WHERE user_id = ?
                    """, (int(uid),))
                    row = cursor.fetchone()
                    conn.close()
                    if row:
                        settings = {
                            "language": row["language"],
                            "notify_badges": bool(row["notify_badges"]),
                            "notify_reminders": bool(row["notify_reminders"]),
                            "scan_derivatives": bool(row["scan_derivatives"]),
                            "warn_traces": bool(row["warn_traces"]),
                        }
                start_response('200 OK', headers)
                return [json.dumps({"success": True, "settings": settings}).encode('utf-8')]

            if method == 'POST':
                uid = body.get('user_id')
                if not uid:
                    start_response('400 Bad Request', headers)
                    return [json.dumps({"success": False, "message": "user_id is required"}).encode('utf-8')]
                lang = str(body.get('language', 'system'))
                nb = 1 if body.get('notify_badges', True) else 0
                nr = 1 if body.get('notify_reminders', False) else 0
                sd = 1 if body.get('scan_derivatives', True) else 0
                wt = 1 if body.get('warn_traces', True) else 0
                now = datetime.utcnow().isoformat()
                conn = get_db()
                cursor = conn.cursor()
                cursor.execute("""
                INSERT INTO user_settings (user_id, language, notify_badges, notify_reminders, scan_derivatives, warn_traces, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(user_id) DO UPDATE SET
                    language = excluded.language,
                    notify_badges = excluded.notify_badges,
                    notify_reminders = excluded.notify_reminders,
                    scan_derivatives = excluded.scan_derivatives,
                    warn_traces = excluded.warn_traces,
                    updated_at = excluded.updated_at
                """, (int(uid), lang, nb, nr, sd, wt, now))
                conn.commit()
                conn.close()
                start_response('200 OK', headers)
                return [json.dumps({"success": True, "message": "Đã lưu cài đặt thành công."}).encode('utf-8')]

        # 11d. Family Profiles ("Hồ sơ gia đình")
        if path == '/api/v1/profile/family':
            if method == 'GET':
                query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
                uid = query.get('user_id', [None])[0]
                members = []
                if uid:
                    conn = get_db()
                    cursor = conn.cursor()
                    cursor.execute("SELECT id, member_name, relationship, is_primary, created_at FROM family_members WHERE user_id = ? ORDER BY is_primary DESC, id ASC", (int(uid),))
                    members = [dict(r) for r in cursor.fetchall()]
                    if not members:
                        cursor.execute("SELECT full_name FROM users WHERE id = ?", (int(uid),))
                        u_row = cursor.fetchone()
                        raw_short = (u_row["full_name"].strip().split()[-1] if u_row and u_row["full_name"] else "Tôi")
                        short_name = raw_short[0].upper() + raw_short[1:] if raw_short else "Tôi"
                        now = datetime.utcnow().isoformat()
                        cursor.execute("INSERT INTO family_members (user_id, member_name, relationship, is_primary, created_at) VALUES (?, ?, 'Bản thân', 1, ?)", (int(uid), short_name, now))
                        conn.commit()
                        cursor.execute("SELECT id, member_name, relationship, is_primary, created_at FROM family_members WHERE user_id = ? ORDER BY is_primary DESC, id ASC", (int(uid),))
                        members = [dict(r) for r in cursor.fetchall()]
                    conn.close()
                start_response('200 OK', headers)
                return [json.dumps({"success": True, "members": members}).encode('utf-8')]

            if method == 'POST':
                uid = body.get('user_id')
                action = body.get('action', 'add')
                if not uid:
                    start_response('400 Bad Request', headers)
                    return [json.dumps({"success": False, "message": "user_id is required"}).encode('utf-8')]
                conn = get_db()
                cursor = conn.cursor()
                if action == 'delete':
                    member_id = body.get('member_id')
                    if member_id:
                        cursor.execute("DELETE FROM family_members WHERE id = ? AND user_id = ? AND is_primary = 0", (int(member_id), int(uid)))
                        conn.commit()
                else:
                    member_name = (body.get('member_name') or '').strip()
                    rel = (body.get('relationship') or 'Thành viên').strip()
                    if member_name:
                        now = datetime.utcnow().isoformat()
                        cursor.execute("INSERT INTO family_members (user_id, member_name, relationship, is_primary, created_at) VALUES (?, ?, ?, 0, ?)", (int(uid), member_name, rel, now))
                        conn.commit()
                cursor.execute("SELECT id, member_name, relationship, is_primary, created_at FROM family_members WHERE user_id = ? ORDER BY is_primary DESC, id ASC", (int(uid),))
                members = [dict(r) for r in cursor.fetchall()]
                conn.close()
                start_response('200 OK', headers)
                return [json.dumps({"success": True, "members": members}).encode('utf-8')]

        # 12. Real Scan History & Packaging Label Evaluation ("Quét nhãn" & "Lịch sử")
        if path == '/api/v1/scans':
            if not hasattr(application, '_foodon_engine'):
                sys.path.insert(0, os.path.dirname(__file__))
                from hybrid_ontology import HybridFoodOnEngine
                application._foodon_engine = HybridFoodOnEngine()
            eng = application._foodon_engine

            def _fetch_user_scan_summary(conn, uid_int: int):
                cur = conn.cursor()
                cur.execute("SELECT id, member_name, label_title, raw_text, verdict, risk_level, risk_label_vi, additive_count, warning_count, result_json, created_at FROM scan_history WHERE user_id = ? ORDER BY id DESC LIMIT 50", (uid_int,))
                rows = cur.fetchall()
                scans = []
                month_prefix = datetime.utcnow().strftime("%Y-%m")
                monthly_scans = 0
                monthly_warnings = 0
                warning_scans = 0
                for r in rows:
                    d = dict(r)
                    try:
                        d["evaluation"] = json.loads(d.pop("result_json", "{}"))
                    except Exception:
                        d["evaluation"] = {}
                    scans.append(d)
                    if d["warning_count"] > 0 or d["risk_level"] == "high":
                        warning_scans += 1
                    if str(d["created_at"]).startswith(month_prefix):
                        monthly_scans += 1
                        monthly_warnings += int(d["warning_count"])
                return {
                    "scans": scans,
                    "total_scans": len(scans),
                    "warning_scans": warning_scans,
                    "monthly_scans": monthly_scans,
                    "monthly_warnings": monthly_warnings,
                }

            if method == 'GET':
                query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
                uid = query.get('user_id', [None])[0]
                if not uid:
                    start_response('400 Bad Request', headers)
                    return [json.dumps({"success": False, "message": "user_id is required"}).encode('utf-8')]
                conn = get_db()
                summary = _fetch_user_scan_summary(conn, int(uid))
                conn.close()
                start_response('200 OK', headers)
                return [json.dumps({"success": True, **summary}, ensure_ascii=False).encode('utf-8')]

            if method == 'POST':
                uid = body.get('user_id')
                raw_text = (body.get('raw_text') or body.get('ingredients') or '').strip()
                lang = (body.get('lang') or 'vi').strip().lower()
                is_en = lang.startswith('en')
                default_title = 'Scan result' if is_en else 'Kết quả quét'
                label_title = (body.get('label_title') or default_title).strip()
                member_name = (body.get('member_name') or '').strip()
                if not uid or not raw_text:
                    start_response('400 Bad Request', headers)
                    msg = "Please enter or scan packaging ingredients." if is_en else "Vui lòng nhập hoặc quét thành phần trên nhãn bao bì."
                    return [json.dumps({"success": False, "message": msg}).encode('utf-8')]

                conn = get_db()
                cursor = conn.cursor()
                cursor.execute("SELECT allergen_code as code, allergen_name as name, severity FROM user_allergens WHERE user_id = ?", (int(uid),))
                user_als = [dict(r) for r in cursor.fetchall()]
                cursor.execute("SELECT chronic_code FROM user_chronics WHERE user_id = ?", (int(uid),))
                user_chs = [r["chronic_code"] for r in cursor.fetchall()]

                # Split ingredients by comma, semicolon, or newline
                import re as _re
                cleaned_text = _re.sub(r"^(?:thành phần|ingredients)\s*[:\-]\s*", "", raw_text, flags=_re.IGNORECASE)
                tokens = [t.strip(" .") for t in _re.split(r"[,;\n]+", cleaned_text) if t.strip(" .")]

                eval_res = eng.evaluate_packaging_label(tokens, user_als, user_chs, lang=lang)

                # Inspect matched concepts for E-code additives and ontological risk level
                detected_additives = []
                highest_concept_risk = "safe"
                for tok_detail in eval_res.get("details", []):
                    for m in tok_detail.get("matches", []):
                        c = m["curie"]
                        rk = eng.classify_concept_risk(c)["risk_level"]
                        if rk == "high":
                            highest_concept_risk = "high"
                        elif rk == "low" and highest_concept_risk == "safe":
                            highest_concept_risk = "low"
                        if m.get("ecodes") or "FOODON:03412972" in m.get("lineage", ""):
                            card = eng._build_concept_card(c, lang=lang)
                            detected_additives.append(card)

                eval_res["detected_additives"] = detected_additives
                warning_count = len(eval_res.get("red_triggers", [])) + len(eval_res.get("yellow_triggers", []))
                additive_count = len(detected_additives) if detected_additives else len([d for d in eval_res.get("details", []) if d.get("matched")])

                if eval_res["verdict"] == "RED" or highest_concept_risk == "high":
                    risk_level = "high"
                    risk_label_vi = "Nguy cơ cao"
                elif eval_res["verdict"] == "YELLOW" or highest_concept_risk == "low":
                    risk_level = "low"
                    risk_label_vi = "Nguy cơ thấp"
                else:
                    risk_level = "safe"
                    risk_label_vi = "An toàn"

                now = datetime.utcnow().isoformat()
                cursor.execute("""
                INSERT INTO scan_history (user_id, member_name, label_title, raw_text, verdict, risk_level, risk_label_vi, additive_count, warning_count, result_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    int(uid),
                    member_name,
                    label_title,
                    raw_text,
                    eval_res["verdict"],
                    risk_level,
                    risk_label_vi,
                    additive_count,
                    warning_count,
                    json.dumps(eval_res, ensure_ascii=False),
                    now,
                ))
                conn.commit()
                summary = _fetch_user_scan_summary(conn, int(uid))
                conn.close()

                start_response('200 OK', headers)
                return [json.dumps({
                    "success": True,
                    "latest_scan": summary["scans"][0] if summary["scans"] else None,
                    **summary,
                }, ensure_ascii=False).encode('utf-8')]

        # 13. FoodOn + Kala Hybrid Ontology Explorer Web UI & REST API (FG3 / UC09)
        if path == '/foodon-test' and method == 'GET':
            html_file = os.path.join(os.path.dirname(__file__), 'static', 'foodon_explorer.html')
            with open(html_file, 'r', encoding='utf-8') as f:
                html_content = f.read()
            start_response('200 OK', [('Content-Type', 'text/html; charset=utf-8')])
            return [html_content.encode('utf-8')]

        if path == '/api/v1/foodon/allergy-lookup' and method == 'GET':
            if not hasattr(application, '_foodon_engine'):
                sys.path.insert(0, os.path.dirname(__file__))
                from hybrid_ontology import HybridFoodOnEngine
                application._foodon_engine = HybridFoodOnEngine()
            query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
            q = query.get('q', [''])[0]
            lang = query.get('lang', ['vi'])[0]
            limit = int(query.get('limit', ['12'])[0])
            res = application._foodon_engine.search_allergy_foods(query=q, lang=lang, limit=limit)
            start_response('200 OK', headers)
            return [json.dumps(res, ensure_ascii=False).encode('utf-8')]

        if path == '/api/v1/foodon/additives' and method == 'GET':
            if not hasattr(application, '_foodon_engine'):
                sys.path.insert(0, os.path.dirname(__file__))
                from hybrid_ontology import HybridFoodOnEngine
                application._foodon_engine = HybridFoodOnEngine()
            query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
            q = query.get('q', [''])[0]
            lang = query.get('lang', ['vi'])[0]
            limit = int(query.get('limit', ['60'])[0])
            res = application._foodon_engine.list_additives(query=q, lang=lang, limit=limit)
            start_response('200 OK', headers)
            return [json.dumps(res, ensure_ascii=False).encode('utf-8')]

        if path == '/api/v1/foodon/category' and method == 'GET':
            if not hasattr(application, '_foodon_engine'):
                sys.path.insert(0, os.path.dirname(__file__))
                from hybrid_ontology import HybridFoodOnEngine
                application._foodon_engine = HybridFoodOnEngine()
            query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
            cat = query.get('category', ['sugar'])[0]
            lang = query.get('lang', ['vi'])[0]
            als_str = query.get('allergens', [''])[0]
            als = [x.strip() for x in als_str.split(',') if x.strip()]
            limit = int(query.get('limit', ['20'])[0])
            res = application._foodon_engine.get_category_concepts(category=cat, user_allergens=als, lang=lang, limit=limit)
            start_response('200 OK', headers)
            return [json.dumps(res, ensure_ascii=False).encode('utf-8')]

        if path == '/api/v1/foodon/search' and method == 'GET':
            if not hasattr(application, '_foodon_engine'):
                sys.path.insert(0, os.path.dirname(__file__))
                from hybrid_ontology import HybridFoodOnEngine
                application._foodon_engine = HybridFoodOnEngine()
            query = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
            q = query.get('q', [''])[0]
            lang = query.get('lang', ['all'])[0]
            allergen = query.get('allergen', [''])[0]
            limit = int(query.get('limit', ['30'])[0])
            res = application._foodon_engine.search_concepts(query=q, lang_scope=lang, allergen_filter=allergen, limit=limit)
            start_response('200 OK', headers)
            return [json.dumps(res, ensure_ascii=False).encode('utf-8')]

        if path == '/api/v1/foodon/evaluate' and method == 'POST':
            if not hasattr(application, '_foodon_engine'):
                sys.path.insert(0, os.path.dirname(__file__))
                from hybrid_ontology import HybridFoodOnEngine
                application._foodon_engine = HybridFoodOnEngine()
            ingredients = body.get('ingredients') or []
            if isinstance(ingredients, str):
                ingredients = [x.strip() for x in ingredients.split(',') if x.strip()]
            allergens = body.get('allergens') or []
            chronics = body.get('chronics') or []
            res = application._foodon_engine.evaluate_packaging_label(ingredients, allergens, chronics)
            start_response('200 OK', headers)
            return [json.dumps(res, ensure_ascii=False).encode('utf-8')]

        start_response('404 Not Found', headers)
        return [json.dumps({"error": "Endpoint Not Found", "path": path}).encode('utf-8')]

    except Exception as exc:
        sys.stderr.write(f"[WSGI EXCEPTION] {exc}\n")
        start_response('500 Internal Server Error', headers)
        return [json.dumps({"success": False, "message": f"Server Error: {str(exc)}"}).encode('utf-8')]
