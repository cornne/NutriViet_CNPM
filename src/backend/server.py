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
    resend_token_for_email,
    create_reset_token,
    reset_user_password,
    change_user_password,
    get_user_allergens,
    save_user_allergens,
    get_user_metrics,
    save_user_metrics,
    save_scan_session,
    get_user_scan_history,
    get_scan_by_id,
    delete_scan_session,
    get_scan_statistics
)
from email_service import send_verification_email
from ocr_normalizer import (
    normalize_ocr_payload,
    clean_raw_ocr_text,
    tokenize_ingredients,
    extract_e_numbers
)

try:
    from hybrid_ontology import HybridFoodOnEngine
    _foodon_engine = HybridFoodOnEngine()
except Exception as _eng_err:
    _foodon_engine = None

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
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
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

        elif path == "/api/v1/profile/allergens":
            user_id = query.get("user_id", [None])[0]
            if not user_id:
                self._set_headers(400)
                resp = {"status": "error", "message": "Missing user_id query parameter"}
            else:
                allergens = get_user_allergens(int(user_id))
                self._set_headers(200)
                resp = {
                    "status": "success",
                    "user_id": int(user_id),
                    "allergens": allergens,
                    "total": len(allergens)
                }
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        elif path == "/api/v1/profile/metrics":
            user_id = query.get("user_id", [None])[0]
            metrics = get_user_metrics(int(user_id)) if user_id else get_user_metrics(1)
            h_m = float(metrics.get("height", 170.0)) / 100.0
            w = float(metrics.get("weight", 65.0))
            bmi = round(w / (h_m * h_m), 1) if h_m > 0 else 22.0
            metrics["bmi"] = bmi
            metrics["bmi_status"] = "Cân đối" if 18.5 <= bmi < 23.0 else ("Thiếu cân" if bmi < 18.5 else "Thừa cân")
            self._set_headers(200)
            self.wfile.write(json.dumps({"success": True, "metrics": metrics}).encode('utf-8'))

        elif path == "/api/v1/scans":
            user_id = query.get("user_id", [None])[0]
            if not user_id:
                self._set_headers(400)
                resp = {"success": False, "message": "user_id is required"}
            else:
                limit = int(query.get("limit", [50])[0])
                scans = get_user_scan_history(int(user_id), limit=limit)
                stats = get_scan_statistics(int(user_id))
                self._set_headers(200)
                resp = {
                    "success": True,
                    "user_id": int(user_id),
                    "scans": scans,
                    **stats
                }
            self.wfile.write(json.dumps(resp, ensure_ascii=False).encode('utf-8'))

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

    def do_DELETE(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        query = urllib.parse.parse_qs(parsed_url.query)

        if path == "/api/v1/scans":
            scan_id = query.get("scan_id", [None])[0]
            user_id = query.get("user_id", [None])[0]
            if not scan_id:
                self._set_headers(400)
                resp = {"success": False, "message": "scan_id query parameter is required"}
            else:
                ok, err = delete_scan_session(int(scan_id), int(user_id) if user_id else None)
                if ok:
                    self._set_headers(200)
                    resp = {"success": True, "message": "Đã xóa bản ghi quét khỏi cơ sở dữ liệu.", "deleted_id": int(scan_id)}
                else:
                    self._set_headers(404 if err == "SCAN_NOT_FOUND" else 500)
                    resp = {"success": False, "message": err}
            self.wfile.write(json.dumps(resp, ensure_ascii=False).encode('utf-8'))
        else:
            self._set_headers(404)
            resp = {"status": "error", "message": f"Route '{path}' not found"}
            self.wfile.write(json.dumps(resp).encode('utf-8'))

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

        # 4. Forgot Password Route
        elif path == "/api/v1/auth/forgot-password":
            email = body.get("email")
            user, error = create_reset_token(email)
            if error:
                # Anti-enumeration response: always say instructions sent if email valid format
                self._set_headers(200)
                resp = {
                    "status": "success",
                    "message": "Nếu email tồn tại trong hệ thống, hướng dẫn khôi phục mật khẩu đã được gửi đến hộp thư của bạn."
                }
            else:
                self._set_headers(200)
                resp = {
                    "status": "success",
                    "message": "Đã gửi hướng dẫn khôi phục mật khẩu đến email của bạn.",
                    "reset_token": user.get("reset_token")
                }
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        # 5. Save User Allergens Profile (FG2)
        elif path == "/api/v1/profile/allergens":
            user_id = body.get("user_id")
            allergens = body.get("allergens", [])
            if not user_id:
                self._set_headers(400)
                resp = {"status": "error", "message": "user_id is required"}
            else:
                ok, err = save_user_allergens(int(user_id), allergens)
                if ok:
                    self._set_headers(200)
                    resp = {
                        "status": "success",
                        "message": "Hồ sơ dị ứng đã được lưu thành công vào cơ sở dữ liệu.",
                        "count": len(allergens)
                    }
                else:
                    self._set_headers(500)
                    resp = {"status": "error", "message": err}
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        # 6. Change Password Route
        elif path == "/api/v1/auth/change-password":
            user_id = body.get("user_id")
            current_pwd = body.get("current_password")
            new_pwd = body.get("new_password")
            ok, err = change_user_password(int(user_id), current_pwd, new_pwd)
            if ok:
                self._set_headers(200)
                resp = {"success": True, "message": "Đổi mật khẩu thành công!"}
            else:
                self._set_headers(400)
                resp = {"success": False, "message": err or "Đổi mật khẩu thất bại"}
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        # 7. Save Physical & Nutrition Metrics Route
        elif path == "/api/v1/profile/metrics":
            user_id = body.get("user_id")
            age = int(body.get("age", 22))
            gender = body.get("gender", "male")
            height = float(body.get("height", 170.0))
            weight = float(body.get("weight", 65.0))
            activity = body.get("activity_level", "moderate")
            ok, err = save_user_metrics(int(user_id), age, gender, height, weight, activity)
            if ok:
                self._set_headers(200)
                resp = {"success": True, "message": "Đã lưu chỉ số thể trạng thành công!"}
            else:
                self._set_headers(500)
                resp = {"success": False, "message": err}
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        # 8. OCR Text Normalization (FG3 - UC07)
        elif path == "/api/v1/ocr/normalize":
            raw_text = (body.get("raw_text") or "").strip()
            lang = (body.get("lang") or "vi").strip().lower()
            if not raw_text:
                self._set_headers(400)
                resp = {"success": False, "message": "raw_text is required"}
            else:
                norm_res = normalize_ocr_payload(raw_text, lang=lang)
                self._set_headers(200)
                resp = norm_res
            self.wfile.write(json.dumps(resp, ensure_ascii=False).encode('utf-8'))

        # 9. Packaging Label Scan & Allergy Evaluation (FG3 - UC06, UC07, UC08)
        elif path == "/api/v1/scans":
            user_id = body.get("user_id")
            raw_text = (body.get("raw_text") or body.get("ingredients") or "").strip()
            label_title = (body.get("label_title") or "Kết quả quét").strip()
            member_name = (body.get("member_name") or "").strip()
            lang = (body.get("lang") or "vi").strip().lower()

            if not user_id:
                self._set_headers(400)
                resp = {"success": False, "message": "user_id is required"}
                self.wfile.write(json.dumps(resp).encode('utf-8'))
                return

            if not raw_text:
                self._set_headers(400)
                resp = {"success": False, "message": "Vui lòng nhập hoặc quét thành phần trên nhãn bao bì." if lang == "vi" else "Please enter or scan packaging ingredients."}
                self.wfile.write(json.dumps(resp, ensure_ascii=False).encode('utf-8'))
                return

            # Clean & normalize raw text, extract tokens & E-numbers
            norm_res = normalize_ocr_payload(raw_text, lang=lang)
            tokens = norm_res["tokens"]
            detected_additives = norm_res["extracted_e_numbers"]
            normalized_text = norm_res["normalized_text"]

            # Retrieve user allergens
            user_als = get_user_allergens(int(user_id))

            # Run hazard evaluation
            if _foodon_engine is not None:
                eval_res = _foodon_engine.evaluate_packaging_label(tokens, user_als, lang=lang)
                existing_add_codes = {a.get("code") or a.get("standard_code") for a in eval_res.get("detected_additives", [])}
                for add in detected_additives:
                    if add.get("standard_code") not in existing_add_codes:
                        eval_res.setdefault("detected_additives", []).append(add)
            else:
                red_triggers = []
                for tok in tokens:
                    tok_lower = tok.lower()
                    for al in user_als:
                        code = al.get("code", "").lower()
                        name = al.get("name", "").lower()
                        if (code and code in tok_lower) or (name and name in tok_lower):
                            red_triggers.append({
                                "token": tok,
                                "allergen_code": code,
                                "allergen_name": al.get("name", ""),
                                "severity": al.get("severity", "high")
                            })
                verdict = "RED" if red_triggers else "GREEN"
                eval_res = {
                    "verdict": verdict,
                    "title": "NGUY HIỂM: PHÁT HIỆN DỊ ỨNG" if verdict == "RED" else "AN TOÀN: KHÔNG PHÁT HIỆN DỊ ỨNG",
                    "red_triggers": red_triggers,
                    "yellow_triggers": [],
                    "detected_additives": detected_additives
                }

            verdict = eval_res.get("verdict", "GREEN")
            warning_count = len(eval_res.get("red_triggers", [])) + len(eval_res.get("yellow_triggers", []))
            additive_count = len(eval_res.get("detected_additives", []))

            if verdict == "RED":
                risk_level = "high"
                risk_label_vi = "Nguy cơ cao"
            elif verdict == "YELLOW":
                risk_level = "low"
                risk_label_vi = "Nguy cơ thấp"
            else:
                risk_level = "safe"
                risk_label_vi = "An toàn"

            # Persist session to database
            saved_scan, err = save_scan_session(
                user_id=int(user_id),
                raw_text=raw_text,
                label_title=label_title,
                member_name=member_name,
                normalized_text=normalized_text,
                tokens=tokens,
                additives=detected_additives,
                verdict=verdict,
                risk_level=risk_level,
                risk_label_vi=risk_label_vi,
                additive_count=additive_count,
                warning_count=warning_count,
                result_json=eval_res
            )

            if err:
                self._set_headers(500)
                resp = {"success": False, "message": err}
            else:
                all_scans = get_user_scan_history(int(user_id))
                stats = get_scan_statistics(int(user_id))
                self._set_headers(200)
                resp = {
                    "success": True,
                    "latest_scan": saved_scan,
                    "scans": all_scans,
                    **stats
                }
            self.wfile.write(json.dumps(resp, ensure_ascii=False).encode('utf-8'))

        # 10. Delete Scan Session (POST fallback)
        elif path == "/api/v1/scans/delete":
            scan_id = body.get("scan_id")
            user_id = body.get("user_id")
            if not scan_id:
                self._set_headers(400)
                resp = {"success": False, "message": "scan_id is required"}
            else:
                ok, err = delete_scan_session(int(scan_id), int(user_id) if user_id else None)
                if ok:
                    self._set_headers(200)
                    resp = {"success": True, "message": "Đã xóa bản ghi quét thành công.", "deleted_id": int(scan_id)}
                else:
                    self._set_headers(404 if err == "SCAN_NOT_FOUND" else 500)
                    resp = {"success": False, "message": err}
            self.wfile.write(json.dumps(resp, ensure_ascii=False).encode('utf-8'))

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
