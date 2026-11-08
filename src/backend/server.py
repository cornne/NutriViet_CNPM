"""
NutriViet Authentication Backend API Server
Full-Stack Deliverable with Email Verification Link (Resend API)
Compatible with Python 3.8+ (Zero external dependency required)
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os
import sys
import urllib.parse
from database import (
    init_db,
    create_user,
    authenticate_user,
    get_all_users,
    verify_user_token,
    resend_token_for_email
)
from email_service import send_verification_email

HOST = "0.0.0.0"
PORT = int(os.environ.get("PORT", 8000))

SUCCESS_HTML_PAGE = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Kích hoạt thành công - NutriViet</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #F3F4F6; margin: 0; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 16px; }
    .card { background: white; border-radius: 20px; padding: 40px 28px; max-width: 440px; width: 100%; text-align: center; box-shadow: 0 10px 25px rgba(0,0,0,0.05); }
    .icon { width: 72px; height: 72px; background: #D1FAE5; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 36px; color: #10B981; }
    h1 { color: #111827; font-size: 22px; margin: 0 0 12px; }
    p { color: #4B5563; font-size: 15px; line-height: 1.5; margin: 0 0 24px; }
    .btn { display: inline-block; background: #10B981; color: white; text-decoration: none; padding: 12px 24px; border-radius: 12px; font-weight: 600; font-size: 15px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✓</div>
    <h1>Xác thực thành công!</h1>
    <p>Tài khoản NutriViet của bạn đã được kích hoạt. Hãy quay lại ứng dụng trên điện thoại để đăng nhập.</p>
    <a href="#" class="btn" onclick="window.close();">Quay lại Ứng Dụng</a>
  </div>
</body>
</html>
"""

FAIL_HTML_PAGE = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Xác thực thất bại - NutriViet</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #F3F4F6; margin: 0; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 16px; }
    .card { background: white; border-radius: 20px; padding: 40px 28px; max-width: 440px; width: 100%; text-align: center; box-shadow: 0 10px 25px rgba(0,0,0,0.05); }
    .icon { width: 72px; height: 72px; background: #FEE2E2; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 36px; color: #EF4444; }
    h1 { color: #111827; font-size: 22px; margin: 0 0 12px; }
    p { color: #4B5563; font-size: 15px; line-height: 1.5; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✕</div>
    <h1>Link không hợp lệ</h1>
    <p>Liên kết xác thực không tồn tại hoặc đã hết hạn. Vui lòng mở ứng dụng NutriViet và yêu cầu gửi lại email xác thực.</p>
  </div>
</body>
</html>
"""

class NutriVietAuthHandler(BaseHTTPRequestHandler):

    def _set_headers(self, status_code=200, content_type="application/json"):
        self.send_response(status_code)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With")
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(204)

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        query = urllib.parse.parse_qs(parsed_url.query)

        if path == "/" or path == "/health":
            self._set_headers(200)
            response = {
                "system": "NutriViet Authentication Microservice",
                "version": "1.1.0",
                "status": "healthy",
                "endpoints": [
                    "POST /api/v1/auth/register",
                    "POST /api/v1/auth/login",
                    "POST /api/v1/auth/resend-verification",
                    "GET /verify-email?token=...",
                    "GET /api/v1/users"
                ]
            }
            self.wfile.write(json.dumps(response, indent=2).encode('utf-8'))

        elif path == "/verify-email":
            token = query.get("token", [None])[0]
            user, err = verify_user_token(token)
            if user:
                self._set_headers(200, content_type="text/html; charset=utf-8")
                self.wfile.write(SUCCESS_HTML_PAGE.encode('utf-8'))
            else:
                self._set_headers(400, content_type="text/html; charset=utf-8")
                self.wfile.write(FAIL_HTML_PAGE.encode('utf-8'))

        elif path == "/api/v1/users":
            users = get_all_users()
            self._set_headers(200)
            response = {
                "status": "success",
                "count": len(users),
                "users": users
            }
            self.wfile.write(json.dumps(response, indent=2).encode('utf-8'))

        else:
            self._set_headers(404)
            response = {"status": "error", "message": f"Route '{path}' not found"}
            self.wfile.write(json.dumps(response).encode('utf-8'))

    def do_POST(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)

        try:
            body = json.loads(post_data.decode('utf-8')) if content_length > 0 else {}
        except json.JSONDecodeError:
            self._set_headers(400)
            resp = {"status": "error", "message": "Malformed JSON payload"}
            self.wfile.write(json.dumps(resp).encode('utf-8'))
            return

        # 1. Register Route
        if path == "/api/v1/auth/register":
            full_name = body.get("full_name")
            email = body.get("email")
            password = body.get("password")

            user, error = create_user(full_name, email, password, is_verified=0)

            if error:
                status_code = 409 if error == "EMAIL_ALREADY_EXISTS" else 400
                self._set_headers(status_code)
                resp = {"status": "error", "code": error, "message": "Email đã được sử dụng" if error == "EMAIL_ALREADY_EXISTS" else error}
            else:
                # Trigger confirmation email in background
                send_verification_email(user["email"], user["full_name"], user["verification_token"])
                self._set_headers(201)
                resp = {
                    "status": "success",
                    "requires_verification": True,
                    "message": "Đăng ký thành công! Vui lòng kiểm tra email để kích hoạt tài khoản.",
                    "user": {
                        "id": user["id"],
                        "full_name": user["full_name"],
                        "email": user["email"]
                    }
                }
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        # 2. Login Route
        elif path == "/api/v1/auth/login":
            email = body.get("email")
            password = body.get("password")

            user, error = authenticate_user(email, password)

            if error == "EMAIL_NOT_VERIFIED":
                self._set_headers(403)
                resp = {
                    "status": "error",
                    "code": "EMAIL_NOT_VERIFIED",
                    "message": "Tài khoản chưa được kích hoạt. Vui lòng bấm vào liên kết xác thực trong hộp thư Gmail."
                }
            elif error:
                self._set_headers(401)
                resp = {
                    "status": "error",
                    "code": "INVALID_CREDENTIALS",
                    "message": "Email hoặc mật khẩu không chính xác"
                }
            else:
                token = f"nv_token_{user['id']}_{os.urandom(8).hex()}"
                self._set_headers(200)
                resp = {
                    "status": "success",
                    "token": token,
                    "user": user
                }
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        # 3. Resend Verification Route
        elif path == "/api/v1/auth/resend-verification":
            email = body.get("email")
            user, error = resend_token_for_email(email)
            if error == "ALREADY_VERIFIED":
                self._set_headers(400)
                resp = {"status": "error", "message": "Tài khoản này đã được xác thực rồi."}
            elif error:
                self._set_headers(404)
                resp = {"status": "error", "message": "Không tìm thấy tài khoản với email này."}
            else:
                send_verification_email(user["email"], user["full_name"], user["verification_token"])
                self._set_headers(200)
                resp = {"status": "success", "message": "Đã gửi lại link xác thực đến email của bạn."}
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        else:
            self._set_headers(404)
            resp = {"status": "error", "message": f"Endpoint '{path}' not found"}
            self.wfile.write(json.dumps(resp).encode('utf-8'))

    def log_message(self, format, *args):
        sys.stderr.write(f"[{self.log_date_time_string()}] {format % args}\n")

def run():
    init_db()
    server_address = (HOST, PORT)
    httpd = HTTPServer(server_address, NutriVietAuthHandler)
    print("=" * 60)
    print(f"🚀 NutriViet Auth Backend Server is running!")
    print(f"📡 Port: {PORT}")
    print("=" * 60)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[SHUTDOWN] Server stopped safely.")

if __name__ == "__main__":
    run()
