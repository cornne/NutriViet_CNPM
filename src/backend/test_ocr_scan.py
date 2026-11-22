"""
Comprehensive Unit & Integration Test Suite for FG3 (Packaging OCR Scanner)
Validates UC06, UC07, UC08 Implementation & Real Vietnamese Packaging Data
Performer: Le Tat Nam | Reviewer: Nguyen Hoang Phuc Thinh
"""

import unittest
import json
import os
import sys

# Ensure backend path is in sys.path
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from ocr_normalizer import (
    clean_raw_ocr_text,
    normalize_vietnamese_diacritics,
    tokenize_ingredients,
    extract_e_numbers,
    normalize_ocr_payload,
    STANDARD_ADDITIVES
)
from database import (
    init_db,
    create_user,
    save_user_allergens,
    save_scan_session,
    get_user_scan_history,
    get_scan_by_id,
    delete_scan_session,
    get_scan_statistics,
    get_connection
)
from server import NutriVietAuthHandler

class TestOCRNormalizer(unittest.TestCase):
    """Test suite for OCR Text Normalization & Additive Tokenizer (UC07)"""

    def test_01_clean_packaging_prefixes_and_noise(self):
        """Verify removal of introductory banners and noise characters"""
        raw_samples = [
            ("Thành phần: Bột mì, Đường, Muối.", "Bột mì, Đường, Muối."),
            ("THÀNH PHẦN CẤU TẠO: Bột mì, Dầu cọ, Đậu nành.", "Bột mì, Dầu cọ, Đậu nành."),
            ("Ingredients / Thành phần: Sữa tươi (95%), Đường.", "Sữa tươi (95%), Đường."),
            ("Nguyên liệu chính: Gạo, Nước, Muối i-ốt.", "Gạo, Nước, Muối i-ốt."),
            ("• Thành phần: Bột gạo, Tôm (10%) | ~", "Bột gạo, Tôm (10%)")
        ]
        for raw, expected in raw_samples:
            cleaned = clean_raw_ocr_text(raw)
            self.assertFalse(cleaned.lower().startswith("thành phần"), f"Failed for: {raw}")
            self.assertFalse(cleaned.lower().startswith("nguyên liệu"), f"Failed for: {raw}")
            self.assertFalse(cleaned.lower().startswith("ingredients"), f"Failed for: {raw}")

    def test_02_clean_trailing_packaging_metadata(self):
        """Verify stripping of expiry dates, net weight, manufacturing info"""
        noisy_text = (
            "Thành phần: Bột mì (65%), Đường, Đậu phộng (12%), Muối. "
            "HSD: 24/12/2027. NSX: 24/12/2025. KLT: 250g. "
            "Sản xuất tại: Công ty TNHH Thực Phẩm NutriViet, KCN Tân Bình, TP.HCM."
        )
        cleaned = clean_raw_ocr_text(noisy_text)
        self.assertNotIn("HSD:", cleaned)
        self.assertNotIn("NSX:", cleaned)
        self.assertNotIn("KLT:", cleaned)
        self.assertNotIn("Công ty TNHH", cleaned)
        self.assertIn("Đậu phộng (12%)", cleaned)

    def test_03_repair_hyphenated_word_breaks(self):
        """Verify repair of broken words split across packaging lines"""
        raw_wrap = "Bột mì, đậu-\nphộng, sữa bò,\nchất điều vị"
        cleaned = clean_raw_ocr_text(raw_wrap)
        self.assertIn("đậu phộng", cleaned)
        self.assertNotIn("đậu-", cleaned)

    def test_04_vietnamese_diacritics_normalization(self):
        """Verify Unicode NFC standard form and Vietnamese tone consistency"""
        sample = "Hương sữa tươi tự nhiên, chất bảo quản (Natri benzoat), màu thực phẩm tổng hợp"
        normalized = normalize_vietnamese_diacritics(sample)
        self.assertEqual(normalized, sample)
        # Tone mark placement check
        self.assertIn("òa", normalize_vietnamese_diacritics("oà"))
        self.assertIn("úy", normalize_vietnamese_diacritics("uý"))

    def test_05_intelligent_ingredient_tokenization(self):
        """Verify token segmentation preserving parenthetical percentages and sub-lists"""
        text = "Bột mì (65%), Dầu cọ, Đậu phộng (10%), Chất nhũ hóa (E322i, INS 471), Muối i-ốt, Hương vani tổng hợp"
        tokens = tokenize_ingredients(text)
        expected_tokens = [
            "Bột mì (65%)",
            "Dầu cọ",
            "Đậu phộng (10%)",
            "Chất nhũ hóa (E322i, INS 471)",
            "Muối i-ốt",
            "Hương vani tổng hợp"
        ]
        self.assertEqual(tokens, expected_tokens)

    def test_06_e_number_and_ins_extraction(self):
        """Verify detection of European E-numbers and Codex INS additive codes"""
        text = "Chất điều vị (E621, INS 627, E631), Chất nhũ hóa (E322i, INS 471), Phẩm màu (E102, INS 110)"
        additives = extract_e_numbers(text, lang="vi")
        codes = [a["standard_code"] for a in additives]

        self.assertIn("E621", codes)
        self.assertIn("E627", codes)
        self.assertIn("E631", codes)
        self.assertIn("E322I", codes)
        self.assertIn("E471", codes)
        self.assertIn("E102", codes)
        self.assertIn("E110", codes)

        # Verify metadata enrichment
        e621_meta = next(a for a in additives if a["standard_code"] == "E621")
        self.assertIn("Bột ngọt", e621_meta["name"])
        self.assertEqual(e621_meta["category"], "Chất điều vị")

        e322_meta = next(a for a in additives if a["standard_code"] == "E322I")
        self.assertIn("Lecithin", e322_meta["name"])
        self.assertEqual(e322_meta["category"], "Chất nhũ hóa")

    def test_07_real_food_label_mi_hao_hao(self):
        """Real-world test: Mì ăn liền Hảo Hảo Tôm Chua Cay"""
        hao_hao_label = (
            "Thành phần: Vắt mì: Bột mì, dầu cọ, tinh bột khoai mì, muối, đường, chất điều vị (621, 631, 627), "
            "chất ổn định (451i, 501i), phẩm màu tự nhiên (160a(ii)). "
            "Gói gia vị: Dầu cọ, muối, đường, tôm (15 g/kg), chất điều vị (621, 631, 627), hành sấy, "
            "ớt, chất điều chỉnh độ acid (330). HSD: 5 tháng kể từ NSX. KLT: 75 g."
        )
        res = normalize_ocr_payload(hao_hao_label, lang="vi")
        self.assertTrue(res["success"])
        self.assertGreater(len(res["tokens"]), 5)
        # Check that 'tôm' and 'bột mì' are retained
        token_str = " ".join(res["tokens"]).lower()
        self.assertIn("bột mì", token_str)
        self.assertIn("tôm", token_str)

    def test_08_real_food_label_banh_quy_oreo(self):
        """Real-world test: Bánh quy kẹp kem Oreo"""
        oreo_label = (
            "THÀNH PHẦN: Bột mì, Đường, Dầu thực vật không hydro hóa (dầu cọ chứa chất chống oxy hóa TBHQ (319)), "
            "Bột cacao (4%), Siro fructose, Chất tạo xốp (500(ii), 503(ii)), Muối, Bột bắp, "
            "Chất nhũ hóa (lecithin đậu nành (322(i))), Hương vani tổng hợp. "
            "Thông tin cảnh báo dị ứng: Chứa bột mì và đậu nành. Khối lượng tịnh: 133g."
        )
        res = normalize_ocr_payload(oreo_label, lang="vi")
        self.assertTrue(res["success"])
        self.assertGreater(res["token_count"], 4)
        tokens_lower = [t.lower() for t in res["tokens"]]
        self.assertTrue(any("bột mì" in t for t in tokens_lower))
        self.assertTrue(any("đậu nành" in t or "lecithin" in t for t in tokens_lower))


class TestDatabaseScanHistory(unittest.TestCase):
    """Test suite for Scan History Database Operations (UC08)"""

    @classmethod
    def setUpClass(cls):
        init_db()

    def test_01_save_and_retrieve_scan_session(self):
        """Verify saving a scan session and reading it chronologically"""
        user_id = 1
        raw_text = "Thành phần: Bột mì, Đường, Đậu phộng (15%), Muối, E322i."
        label_title = "Bánh Quy Bơ Đậu Phộng Test"
        tokens = ["Bột mì", "Đường", "Đậu phộng (15%)", "Muối", "E322i"]
        additives = [{"code": "E322i", "standard_code": "E322", "name": "Lecithin"}]

        saved, err = save_scan_session(
            user_id=user_id,
            raw_text=raw_text,
            label_title=label_title,
            member_name="Nam",
            normalized_text="Bột mì, Đường, Đậu phộng (15%), Muối, E322i",
            tokens=tokens,
            additives=additives,
            verdict="RED",
            risk_level="high",
            risk_label_vi="Nguy cơ cao",
            additive_count=1,
            warning_count=1,
            result_json={"verdict": "RED", "red_triggers": [{"token": "Đậu phộng", "allergen": "peanuts"}]}
        )

        self.assertIsNone(err)
        self.assertIsNotNone(saved)
        scan_id = saved["id"]

        # Retrieve by scan_id
        record = get_scan_by_id(scan_id, user_id=user_id)
        self.assertIsNotNone(record)
        self.assertEqual(record["label_title"], label_title)
        self.assertEqual(record["verdict"], "RED")
        self.assertEqual(record["tokens"], tokens)
        self.assertEqual(record["additives"], additives)
        self.assertEqual(record["evaluation"]["verdict"], "RED")

        # Retrieve user history list
        history = get_user_scan_history(user_id, limit=10)
        self.assertGreater(len(history), 0)
        self.assertEqual(history[0]["id"], scan_id)

        # Check statistics
        stats = get_scan_statistics(user_id)
        self.assertGreaterEqual(stats["total_scans"], 1)
        self.assertGreaterEqual(stats["warning_scans"], 1)
        self.assertGreaterEqual(stats["monthly_scans"], 1)

    def test_02_delete_scan_session(self):
        """Verify deleting a scan session from history (UC08 A2 flow)"""
        user_id = 1
        saved, _ = save_scan_session(
            user_id=user_id,
            raw_text="Nước cam ép, Đường, Vitamin C (E300).",
            label_title="Nước cam ép xóa test",
            verdict="GREEN",
            risk_level="safe",
            risk_label_vi="An toàn"
        )
        scan_id = saved["id"]

        # Ensure exists
        self.assertIsNotNone(get_scan_by_id(scan_id))

        # Delete
        ok, err = delete_scan_session(scan_id, user_id=user_id)
        self.assertTrue(ok)
        self.assertIsNone(err)

        # Verify gone
        self.assertIsNone(get_scan_by_id(scan_id))


class DummyNutriVietHandler(NutriVietAuthHandler):
    """Direct in-memory mock handler for deterministic, socket-free testing"""
    def __init__(self, method: str, path: str, body: dict = None):
        import io
        self.command = method
        self.path = path
        body_bytes = json.dumps(body, ensure_ascii=False).encode('utf-8') if body is not None else b""
        self.headers = {
            'Content-Length': str(len(body_bytes)),
            'Content-Type': 'application/json'
        }
        self.rfile = io.BytesIO(body_bytes)
        self.wfile = io.BytesIO()
        self._status = 200

    def _set_headers(self, status_code=200, content_type="application/json"):
        self._status = status_code

    def send_response(self, code, message=None):
        self._status = code

    def send_header(self, keyword, value):
        pass

    def end_headers(self):
        pass

    def get_json(self):
        self.wfile.seek(0)
        return json.loads(self.wfile.read().decode('utf-8'))


class TestServerAPIEndpoints(unittest.TestCase):
    """Test suite for HTTP REST Handlers in server.py (UC06, UC07, UC08)"""

    @classmethod
    def setUpClass(cls):
        init_db()
        # Ensure user 1 has peanut allergy configured for RED alert verification
        save_user_allergens(1, [{"code": "peanuts", "name": "Đậu phộng", "severity": "high"}])

    def test_01_api_ocr_normalize(self):
        """Test POST /api/v1/ocr/normalize endpoint logic"""
        payload = {
            "raw_text": "Thành phần: Bột mì (70%), Đường, Đậu phộng (10%), Chất nhũ hóa (E322i). HSD: 12/2027",
            "lang": "vi"
        }
        handler = DummyNutriVietHandler("POST", "/api/v1/ocr/normalize", payload)
        handler.do_POST()
        self.assertEqual(handler._status, 200)
        data = handler.get_json()
        self.assertTrue(data["success"])
        self.assertIn("Bột mì (70%)", data["tokens"])
        self.assertIn("Đậu phộng (10%)", data["tokens"])
        self.assertEqual(len(data["extracted_e_numbers"]), 1)
        self.assertEqual(data["extracted_e_numbers"][0]["standard_code"], "E322I")

    def test_02_api_create_scan_session(self):
        """Test POST /api/v1/scans with allergen trigger (RED alert) and DB save"""
        payload = {
            "user_id": 1,
            "raw_text": "Thành phần: Bột mì, Đường, Bơ đậu phộng, Dầu cọ, Chất điều vị E621. KLT: 100g",
            "label_title": "Bánh Bơ Đậu Phộng API Test",
            "member_name": "Lê Tất Nam",
            "lang": "vi"
        }
        handler = DummyNutriVietHandler("POST", "/api/v1/scans", payload)
        handler.do_POST()
        self.assertEqual(handler._status, 200)
        data = handler.get_json()
        self.assertTrue(data["success"])
        self.assertIsNotNone(data["latest_scan"])
        self.assertEqual(data["latest_scan"]["label_title"], "Bánh Bơ Đậu Phộng API Test")
        self.assertEqual(data["latest_scan"]["verdict"], "RED")
        self.assertEqual(data["latest_scan"]["risk_level"], "high")
        self.assertGreaterEqual(data["total_scans"], 1)

    def test_03_api_get_scans_history(self):
        """Test GET /api/v1/scans?user_id=1"""
        handler = DummyNutriVietHandler("GET", "/api/v1/scans?user_id=1")
        handler.do_GET()
        self.assertEqual(handler._status, 200)
        data = handler.get_json()
        self.assertTrue(data["success"])
        self.assertIsInstance(data["scans"], list)
        self.assertGreater(len(data["scans"]), 0)

    def test_04_api_delete_scan(self):
        """Test DELETE /api/v1/scans?scan_id=...&user_id=1"""
        # First save a scan
        saved, _ = save_scan_session(
            user_id=1,
            raw_text="Gạo tẻ, Nước khoáng.",
            label_title="Scan to delete",
            verdict="GREEN"
        )
        scan_id = saved["id"]

        handler = DummyNutriVietHandler("DELETE", f"/api/v1/scans?scan_id={scan_id}&user_id=1")
        handler.do_DELETE()
        self.assertEqual(handler._status, 200)
        data = handler.get_json()
        self.assertTrue(data["success"])
        self.assertEqual(data["deleted_id"], scan_id)


if __name__ == "__main__":
    print("=" * 70)
    print("🧪 Running NutriViet FG3 OCR Scanner & History Test Suite")
    print("=" * 70)
    unittest.main(verbosity=2)
