"""
Comprehensive Accuracy, Compaction & Latency Evaluation Benchmark
for NutriViet Pure-English Official FoodOn Engine (`nutriviet_hybrid.db`)
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from hybrid_ontology import HybridFoodOnEngine, HYBRID_DB_PATH

# ---------------------------------------------------------------------------
# Benchmark 1: Single Ingredient Recognition & Allergen/Chronic Classification
# Format: (input_token, expected_allergens_set, expected_chronics_set, category)
# ---------------------------------------------------------------------------
BENCHMARK_INGREDIENTS = [
    # 1. Peanuts
    ("peanut", {"peanuts"}, set(), "1_peanuts"),
    ("peanuts", {"peanuts"}, set(), "1_peanuts"),
    ("peanut butter", {"peanuts"}, set(), "1_peanuts"),
    ("peanut oil", {"peanuts"}, set(), "1_peanuts"),
    ("Peanuts (28%)", {"peanuts"}, set(), "1_peanuts"),
    ("groundnut", {"peanuts"}, set(), "1_peanuts"),

    # 2. Milk & Dairy Derivatives
    ("milk", {"milk"}, set(), "2_milk"),
    ("cow milk", {"milk"}, set(), "2_milk"),
    ("powdered milk", {"milk"}, set(), "2_milk"),
    ("condensed milk", {"milk"}, set(), "2_milk"),
    ("butter", {"milk"}, set(), "2_milk"),
    ("cheese", {"milk"}, set(), "2_milk"),
    ("cream", {"milk"}, set(), "2_milk"),
    ("yogurt", {"milk"}, set(), "2_milk"),
    ("casein", {"milk"}, set(), "2_milk"),
    ("sodium caseinate", {"milk"}, set(), "2_milk"),
    ("whey", {"milk"}, set(), "2_milk"),
    ("whey protein", {"milk"}, set(), "2_milk"),
    ("lactose", {"milk"}, set(), "2_milk"),

    # 3. Seafood (Crustaceans, Molluscs, Fish)
    ("shrimp", {"seafood"}, None, "3_seafood"),
    ("crab", {"seafood"}, None, "3_seafood"),
    ("lobster", {"seafood"}, None, "3_seafood"),
    ("fish", {"seafood"}, None, "3_seafood"),
    ("salmon", {"seafood"}, None, "3_seafood"),
    ("tuna", {"seafood"}, None, "3_seafood"),
    ("mackerel", {"seafood"}, None, "3_seafood"),
    ("squid", {"seafood"}, None, "3_seafood"),
    ("octopus", {"seafood"}, None, "3_seafood"),
    ("oyster", {"seafood"}, None, "3_seafood"),
    ("clam", {"seafood"}, None, "3_seafood"),
    ("mussel", {"seafood"}, None, "3_seafood"),
    ("shrimp powder (2.5%)", {"seafood"}, None, "3_seafood"),
    ("fish sauce", {"seafood"}, None, "3_seafood"),

    # 4. Eggs & Egg Derivatives
    ("egg", {"eggs"}, set(), "4_eggs"),
    ("chicken egg", {"eggs"}, set(), "4_eggs"),
    ("egg yolk", {"eggs"}, set(), "4_eggs"),
    ("egg white", {"eggs"}, set(), "4_eggs"),
    ("albumin", {"eggs"}, set(), "4_eggs"),
    ("mayonnaise", {"eggs"}, set(), "4_eggs"),
    ("egg powder", {"eggs"}, set(), "4_eggs"),

    # 5. Soybeans & Soy Derivatives (including plant milk guard!)
    ("soybean", {"soy"}, set(), "5_soy"),
    ("soy", {"soy"}, set(), "5_soy"),
    ("tofu", {"soy"}, set(), "5_soy"),
    ("soy milk", {"soy"}, set(), "5_soy"),  # Must NOT trigger milk!
    ("soybean oil", {"soy"}, set(), "5_soy"),
    ("Emulsifier (soy lecithin)", {"soy"}, set(), "5_soy"),
    ("soy lecithin", {"soy"}, set(), "5_soy"),

    # 6. Gluten & Cereal Grains
    ("wheat", {"gluten"}, set(), "6_gluten"),
    ("wheat flour", {"gluten"}, set(), "6_gluten"),
    ("barley", {"gluten"}, set(), "6_gluten"),
    ("rye", {"gluten"}, set(), "6_gluten"),
    ("oat", {"gluten"}, set(), "6_gluten"),
    ("malt", {"gluten"}, set(), "6_gluten"),
    ("gluten", {"gluten"}, set(), "6_gluten"),

    # 7. Tree Nuts
    ("cashew", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("almond", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("walnut", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("chestnut", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("hazelnut", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("pistachio", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("macadamia", {"tree_nuts"}, set(), "7_tree_nuts"),
    ("pecan", {"tree_nuts"}, set(), "7_tree_nuts"),

    # 8. Sesame
    ("sesame", {"sesame"}, set(), "8_sesame"),
    ("sesame seed", {"sesame"}, set(), "8_sesame"),
    ("sesame oil", {"sesame"}, set(), "8_sesame"),

    # 9. E-Numbers / INS Codes & Chronic Condition Triggers
    ("Flavor enhancer (E621)", set(), {"hypertension", "gout"}, "9_ecodes_chronic"),
    ("INS 621", set(), {"hypertension", "gout"}, "9_ecodes_chronic"),
    ("monosodium glutamate", set(), {"hypertension", "gout"}, "9_ecodes_chronic"),
    ("E322", set(), set(), "9_ecodes_chronic"),
    ("INS 322(i)", set(), set(), "9_ecodes_chronic"),
    ("Thickener (E407)", set(), set(), "9_ecodes_chronic"),
    ("E440", set(), set(), "9_ecodes_chronic"),
    ("Sweetener (E954)", set(), set(), "9_ecodes_chronic"),
    ("E100", set(), set(), "9_ecodes_chronic"),
    ("sugar", set(), {"diabetes"}, "9_ecodes_chronic"),
    ("cane sugar", set(), {"diabetes"}, "9_ecodes_chronic"),
    ("honey", set(), {"diabetes"}, "9_ecodes_chronic"),
    ("syrup", set(), {"diabetes"}, "9_ecodes_chronic"),
    ("salt", set(), {"hypertension"}, "9_ecodes_chronic"),
    ("table salt", set(), {"hypertension"}, "9_ecodes_chronic"),
    ("lard", set(), {"cholesterol"}, "9_ecodes_chronic"),
    ("palm oil", set(), {"cholesterol"}, "9_ecodes_chronic"),

    # 10. Safe Non-Allergen Ingredients & Negative/Free Claims
    ("water", set(), set(), "10_safe_negatives"),
    ("rice", set(), set(), "10_safe_negatives"),
    ("rice flour", set(), set(), "10_safe_negatives"),
    ("pork", set(), set(), "10_safe_negatives"),
    ("beef", set(), set(), "10_safe_negatives"),
    ("chicken", set(), set(), "10_safe_negatives"),
    ("carrot", set(), set(), "10_safe_negatives"),
    ("potato", set(), set(), "10_safe_negatives"),
    ("onion", set(), set(), "10_safe_negatives"),
    ("garlic", set(), set(), "10_safe_negatives"),
    ("black pepper", set(), set(), "10_safe_negatives"),
    ("coconut", set(), set(), "10_safe_negatives"),
    ("coconut oil", set(), set(), "10_safe_negatives"),
    ("eggplant", set(), set(), "10_safe_negatives"),
    ("buckwheat", set(), set(), "10_safe_negatives"),
    ("gluten-free wheat starch", set(), set(), "10_safe_negatives"),
    ("lactose-free milk", {"milk"}, set(), "10_safe_negatives"),

    # 11. Simulated English OCR Typos
    ("peanutt", {"peanuts"}, set(), "11_ocr_fuzzy"),
    ("almmond", {"tree_nuts"}, set(), "11_ocr_fuzzy"),
    ("soybeann", {"soy"}, set(), "11_ocr_fuzzy"),
    ("hazelnutt", {"tree_nuts"}, set(), "11_ocr_fuzzy"),
]

# ---------------------------------------------------------------------------
# Benchmark 2: End-to-End Packaging Label Scenarios (UC09 RED / YELLOW / GREEN)
# ---------------------------------------------------------------------------
BENCHMARK_PACKAGING_SCENARIOS = [
    {
        "name": "Scenario 1: Butter Milk Biscuits (Milk allergy -> RED)",
        "tokens": ["Wheat flour", "Sugar", "Palm oil", "Powdered milk (8%)", "Whey protein", "Emulsifier (E322)", "Salt"],
        "user_allergens": [{"code": "milk", "severity": "anaphylaxis"}],
        "user_chronics": [],
        "expected_verdict": "RED",
    },
    {
        "name": "Scenario 2: Shrimp Instant Noodles (Seafood allergy + Hypertension -> RED)",
        "tokens": ["Wheat flour", "Palm oil", "Salt", "Sugar", "Shrimp powder (2.5%)", "Flavor enhancer (E621)", "Onion", "Garlic"],
        "user_allergens": [{"code": "seafood", "severity": "high"}],
        "user_chronics": ["hypertension"],
        "expected_verdict": "RED",
    },
    {
        "name": "Scenario 3: Pure Soy Milk (Milk allergy only, NOT soy -> GREEN)",
        "tokens": ["Water", "Soy milk (92%)", "Salt"],
        "user_allergens": [{"code": "milk", "severity": "anaphylaxis"}],
        "user_chronics": [],
        "expected_verdict": "GREEN",
    },
    {
        "name": "Scenario 4: Sweetened Soft Drink (No allergen match + Diabetes -> YELLOW)",
        "tokens": ["Water", "Cane sugar (11%)", "Natural flavor"],
        "user_allergens": [{"code": "peanuts", "severity": "high"}],
        "user_chronics": ["diabetes"],
        "expected_verdict": "YELLOW",
    },
    {
        "name": "Scenario 5: Mixed Nut Candy with OCR Typos (Peanut & Tree Nut allergy -> RED)",
        "tokens": ["Sugar", "Malt", "peanutt (25%)", "almmond", "sesame"],
        "user_allergens": [{"code": "peanuts", "severity": "high"}, {"code": "tree_nuts", "severity": "high"}],
        "user_chronics": [],
        "expected_verdict": "RED",
    },
    {
        "name": "Scenario 6: Traditional Rice Noodles (Gluten & Peanut allergy -> GREEN)",
        "tokens": ["Rice flour (85%)", "Water", "Salt"],
        "user_allergens": [{"code": "gluten", "severity": "high"}, {"code": "peanuts", "severity": "high"}],
        "user_chronics": [],
        "expected_verdict": "GREEN",
    },
]


def run_evaluation():
    print("=" * 80)
    print(" NUTRIVIET PURE-ENGLISH FOODON ENGINE EVALUATION BENCHMARK")
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

        al_ok = (pred_allergens == exp_allergens)
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
        ev = engine.evaluate_packaging_label(sc["tokens"], sc["user_allergens"], sc["user_chronics"], lang="en")
        ok = (ev["verdict"] == sc["expected_verdict"])
        if ok:
            scenario_pass += 1
        status = "PASS" if ok else "FAIL"
        print(f"  [{status}] {sc['name']}")
        print(f"         Verdict: {ev['wcag_glyph']} {ev['verdict']} (Expected: {sc['expected_verdict']}) | Latency: {ev['latency_ms']} ms")
        for rt in ev["red_triggers"]:
            print(f"         -> RED Trigger: {rt['token']!r} [{rt['allergen_name_en']}] via {rt['lineage']}")
        for yt in ev["yellow_triggers"]:
            lbl = yt.get("allergen_name_en") or yt.get("chronic_name_en")
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
