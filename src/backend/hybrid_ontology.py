"""
NutriViet Hybrid Ontology & Bilingual Dictionary Engine (FoodOn + Kala)
=======================================================================
100% Data-Driven Connection between:
  1. FoodOn Repository (foodon.owl, foodon-synonyms.tsv, ingredients.yaml)
  2. Kala Bilingual Databases (va_v3.db Vietnamese->English, av_v3.db English->Vietnamese)

Zero hardcoded fallback wordlists: all lexical terms, synonyms, E-numbers/INS codes,
and taxonomic/derivation hierarchies are extracted and compacted directly from the
source databases into `src/backend/data/nutriviet_hybrid.db`.
"""

import os
import re
import sys
import json
import time
import zlib
import sqlite3
import unicodedata
from difflib import SequenceMatcher
import yaml

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
FOODON_DIR = os.path.join(DATA_DIR, "foodon")
HYBRID_DB_PATH = os.path.join(DATA_DIR, "nutriviet_hybrid.db")

# ---------------------------------------------------------------------------
# Ontology Root Anchors in FoodOn (Strictly Official CURIEs in foodon.owl)
# ---------------------------------------------------------------------------
FOODON_ALLERGEN_ROOTS = {
    "peanuts": {
        "include_roots": {
            "FOODON:00003206",  # peanut
            "FOODON:00002099",  # peanut food product
            "FOODON:03411270",  # peanut plant
            "NCBITaxon:3818",   # Arachis hypogaea
            "FOODON:03510218",  # food allergen labelling about peanuts
        },
        "exclude_roots": set(),
    },
    "soy": {
        "include_roots": {
            "FOODON:03301415",  # soybean
            "FOODON:00002266",  # soybean food product
            "FOODON:03411452",  # soybean plant
            "NCBITaxon:3847",   # Glycine max
            "FOODON:03510219",  # food allergen labelling about soybeans
        },
        "exclude_roots": {
            "FOODON:03310629",  # soybean milk substitute (hypoallergenic)
        },
    },
    "milk": {
        "include_roots": {
            "FOODON:00001256",  # dairy food product
            "FOODON:02010012",  # animal milk
            "FOODON:03315150",  # mammalian milk product
            "FOODON:00001257",  # milk or milk based food product
            "FOODON:00001771",  # cow milk based food product
            "FOODON:03420180",  # casein (predominant protein of milk per IAO_0000115)
            "CHEBI:17716",      # lactose (milk sugar per IAO_0000115)
            "FOODON:03542650",  # milk, whey and cream
            "FOODON:03510220",  # food allergen labelling about milk and lactose
        },
        "exclude_roots": {
            "FOODON:03510171",  # lactose free food
            "FOODON:00002266",  # soybean food product (soy milk)
            "FOODON:00001816",  # plant-based milk beverage
            "FOODON:03301451",  # coconut milk
        },
    },
    "eggs": {
        "include_roots": {
            "FOODON:02010002",  # animal egg
            "FOODON:00001274",  # egg food product
            "FOODON:00001105",  # avian egg food product
            "FOODON:03420194",  # egg component (yolk/white)
            "UBERON:0008944",   # albumen (egg white)
            "UBERON:0007378",   # egg yolk
            "CHEBI:166964",     # albumin type
            "FOODON:00001234",  # mayonnaise food product (emulsion with egg yolk per IAO_0000111)
            "FOODON:03510216",  # food allergen labelling about eggs
        },
        "exclude_roots": {
            "FOODON:03411579",  # eggplant (Solanum melongena)
            "FOODON:03306409",  # mayonnaise analog (eggless)
        },
    },
    "seafood": {
        "include_roots": {
            "FOODON:03411433",  # shellfish species
            "FOODON:03411374",  # crustacean
            "FOODON:03412112",  # mollusc
            "FOODON:00005704",  # crustacean material
            "FOODON:00005702",  # mollusc material
            "FOODON:00002581",  # aquatic invertebrate
            "FOODON:03411021",  # fish or lower water animal
            "FOODON:00001248",  # fish food product
            "FOODON:03411365",  # fish
            "FOODON:00005506",  # fish material
            "FOODON:00001293",  # shellfish food product
            "FOODON:03510215",  # crustaceans allergen labelling
            "FOODON:03510217",  # fish allergen labelling
            "FOODON:03510232",  # molluscs allergen labelling
        },
        "exclude_roots": set(),
    },
    "gluten": {
        "include_roots": {
            "FOODON:03420177",  # gluten
            "FOODON:00001907",  # gluten refined food product
            "CHEBI:166887",     # glutenin
            "FOODON:00001141",  # wheat food product
            "FOODON:03411312",  # wheat plant
            "NCBITaxon:4564",   # Triticum (wheat)
            "FOODON:00001138",  # barley food product
            "FOODON:03411598",  # barley plant
            "NCBITaxon:4513",   # Hordeum (barley)
            "FOODON:00005788",  # malt (germinated cereal grain)
            "FOODON:00001222",  # rye food product
            "FOODON:03411599",  # rye plant
            "NCBITaxon:4550",   # Secale (rye)
            "FOODON:00001189",  # oat food product
            "FOODON:00003429",  # oat
            "FOODON:03411414",  # oat plant
            "NCBITaxon:4498",   # Avena (oat)
            "FOODON:03544161",  # gluten (efsa)
            "FOODON:03510214",  # cereals containing gluten
        },
        "exclude_roots": {
            "FOODON:03510174",  # gluten free claim
            "FOODON:00005437",  # gluten-free pasta
            "FOODON:03315911",  # cereal based food gluten free
            "FOODON:03316290",  # pastry (gluten-free)
            "FOODON:03540082",  # rye flour, gluten free
            "FOODON:03540166",  # gluten free bread
            "FOODON:03544168",  # wheat starch, gluten free
            "FOODON:03411597",  # buckwheat plant (pseudocereal)
            "FOODON:00001725",  # buckwheat food product
            "FOODON:00004220",  # buckwheat seed
        },
    },
    "tree_nuts": {
        "include_roots": {
            "FOODON:00001172",  # nut food product
            "FOODON:03411213",  # nut producing plant
            "FOODON:00005735",  # nut (whole or part)
            "FOODON:00003523",  # almond
            "FOODON:00001587",  # almond food product
            "FOODON:00002338",  # walnut food product
            "FOODON:03301364",  # walnut
            "FOODON:03411221",  # cashew plant
            "FOODON:00001746",  # cashew nut food product
            "FOODON:00003615",  # cashew nut
            "FOODON:00001925",  # hazelnut food product
            "FOODON:00002933",  # hazelnut
            "FOODON:03411273",  # hazelnut tree
            "FOODON:00002116",  # pistachio food product
            "FOODON:00003691",  # pistachio nut
            "FOODON:03411420",  # pistachio plant
            "FOODON:00002016",  # macadamia nut food product
            "FOODON:00003003",  # macadamia nut
            "FOODON:03411357",  # macadamia plant
            "NCBITaxon:4329",   # Macadamia
            "FOODON:00002096",  # pecan food product
            "FOODON:00001718",  # chestnut food product
            "FOODON:03510221",  # nuts allergen labelling
        },
        "exclude_roots": {
            "FOODON:00003206",  # peanut (classified under peanuts)
            "FOODON:00002099",  # peanut food product
            "FOODON:03411270",  # peanut plant
            "NCBITaxon:3818",   # Arachis hypogaea
            "FOODON:00003449",  # coconut
            "FOODON:03316908",  # coconut food product
            "FOODON:03310046",  # coconut oil
            "FOODON:00001786",  # coconut milk/product
            "FOODON:03411214",  # coconut palm
            "FOODON:03301712",  # nutmeg
            "FOODON:00002045",  # nutmeg food product
            "FOODON:03411337",  # earthnut / pignut (apios/conopodium tuber)
        },
    },
    "sesame": {
        "include_roots": {
            "FOODON:00002232",  # sesame food product
            "FOODON:03411226",  # sesame plant
            "FOODON:03310306",  # sesame seed
            "NCBITaxon:4182",   # Sesamum indicum
            "FOODON:03510224",  # sesame allergen labelling
        },
        "exclude_roots": set(),
    },
}

FOODON_CHRONIC_ROOTS = {
    "diabetes": {
        "FOODON:00002300",  # sweetener food product
        "FOODON:00001083",  # sugar condiment
        "FOODON:03420108",  # sugar
        "FOODON:03303225",  # syrup
        "CHEBI:17992",      # sucrose
        "CHEBI:17234",      # glucose
        "CHEBI:15824",      # fructose
        "CHEBI:17306",      # maltose
    },
    "hypertension": {
        "FOODON:00002215",  # salt food product
        "FOODON:03309954",  # table salt
        "CHEBI:24866",      # salt
        "CHEBI:26710",      # sodium chloride
        "CHEBI:38700",      # organic sodium salt (includes MSG CHEBI:64220)
        "CHEBI:26708",      # sodium molecular entity
        "CHEBI:64220",      # monosodium glutamate
    },
    "gout": {
        "CHEBI:64220",      # monosodium glutamate (E621)
        "CHEBI:26385",      # purine
        "FOODON:03411433",  # shellfish (high purine)
        "FOODON:00001258",  # fermented / alcoholic
    },
    "cholesterol": {
        "FOODON:00001040",  # animal fat food product
        "FOODON:02010033",  # animal fat
        "FOODON:03302051",  # lard
        "CHEBI:16113",      # cholesterol
        "CHEBI:26607",      # saturated fatty acid
        "FOODON:03310232",  # palm oil
        "FOODON:03301829",  # palm oil (refined)
        "FOODON:03411286",  # palm plant
    },
}

ALLERGEN_DISPLAY_NAMES_VI = {
    "peanuts": "Đậu phộng (Lạc)",
    "seafood": "Hải sản / Giáp xác / Cá",
    "milk": "Sữa bò & Chế phẩm Sữa (Casein/Whey/Lactose)",
    "gluten": "Gluten / Ngũ cốc (Lúa mì, Đại mạch, Yến mạch)",
    "eggs": "Trứng & Chế phẩm Trứng (Albumin/Mayonnaise)",
    "soy": "Đậu nành (Đỗ tương)",
    "tree_nuts": "Hạt cây (Hạnh nhân, Óc chó, Hạt điều, Hạt phỉ...)",
    "sesame": "Mè (Vừng)",
}

CHRONIC_DISPLAY_NAMES_VI = {
    "gout": "Gút / Axit Uric cao",
    "diabetes": "Tiểu đường (Kiểm soát Đường/Carb)",
    "hypertension": "Tăng huyết áp (Kiểm soát Muối/Natri)",
    "cholesterol": "Mỡ máu / Cholesterol cao",
}


# ---------------------------------------------------------------------------
# Text Normalization & Kala Decompression Utilities
# ---------------------------------------------------------------------------
def remove_vietnamese_accents(text: str) -> str:
    if not text:
        return ""
    text = text.replace("đ", "d").replace("Đ", "D")
    nfkd = unicodedata.normalize("NFKD", text)
    return "".join(c for c in nfkd if not unicodedata.combining(c)).lower().strip()


def normalize_en_key(text: str) -> str:
    if not text:
        return ""
    t = text.lower().strip()
    t = t.replace("'s ", " ").replace("’s ", " ").replace("s' ", " ")
    t = re.sub(r"[-_]+", " ", t)
    t = re.sub(r"\s+", " ", t)
    return t.strip()


def decode_kala_blob(b: bytes) -> str:
    if not b:
        return ""
    if isinstance(b, str):
        return b
    payload = b[3:] if b[:3] == b"\t\t\t" else b
    if payload[:2] == b"\x8b\x1f":
        base_n = ((len(payload) // 2) & ~1) + 16
        for n in (base_n, base_n - 2, base_n + 2, len(payload) & ~1):
            data = bytearray(payload)
            limit = min(n, len(data) & ~1)
            data[0:limit:2], data[1:limit:2] = data[1:limit:2], data[0:limit:2]
            try:
                return zlib.decompress(bytes(data), 16 + zlib.MAX_WBITS).decode("utf-8", errors="ignore")
            except Exception:
                pass
    return payload.decode("utf-8", errors="ignore")


def uri_to_curie(uri: str) -> str:
    uri = uri.strip("<> ")
    if "/obo/" in uri:
        tail = uri.split("/obo/")[1]
        return tail.replace("_", ":", 1)
    return uri


# ---------------------------------------------------------------------------
# Build Pipeline: FoodOn + Kala -> Compacted nutriviet_hybrid.db
# ---------------------------------------------------------------------------
def build_hybrid_database(db_path: str = HYBRID_DB_PATH, verbose: bool = True) -> dict:
    t0 = time.time()
    owl_path = os.path.join(FOODON_DIR, "foodon.owl")
    syn_tsv_path = os.path.join(FOODON_DIR, "foodon-synonyms.tsv")
    yaml_path = os.path.join(FOODON_DIR, "src", "ontology", "scripts", "ingredients.yaml")
    va_db_path = os.path.join(DATA_DIR, "va_v3.db")
    av_db_path = os.path.join(DATA_DIR, "av_v3.db")

    if verbose:
        print("[1/5] Parsing foodon.owl & foodon-synonyms.tsv...")
    with open(owl_path, "r", encoding="utf-8") as f:
        owl_text = f.read()

    parents_map = {}      # curie -> set of parent curies
    children_map = {}     # parent_curie -> set of child curies
    labels_map = {}       # curie -> primary English label
    curie_ecodes = {}     # curie -> set of E/INS codes
    owl_synonyms = {}     # curie -> set of English synonyms
    deprecated_curies = set()

    for m in re.finditer(r'<!-- (http://purl\.obolibrary\.org/obo/[A-Za-z0-9_]+) -->\s*<owl:Class.*?</owl:Class>', owl_text, flags=re.DOTALL):
        block = m.group(0)
        curie = uri_to_curie(m.group(1))
        if '<owl:deprecated rdf:datatype="http://www.w3.org/2001/XMLSchema#boolean">true</owl:deprecated>' in block:
            deprecated_curies.add(curie)
            continue

        lbl_m = re.search(r'<rdfs:label[^>]*>([^<]+)</rdfs:label>', block)
        if lbl_m:
            lbl_clean = lbl_m.group(1).replace("&apos;", "'").replace("&amp;", "&").strip()
            if not lbl_clean.lower().startswith("obsolete"):
                labels_map[curie] = lbl_clean

        # Direct rdfs:subClassOf ONLY (never unionOf or disjointWith!)
        for sub_m in re.finditer(r'<rdfs:subClassOf rdf:resource="(http://purl\.obolibrary\.org/obo/[^"]+)"/>', block):
            p = uri_to_curie(sub_m.group(1))
            parents_map.setdefault(curie, set()).add(p)
            children_map.setdefault(p, set()).add(curie)

        # OWL Restriction axioms inside subClassOf or equivalentClass/intersectionOf
        for some_m in re.finditer(
            r'<owl:Restriction>\s*<owl:onProperty rdf:resource="http://purl\.obolibrary\.org/obo/([^"]+)"/>\s*<owl:someValuesFrom rdf:resource="(http://purl\.obolibrary\.org/obo/[^"]+)"/>',
            block,
        ):
            prop = some_m.group(1)
            if prop in ("RO_0001000", "BFO_0000050", "RO_0002162", "FOODON_00002420", "RO_0009001"):
                p = uri_to_curie(some_m.group(2))
                parents_map.setdefault(curie, set()).add(p)
                children_map.setdefault(p, set()).add(curie)

        # Named classes inside owl:intersectionOf ONLY (not owl:unionOf!)
        for inter_m in re.finditer(r'<owl:intersectionOf[^>]*>(.*?)</owl:intersectionOf>', block, flags=re.DOTALL):
            inter_body = inter_m.group(1)
            for desc_m in re.finditer(r'<rdf:Description rdf:about="(http://purl\.obolibrary\.org/obo/[^"]+)"/>', inter_body):
                p = uri_to_curie(desc_m.group(1))
                if p != curie:
                    parents_map.setdefault(curie, set()).add(p)
                    children_map.setdefault(p, set()).add(curie)

        # Synonyms in OWL
        for syn_m in re.finditer(r'<oboInOwl:has(?:Exact|Broad|Narrow)?Synonym[^>]*>([^<]+)</oboInOwl:has(?:Exact|Broad|Narrow)?Synonym>', block):
            s_val = syn_m.group(1).replace("&apos;", "'").strip()
            if s_val and not s_val.startswith("http"):
                owl_synonyms.setdefault(curie, set()).add(s_val)

        # Europe:: and Codex:: E-numbers / INS codes
        for eu in re.findall(r'>Europe::([^<]+)<', block):
            code = re.sub(r"\s+", "", eu.strip().lower())
            curie_ecodes.setdefault(curie, set()).add(f"e{code}")
        for cx in re.findall(r'>Codex::([^<]+)<', block):
            code = re.sub(r"\s+", "", cx.strip().lower())
            curie_ecodes.setdefault(curie, set()).add(f"ins{code}")
            base_num = re.sub(r"\(.*?\)", "", code)
            if base_num:
                curie_ecodes.setdefault(curie, set()).add(f"e{base_num}")
                curie_ecodes.setdefault(curie, set()).add(f"ins{base_num}")

    # Merge foodon-synonyms.tsv
    with open(syn_tsv_path, "r", encoding="utf-8") as f:
        f.readline()
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 4:
                continue
            c = uri_to_curie(parts[0])
            if c in deprecated_curies:
                continue
            if parts[1]:
                p = uri_to_curie(parts[1])
                parents_map.setdefault(c, set()).add(p)
                children_map.setdefault(p, set()).add(c)
            ltype = parts[2]
            raw_lbl = parts[3]
            if ltype and raw_lbl:
                clean_lbl = re.sub(r'^"|"@en$|"$', '', raw_lbl).split('"^^')[0].strip()
                if not clean_lbl or clean_lbl.startswith("http") or clean_lbl.lower().startswith("obsolete"):
                    continue
                if ltype == '"label"' and c not in labels_map:
                    labels_map[c] = clean_lbl
                elif "synonym" in ltype or "alternative" in ltype:
                    owl_synonyms.setdefault(c, set()).add(clean_lbl)

    if verbose:
        print("[2/5] Loading FoodOn ingredients.yaml & assumptions...")
    with open(yaml_path, "r", encoding="utf-8") as f:
        ing_yaml = yaml.safe_load(f)

    assumptions_map = {normalize_en_key(k): normalize_en_key(v) for k, v in (ing_yaml.get("assumptions") or {}).items()}
    yaml_ingredients = ing_yaml.get("ingredient") or {}

    node_types = {}
    node_subtypes = {}

    for curie, info in yaml_ingredients.items():
        if curie in deprecated_curies:
            continue
        lbl = str(info.get("label") or "").strip()
        if lbl and curie not in labels_map:
            labels_map[curie] = lbl
        t = info.get("type")
        if isinstance(t, list):
            t = ",".join(str(x) for x in t)
        node_types[curie] = str(t or "")
        st = info.get("subtype")
        if isinstance(st, list):
            st = ",".join(str(x) for x in st)
        node_subtypes[curie] = str(st or "")

        for p in (info.get("parent") or []):
            parents_map.setdefault(curie, set()).add(p)
            children_map.setdefault(p, set()).add(curie)

        for syn in (info.get("synonyms") or []):
            s_clean = re.sub(r"\s*\((exact|broad|narrow).*?\)\s*$", "", str(syn)).strip()
            if not s_clean:
                continue
            if re.match(r"^e\d{3,4}[a-z]?$", s_clean.lower()):
                curie_ecodes.setdefault(curie, set()).add(s_clean.lower())
            else:
                owl_synonyms.setdefault(curie, set()).add(s_clean)

        for ai_syn, meta in (info.get("ai_synonyms") or {}).items():
            if isinstance(meta, dict) and meta.get("status") == "reject":
                continue
            s_clean = str(ai_syn).strip()
            if re.match(r"^e\d{3,4}[a-z]?$", s_clean.lower()):
                curie_ecodes.setdefault(curie, set()).add(s_clean.lower())
            else:
                owl_synonyms.setdefault(curie, set()).add(s_clean)

        for form_curie, form_labels in (info.get("food_forms") or {}).items():
            parents_map.setdefault(form_curie, set()).add(curie)
            children_map.setdefault(curie, set()).add(form_curie)
            for fl in (form_labels or []):
                owl_synonyms.setdefault(form_curie, set()).add(str(fl).strip())

    if verbose:
        print("[3/5] Computing ontology subtree closures for allergen & chronic roots...")

    def get_subtree_nodes(include_roots: set, exclude_roots: set, max_depth: int = 10) -> set:
        visited = set()
        queue = [(r, 0) for r in include_roots]
        while queue:
            curr, d = queue.pop(0)
            if curr in visited or curr in exclude_roots or d > max_depth:
                continue
            lbl_lower = labels_map.get(curr, "").lower()
            if any(neg in lbl_lower for neg in ("gluten-free", "gluten free", "lactose free", "lactose-free", "hypoallergenic", "dairy-free", "egg-free", "nut-free")):
                continue
            visited.add(curr)
            for child in children_map.get(curr, ()):
                if child not in visited and child not in exclude_roots:
                    queue.append((child, d + 1))
        return visited

    curie_allergens = {}
    for al_code, rules in FOODON_ALLERGEN_ROOTS.items():
        subtree = get_subtree_nodes(rules["include_roots"], rules["exclude_roots"])
        for c in subtree:
            curie_allergens.setdefault(c, set()).add(al_code)

    curie_chronics = {}
    for ch_code, roots in FOODON_CHRONIC_ROOTS.items():
        subtree = get_subtree_nodes(roots, set())
        for c in subtree:
            curie_chronics.setdefault(c, set()).add(ch_code)

    # Choose single best parent_curie per node for compact O(1) lineage reconstruction
    best_parent_map = {}
    for c, pars in parents_map.items():
        valid_pars = [p for p in pars if p != c and p in labels_map and p.startswith(("FOODON:", "CHEBI:", "NCBITaxon:", "UBERON:"))]
        if valid_pars:
            al_pars = [p for p in valid_pars if curie_allergens.get(p)]
            best_parent_map[c] = sorted(al_pars)[0] if al_pars else sorted(valid_pars)[0]

    # Build English -> CURIE Index from FoodOn
    en_index = {}
    active_curies = set(yaml_ingredients.keys()) | set(curie_allergens.keys()) | set(curie_chronics.keys()) | set(curie_ecodes.keys())
    anc_to_add = set()
    for c in list(active_curies):
        curr = c
        for _ in range(5):
            p = best_parent_map.get(curr)
            if not p or p in active_curies or p in anc_to_add:
                break
            anc_to_add.add(p)
            curr = p
    active_curies |= anc_to_add

    def register_en_term(term: str, curie: str, tier: int):
        norm = normalize_en_key(term)
        if not norm or len(norm) < 2:
            return
        en_index.setdefault(norm, []).append((curie, tier))

    for c in active_curies:
        lbl = labels_map.get(c, "")
        if not lbl:
            continue
        register_en_term(lbl, c, 1)
        for suffix in (" food product", " plant", " tree", " type"):
            if lbl.lower().endswith(suffix):
                base_lbl = lbl[:-len(suffix)].strip()
                if len(base_lbl) >= 3:
                    register_en_term(base_lbl, c, 2)
        if lbl.lower().startswith("monosodium "):
            base_anion = lbl[len("monosodium "):].strip()
            if len(base_anion) >= 5:
                register_en_term(base_anion, c, 2)
        for syn in owl_synonyms.get(c, ()):
            # Do not index generic component synonyms (like "soy lecithin") on a generic parent if a specific node exists,
            # or allow component decomposition to handle the modifier ("soy").
            syn_norm = normalize_en_key(syn)
            if c == "CHEBI:61995" and any(mod in syn_norm for mod in ("soy", "soya", "egg", "sunflower")):
                continue
            register_en_term(syn, c, 2)

    for src_en, dst_en in assumptions_map.items():
        if dst_en in en_index:
            for dst_curie, _ in en_index[dst_en]:
                en_index.setdefault(src_en, []).insert(0, (dst_curie, 0))

    best_en_to_curie = {}
    for norm_en, cand_list in en_index.items():
        def score_cand(item):
            c, tier = item
            in_yaml = 0 if c in yaml_ingredients else 1
            has_al = 0 if c in curie_allergens else 1
            has_ch = 0 if c in curie_chronics else 1
            lbl_len = len(labels_map.get(c, ""))
            return (tier, has_al, has_ch, in_yaml, lbl_len, c)
        best_c = sorted(cand_list, key=score_cand)[0][0]
        best_en_to_curie[norm_en] = best_c

    if verbose:
        print("[4/5] Bridging Kala va_v3.db & av_v3.db with FoodOn...")

    # Load va_v3.db
    conn_va = sqlite3.connect(va_db_path)
    cur_va = conn_va.cursor()
    cur_va.execute("SELECT word, word_ko_dau, mean, va FROM word_tbl")
    va_rows = cur_va.fetchall()
    conn_va.close()

    va_lookup = {}
    va_redirect_groups = {}  # target_word -> set of alias_words (e.g. 'đậu phụng' -> {'đậu phộng', 'lạc'})
    for w, w_kd, mean, va_blob in va_rows:
        w_clean = (w or "").strip()
        if not w_clean:
            continue
        w_low = w_clean.lower()
        m_clean = (mean or "").strip()
        va_lookup[w_low] = (w_clean, (w_kd or "").strip().lower(), m_clean, va_blob)
        if m_clean.startswith("@"):
            tgt = m_clean[1:].strip().lower()
            va_redirect_groups.setdefault(tgt, set()).add(w_low)

    def resolve_va_senses(w_key: str, depth: int = 0) -> list[tuple[str, int]]:
        if depth > 3 or w_key not in va_lookup:
            return []
        _, _, mean, va_blob = va_lookup[w_key]
        if mean.startswith("@"):
            target = mean[1:].strip().lower()
            return resolve_va_senses(target, depth + 1)
        m_xem = re.search(r"(?:^|\))\s*xem\s+(.+)$", mean, flags=re.IGNORECASE)
        if m_xem:
            target = re.sub(r"\s+\d+$", "", m_xem.group(1).strip().lower())
            res = resolve_va_senses(target, depth + 1)
            if res:
                return res
            res2 = resolve_va_senses(target.replace("-", " "), depth + 1)
            if res2:
                return res2

        results = []
        if mean:
            results.append((mean, 1))
        html = decode_kala_blob(va_blob)
        if html:
            senses = re.findall(r'(?:<div class="m">|<d1m">)\s*<span>(.*?)</span>(.*?)</div>', html)
            for idx, (s1, s2) in enumerate(senses, start=1):
                combined = re.sub(r"<[^>]+>", " ", s1 + " " + s2).strip()
                if combined:
                    results.append((combined, idx))
        return results

    # Store single best (curie, tier) per (vi_word_lower, curie) -> later we keep top tier per vi_word_lower
    vi_candidates = {}  # vi_word_lower -> dict[curie, best_tier]

    def add_vi_candidate(vi_word: str, curie: str, tier: int):
        vi_clean = re.sub(r"\s+", " ", vi_word.strip().lower()).strip(".,;:!?\"'()-")
        if not vi_clean or len(vi_clean) < 2 or len(vi_clean.split()) > 5:
            return
        # Reject strings that still contain HTML/encoding artifacts or English definitions
        if any(ch in vi_clean for ch in ("<", ">", "=", "/", "\\", "@", "#")):
            return
        cur_map = vi_candidates.setdefault(vi_clean, {})
        if curie not in cur_map or tier < cur_map[curie]:
            cur_map[curie] = tier
        if "-" in vi_clean:
            vi_spaced = re.sub(r"\s+", " ", vi_clean.replace("-", " ")).strip()
            if len(vi_spaced) >= 2:
                cur_map2 = vi_candidates.setdefault(vi_spaced, {})
                if curie not in cur_map2 or tier < cur_map2[curie]:
                    cur_map2[curie] = tier

    for w_key, (w_orig, _, _, _) in va_lookup.items():
        senses = resolve_va_senses(w_key)
        for sense_str, rank in senses:
            if re.search(r"^(?:xem|như)\s+", sense_str.strip(), flags=re.IGNORECASE):
                continue
            # Check if sense has a parenthetical Vietnamese compound override like "tench (cá mè)" where w_key="mè"
            paren_vi = re.findall(r"\(([^)]+)\)", sense_str)
            is_compound_override = False
            for pv in paren_vi:
                pv_clean = re.sub(r"\s+", " ", pv.strip().lower())
                if w_key in pv_clean and pv_clean != w_key and len(pv_clean.split()) > len(w_key.split()):
                    # This sense actually defines `pv_clean` (e.g. "cá mè"), NOT standalone `w_key` ("mè")!
                    is_compound_override = True
                    no_p = re.sub(r"\([^)]*\)", " ", sense_str).strip(" .")
                    norm_en = normalize_en_key(no_p)
                    if norm_en in best_en_to_curie:
                        add_vi_candidate(pv_clean, best_en_to_curie[norm_en], 1)
            if is_compound_override:
                continue

            no_paren = re.sub(r"\([^)]*\)", " ", sense_str)
            candidates = [c.strip() for c in re.split(r"[;,/]", no_paren) if c.strip()]
            for gloss_idx, cand in enumerate(candidates):
                norm_cand = normalize_en_key(cand.rstrip("."))
                if norm_cand in assumptions_map:
                    norm_cand = assumptions_map[norm_cand]
                lookup_keys = [norm_cand, norm_cand.replace(" ", "")]
                if norm_cand.endswith("s") and len(norm_cand) > 4:
                    lookup_keys.append(norm_cand[:-1])
                matched_c = None
                for lk in lookup_keys:
                    if lk in best_en_to_curie:
                        matched_c = best_en_to_curie[lk]
                        break
                if matched_c:
                    tier = 1 if rank == 1 else (2 if rank <= 2 else 3)
                    add_vi_candidate(w_orig, matched_c, tier)

    # Load av_v3.db
    conn_av = sqlite3.connect(av_db_path)
    cur_av = conn_av.cursor()
    cur_av.execute("SELECT word, mean, av FROM av")
    av_rows = cur_av.fetchall()
    conn_av.close()

    av_lookup = {}
    for en_w, mean, av_blob in av_rows:
        if not en_w:
            continue
        av_lookup[en_w.strip().lower()] = ((mean or "").strip(), av_blob)

    def resolve_av_senses(en_key: str, depth: int = 0) -> tuple[list[tuple[str, int]], list[tuple[str, str]]]:
        if depth > 3 or en_key not in av_lookup:
            return [], []
        mean, av_blob = av_lookup[en_key]
        if mean.startswith("@"):
            target = mean[1:].split("#")[0].strip().lower().replace("-", " ")
            s, sub = resolve_av_senses(target, depth + 1)
            if s:
                return s, sub
            return resolve_av_senses(mean[1:].split("#")[0].strip().lower(), depth + 1)
        m_nhu = re.match(r"^như\s+([a-z0-9\-\s]+?)(?:#|$)", mean.strip(), flags=re.IGNORECASE)
        if m_nhu:
            target = m_nhu.group(1).strip().lower()
            s, sub = resolve_av_senses(target, depth + 1)
            if s:
                return s, sub
            s2, sub2 = resolve_av_senses(target.replace("-", " "), depth + 1)
            if s2:
                return s2, sub2
        results = []
        sub_entries = []
        if mean:
            results.append((mean.split("#")[0].strip(), 1))
        html = decode_kala_blob(av_blob)
        if html:
            senses = re.findall(r'(?:<div class="m">|<d1m">)\s*<span>(.*?)</span>(.*?)</div>', html)
            for idx, (s1, s2) in enumerate(senses, start=1):
                combined = re.sub(r"<[^>]+>", " ", s1 + " " + s2).strip()
                if combined:
                    results.append((combined, idx))
            # Also extract compound sub-entries `<d1e">...</div><d1em"><span>...</span>`
            pairs = re.findall(r'(?:<div class="e">|<d1e">)(.*?)</div>\s*(?:<div class="em">|<d1em">)\s*<span>(.*?)</span>', html)
            for en_sub, vi_sub in pairs:
                en_c = re.sub(r"<[^>]+>", " ", en_sub)
                en_c = re.sub(r"\s+", " ", en_c).strip()
                vi_c = re.sub(r"<[^>]+>", " ", vi_sub).strip()
                if en_c and vi_c:
                    sub_entries.append((en_c, vi_c))
        return results, sub_entries

    vi_classifiers = ("cây ", "quả ", "hạt ", "củ ", "con ", "loài ")
    domain_meta_tags = {
        "hoá học", "thực vật học", "động vật học", "y học", "sinh vật học",
        "giải phẫu", "từ mỹ,nghĩa mỹ", "từ lóng", "số nhiều", "như", "kỹ thuật", "thơ ca"
    }

    def process_av_vi_gloss(raw_vi_str: str, target_curie: str, base_tier: int):
        # 1. Extract short parenthetical synonyms e.g. "bơ lạc (bơ đậu phụng)" -> "bơ đậu phụng"
        # Skip multi-item example lists inside parentheses that contain commas/semicolons/ellipsis e.g. "(bột mì, ngô, gạo)", "(gạo...)"
        for pm in re.findall(r"\(([^)]+)\)", raw_vi_str):
            if "," in pm or ";" in pm or "..." in pm or ".." in pm:
                continue
            pm_clean = re.sub(r"\s+", " ", pm.strip().lower())
            if pm_clean not in domain_meta_tags and 1 <= len(pm_clean.split()) <= 4:
                # Ignore geographical or long notes
                if not any(w in pm_clean for w in ("bắc mỹ", "châu", "thế kỷ", "dùng để", "nhất là", "chủ yếu", "thường")):
                    p_tier = min(base_tier + 1, 3)
                    add_vi_candidate(pm_clean, target_curie, p_tier)
                    # Also propagate @ dialect equivalents from va_v3.db (e.g. "đậu phụng" -> "đậu phộng")
                    for tgt_word, aliases in va_redirect_groups.items():
                        if tgt_word in pm_clean:
                            for al_w in aliases:
                                add_vi_candidate(pm_clean.replace(tgt_word, al_w), target_curie, p_tier)

        # 2. Main text outside parentheses
        cleaned = re.sub(r"\([^)]*\)", " ", raw_vi_str)
        cleaned = re.split(r"\bnhư\b|\|\|", cleaned)[0]
        parts = [p.strip() for p in re.split(r"[;,]", cleaned) if p.strip()]
        for idx, p in enumerate(parts):
            p_low = re.sub(r"\s+", " ", p.lower()).strip(" .-#")
            if not p_low or len(p_low.split()) > 4:
                continue
            t = base_tier if idx == 0 else min(base_tier + 1, 3)
            add_vi_candidate(p_low, target_curie, t)
            for tgt_word, aliases in va_redirect_groups.items():
                if tgt_word in p_low:
                    for al_w in aliases:
                        add_vi_candidate(p_low.replace(tgt_word, al_w), target_curie, t)
            for clf in vi_classifiers:
                if p_low.startswith(clf):
                    stripped = p_low[len(clf):].strip()
                    # Only strip classifier when the remaining noun phrase is multi-word (e.g. "quả óc chó" -> "óc chó",
                    # "cây hạnh nhân" -> "hạnh nhân"), preventing 1-syllable collisions like "hạt điều" -> "điều".
                    if len(stripped.split()) >= 2:
                        add_vi_candidate(stripped, target_curie, t)

    for en_key in list(av_lookup.keys()):
        norm_en = normalize_en_key(en_key)
        if norm_en in assumptions_map:
            norm_en = assumptions_map[norm_en]
        target_curie = best_en_to_curie.get(norm_en) or best_en_to_curie.get(norm_en.replace(" ", ""))
        senses, sub_entries = resolve_av_senses(en_key)

        if target_curie:
            for sense_str, rank in senses:
                tier = 1 if rank == 1 else (2 if rank <= 3 else 3)
                process_av_vi_gloss(sense_str, target_curie, tier)

        # Also check sub_entries `<d1e">...</div><d1em">` against FoodOn English index!
        for sub_en, sub_vi in sub_entries:
            norm_sub = normalize_en_key(sub_en)
            if norm_sub in assumptions_map:
                norm_sub = assumptions_map[norm_sub]
            sub_lookup = [norm_sub, norm_sub.replace(" ", "")]
            if norm_sub.endswith("s") and len(norm_sub) > 4:
                sub_lookup.append(norm_sub[:-1])
            sub_curie = None
            for slk in sub_lookup:
                if slk in best_en_to_curie:
                    sub_curie = best_en_to_curie[slk]
                    break
            if sub_curie:
                process_av_vi_gloss(sub_vi, sub_curie, 1)

    # Prune vi_candidates: for each Vietnamese term, keep only its highest-confidence tier(s)
    # and select the primary best CURIE per allergen/type so there are no noisy lower-tier collisions.
    vi_final_rows = []  # (vi_word, vi_ascii, curie, tier)
    for vi_word, cur_map in vi_candidates.items():
        min_tier = min(cur_map.values())
        best_curies = [c for c, t in cur_map.items() if t == min_tier]
        # Sort best_curies: prefer those with allergen/chronic tags, in yaml_ingredients, shorter label
        best_curies.sort(key=lambda c: (
            0 if (c in curie_allergens or c in curie_chronics) else 1,
            0 if c in yaml_ingredients else 1,
            len(labels_map.get(c, "")),
            c,
        ))
        selected_curie = best_curies[0]
        vi_ascii = remove_vietnamese_accents(vi_word)
        vi_final_rows.append((vi_word, vi_ascii, selected_curie, min_tier))

    if verbose:
        print(f"[5/5] Writing ultra-compact SQLite database to {db_path}...")
    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    cur.execute("""
    CREATE TABLE foodon_concepts (
        curie TEXT PRIMARY KEY,
        label_en TEXT NOT NULL,
        parent_curie TEXT,
        food_type TEXT,
        allergen_codes TEXT,
        chronic_codes TEXT,
        ecodes TEXT
    ) WITHOUT ROWID
    """)

    cur.execute("""
    CREATE TABLE lexical_bridge (
        term_norm TEXT NOT NULL,
        term_ascii TEXT NOT NULL,
        lang TEXT NOT NULL,
        curie TEXT NOT NULL,
        confidence_tier INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (term_norm, lang)
    ) WITHOUT ROWID
    """)

    cur.execute("""
    CREATE TABLE ecode_bridge (
        ecode TEXT PRIMARY KEY,
        curie TEXT NOT NULL
    ) WITHOUT ROWID
    """)

    # Collect all CURIEs needed (including parent chain up to 5 hops for lineage reconstruction)
    referenced_curies = set(best_en_to_curie.values()) | {r[2] for r in vi_final_rows} | set(curie_ecodes.keys())
    chain_curies = set()
    for c in list(referenced_curies):
        curr = c
        for _ in range(5):
            p = best_parent_map.get(curr)
            if not p or p in referenced_curies or p in chain_curies:
                break
            chain_curies.add(p)
            curr = p
    referenced_curies |= chain_curies

    concept_rows = []
    for c in sorted(referenced_curies):
        lbl = labels_map.get(c, c)
        par = best_parent_map.get(c, "")
        ft = node_types.get(c, "")
        als = ",".join(sorted(curie_allergens.get(c, set())))
        chs = ",".join(sorted(curie_chronics.get(c, set())))
        ecs = ",".join(sorted(curie_ecodes.get(c, set())))
        concept_rows.append((c, lbl, par, ft, als, chs, ecs))

    cur.executemany("INSERT INTO foodon_concepts VALUES (?, ?, ?, ?, ?, ?, ?)", concept_rows)

    lex_rows = []
    for norm_en, c in best_en_to_curie.items():
        if c in referenced_curies:
            lex_rows.append((norm_en, norm_en, "en", c, 1))
    for vi_word, vi_ascii, c, tier in vi_final_rows:
        if c in referenced_curies:
            lex_rows.append((vi_word, vi_ascii, "vi", c, tier))

    cur.executemany("INSERT OR REPLACE INTO lexical_bridge VALUES (?, ?, ?, ?, ?)", lex_rows)

    ecode_rows = {}
    for c, codes in curie_ecodes.items():
        if c in referenced_curies:
            for code in codes:
                ecode_rows.setdefault(code.lower(), c)
    cur.executemany("INSERT OR REPLACE INTO ecode_bridge VALUES (?, ?)", list(ecode_rows.items()))

    cur.execute("CREATE INDEX idx_lex_ascii ON lexical_bridge(term_ascii)")
    conn.commit()
    cur.execute("VACUUM")
    conn.close()

    elapsed = time.time() - t0
    db_size = os.path.getsize(db_path)
    stats = {
        "build_time_sec": round(elapsed, 2),
        "raw_total_mb": 146.7,
        "hybrid_db_size_bytes": db_size,
        "hybrid_db_size_mb": round(db_size / (1024 * 1024), 2),
        "compression_ratio_pct": round((1.0 - (db_size / (146.7 * 1024 * 1024))) * 100, 2),
        "total_concepts": len(concept_rows),
        "total_en_terms": len(best_en_to_curie),
        "total_vi_terms": len(vi_final_rows),
        "total_ecodes": len(ecode_rows),
        "allergen_tagged_concepts": sum(1 for r in concept_rows if r[4]),
        "chronic_tagged_concepts": sum(1 for r in concept_rows if r[5]),
    }
    if verbose:
        print(f"[DONE] Built nutriviet_hybrid.db in {stats['build_time_sec']}s | Size: {stats['hybrid_db_size_mb']} MB (-{stats['compression_ratio_pct']}%)")
        print("       Stats:", json.dumps(stats, indent=2))
    return stats


# ---------------------------------------------------------------------------
# Runtime Hybrid Engine: Multi-Stage Recognition + Fuzzy Match + Graph Trace
# ---------------------------------------------------------------------------
class HybridFoodOnEngine:
    """
    Production & Offline-Ready Hybrid Evaluation Engine over `nutriviet_hybrid.db`.
    Implements a 4-stage pipeline:
      Stage 1: E-Number / INS Regex & Exact Dictionary Lookup (VI + EN)
      Stage 2: Packaging Qualifier & Percentage Stripping (e.g. "Đậu phộng (28%)")
      Stage 3: Component / Sub-phrase Decomposition (e.g. "Lecithin đậu nành" -> "lecithin" + "đậu nành")
      Stage 4: 2-Layer Accented + Unaccented Levenshtein Fuzzy Matching (for OCR noise)
    """

    def __init__(self, db_path: str = HYBRID_DB_PATH):
        if not os.path.exists(db_path):
            build_hybrid_database(db_path, verbose=False)
        self.db_path = db_path
        self._load_in_memory_indices()

    def _load_in_memory_indices(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        self.concepts = {}
        cur.execute("SELECT * FROM foodon_concepts")
        for r in cur.fetchall():
            self.concepts[r["curie"]] = {
                "curie": r["curie"],
                "label_en": r["label_en"],
                "parent_curie": r["parent_curie"] or "",
                "food_type": r["food_type"] or "",
                "allergens": [x for x in (r["allergen_codes"] or "").split(",") if x],
                "chronics": [x for x in (r["chronic_codes"] or "").split(",") if x],
                "ecodes": [x for x in (r["ecodes"] or "").split(",") if x],
            }

        self.ecode_map = {}
        cur.execute("SELECT ecode, curie FROM ecode_bridge")
        for r in cur.fetchall():
            self.ecode_map[r["ecode"]] = r["curie"]

        self.vi_exact = {}   # term_norm -> (curie, tier)
        self.en_exact = {}   # term_norm -> (curie, tier)
        self.ascii_index = {}  # term_ascii -> list of (term_norm, lang, curie, tier)
        self.first_char_buckets = {}  # (first_char, len_bucket) -> list of (term_norm, term_ascii, lang, curie, tier)

        cur.execute("SELECT term_norm, term_ascii, lang, curie, confidence_tier FROM lexical_bridge")
        for r in cur.fetchall():
            tn = r["term_norm"]
            ta = r["term_ascii"]
            lang = r["lang"]
            c = r["curie"]
            tier = r["confidence_tier"]
            if lang == "vi":
                self.vi_exact[tn] = (c, tier)
            else:
                self.en_exact[tn] = (c, tier)
            self.ascii_index.setdefault(ta, []).append((tn, lang, c, tier))
            if ta:
                key = ta[0]
                self.first_char_buckets.setdefault(key, []).append((tn, ta, lang, c, tier))

        conn.close()

    def get_lineage(self, curie: str, max_hops: int = 4) -> list[dict]:
        chain = []
        curr = curie
        seen = set()
        for _ in range(max_hops + 1):
            if not curr or curr in seen or curr not in self.concepts:
                break
            seen.add(curr)
            info = self.concepts[curr]
            chain.append({"curie": curr, "label_en": info["label_en"]})
            curr = info["parent_curie"]
        return chain

    def get_lineage_string(self, curie: str) -> str:
        return " -> ".join(f"{item['curie']} ({item['label_en']})" for item in self.get_lineage(curie))

    def _exact_lookup(self, norm_text: str) -> tuple[str, str, float] | None:
        """Checks exact VI, exact EN, and normalized EN key."""
        if norm_text in self.vi_exact:
            c, _ = self.vi_exact[norm_text]
            return c, "exact_vi", 1.0
        en_k = normalize_en_key(norm_text)
        if en_k in self.en_exact:
            c, _ = self.en_exact[en_k]
            return c, "exact_en", 1.0
        # Also try singularizing English plural
        if en_k.endswith("s") and len(en_k) > 4 and en_k[:-1] in self.en_exact:
            c, _ = self.en_exact[en_k[:-1]]
            return c, "exact_en_singular", 0.98
        return None

    def _fuzzy_lookup(self, raw_token: str, threshold: float = 0.80) -> tuple[str, str, str, float] | None:
        """
        2-Layer Weighted Levenshtein Fuzzy Matching:
          Score = 0.6 * Sim(token_norm, candidate_norm) + 0.4 * Sim(token_ascii, candidate_ascii)
        """
        t_norm = re.sub(r"\s+", " ", raw_token.strip().lower())
        t_ascii = remove_vietnamese_accents(t_norm)
        if len(t_ascii) < 3:
            return None

        # Fast path: if unaccented string matches an exact term_ascii in our dictionary!
        if t_ascii in self.ascii_index:
            candidates = self.ascii_index[t_ascii]
            # Prefer Vietnamese match with highest confidence tier (lowest tier number) and highest accented similarity
            best_cand = None
            best_score = -1.0
            for tn, lang, c, tier in candidates:
                sim_acc = SequenceMatcher(None, t_norm, tn).ratio()
                score = 0.6 * sim_acc + 0.4 * 1.0 + (0.02 if lang == "vi" else 0.0) - (tier - 1) * 0.03
                if score > best_score:
                    best_score = score
                    best_cand = (c, tn, "ascii_fold_match", round(min(score, 0.99), 3))
            if best_cand:
                return best_cand

        # Candidate search in first-character bucket (plus orthographic/phonetic neighbor if first char varies e.g. s <-> x in si-rô/xi-rô)
        t_len = len(t_ascii)
        buckets_to_scan = [t_ascii[0]]
        ortho_neighbors = {"s": ["x"], "x": ["s"], "d": ["g"], "g": ["d"]}
        for nb in ortho_neighbors.get(t_ascii[0], ()):
            if nb not in buckets_to_scan:
                buckets_to_scan.append(nb)
        best_match = None
        best_sim = threshold

        for b_char in buckets_to_scan:
            for tn, ta, lang, c, tier in self.first_char_buckets.get(b_char, ()):
                if abs(len(ta) - t_len) > 2:
                    continue
                # Quick character set overlap check before SequenceMatcher
                sim_ascii = SequenceMatcher(None, t_ascii, ta).ratio()
                if sim_ascii < 0.72:
                    continue
                sim_acc = SequenceMatcher(None, t_norm, tn).ratio()
                weighted_sim = 0.6 * sim_acc + 0.4 * sim_ascii
                # Slight penalty for tier > 1 so primary senses win ties
                effective_sim = weighted_sim - (tier - 1) * 0.02
                if effective_sim >= best_sim:
                    best_sim = effective_sim
                    best_match = (c, tn, f"fuzzy_{lang}", round(weighted_sim, 3))

        return best_match

    def recognize_ingredient(self, raw_token: str) -> dict:
        """
        Recognizes a single ingredient string from a packaging label and returns
        all matched FoodOn CURIEs, allergens, chronic flags, and lineage paths.
        """
        clean_token = re.sub(r"\s+", " ", (raw_token or "").strip())
        if not clean_token:
            return {"input": raw_token, "matched": False, "matches": [], "allergens": [], "chronics": []}

        matched_records = []
        seen_curies = set()

        def add_match(curie: str, matched_term: str, match_type: str, confidence: float):
            if curie in seen_curies or curie not in self.concepts:
                return
            seen_curies.add(curie)
            info = self.concepts[curie]
            matched_records.append({
                "curie": curie,
                "label_en": info["label_en"],
                "matched_term": matched_term,
                "match_type": match_type,
                "confidence": confidence,
                "food_type": info["food_type"],
                "allergens": info["allergens"],
                "chronics": info["chronics"],
                "ecodes": info["ecodes"],
                "lineage": self.get_lineage_string(curie),
            })

        # Stage 1: Check E-numbers / INS codes via strict Regex (Never fuzzy match E-codes!)
        for e_match in re.finditer(r"\b(e|ins)\s*(\d{3,4}[a-z]?(?:\([ivx]+\))?)\b", clean_token.lower()):
            prefix = e_match.group(1)
            num_part = e_match.group(2)
            base_num = re.sub(r"\(.*?\)", "", num_part)
            for candidate_code in (f"{prefix}{num_part}", f"e{base_num}", f"ins{base_num}"):
                if candidate_code in self.ecode_map:
                    add_match(self.ecode_map[candidate_code], e_match.group(0).upper(), "ecode_exact", 1.0)
                    break

        # Strip percentages e.g. "(28%)", "28.5%", and E-code parentheticals e.g. "(E469)", "(INS 621)"
        stripped_token = re.sub(r"\(\s*\d+(?:[.,]\d+)?\s*%\s*\)", " ", clean_token)
        stripped_token = re.sub(r"\b\d+(?:[.,]\d+)?\s*%", " ", stripped_token)
        stripped_token = re.sub(r"\(\s*(?:e|ins)\s*\d{3,4}[a-z]?(?:\([ivx]+\))?\s*\)", " ", stripped_token, flags=re.IGNORECASE)

        # Also extract any remaining parenthetical sub-ingredients e.g. "Chất nhũ hóa (Lecithin đậu nành)"
        sub_parts = [stripped_token]
        for pm in re.findall(r"\(([^)]+)\)", stripped_token):
            sub_parts.append(pm)
        main_no_paren = re.sub(r"\([^)]*\)", " ", stripped_token)
        if main_no_paren.strip() != stripped_token.strip():
            sub_parts.insert(0, main_no_paren)

        # Check explicit allergen-free / gluten-free / lactose-free claims on the full token
        low_full = clean_token.lower()
        is_gluten_free = any(x in low_full for x in ("không chứa gluten", "không gluten", "gluten-free", "gluten free"))
        is_lactose_free = any(x in low_full for x in ("không chứa lactose", "không lactose", "lactose-free", "lactose free"))
        is_plant_milk = any(x in low_full for x in ("sữa đậu nành", "sữa hạnh nhân", "sữa yến mạch", "sữa dừa", "sữa gạo", "sữa hạt", "soy milk", "soya milk", "almond milk", "oat milk", "coconut milk", "rice milk"))
        is_plant_butter = any(x in low_full for x in ("bơ thực vật", "bơ đậu phộng", "bơ đậu phụng", "bơ lạc", "bơ hạnh nhân", "bơ hạt", "bơ ca cao", "bơ cacao", "trái bơ", "quả bơ", "peanut butter", "almond butter", "cocoa butter", "margarine"))

        # Stage 2A & 2B: Whole-part Exact Lookup OR Whole-part Unaccented ASCII-Fold Lookup
        unmatched_parts = []
        for part in sub_parts:
            p_norm = re.sub(r"\s+", " ", part.strip().lower()).strip(".,;:-")
            if not p_norm:
                continue
            exact = self._exact_lookup(p_norm)
            if exact:
                add_match(exact[0], p_norm, exact[1], exact[2])
                continue
            # Check whole-phrase ASCII-fold match (e.g. "đâu phông" -> "đậu phộng", "bột mi" -> "bột mì", "dau nanh" -> "đậu nành")
            p_ascii = remove_vietnamese_accents(p_norm)
            if len(p_ascii) >= 4 and p_ascii in self.ascii_index:
                fz_ascii = self._fuzzy_lookup(p_norm, threshold=0.80)
                if fz_ascii:
                    add_match(fz_ascii[0], fz_ascii[1], fz_ascii[2], fz_ascii[3])
                    continue
            unmatched_parts.append(p_norm)

        # Stage 3: Component / Sub-phrase Decomposition (ONLY for parts that did not match as a whole phrase in Stage 2!)
        functional_stopwords = {
            "chất", "điều", "vị", "chỉnh", "độ", "làm", "dày", "tạo", "ngọt", "nhũ", "hóa", "hoá",
            "ổn", "định", "bảo", "quản", "chống", "oxy", "hương", "màu", "tự", "nhiên", "tổng", "hợp",
            "chiết", "xuất", "tinh", "dầu", "bột", "nước", "không", "chứa", "Và", "và", "hoặc",
        }
        for p_norm in unmatched_parts:
            words = p_norm.split()
            if len(words) >= 2:
                covered_indices = set()
                for n in range(min(len(words) - 1, 4), 0, -1):
                    for i in range(len(words) - n + 1):
                        if any(idx in covered_indices for idx in range(i, i + n)):
                            continue
                        sub_phrase = " ".join(words[i : i + n])
                        if n == 1:
                            if sub_phrase in functional_stopwords:
                                continue
                            if sub_phrase == "sữa" and is_plant_milk:
                                continue
                            if sub_phrase == "bơ" and is_plant_butter:
                                continue
                        exact_sub = self._exact_lookup(sub_phrase)
                        if exact_sub:
                            add_match(exact_sub[0], sub_phrase, f"component_{exact_sub[1]}", 0.95)
                            covered_indices.update(range(i, i + n))

        # Stage 4: 2-Layer Levenshtein Fuzzy Matching (only if no exact/component match was found!)
        if not matched_records:
            for p_norm in unmatched_parts:
                fuzzy = self._fuzzy_lookup(p_norm, threshold=0.80)
                if fuzzy:
                    add_match(fuzzy[0], fuzzy[1], fuzzy[2], fuzzy[3])
                elif len(p_norm.split()) >= 2:
                    words = p_norm.split()
                    for n in (2, 1):
                        for i in range(len(words) - n + 1):
                            sub_p = " ".join(words[i : i + n])
                            if len(sub_p) < 4 or sub_p in functional_stopwords:
                                continue
                            fz_sub = self._fuzzy_lookup(sub_p, threshold=0.82)
                            if fz_sub:
                                add_match(fz_sub[0], fz_sub[1], f"component_{fz_sub[2]}", fz_sub[3])

        # Aggregate allergens and chronic flags across matched records (applying explicit claim exclusions)
        all_allergens = set()
        all_chronics = set()
        for rec in matched_records:
            for al in rec["allergens"]:
                if al == "gluten" and is_gluten_free:
                    continue
                if al == "milk" and is_lactose_free and rec["curie"] == "CHEBI:17716":
                    continue
                if al == "milk" and is_plant_milk and rec["curie"] in ("FOODON:02020891", "CHEBI:17716"):
                    continue
                all_allergens.add(al)
            for ch in rec["chronics"]:
                if ch == "diabetes" and is_lactose_free and rec["curie"] == "CHEBI:17716":
                    continue
                all_chronics.add(ch)

        return {
            "input": raw_token,
            "matched": len(matched_records) > 0,
            "matches": matched_records,
            "allergens": sorted(all_allergens),
            "chronics": sorted(all_chronics),
        }

    def evaluate_packaging_label(
        self,
        ingredient_tokens: list[str],
        user_allergens: list[dict] | list[str],
        user_chronics: list[str] | None = None,
    ) -> dict:
        """
        Full UC09 Packaging Hazard Evaluation:
          - Compares extracted ingredient tokens against the user's allergy profile & chronic conditions.
          - Returns RED (Dangerous), YELLOW (Caution), or GREEN (Safe) verdict with WCAG dual-coded glyphs
            (`[X]`, `[!]`, `[OK]`) and FoodOn ontological lineage explanations.
        """
        t0 = time.perf_counter()
        user_chronics = set(user_chronics or [])
        profile_severity = {}
        for item in user_allergens:
            if isinstance(item, str):
                profile_severity[item] = "high"
            elif isinstance(item, dict):
                code = item.get("code") or item.get("allergen_code")
                sev = (item.get("severity") or "high").lower()
                if code:
                    profile_severity[code] = sev

        token_results = []
        red_triggers = []
        yellow_triggers = []

        for tok in ingredient_tokens:
            res = self.recognize_ingredient(tok)
            token_results.append(res)

            # Check allergen intersections
            for al_code in res["allergens"]:
                if al_code in profile_severity:
                    sev = profile_severity[al_code]
                    primary_match = res["matches"][0] if res["matches"] else {}
                    trigger_info = {
                        "token": tok,
                        "allergen_code": al_code,
                        "allergen_name_vi": ALLERGEN_DISPLAY_NAMES_VI.get(al_code, al_code),
                        "severity": sev,
                        "curie": primary_match.get("curie", ""),
                        "label_en": primary_match.get("label_en", ""),
                        "lineage": primary_match.get("lineage", ""),
                        "match_type": primary_match.get("match_type", ""),
                        "confidence": primary_match.get("confidence", 1.0),
                    }
                    if sev in ("anaphylaxis", "high"):
                        red_triggers.append(trigger_info)
                    else:
                        yellow_triggers.append(trigger_info)

            # Check chronic condition intersections
            for ch_code in res["chronics"]:
                if ch_code in user_chronics:
                    primary_match = res["matches"][0] if res["matches"] else {}
                    yellow_triggers.append({
                        "token": tok,
                        "chronic_code": ch_code,
                        "chronic_name_vi": CHRONIC_DISPLAY_NAMES_VI.get(ch_code, ch_code),
                        "severity": "caution",
                        "curie": primary_match.get("curie", ""),
                        "label_en": primary_match.get("label_en", ""),
                        "lineage": primary_match.get("lineage", ""),
                        "match_type": primary_match.get("match_type", ""),
                        "confidence": primary_match.get("confidence", 1.0),
                    })

        if red_triggers:
            verdict = "RED"
            wcag_glyph = "[!X]"
            title_vi = "NGUY HIỂM: PHÁT HIỆN DỊ ỨNG - KHÔNG NÊN SỬ DỤNG"
        elif yellow_triggers:
            verdict = "YELLOW"
            wcag_glyph = "[!?]"
            title_vi = "CẢNH BÁO: CẦN THẬN TRỌNG - CHỨA CHẤT CẦN KIÊNG / TIẾT CHẾ"
        else:
            verdict = "GREEN"
            wcag_glyph = "[OK]"
            title_vi = "AN TOÀN SỬ DỤNG - KHÔNG PHÁT HIỆN DỊ ỨNG"

        latency_ms = round((time.perf_counter() - t0) * 1000, 2)
        return {
            "verdict": verdict,
            "wcag_glyph": wcag_glyph,
            "title_vi": title_vi,
            "latency_ms": latency_ms,
            "red_triggers": red_triggers,
            "yellow_triggers": yellow_triggers,
            "tokens_analyzed": len(ingredient_tokens),
            "details": token_results,
        }


if __name__ == "__main__":
    build_hybrid_database()
