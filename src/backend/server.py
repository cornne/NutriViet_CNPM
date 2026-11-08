"""
NutriViet Authentication Backend API Server
Full-Stack Deliverable for PA3-2026 (Section E)
Compatible with Python 3.8+ (Zero external dependency required)
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os
import sys
import urllib.parse
from database import init_db, create_user, authenticate_user, get_all_users

HOST = "0.0.0.0"  # Listen on all interfaces so Android Emulator and LAN devices can connect
PORT = int(os.environ.get("PORT", 8000))

class NutriVietAuthHandler(BaseHTTPRequestHandler):

    def _set_headers(self, status_code=200, content_type="application/json"):
        self.send_response(status_code)
        self.send_header("Content-Type", content_type)
        # Enable CORS for Flutter web / mobile / emulators
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With")
        self.end_headers()

    def do_OPTIONS(self):
        """Handle CORS pre-flight requests"""
        self._set_headers(204)

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        if path == "/" or path == "/health":
            self._set_headers(200)
            response = {
                "system": "NutriViet Authentication Microservice",
                "version": "1.0.0",
                "status": "healthy",
                "endpoints": [
                    "POST /api/v1/auth/register",
                    "POST /api/v1/auth/login",
                    "GET /api/v1/users"
                ]
            }
            self.wfile.write(json.dumps(response, indent=2).encode('utf-8'))

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

        # Read JSON body
        content_length = int(self.headers.get('Content-Length', 0))
        body_bytes = self.rfile.read(content_length)
        
        try:
            payload = json.loads(body_bytes.decode('utf-8')) if body_bytes else {}
        except json.JSONDecodeError:
            self._set_headers(400)
            self.wfile.write(json.dumps({"status": "error", "message": "Invalid JSON payload"}).encode('utf-8'))
            return

        print(f"\n[REQUEST] POST {path} | Data: {payload.get('email', 'N/A')}")

        if path == "/api/v1/auth/register":
            full_name = payload.get("full_name", "")
            email = payload.get("email", "")
            password = payload.get("password", "")

            user, error = create_user(full_name, email, password)
            if error == "EMAIL_ALREADY_EXISTS":
                self._set_headers(409)
                resp = {
                    "status": "error",
                    "code": "EMAIL_ALREADY_EXISTS",
                    "message": "Email is already registered. Please log in instead."
                }
            elif error:
                self._set_headers(400)
                resp = {"status": "error", "message": error}
            else:
                self._set_headers(201)
                resp = {
                    "status": "success",
                    "message": "User registered successfully",
                    "token": f"nutriviet_jwt_{user['id']}_{os.urandom(8).hex()}",
                    "user": user
                }
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        elif path == "/api/v1/auth/login":
            email = payload.get("email", "")
            password = payload.get("password", "")

            user, error = authenticate_user(email, password)
            if error:
                self._set_headers(401)
                resp = {
                    "status": "error",
                    "code": "INVALID_CREDENTIALS",
                    "message": "Invalid email or password"
                }
            else:
                self._set_headers(200)
                resp = {
                    "status": "success",
                    "message": "Authentication successful",
                    "token": f"nutriviet_jwt_{user['id']}_{os.urandom(8).hex()}",
                    "user": user
                }
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        else:
            self._set_headers(404)
            resp = {"status": "error", "message": f"Endpoint '{path}' not found"}
            self.wfile.write(json.dumps(resp).encode('utf-8'))

    def log_message(self, format, *args):
        # Clean logging
        sys.stderr.write(f"[{self.log_date_time_string()}] {format % args}\n")

def run():
    init_db()
    server_address = (HOST, PORT)
    httpd = HTTPServer(server_address, NutriVietAuthHandler)
    print("=" * 60)
    print(f"🚀 NutriViet Auth Backend Server is running!")
    print(f"📡 Local host URL     : http://localhost:{PORT}")
    print(f"📱 Android Emulator   : http://10.0.2.2:{PORT}")
    print(f"👥 Database Explorer  : http://localhost:{PORT}/api/v1/users")
    print("=" * 60)
    print("Press Ctrl+C to terminate.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[SHUTDOWN] Server stopped safely.")

if __name__ == "__main__":
    run()

