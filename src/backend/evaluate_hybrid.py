"""
Comprehensive Accuracy, Compaction & Latency Evaluation Benchmark
for NutriViet Hybrid FoodOn + Kala Engine (`nutriviet_hybrid.db`)
"""

import os
import sys
import time
import json

sys.path.insert(0, os.path.dirname(__file__))
from hybrid_ontology import HybridFoodOnEngine, HYBRID_DB_PATH, DATA_DIR

# ---------------------------------------------------------------------------
# Benchmark 1: Single Ingredient Recognition & Allergen/Chronic Classification
# Format: (input_token, expected_allergens_set, expected_chronics_set, category)
# ---------------------------------------------------------------------------
BENCHMARK_INGREDIENTS = [
    # 1. Peanuts (Vietnamese dialects + products + English)
    ("đậu phộng", {"peanuts"}, set(), "1_peanuts"),
    ("lạc", {"peanuts"}, set(), "1_peanuts"),
    ("đậu phụng", {"peanuts"}, set(), "1_peanuts"),
    ("bơ đậu phộng", {"peanuts"}, set(), "1_peanuts"),
    ("bơ lạc", {"peanuts"}, set(), "1_peanuts"),
    ("dầu đậu phộng", {"peanuts"}, set(), "1_peanuts"),
    ("Đậu phộng (28%)", {"peanuts"}, set(), "1_peanuts"),
    ("peanut", {"peanuts"}, set(), "1_peanuts"),
    ("peanut butter", {"peanuts"}, set(), "1_peanuts"),

    # 2. Milk & Hidden Dairy Derivatives (Vietnamese + English)
    ("sữa bò", {"milk"}, set(), "2_milk"),
    ("sữa tươi", {"milk"}, set(), "2_milk"),
    ("sữa đặc", {"milk"}, set(), "2_milk"),
    ("sữa bột", {"milk"}, set(), "2_milk"),
    ("bơ", {"milk"}, set(), "2_milk"),
    ("phô mai", {"milk"}, set(), "2_milk"),
    ("phó mát", {"milk"}, set(), "2_milk"),
    ("kem sữa", {"milk"}, set(), "2_milk"),
    ("sữa chua", {"milk"}, set(), "2_milk"),
    ("casein", {"milk"}, set(), "2_milk"),
    ("ca-zê-in", {"milk"}, set(), "2_milk"),
    ("sodium caseinate", {"milk"}, set(), "2_milk"),
    ("whey", {"milk"}, set(), "2_milk"),
    ("nước sữa", {"milk"}, set(), "2_milk"),
    ("đạm whey", {"milk"}, set(), "2_milk"),
    ("lactose", {"milk"}, set(), "2_milk"),
    ("đường sữa", {"milk"}, set(), "2_milk"),
    ("lactoza", {"milk"}, set(), "2_milk"),

    # 3. Seafood (Crustaceans, Molluscs, Fish in Vietnamese)
    ("tôm", {"seafood"}, None, "3_seafood"),
    ("cua", {"seafood"}, None, "3_seafood"),
    ("ghẹ", {"seafood"}, None, "3_seafood"),
    ("tôm hùm", {"seafood"}, None, "3_seafood"),
    ("cá", {"seafood"}, None, "3_seafood"),
    ("cá hồi", {"seafood"}, None, "3_seafood"),
    ("cá ngừ", {"seafood"}, None, "3_seafood"),
    ("cá thu", {"seafood"}, None, "3_seafood"),
    ("mực", {"seafood"}, None, "3_seafood"),
    ("bạch tuộc", {"seafood"}, None, "3_seafood"),
    ("hàu", {"seafood"}, None, "3_seafood"),
    ("sò", {"seafood"}, None, "3_seafood"),
    ("ngao", {"seafood"}, None, "3_seafood"),
    ("hến", {"seafood"}, None, "3_seafood"),
    ("vẹm", {"seafood"}, None, "3_seafood"),
    ("bột tôm", {"seafood"}, None, "3_seafood"),
    ("chiết xuất cua", {"seafood"}, None, "3_seafood"),

    # 4. Eggs & Egg Derivatives
    ("trứng", {"eggs"}, set(), "4_eggs"),
    ("trứng gà", {"eggs"}, set(), "4_eggs"),
    ("trứng vịt", {"eggs"}, set(), "4_eggs"),
    ("lòng đỏ trứng", {"eggs"}, set(), "4_eggs"),
    ("lòng trắng trứng", {"eggs"}, set(), "4_eggs"),
    ("albumin", {"eggs"}, set(), "4_eggs"),
    ("mayonnaise", {"eggs"}, set(), "4_eggs"),
    ("bột trứng", {"eggs"}, set(), "4_eggs"),

    # 5. Soybeans & Soy Derivatives (including plant milk override!)
    ("đậu nành", {"soy"}, set(), "5_soy"),
    ("đỗ tương", {"soy"}, set(), "5_soy"),
    ("đậu phụ", {"soy"}, set(), "5_soy"),
    ("tàu hũ", {"soy"}, set(), "5_soy"),
    ("sữa đậu nành", {"soy"}, set(), "5_soy"),  # Must NOT trigger milk!
    ("dầu đậu nành", {"soy"}, set(), "5_soy"),
    ("Chất nhũ hóa (Lecithin đậu nành)", {"soy"}, set(), "5_soy"),
    ("soy lecithin", {"soy"}, set(), "5_soy"),

    # 6. Gluten & Cereal Grains
    ("lúa mì", {"gluten"}, set(), "6_gluten"),
    ("bột mì", {"gluten"}, set(), "6_gluten"),
    ("lúa mạch", {"gluten"}, set(), "6_gluten"),
    ("đại mạch", {"gluten"}, set(), "6_gluten"),
    ("lúa mạch đen", {"gluten"}, set(), "6_gluten"),
    ("yến mạch", {"gluten"}, set(), "6_gluten"),
    ("mạch nha", {"gluten"}, set(), "6_gluten"),
    ("gluten", {"gluten"}, set(), "6_gluten"),
    ("wheat flour", {"gluten"}, set(), "6_gluten"),

    # 7. Tree Nuts
    ("hạt điều", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("đào lộn hột", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("hạnh nhân", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("óc chó", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("quả óc chó", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("hạt dẻ", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("quả phỉ", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("hạt dẻ cười", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("macadamia", {"tree_nuts"}, set(), "7_tree_nuts"),

    # 8. Sesame
    ("mè", {"sesame"}, set(), "8_sesame"),
    ("vừng", {"sesame"}, set(), "8_sesame"),
    ("dầu mè", {"sesame"}, set(), "8_sesame"),
    ("hạt mè", {"sesame"}, set(), "8_sesame"),
    ("sesame oil", {"sesame"}, set(), "8_sesame"),

    # 9. E-Numbers / INS Codes & Chronic Condition Triggers
    ("Chất điều vị (E621)", set(), {"hypertension", "gout"}, "9_ecodes_chronic"),
    ("INS 621", set(), {"hypertension", "gout"}, "9_ecodes_chronic"),
    ("bột ngọt", set(), {"hypertension", "gout"}, "9_ecodes_chronic"),
    ("mì chính", set(), {"hypertension", "gout"}, "9_ecodes_chronic"),
    ("E322", set(), set(), "9_ecodes_chronic"),
    ("INS 322(i)", set(), set(), "9_ecodes_chronic"),
    ("Chất làm dày (E407)", set(), set(), "9_ecodes_chronic"),
    ("E440", set(), set(), "9_ecodes_chronic"),
    ("Chất tạo ngọt (E954)", set(), set(), "9_ecodes_chronic"),
    ("E100", set(), set(), "9_ecodes_chronic"),
    ("đường", set(), {"diabetes"}, "9_ecodes_chronic"),
    ("đường mía", set(), {"diabetes"}, "9_ecodes_chronic"),
    ("mật ong", set(), {"diabetes"}, "9_ecodes_chronic"),
    ("si-rô", set(), {"diabetes"}, "9_ecodes_chronic"),
    ("muối", set(), {"hypertension"}, "9_ecodes_chronic"),
    ("muối ăn", set(), {"hypertension"}, "9_ecodes_chronic"),
    ("mỡ lợn", set(), {"cholesterol"}, "9_ecodes_chronic"),
    ("dầu cọ", set(), {"cholesterol"}, "9_ecodes_chronic"),

    # 10. Safe Non-Allergen Ingredients & Negative/Free Claims (False Positive Guard)
    ("nước", set(), set(), "10_safe_negatives"),
    ("gạo", set(), set(), "10_safe_negatives"),
    ("bột gạo", set(), set(), "10_safe_negatives"),
    ("thịt lợn", set(), set(), "10_safe_negatives"),
    ("thịt bò", set(), set(), "10_safe_negatives"),
    ("thịt gà", set(), set(), "10_safe_negatives"),
    ("cà rốt", set(), set(), "10_safe_negatives"),
    ("khoai tây", set(), set(), "10_safe_negatives"),
    ("hành tây", set(), set(), "10_safe_negatives"),
    ("tỏi", set(), set(), "10_safe_negatives"),
    ("hạt tiêu", set(), set(), "10_safe_negatives"),
    ("ớt", set(), set(), "10_safe_negatives"),
    ("dừa", set(), set(), "10_safe_negatives"),
    ("dầu dừa", set(), set(), "10_safe_negatives"),
    ("cà tím", set(), set(), "10_safe_negatives"),
    ("kiều mạch", set(), set(), "10_safe_negatives"),
    ("Bột mì không chứa gluten", set(), set(), "10_safe_negatives"),
    ("Sữa bò không chứa lactose", {"milk"}, set(), "10_safe_negatives"),  # Still cow milk protein (casein/whey), unless lactose-only check

    # 11. Simulated OCR Noise & Unaccented Vietnamese Strings
    ("đâu phông", {"peanuts"}, set(), "11_ocr_fuzzy"),
    ("sua bo", {"milk"}, set(), "11_ocr_fuzzy"),
    ("bột mi", {"gluten"}, set(), "11_ocr_fuzzy"),
    ("hanh nhan", {"tree_nuts"}, set(), "11_ocr_fuzzy"),
    ("dau nanh", {"soy"}, set(), "11_ocr_fuzzy"),
    ("hat dieu", {"tree_nuts"}, set(), "11_ocr_fuzzy"),
]

# ---------------------------------------------------------------------------
# Benchmark 2: End-to-End Packaging Label Scenarios (UC09 RED / YELLOW / GREEN)
# ---------------------------------------------------------------------------
BENCHMARK_PACKAGING_SCENARIOS = [
    {
        "name": "Scenario 1: Bánh quy bơ sữa (User dị ứng Sữa nghiêm trọng -> RED)",
        "tokens": ["Bột mì", "Đường", "Dầu cọ", "Sữa bột (8%)", "Whey protein", "Chất nhũ hóa (E322)", "Muối"],
        "user_allergens": [{"code": "milk", "severity": "anaphylaxis"}],
        "user_chronics": [],
        "expected_verdict": "RED",
    },
    {
        "name": "Scenario 2: Mì ăn liền tôm chua cay (User dị ứng Hải sản & bệnh Tăng huyết áp -> RED)",
        "tokens": ["Bột mì", "Dầu cọ", "Muối", "Đường", "Bột tôm (2.5%)", "Chất điều vị (E621)", "Hành", "Tỏi", "Ớt"],
        "user_allergens": [{"code": "seafood", "severity": "high"}],
        "user_chronics": ["hypertension"],
        "expected_verdict": "RED",
    },
    {
        "name": "Scenario 3: Sữa đậu nành nguyên chất (User dị ứng Sữa bò, KHÔNG dị ứng Đậu nành -> GREEN)",
        "tokens": ["Nước", "Sữa đậu nành (92%)", "Muối"],
        "user_allergens": [{"code": "milk", "severity": "anaphylaxis"}],
        "user_chronics": [],
        "expected_verdict": "GREEN",
    },
    {
        "name": "Scenario 4: Nước giải khát có đường (User không dị ứng nhưng bị Tiểu đường -> YELLOW)",
        "tokens": ["Nước", "Đường mía (11%)", "Hương tự nhiên"],
        "user_allergens": [{"code": "peanuts", "severity": "high"}],
        "user_chronics": ["diabetes"],
        "expected_verdict": "YELLOW",
    },
    {
        "name": "Scenario 5: Kẹo hạt tổng hợp bị lỗi OCR mất dấu (User dị ứng Đậu phộng & Hạt cây -> RED)",
        "tokens": ["Đường", "Mạch nha", "đâu phông (25%)", "hanh nhan", "mè"],
        "user_allergens": [{"code": "peanuts", "severity": "high"}, {"code": "tree_nuts", "severity": "high"}],
        "user_chronics": [],
        "expected_verdict": "RED",
    },
    {
        "name": "Scenario 6: Bánh phở gạo truyền thống (User dị ứng Gluten & Đậu phộng -> GREEN)",
        "tokens": ["Bột gạo (85%)", "Nước", "Muối"],
        "user_allergens": [{"code": "gluten", "severity": "high"}, {"code": "peanuts", "severity": "high"}],
        "user_chronics": [],
        "expected_verdict": "GREEN",
    },
]


def run_evaluation():
    print("=" * 80)
    print(" NUTRIVIET HYBRID ONTOLOGY ENGINE (FOODON + KALA) EVALUATION BENCHMARK")
    print("=" * 80)

    t_init0 = time.perf_counter()
    engine = HybridFoodOnEngine()
    init_ms = (time.perf_counter() - t_init0) * 1000
    db_size_mb = os.path.getsize(HYBRID_DB_PATH) / (1024 * 1024)

    print(f"[Engine Loaded] DB Size: {db_size_mb:.2f} MB | Cold Start Time: {init_ms:.1f} ms")
    print(f"                Concepts: {len(engine.concepts):,} | VI Terms: {len(engine.vi_exact):,} | EN Terms: {len(engine.en_exact):,} | E-codes: {len(engine.ecode_map):,}")
    print("-" * 80)

    tp = 0
    fp = 0
    fn = 0
    tn = 0
    exact_matches = 0
    total_cases = len(BENCHMARK_INGREDIENTS)
    failures = []
    latencies_ms = []

    for token, exp_allergens, exp_chronics, cat in BENCHMARK_INGREDIENTS:
        t0 = time.perf_counter()
        res = engine.recognize_ingredient(token)
        lat_ms = (time.perf_counter() - t0) * 1000
        latencies_ms.append(lat_ms)

        pred_allergens = set(res["allergens"])
        pred_chronics = set(res["chronics"])

        # Allergen set evaluation
        al_ok = (pred_allergens == exp_allergens)
        # Chronic set evaluation (if exp_chronics is not None and non-empty, check subset)
        ch_ok = True
        if exp_chronics:
            ch_ok = exp_chronics.issubset(pred_chronics)

        if exp_allergens:
            tp += len(pred_allergens & exp_allergens)
            fp += len(pred_allergens - exp_allergens)
            fn += len(exp_allergens - pred_allergens)
        else:
            if not pred_allergens:
                tn += 1
            else:
                fp += len(pred_allergens)

        if al_ok and ch_ok and res["matched"]:
            exact_matches += 1
        else:
            failures.append({
                "category": cat,
                "token": token,
                "matched": res["matched"],
                "expected_allergens": sorted(exp_allergens),
                "predicted_allergens": sorted(pred_allergens),
                "expected_chronics": sorted(exp_chronics) if exp_chronics else [],
                "predicted_chronics": sorted(pred_chronics),
                "matches": [(m["curie"], m["label_en"], m["match_type"], m["confidence"]) for m in res["matches"]],
            })

    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = (2 * precision * recall / (precision + recall)) if (precision + recall) else 0.0
    accuracy = exact_matches / total_cases if total_cases else 0.0
    avg_lat = sum(latencies_ms) / len(latencies_ms) if latencies_ms else 0.0

    print(f"[Benchmark 1: Single Ingredient Recognition ({total_cases} Test Cases)]")
    print(f"  - Exact Case Accuracy : {exact_matches}/{total_cases} ({accuracy * 100:.2f}%)")
    print(f"  - Allergen Precision  : {precision * 100:.2f}% (TP={tp}, FP={fp})")
    print(f"  - Allergen Recall     : {recall * 100:.2f}% (TP={tp}, FN={fn})")
    print(f"  - Allergen F1-Score   : {f1 * 100:.2f}%")
    print(f"  - True Negatives (TN) : {tn}")
    print(f"  - Avg Query Latency   : {avg_lat:.3f} ms/token")

    if failures:
        print(f"\n[!] Failures / Mismatches ({len(failures)}):")
        for f in failures:
            print(f"  * [{f['category']}] {f['token']!r} -> matched={f['matched']} | "
                  f"exp_al={f['expected_allergens']} got_al={f['predicted_allergens']} | "
                  f"exp_ch={f['expected_chronics']} got_ch={f['predicted_chronics']} | "
                  f"nodes={f['matches']}")

    print("\n" + "-" * 80)
    print(f"[Benchmark 2: End-to-End Packaging Label Scenarios ({len(BENCHMARK_PACKAGING_SCENARIOS)} Scenarios)]")
    scenario_pass = 0
    for sc in BENCHMARK_PACKAGING_SCENARIOS:
        ev = engine.evaluate_packaging_label(sc["tokens"], sc["user_allergens"], sc["user_chronics"])
        ok = (ev["verdict"] == sc["expected_verdict"])
        if ok:
            scenario_pass += 1
        status = "PASS" if ok else "FAIL"
        print(f"  [{status}] {sc['name']}")
        print(f"         Verdict: {ev['wcag_glyph']} {ev['verdict']} (Expected: {sc['expected_verdict']}) | Latency: {ev['latency_ms']} ms")
        for rt in ev["red_triggers"]:
            print(f"         -> RED Trigger: {rt['token']!r} [{rt['allergen_name_vi']}] via {rt['lineage']}")
        for yt in ev["yellow_triggers"]:
            lbl = yt.get("allergen_name_vi") or yt.get("chronic_name_vi")
            print(f"         -> YELLOW Trigger: {yt['token']!r} [{lbl}] via {yt['lineage']}")

    print("=" * 80)
    return {
        "total_cases": total_cases,
        "exact_matches": exact_matches,
        "accuracy_pct": round(accuracy * 100, 2),
        "precision_pct": round(precision * 100, 2),
        "recall_pct": round(recall * 100, 2),
        "f1_pct": round(f1 * 100, 2),
        "avg_latency_ms": round(avg_lat, 3),
        "scenario_pass": scenario_pass,
        "scenario_total": len(BENCHMARK_PACKAGING_SCENARIOS),
        "failures": failures,
    }


if __name__ == "__main__":
    run_evaluation()
