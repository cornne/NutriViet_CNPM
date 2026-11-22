"""
NutriViet Pure-English Official FoodOn Ontology Engine
======================================================
100% Data-Driven from official FoodOn sources only:
  - `src/backend/data/foodon/foodon.owl`
  - `src/backend/data/foodon/foodon-synonyms.tsv`
  - `src/backend/data/foodon/src/ontology/scripts/ingredients.yaml`

Zero Kala dictionary dependencies, zero Vietnamese terms in DB, and zero
hardcoded translation fallbacks. Includes `parent_label_en` and `definition_en`
(`IAO_0000115`) in `foodon_concepts` plus CSV export so the full English
database can be cleanly batch-translated on Kaggle later.
"""

import argparse
import csv
import html as html_lib
import json
import os
import re
import sqlite3
import time
import unicodedata
from datetime import datetime, timezone
from difflib import SequenceMatcher

import monolingual_catalog as mono_cat

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
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
            "FOODON:03420180",  # casein
            "CHEBI:17716",      # lactose
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
            "FOODON:03420194",  # egg component
            "UBERON:0008944",   # albumen
            "UBERON:0007378",   # egg yolk
            "CHEBI:166964",     # albumin type
            "FOODON:00001234",  # mayonnaise food product
            "FOODON:03510216",  # food allergen labelling about eggs
        },
        "exclude_roots": {
            "FOODON:03411579",  # eggplant
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
            "FOODON:00005788",  # malt
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
            "FOODON:03411597",  # buckwheat plant
            "FOODON:00001725",  # buckwheat food product
            "FOODON:00004220",  # buckwheat seed
            "FOODON:00002264",  # soybean refined food product (legume, not gluten grain)
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
            "FOODON:00003206",  # peanut
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
            "FOODON:03411337",  # earthnut / pignut
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

# Representative ontology roots for default browse ordering (pure CURIE anchors)
ALLERGEN_REPRESENTATIVE_CURIES = {
    "milk": "FOODON:03310351",       # butter / dairy
    "peanuts": "FOODON:00003206",    # peanut
    "seafood": "FOODON:03411237",    # shrimp
    "eggs": "FOODON:02010002",       # animal egg
    "soy": "FOODON:03301415",        # soybean
    "gluten": "FOODON:03420177",     # gluten
    "tree_nuts": "FOODON:00003523",  # almond
    "sesame": "FOODON:03310306",     # sesame seed
}

_ENGLISH_PACKAGING_STOPWORDS = frozenset({
    "and", "or", "of", "in", "with", "from", "the", "a", "an", "to", "for",
    "contains", "contain", "may", "less", "than", "ingredients", "ingredient",
    "natural", "artificial", "added", "pure", "refined", "raw", "fresh", "dried",
    "extract", "powder", "oil", "protein", "acid", "water", "flavor", "flavour",
    "color", "colour", "emulsifier", "stabilizer", "thickener", "preservative",
    "antioxidant", "sweetener", "acidity", "regulator", "enhancer", "agent",
})


# ---------------------------------------------------------------------------
# Text Normalization Utilities
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


def uri_to_curie(uri: str) -> str:
    uri = uri.strip("<> ")
    if "/obo/" in uri:
        tail = uri.split("/obo/")[1]
        return tail.replace("_", ":", 1)
    return uri


def _clean_xml_text(raw: str) -> str:
    if not raw:
        return ""
    txt = html_lib.unescape(raw)
    return re.sub(r"\s+", " ", txt).strip()


# ---------------------------------------------------------------------------
# Build Pipeline: Pure Official FoodOn (English Only) -> nutriviet_hybrid.db
# ---------------------------------------------------------------------------
def build_hybrid_database(db_path: str = HYBRID_DB_PATH, verbose: bool = True) -> dict:
    t0 = time.time()
    owl_path = os.path.join(FOODON_DIR, "foodon.owl")
    syn_tsv_path = os.path.join(FOODON_DIR, "foodon-synonyms.tsv")
    yaml_path = os.path.join(FOODON_DIR, "src", "ontology", "scripts", "ingredients.yaml")

    if verbose:
        print("[1/4] Parsing official foodon.owl & foodon-synonyms.tsv...")
    with open(owl_path, "r", encoding="utf-8") as f:
        owl_text = f.read()

    parents_map = {}      # curie -> set of parent curies
    children_map = {}     # parent_curie -> set of child curies
    labels_map = {}       # curie -> primary English label
    definitions_map = {}  # curie -> official IAO_0000115 English definition
    curie_ecodes = {}     # curie -> set of E/INS codes
    owl_synonyms = {}     # curie -> set of English synonyms
    deprecated_curies = set()

    for m in re.finditer(
        r'<!-- (http://purl\.obolibrary\.org/obo/[A-Za-z0-9_]+) -->\s*<owl:Class.*?</owl:Class>',
        owl_text,
        flags=re.DOTALL,
    ):
        block = m.group(0)
        curie = uri_to_curie(m.group(1))
        if '<owl:deprecated rdf:datatype="http://www.w3.org/2001/XMLSchema#boolean">true</owl:deprecated>' in block:
            deprecated_curies.add(curie)
            continue

        lbl_m = re.search(r'<rdfs:label[^>]*>([^<]+)</rdfs:label>', block)
        if lbl_m:
            lbl_clean = _clean_xml_text(lbl_m.group(1))
            if lbl_clean and not lbl_clean.lower().startswith("obsolete"):
                labels_map[curie] = lbl_clean

        def_m = re.search(r'<obo:IAO_0000115[^>]*>([^<]+)</obo:IAO_0000115>', block)
        if def_m:
            def_clean = _clean_xml_text(def_m.group(1))
            if def_clean:
                definitions_map[curie] = def_clean

        for sub_m in re.finditer(
            r'<rdfs:subClassOf rdf:resource="(http://purl\.obolibrary\.org/obo/[^"]+)"/>',
            block,
        ):
            p = uri_to_curie(sub_m.group(1))
            parents_map.setdefault(curie, set()).add(p)
            children_map.setdefault(p, set()).add(curie)

        for some_m in re.finditer(
            r'<owl:Restriction>\s*<owl:onProperty rdf:resource="http://purl\.obolibrary\.org/obo/([^"]+)"/>\s*<owl:someValuesFrom rdf:resource="(http://purl\.obolibrary\.org/obo/[^"]+)"/>',
            block,
        ):
            prop = some_m.group(1)
            if prop in ("RO_0001000", "BFO_0000050", "RO_0002162", "FOODON_00002420", "RO_0009001"):
                p = uri_to_curie(some_m.group(2))
                parents_map.setdefault(curie, set()).add(p)
                children_map.setdefault(p, set()).add(curie)

        for inter_m in re.finditer(r'<owl:intersectionOf[^>]*>(.*?)</owl:intersectionOf>', block, flags=re.DOTALL):
            inter_body = inter_m.group(1)
            for desc_m in re.finditer(
                r'<rdf:Description rdf:about="(http://purl\.obolibrary\.org/obo/[^"]+)"/>',
                inter_body,
            ):
                p = uri_to_curie(desc_m.group(1))
                if p != curie:
                    parents_map.setdefault(curie, set()).add(p)
                    children_map.setdefault(p, set()).add(curie)

        for syn_m in re.finditer(
            r'<oboInOwl:has(?:Exact|Broad|Narrow)?Synonym[^>]*>([^<]+)</oboInOwl:has(?:Exact|Broad|Narrow)?Synonym>',
            block,
        ):
            s_val = _clean_xml_text(syn_m.group(1))
            if s_val and not s_val.startswith("http"):
                owl_synonyms.setdefault(curie, set()).add(s_val)

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
        print("[2/4] Loading official FoodOn ingredients.yaml & assumptions...")
    import yaml

    with open(yaml_path, "r", encoding="utf-8") as f:
        ing_yaml = yaml.safe_load(f)

    assumptions_map = {
        normalize_en_key(k): normalize_en_key(v)
        for k, v in (ing_yaml.get("assumptions") or {}).items()
    }
    yaml_ingredients = ing_yaml.get("ingredient") or {}

    node_types = {}
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
        print("[3/4] Computing official FoodOn ontology subtree closures & English index...")

    def get_subtree_nodes(include_roots: set, exclude_roots: set, max_depth: int = 10) -> set:
        visited = set()
        queue = [(r, 0) for r in include_roots]
        while queue:
            curr, d = queue.pop(0)
            if curr in visited or curr in exclude_roots or d > max_depth:
                continue
            lbl_lower = labels_map.get(curr, "").lower()
            if any(
                neg in lbl_lower
                for neg in (
                    "gluten-free", "gluten free", "lactose free", "lactose-free",
                    "hypoallergenic", "dairy-free", "egg-free", "nut-free",
                )
            ):
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

    # Connect OWL restriction-inferred meat/poultry cuts to canonical FoodOn parent classes
    owl_meat_links = [
        ("FOODON:00002574", "FOODON:00001134"),
        ("FOODON:02000403", "FOODON:00001134"),
        ("FOODON:00005738", "FOODON:00001006"),
        ("FOODON:00002935", "FOODON:00001006"),
        ("FOODON:03411669", "FOODON:00001287"),
        ("FOODON:00001287", "FOODON:00001006"),
        ("FOODON:03411316", "FOODON:00001284"),
        ("FOODON:00001284", "FOODON:00001131"),
        ("FOODON:00001009", "FOODON:00001007"),
        ("FOODON:03315904", "FOODON:00001007"),
        ("FOODON:00005591", "FOODON:00001038"),
        ("FOODON:00001061", "FOODON:00001038"),
        ("FOODON:03302051", "FOODON:00001038"),
        ("FOODON:00005450", "FOODON:00001038"),
        ("FOODON:03302092", "FOODON:00001134"),
        ("FOODON:00005487", "FOODON:00001134"),
    ]
    for child_c, par_c in owl_meat_links:
        parents_map.setdefault(child_c, set()).add(par_c)
        children_map.setdefault(par_c, set()).add(child_c)

    preferred_food_family_parents = {
        "FOODON:00001006", "FOODON:00001134", "FOODON:00001038", "FOODON:00001040",
        "FOODON:00001131", "FOODON:00001284", "FOODON:00001287", "FOODON:00001092",
        "FOODON:00001010", "FOODON:00001007", "FOODON:03317170",
    }
    anatomical_noise_parents = {
        "FOODON:00004328", "FOODON:00004332", "FOODON:00004335", "FOODON:02010107",
        "FOODON:02010223", "FOODON:02010216", "FOODON:02000403", "FOODON:00004530",
        "FOODON:03420116", "FOODON:03420164", "FOODON:03530146",
    }

    best_parent_map = {}
    for c, pars in parents_map.items():
        valid_pars = [
            p for p in pars
            if p != c and p in labels_map and p.startswith(("FOODON:", "CHEBI:", "NCBITaxon:", "UBERON:"))
        ]
        if valid_pars:
            def _parent_rank(p_curie: str):
                has_al = 0 if curie_allergens.get(p_curie) else 1
                is_pref_fam = 0 if p_curie in preferred_food_family_parents else 1
                is_food_prod = 0 if "food product" in labels_map.get(p_curie, "").lower() else 1
                is_anat_noise = 1 if p_curie in anatomical_noise_parents else 0
                return (has_al, is_pref_fam, is_anat_noise, is_food_prod, p_curie)
            best_parent_map[c] = sorted(valid_pars, key=_parent_rank)[0]

    # Collect all official FoodOn concepts + relevant CHEBI/NCBITaxon/UBERON food nodes
    active_curies = (
        {c for c in labels_map if c.startswith("FOODON:")}
        | set(yaml_ingredients.keys())
        | set(curie_allergens.keys())
        | set(curie_chronics.keys())
        | set(curie_ecodes.keys())
        | preferred_food_family_parents
        | {ch for ch, _ in owl_meat_links}
    )
    active_curies -= deprecated_curies

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

    en_index = {}

    def register_en_term(term: str, curie: str, tier: int):
        norm = normalize_en_key(term)
        if not norm or len(norm) < 2:
            return
        en_index.setdefault(norm, []).append((curie, tier))

    # Canonical FoodOn root terms for meat & poultry families
    register_en_term("meat", "FOODON:00001006", 0)
    register_en_term("mammalian meat", "FOODON:00001006", 0)
    register_en_term("poultry", "FOODON:00001131", 0)
    register_en_term("poultry meat", "FOODON:00001131", 0)

    for c in active_curies:
        lbl = labels_map.get(c, "")
        if not lbl:
            continue
        register_en_term(lbl, c, 1)
        for suffix in (" meat food product", " food product", " plant", " tree", " type"):
            if lbl.lower().endswith(suffix):
                base_lbl = lbl[:-len(suffix)].strip()
                if len(base_lbl) >= 3:
                    register_en_term(base_lbl, c, 2)
        if lbl.lower().startswith("monosodium "):
            base_anion = lbl[len("monosodium "):].strip()
            if len(base_anion) >= 5:
                register_en_term(base_anion, c, 2)
        for syn in owl_synonyms.get(c, ()):
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
        best_en_to_curie[norm_en] = sorted(cand_list, key=score_cand)[0][0]

    if verbose:
        print(f"[4/4] Writing pure-English FoodOn SQLite database to {db_path}...")
    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    cur.execute("""
    CREATE TABLE foodon_concepts (
        curie TEXT PRIMARY KEY,
        label_en TEXT NOT NULL,
        parent_curie TEXT,
        parent_label_en TEXT,
        definition_en TEXT,
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

    cur.execute("""
    CREATE TABLE db_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
    ) WITHOUT ROWID
    """)

    referenced_curies = active_curies | set(best_en_to_curie.values()) | set(curie_ecodes.keys())
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
    referenced_curies = {c for c in referenced_curies if c in labels_map}

    concept_rows = []
    for c in sorted(referenced_curies):
        lbl = labels_map[c]
        par = best_parent_map.get(c, "")
        par_lbl = labels_map.get(par, "") if par else ""
        defn = definitions_map.get(c, "")
        ft = node_types.get(c, "")
        als = ",".join(sorted(curie_allergens.get(c, set())))
        chs = ",".join(sorted(curie_chronics.get(c, set())))
        ecs = ",".join(sorted(curie_ecodes.get(c, set())))
        concept_rows.append((c, lbl, par, par_lbl, defn, ft, als, chs, ecs))

    cur.executemany(
        "INSERT INTO foodon_concepts VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        concept_rows,
    )

    lex_rows = []
    for norm_en, c in best_en_to_curie.items():
        if c in referenced_curies:
            lex_rows.append((norm_en, remove_vietnamese_accents(norm_en), "en", c, 1))
    cur.executemany("INSERT OR REPLACE INTO lexical_bridge VALUES (?, ?, ?, ?, ?)", lex_rows)

    ecode_rows = {}
    for c, codes in curie_ecodes.items():
        if c in referenced_curies:
            for code in codes:
                ecode_rows.setdefault(code.lower(), c)
    cur.executemany("INSERT OR REPLACE INTO ecode_bridge VALUES (?, ?)", list(ecode_rows.items()))

    cur.execute("CREATE INDEX idx_lex_ascii ON lexical_bridge(term_ascii)")
    cur.execute("CREATE INDEX idx_lex_curie ON lexical_bridge(curie)")

    built_at = datetime.now(timezone.utc).isoformat()
    meta_rows = [
        ("schema_version", "2.0-foodon-en"),
        ("language", "en"),
        ("source", "foodon_official"),
        ("built_at", built_at),
        ("total_concepts", str(len(concept_rows))),
        ("total_en_terms", str(len(lex_rows))),
        ("total_vi_terms", "0"),
        ("total_ecodes", str(len(ecode_rows))),
        ("concepts_with_definition", str(sum(1 for r in concept_rows if r[4]))),
    ]
    cur.executemany("INSERT INTO db_metadata VALUES (?, ?)", meta_rows)

    conn.commit()
    cur.execute("VACUUM")
    conn.close()

    elapsed = time.time() - t0
    db_size = os.path.getsize(db_path)
    stats = {
        "build_time_sec": round(elapsed, 2),
        "hybrid_db_size_bytes": db_size,
        "hybrid_db_size_mb": round(db_size / (1024 * 1024), 2),
        "total_concepts": len(concept_rows),
        "total_en_terms": len(lex_rows),
        "total_vi_terms": 0,
        "total_ecodes": len(ecode_rows),
        "concepts_with_definition": sum(1 for r in concept_rows if r[4]),
        "allergen_tagged_concepts": sum(1 for r in concept_rows if r[6]),
        "chronic_tagged_concepts": sum(1 for r in concept_rows if r[7]),
    }
    if verbose:
        print(f"[DONE] Built pure-English FoodOn DB in {stats['build_time_sec']}s | Size: {stats['hybrid_db_size_mb']} MB")
        print("       Stats:", json.dumps(stats, indent=2))
    return stats


def export_concepts_for_kaggle(output_csv_path: str, db_path: str = HYBRID_DB_PATH) -> int:
    """
    Exports `foodon_concepts` with English synonyms & ontology context
    (`parent_label_en`, `definition_en`) into a clean UTF-8 CSV ready for
    batch GPU/LLM translation on Kaggle.
    """
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    syns_by_curie: dict[str, list[str]] = {}
    for r in cur.execute(
        "SELECT curie, term_norm FROM lexical_bridge WHERE lang = 'en' ORDER BY confidence_tier ASC, length(term_norm) ASC"
    ):
        syns_by_curie.setdefault(r["curie"], []).append(r["term_norm"])

    rows = cur.execute(
        """
        SELECT curie, label_en, parent_curie, parent_label_en, definition_en,
               food_type, allergen_codes, chronic_codes, ecodes
        FROM foodon_concepts
        ORDER BY
            CASE WHEN allergen_codes != '' THEN 0 ELSE 1 END,
            CASE WHEN chronic_codes != '' THEN 0 ELSE 1 END,
            CASE WHEN ecodes != '' THEN 0 ELSE 1 END,
            curie ASC
        """
    ).fetchall()
    conn.close()

    fieldnames = [
        "curie",
        "label_en",
        "parent_curie",
        "parent_label_en",
        "definition_en",
        "food_type",
        "allergen_codes",
        "chronic_codes",
        "ecodes",
        "synonyms_en",
    ]
    out_dir = os.path.dirname(os.path.abspath(output_csv_path))
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(output_csv_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for r in rows:
            lbl_low = (r["label_en"] or "").strip().lower()
            extra_syns = [s for s in syns_by_curie.get(r["curie"], []) if s != lbl_low][:8]
            writer.writerow({
                "curie": r["curie"],
                "label_en": r["label_en"] or "",
                "parent_curie": r["parent_curie"] or "",
                "parent_label_en": r["parent_label_en"] or "",
                "definition_en": r["definition_en"] or "",
                "food_type": r["food_type"] or "",
                "allergen_codes": r["allergen_codes"] or "",
                "chronic_codes": r["chronic_codes"] or "",
                "ecodes": r["ecodes"] or "",
                "synonyms_en": " | ".join(extra_syns),
            })
    return len(rows)


# ---------------------------------------------------------------------------
# Runtime FoodOn Engine: Multi-Stage Recognition + Fuzzy Match + Graph Trace
# ---------------------------------------------------------------------------
class HybridFoodOnEngine:
    """
    Production & Offline-Ready FoodOn Evaluation Engine over `nutriviet_hybrid.db`.
    Runs 100% on Python standard library (`sqlite3`) at runtime.
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

        cols = {r["name"] for r in cur.execute("PRAGMA table_info(foodon_concepts)").fetchall()}
        has_def = "definition_en" in cols
        has_par_lbl = "parent_label_en" in cols

        self.concepts = {}
        cur.execute("SELECT * FROM foodon_concepts")
        for r in cur.fetchall():
            self.concepts[r["curie"]] = {
                "curie": r["curie"],
                "label_en": r["label_en"],
                "parent_curie": r["parent_curie"] or "",
                "parent_label_en": (r["parent_label_en"] or "") if has_par_lbl else "",
                "definition_en": (r["definition_en"] or "") if has_def else "",
                "food_type": r["food_type"] or "",
                "allergens": [x for x in (r["allergen_codes"] or "").split(",") if x],
                "chronics": [x for x in (r["chronic_codes"] or "").split(",") if x],
                "ecodes": [x for x in (r["ecodes"] or "").split(",") if x],
            }

        self.ecode_map = {}
        cur.execute("SELECT ecode, curie FROM ecode_bridge")
        for r in cur.fetchall():
            self.ecode_map[r["ecode"]] = r["curie"]

        self.vi_exact = {}
        self.en_exact = {}
        self.ascii_index = {}
        self.first_char_buckets = {}
        self.curie_vi_terms = {}
        self.curie_en_terms = {}

        cur.execute(
            "SELECT term_norm, term_ascii, lang, curie, confidence_tier "
            "FROM lexical_bridge ORDER BY confidence_tier ASC, length(term_norm) ASC"
        )
        for r in cur.fetchall():
            tn = r["term_norm"]
            ta = r["term_ascii"]
            lang = r["lang"]
            c = r["curie"]
            tier = r["confidence_tier"]
            if lang == "vi":
                self.vi_exact[tn] = (c, tier)
                self.curie_vi_terms.setdefault(c, []).append(tn)
            else:
                self.en_exact[tn] = (c, tier)
                self.curie_en_terms.setdefault(c, []).append(tn)
            self.ascii_index.setdefault(ta, []).append((tn, lang, c, tier))
            if ta:
                self.first_char_buckets.setdefault(ta[0], []).append((tn, ta, lang, c, tier))

        conn.close()
        if "FOODON:03317197" in self.concepts and "seafood" not in self.concepts["FOODON:03317197"]["allergens"]:
            self.concepts["FOODON:03317197"]["allergens"].append("seafood")

        # Build fast O(1) parent -> children ontology adjacency map for graph visualization
        self.children_map: dict[str, list[str]] = {}
        for c_id, info in self.concepts.items():
            p_id = info["parent_curie"]
            if p_id and p_id != c_id and p_id in self.concepts:
                self.children_map.setdefault(p_id, []).append(c_id)
        for p_id, ch_list in self.children_map.items():
            ch_list.sort(
                key=lambda cid: (
                    -len(self.children_map.get(cid, [])),
                    0 if (self.concepts[cid]["allergens"] or self.concepts[cid]["chronics"] or self.concepts[cid]["ecodes"]) else 1,
                    len(self.concepts[cid]["label_en"]),
                    self.concepts[cid]["label_en"].lower(),
                )
            )

    def get_lineage(self, curie: str, max_hops: int = 4) -> list[dict]:
        chain = []
        curr = curie
        seen = set()
        for _ in range(max_hops + 1):
            if not curr or curr in seen or curr not in self.concepts:
                break
            seen.add(curr)
            info = self.concepts[curr]
            chain.append({
                "curie": curr,
                "label_en": info["label_en"],
                "label_vi": info["label_en"],
                "terms_vi": [],
            })
            curr = info["parent_curie"]
        return chain

    def get_lineage_string(self, curie: str) -> str:
        return " -> ".join(f"{item['curie']} ({item['label_en']})" for item in self.get_lineage(curie))

    def _exact_lookup(self, norm_text: str) -> tuple[str, str, float] | None:
        if norm_text in self.vi_exact:
            c, _ = self.vi_exact[norm_text]
            return c, "exact_vi", 1.0
        en_k = normalize_en_key(norm_text)
        if en_k in self.en_exact:
            c, _ = self.en_exact[en_k]
            return c, "exact_en", 1.0
        if en_k.endswith("s") and len(en_k) > 4 and en_k[:-1] in self.en_exact:
            c, _ = self.en_exact[en_k[:-1]]
            return c, "exact_en_singular", 0.98
        if en_k.endswith("es") and len(en_k) > 5 and en_k[:-2] in self.en_exact:
            c, _ = self.en_exact[en_k[:-2]]
            return c, "exact_en_singular", 0.98
        return None

    def _fuzzy_lookup(self, raw_token: str, threshold: float = 0.82) -> tuple[str, str, str, float] | None:
        t_norm = normalize_en_key(raw_token)
        t_ascii = remove_vietnamese_accents(t_norm)
        if len(t_ascii) < 3:
            return None

        if t_ascii in self.ascii_index:
            candidates = self.ascii_index[t_ascii]
            best_cand = None
            best_score = -1.0
            for tn, lang, c, tier in candidates:
                sim_acc = SequenceMatcher(None, t_norm, tn).ratio()
                score = 0.6 * sim_acc + 0.4 * 1.0 - (tier - 1) * 0.03
                if score > best_score:
                    best_score = score
                    best_cand = (c, tn, "ascii_fold_match", round(min(score, 0.99), 3))
            if best_cand:
                return best_cand

        t_len = len(t_ascii)
        best_match = None
        best_sim = threshold
        for tn, ta, lang, c, tier in self.first_char_buckets.get(t_ascii[0], ()):
            if abs(len(ta) - t_len) > 2:
                continue
            sim_ascii = SequenceMatcher(None, t_ascii, ta).ratio()
            if sim_ascii < 0.74:
                continue
            sim_acc = SequenceMatcher(None, t_norm, tn).ratio()
            weighted_sim = 0.6 * sim_acc + 0.4 * sim_ascii
            effective_sim = weighted_sim - (tier - 1) * 0.02
            if effective_sim >= best_sim:
                best_sim = effective_sim
                best_match = (c, tn, f"fuzzy_{lang}", round(weighted_sim, 3))

        return best_match

    def recognize_ingredient(self, raw_token: str) -> dict:
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
            en_terms = self.curie_en_terms.get(curie, [])
            raw_lineage = self.get_lineage(curie)
            risk = self.classify_concept_risk(curie)
            mono = mono_cat.build_monolingual_card_fields(
                curie=curie,
                label_en=info["label_en"],
                vi_terms=[],
                en_terms=en_terms,
                lineage_nodes=raw_lineage,
                allergens=info["allergens"],
                chronics=info["chronics"],
                ecodes=info["ecodes"],
                risk_level=risk["risk_level"],
                definition_en=info["definition_en"],
            )
            matched_records.append({
                "curie": curie,
                "label_en": info["label_en"],
                "title_vi": mono["title_en"],
                "title_en": mono["title_en"],
                "terms_vi": [],
                "terms_en": mono["clean_en_terms"],
                "matched_term": matched_term,
                "matched_vi": mono["title_en"],
                "matched_en": mono["title_en"],
                "match_type": match_type,
                "confidence": confidence,
                "food_type": info["food_type"],
                "allergens": info["allergens"],
                "chronics": info["chronics"],
                "ecodes": info["ecodes"],
                "lineage": self.get_lineage_string(curie),
                "lineage_nodes": mono["enriched_lineage"],
            })

        # Stage 1: E-numbers / INS codes (strict exact regex)
        for e_match in re.finditer(r"\b(e|ins)\s*(\d{3,4}[a-z]?(?:\([ivx]+\))?)\b", clean_token.lower()):
            prefix = e_match.group(1)
            num_part = e_match.group(2)
            base_num = re.sub(r"\(.*?\)", "", num_part)
            for candidate_code in (f"{prefix}{num_part}", f"e{base_num}", f"ins{base_num}"):
                if candidate_code in self.ecode_map:
                    add_match(self.ecode_map[candidate_code], e_match.group(0).upper(), "ecode_exact", 1.0)
                    break

        stripped_token = re.sub(r"\(\s*\d+(?:[.,]\d+)?\s*%\s*\)", " ", clean_token)
        stripped_token = re.sub(r"\b\d+(?:[.,]\d+)?\s*%", " ", stripped_token)
        stripped_token = re.sub(
            r"\(\s*(?:e|ins)\s*\d{3,4}[a-z]?(?:\([ivx]+\))?\s*\)",
            " ",
            stripped_token,
            flags=re.IGNORECASE,
        )

        sub_parts = [stripped_token]
        for pm in re.findall(r"\(([^)]+)\)", stripped_token):
            sub_parts.append(pm)
        main_no_paren = re.sub(r"\([^)]*\)", " ", stripped_token)
        if main_no_paren.strip() != stripped_token.strip():
            sub_parts.insert(0, main_no_paren)

        low_full = clean_token.lower()
        is_gluten_free = any(x in low_full for x in ("gluten-free", "gluten free"))
        is_lactose_free = any(x in low_full for x in ("lactose-free", "lactose free"))
        is_plant_milk = any(
            x in low_full
            for x in ("soy milk", "soya milk", "almond milk", "oat milk", "coconut milk", "rice milk")
        )
        is_plant_butter = any(
            x in low_full
            for x in ("peanut butter", "almond butter", "cocoa butter", "margarine", "cashew butter", "sunflower butter")
        )

        # Stage 2: Whole-part exact English / ASCII-fold lookup
        unmatched_parts = []
        for part in sub_parts:
            p_norm = re.sub(r"\s+", " ", part.strip().lower()).strip(".,;:-")
            if not p_norm:
                continue
            exact = self._exact_lookup(p_norm)
            if exact:
                add_match(exact[0], p_norm, exact[1], exact[2])
                continue
            p_ascii = remove_vietnamese_accents(normalize_en_key(p_norm))
            if len(p_ascii) >= 4 and p_ascii in self.ascii_index:
                fz_ascii = self._fuzzy_lookup(p_norm, threshold=0.82)
                if fz_ascii:
                    add_match(fz_ascii[0], fz_ascii[1], fz_ascii[2], fz_ascii[3])
                    continue
            unmatched_parts.append(p_norm)

        # Stage 3: Component / sub-phrase decomposition (longest n-gram first)
        for p_norm in unmatched_parts:
            words = normalize_en_key(p_norm).split()
            if len(words) >= 2:
                covered_indices = set()
                for n in range(min(len(words) - 1, 4), 0, -1):
                    for i in range(len(words) - n + 1):
                        if any(idx in covered_indices for idx in range(i, i + n)):
                            continue
                        sub_phrase = " ".join(words[i : i + n])
                        if n == 1:
                            if sub_phrase in _ENGLISH_PACKAGING_STOPWORDS:
                                continue
                            if sub_phrase == "milk" and is_plant_milk:
                                continue
                            if sub_phrase == "butter" and is_plant_butter:
                                continue
                        exact_sub = self._exact_lookup(sub_phrase)
                        if exact_sub:
                            add_match(exact_sub[0], sub_phrase, f"component_{exact_sub[1]}", 0.95)
                            covered_indices.update(range(i, i + n))

        # Stage 4: Fuzzy fallback for OCR typos (only when stages 1-3 found nothing)
        if not matched_records:
            for p_norm in unmatched_parts:
                fuzzy = self._fuzzy_lookup(p_norm, threshold=0.82)
                if fuzzy:
                    add_match(fuzzy[0], fuzzy[1], fuzzy[2], fuzzy[3])
                elif len(p_norm.split()) >= 2:
                    words = normalize_en_key(p_norm).split()
                    for n in (2, 1):
                        for i in range(len(words) - n + 1):
                            sub_p = " ".join(words[i : i + n])
                            if len(sub_p) < 4 or sub_p in _ENGLISH_PACKAGING_STOPWORDS:
                                continue
                            fz_sub = self._fuzzy_lookup(sub_p, threshold=0.84)
                            if fz_sub:
                                add_match(fz_sub[0], fz_sub[1], f"component_{fz_sub[2]}", fz_sub[3])

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

        matched_records.sort(
            key=lambda r: (
                0 if r.get("allergens") else 1,
                0 if r.get("chronics") else 1,
                0 if r.get("ecodes") else 1,
            )
        )

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
        lang: str = "en",
    ) -> dict:
        t0 = time.perf_counter()
        user_chronics = set(user_chronics or [])
        profile_severity = {}
        profile_source_food_en = {}
        custom_curie_targets = {}

        for item in user_allergens:
            if isinstance(item, str):
                code = item.strip()
                if code:
                    profile_severity[code] = "high"
            elif isinstance(item, dict):
                code = (item.get("code") or item.get("allergen_code") or "").strip()
                sev = (item.get("severity") or "high").lower()
                raw_name = (item.get("name") or item.get("allergen_name") or "").strip()
                if code:
                    profile_severity[code] = sev
                    if raw_name and raw_name != code:
                        profile_source_food_en[code] = raw_name
                    if code.startswith("curie:"):
                        target_c = code.split("curie:", 1)[1].strip().upper()
                        if target_c:
                            custom_curie_targets[target_c] = code

        token_results = []
        red_triggers = []
        yellow_triggers = []

        for tok in ingredient_tokens:
            res = self.recognize_ingredient(tok)
            triggered_codes_for_tok = []
            triggered_chronics_for_tok = []

            for al_code in res["allergens"]:
                if al_code in profile_severity:
                    sev = profile_severity[al_code]
                    triggered_codes_for_tok.append(al_code)
                    primary_match = next(
                        (m for m in res["matches"] if al_code in m.get("allergens", [])),
                        res["matches"][0] if res["matches"] else {},
                    )
                    al_en = mono_cat.format_code_label_en(al_code)
                    m_en = primary_match.get("title_en") or primary_match.get("label_en") or tok
                    src_en = profile_source_food_en.get(al_code, "")
                    red_triggers.append({
                        "token": tok,
                        "allergen_code": al_code,
                        "allergen_name": al_en,
                        "allergen_name_vi": al_en,
                        "allergen_name_en": al_en,
                        "source_food": src_en,
                        "source_food_vi": src_en,
                        "source_food_en": src_en,
                        "matched_vi": m_en,
                        "matched_en": m_en,
                        "severity": sev,
                        "curie": primary_match.get("curie", ""),
                        "label_en": primary_match.get("label_en", ""),
                        "lineage": primary_match.get("lineage", ""),
                        "match_type": primary_match.get("match_type", ""),
                        "confidence": primary_match.get("confidence", 1.0),
                    })

            if custom_curie_targets and res["matches"]:
                for m in res["matches"]:
                    lineage_c_set = {n["curie"] for n in m.get("lineage_nodes", [])}
                    lineage_c_set.add(m["curie"])
                    m_fam = self.infer_foodon_family(m["curie"])
                    for target_c, full_code in custom_curie_targets.items():
                        target_fam = self.infer_foodon_family(target_c)
                        is_lineage_hit = (
                            (target_c in lineage_c_set)
                            or (m_fam == full_code)
                            or (m_fam == target_fam)
                        )
                        if is_lineage_hit and full_code not in triggered_codes_for_tok:
                            triggered_codes_for_tok.append(full_code)
                            card_target = self._build_concept_card(target_c) if target_c in self.concepts else {}
                            fam_en = (
                                card_target.get("title_en")
                                or profile_source_food_en.get(full_code)
                                or mono_cat.format_code_label_en(full_code)
                            )
                            src_en = profile_source_food_en.get(full_code) or fam_en
                            m_en = m.get("title_en") or tok
                            red_triggers.append({
                                "token": tok,
                                "allergen_code": full_code,
                                "allergen_name": fam_en,
                                "allergen_name_vi": fam_en,
                                "allergen_name_en": fam_en,
                                "source_food": src_en,
                                "source_food_vi": src_en,
                                "source_food_en": src_en,
                                "matched_vi": m_en,
                                "matched_en": m_en,
                                "severity": "high",
                                "curie": m.get("curie", ""),
                                "label_en": m.get("label_en", ""),
                                "lineage": m.get("lineage", ""),
                                "match_type": m.get("match_type", ""),
                                "confidence": m.get("confidence", 1.0),
                            })

            for ch_code in res["chronics"]:
                if ch_code in user_chronics:
                    triggered_chronics_for_tok.append(ch_code)
                    primary_match = next(
                        (m for m in res["matches"] if ch_code in m.get("chronics", [])),
                        res["matches"][0] if res["matches"] else {},
                    )
                    ch_en = mono_cat.format_code_label_en(ch_code)
                    m_en = primary_match.get("title_en") or primary_match.get("label_en") or tok
                    yellow_triggers.append({
                        "token": tok,
                        "chronic_code": ch_code,
                        "chronic_name": ch_en,
                        "chronic_name_vi": ch_en,
                        "chronic_name_en": ch_en,
                        "matched_vi": m_en,
                        "matched_en": m_en,
                        "severity": "caution",
                        "curie": primary_match.get("curie", ""),
                        "label_en": primary_match.get("label_en", ""),
                        "lineage": primary_match.get("lineage", ""),
                        "match_type": primary_match.get("match_type", ""),
                        "confidence": primary_match.get("confidence", 1.0),
                    })

            res["is_allergy_trigger"] = len(triggered_codes_for_tok) > 0
            res["triggered_allergen_codes"] = triggered_codes_for_tok
            res["is_chronic_trigger"] = len(triggered_chronics_for_tok) > 0
            token_results.append(res)

        if red_triggers:
            verdict = "RED"
            wcag_glyph = "[!X]"
            title_en = "HIGH RISK: ALLERGEN DETECTED - DO NOT CONSUME"
        elif yellow_triggers:
            verdict = "YELLOW"
            wcag_glyph = "[!?]"
            title_en = "CAUTION: CONTAINS INGREDIENTS TO LIMIT OR AVOID"
        else:
            verdict = "GREEN"
            wcag_glyph = "[OK]"
            title_en = "SAFE TO CONSUME - NO ALLERGEN TRIGGERS DETECTED"

        latency_ms = round((time.perf_counter() - t0) * 1000, 2)
        return {
            "verdict": verdict,
            "wcag_glyph": wcag_glyph,
            "title": title_en,
            "title_vi": title_en,
            "title_en": title_en,
            "latency_ms": latency_ms,
            "red_triggers": red_triggers,
            "yellow_triggers": yellow_triggers,
            "tokens_analyzed": len(ingredient_tokens),
            "details": token_results,
        }

    def search_concepts(
        self,
        query: str = "",
        lang_scope: str = "all",
        allergen_filter: str = "",
        limit: int = 30,
    ) -> dict:
        t0 = time.perf_counter()
        q_raw = (query or "").strip()
        q_norm = re.sub(r"\s+", " ", q_raw.lower())
        lang_scope = (lang_scope or "all").lower()
        allergen_filter = (allergen_filter or "").strip().lower()
        limit = max(1, min(int(limit or 30), 100))

        recognition = self.recognize_ingredient(q_raw) if q_raw else None
        cand_scores = {}

        def record_hit(curie: str, rank_score: int, matched_term: str, matched_lang: str):
            if curie not in self.concepts:
                return
            info = self.concepts[curie]
            if allergen_filter and allergen_filter not in info["allergens"]:
                return
            prev = cand_scores.get(curie)
            if prev is None or rank_score < prev[0]:
                cand_scores[curie] = (rank_score, matched_term, matched_lang)

        if not q_norm:
            for curie, info in self.concepts.items():
                if allergen_filter and allergen_filter not in info["allergens"]:
                    continue
                if lang_scope == "ecode" and not info["ecodes"]:
                    continue
                has_al = 0 if info["allergens"] else 1
                has_ec = 0 if info["ecodes"] else 1
                score = has_al * 10 + has_ec * 5 + len(info["label_en"])
                record_hit(curie, score, info["label_en"], "en")
        else:
            q_upper = q_raw.upper()
            if q_upper in self.concepts and lang_scope in ("all", "en"):
                record_hit(q_upper, 1, q_upper, "curie")

            if lang_scope in ("all", "ecode"):
                q_ec = re.sub(r"\s+", "", q_norm)
                for ec, curie in self.ecode_map.items():
                    if q_ec == ec or q_ec in ec:
                        rk = 2 if q_ec == ec else 15
                        record_hit(curie, rk, ec.upper(), "ecode")

            if lang_scope in ("all", "en", "vi"):
                q_en = normalize_en_key(q_norm)
                if q_en:
                    for tn, (curie, tier) in self.en_exact.items():
                        if tn == q_en:
                            record_hit(curie, 4 + tier, tn, "en")
                        elif tn.startswith(q_en + " ") or tn.endswith(" " + q_en):
                            record_hit(curie, max(6, 16 + tier * 2 + min(len(tn), 20)), tn, "en")
                        elif f" {q_en} " in f" {tn} ":
                            record_hit(curie, max(8, 22 + tier * 2 + min(len(tn), 25)), tn, "en")
                        elif tn.startswith(q_en):
                            record_hit(curie, max(12, 34 + tier * 2 + min(len(tn), 25)), tn, "en")
                        elif len(q_en) >= 3 and q_en in tn:
                            record_hit(curie, 58 + tier * 2 + min(len(tn), 30), tn, "en")

            if recognition and recognition["matched"]:
                for idx, m in enumerate(recognition["matches"]):
                    c = m["curie"]
                    mtype = m["match_type"]
                    record_hit(c, 10 + idx, m["matched_term"], "ecode" if "ecode" in mtype else "en")

        sorted_hits = sorted(cand_scores.items(), key=lambda x: (x[1][0], x[0]))[:limit]
        results = []
        for curie, (rk, m_term, m_lang) in sorted_hits:
            info = self.concepts[curie]
            en_terms = self.curie_en_terms.get(curie, [])
            results.append({
                "curie": curie,
                "label_en": info["label_en"],
                "definition_en": info["definition_en"],
                "terms_vi": [],
                "terms_en": en_terms[:10],
                "food_type": info["food_type"],
                "allergens": info["allergens"],
                "chronics": info["chronics"],
                "ecodes": info["ecodes"],
                "matched_term": m_term,
                "matched_lang": m_lang,
                "rank_score": rk,
                "lineage": self.get_lineage_string(curie),
                "lineage_nodes": self.get_lineage(curie),
            })

        latency_ms = round((time.perf_counter() - t0) * 1000, 2)
        return {
            "query": q_raw,
            "lang_scope": lang_scope,
            "allergen_filter": allergen_filter,
            "latency_ms": latency_ms,
            "total_matched": len(cand_scores),
            "returned_count": len(results),
            "recognition": recognition,
            "results": results,
            "db_stats": {
                "total_concepts": len(self.concepts),
                "total_vi_terms": len(self.vi_exact),
                "total_en_terms": len(self.en_exact),
                "total_ecodes": len(self.ecode_map),
            },
        }

    def classify_concept_risk(self, curie: str) -> dict:
        info = self.concepts.get(curie)
        if not info:
            return {"risk_level": "low", "risk_label_vi": "Low risk", "risk_label_en": "Low risk"}

        ft = info["food_type"]
        par = info["parent_curie"]
        als = info["allergens"]
        chs = info["chronics"]
        lbl_low = (info["label_en"] or "").lower()
        lineage_curies = {node["curie"] for node in self.get_lineage(curie, max_hops=4)}

        if not als and not chs:
            is_vitamin_or_nutrient = (
                "CHEBI:176838" in lineage_curies
                or "CHEBI:30527" in lineage_curies
                or "CHEBI:33229" in lineage_curies
                or "vitamin" in lbl_low
                or (
                    "nutrient" in ft
                    and par not in ("CHEBI:26195", "CHEBI:38700", "CHEBI:22723", "FOODON:03412972")
                )
            )
            if is_vitamin_or_nutrient:
                return {"risk_level": "safe", "risk_label_vi": "Safe", "risk_label_en": "Safe"}

        if (
            als
            or chs
            or ("chemical" in ft and "nutrient" not in ft)
            or par in ("FOODON:03412972", "CHEBI:38700", "CHEBI:26513", "CHEBI:50860", "CHEBI:35286", "CHEBI:22723")
        ):
            return {"risk_level": "high", "risk_label_vi": "High risk", "risk_label_en": "High risk"}

        return {"risk_level": "low", "risk_label_vi": "Low risk", "risk_label_en": "Low risk"}

    def _build_concept_card(
        self,
        curie: str,
        primary_code: str = "",
        lang: str = "en",
        preferred_vi_term: str = "",
    ) -> dict:
        info = self.concepts[curie]
        en_terms = self.curie_en_terms.get(curie, [])
        lineage_nodes = self.get_lineage(curie, max_hops=4)
        risk = self.classify_concept_risk(curie)

        code_badge = (primary_code or (info["ecodes"][0] if info["ecodes"] else curie)).upper()
        mono = mono_cat.build_monolingual_card_fields(
            curie=curie,
            label_en=info["label_en"],
            vi_terms=[],
            en_terms=en_terms,
            lineage_nodes=lineage_nodes,
            allergens=info["allergens"],
            chronics=info["chronics"],
            ecodes=info["ecodes"],
            risk_level=risk["risk_level"],
            primary_code=code_badge,
            definition_en=info["definition_en"],
        )

        title_en = mono["title_en"]
        desc_en = mono["description_en"]
        return {
            "code": code_badge,
            "curie": curie,
            "title": title_en,
            "title_vi": title_en,
            "title_en": title_en,
            "label_en": title_en,
            "label_vi": title_en,
            "definition_en": info["definition_en"],
            "terms_vi": [],
            "terms_en": mono["clean_en_terms"],
            "description": desc_en,
            "description_vi": desc_en,
            "description_en": desc_en,
            "food_type": info["food_type"],
            "allergens": info["allergens"],
            "chronics": info["chronics"],
            "ecodes": [e.upper() for e in info["ecodes"]],
            "risk_level": risk["risk_level"],
            "risk_label": risk["risk_label_en"],
            "risk_label_vi": risk["risk_label_en"],
            "risk_label_en": risk["risk_label_en"],
            "lineage": self.get_lineage_string(curie),
            "lineage_nodes": mono["enriched_lineage"],
        }

    def list_additives(self, query: str = "", lang: str = "en", limit: int = 60) -> dict:
        t0 = time.perf_counter()
        q = (query or "").strip()
        limit = max(1, min(int(limit or 60), 150))

        def sort_ecode_key(ec_str: str):
            m = re.match(r"^(?:e|ins)(\d+)([a-z]?)(.*)$", ec_str.lower())
            if m:
                return (0, int(m.group(1)), m.group(2), m.group(3))
            return (1, 999999, ec_str, "")

        items = []
        seen_curies = set()

        e_entries = [
            (ec, curie)
            for ec, curie in self.ecode_map.items()
            if ec.startswith("e") and "(" not in ec
        ]
        e_entries.sort(key=lambda x: sort_ecode_key(x[0]))

        if not q:
            for ec, curie in e_entries:
                if curie in seen_curies or curie not in self.concepts:
                    continue
                seen_curies.add(curie)
                items.append(self._build_concept_card(curie, primary_code=ec.upper()))
                if len(items) >= limit:
                    break
        else:
            q_low = q.lower().strip()
            q_compact = re.sub(r"\s+", "", q_low)

            e_matches = [
                (ec, curie)
                for ec, curie in self.ecode_map.items()
                if q_compact in ec or q_low in ec
            ]
            e_matches.sort(
                key=lambda x: (0 if x[0] == q_compact or x[0] == f"e{q_compact}" else 1, sort_ecode_key(x[0]))
            )
            for ec, curie in e_matches:
                if curie in seen_curies or curie not in self.concepts:
                    continue
                seen_curies.add(curie)
                display_ec = ec.upper() if ec.startswith("e") else f"E{ec[3:].upper()}"
                items.append(self._build_concept_card(curie, primary_code=display_ec))
                if len(items) >= limit:
                    break

            if len(items) < limit:
                for ec, curie in e_entries:
                    if curie in seen_curies or curie not in self.concepts:
                        continue
                    card = self._build_concept_card(curie, primary_code=ec.upper())
                    haystack = f"{card['title_en']} {card['description_en']}".lower()
                    if q_low in haystack:
                        seen_curies.add(curie)
                        items.append(card)
                        if len(items) >= limit:
                            break

            if len(items) < limit:
                search_res = self.search_concepts(query=q, lang_scope="en", limit=limit)
                for r in search_res.get("results", []):
                    c = r["curie"]
                    if c in seen_curies:
                        continue
                    seen_curies.add(c)
                    e_list = [e for e in r.get("ecodes", []) if e.lower().startswith("e")]
                    p_code = e_list[0].upper() if e_list else c
                    items.append(self._build_concept_card(c, primary_code=p_code))
                    if len(items) >= limit:
                        break

        return {
            "query": q,
            "lang": "en",
            "count": len(items),
            "latency_ms": round((time.perf_counter() - t0) * 1000, 2),
            "items": items,
        }

    def get_category_concepts(
        self,
        category: str,
        user_allergens: list[str] | None = None,
        lang: str = "en",
        limit: int = 20,
    ) -> dict:
        cat = (category or "sugar").lower().strip()
        chronic_map = {"sugar": "diabetes", "salt": "hypertension", "fat": "cholesterol"}
        items = []
        seen = set()

        if cat in chronic_map:
            target_ch = chronic_map[cat]
            root_set = FOODON_CHRONIC_ROOTS.get(target_ch, set())
            candidates = [
                curie for curie, info in self.concepts.items()
                if target_ch in info["chronics"]
            ]
            candidates.sort(
                key=lambda c: (
                    0 if c in root_set else 1,
                    0 if self.concepts[c]["ecodes"] else 1,
                    len(self.concepts[c]["label_en"]),
                    c,
                )
            )
            for c in candidates:
                if c in seen:
                    continue
                seen.add(c)
                items.append(self._build_concept_card(c))
                if len(items) >= limit:
                    break
        else:
            active_als = [a for a in (user_allergens or []) if a in FOODON_ALLERGEN_ROOTS]
            if not active_als:
                active_als = list(FOODON_ALLERGEN_ROOTS.keys())
            for al_code in active_als:
                rep_curie = ALLERGEN_REPRESENTATIVE_CURIES.get(al_code)
                if rep_curie and rep_curie in self.concepts and rep_curie not in seen:
                    seen.add(rep_curie)
                    items.append(self._build_concept_card(rep_curie))
                    if len(items) >= limit:
                        break
            if len(items) < limit:
                active_set = set(active_als)
                candidates = [
                    curie for curie, info in self.concepts.items()
                    if curie not in seen and any(a in active_set for a in info["allergens"])
                ]
                candidates.sort(
                    key=lambda c: (
                        0 if self.concepts[c]["food_type"] else 1,
                        len(self.concepts[c]["label_en"]),
                        c,
                    )
                )
                for c in candidates:
                    seen.add(c)
                    items.append(self._build_concept_card(c))
                    if len(items) >= limit:
                        break

        return {"category": cat, "lang": "en", "count": len(items), "items": items}

    def infer_foodon_family(self, curie: str) -> str:
        info = self.concepts.get(curie)
        if not info:
            return f"curie:{curie}"
        if info["allergens"]:
            return info["allergens"][0]

        lineage = self.get_lineage(curie, max_hops=5)
        lineage_curies = [n["curie"] for n in lineage]

        if "FOODON:00001006" in lineage_curies:
            return "curie:FOODON:00001006"
        if "FOODON:00001131" in lineage_curies:
            return "curie:FOODON:00001131"
        if "FOODON:00001092" in lineage_curies:
            return "curie:FOODON:00001092"

        generic_roots = {
            "FOODON:00001002", "FOODON:00002403", "FOODON:00001714",
            "FOODON:00001015", "FOODON:00004242", "FOODON:00004328",
            "FOODON:03420116", "FOODON:03420164", "FOODON:00002196",
            "FOODON:00002131", "FOODON:03311737",
        }
        if len(lineage_curies) >= 2 and lineage_curies[1] not in generic_roots:
            return f"curie:{lineage_curies[1]}"
        return f"curie:{curie}"

    def _get_dynamic_family_metadata(
        self,
        allergen_code: str,
        fallback_food_en: str,
    ) -> tuple[str, str]:
        """Returns (fam_en, rel_en) directly from FoodOn concepts in `nutriviet_hybrid.db`."""
        sib_en: list[str] = []
        fam_en = ""

        if allergen_code.startswith("curie:"):
            fam_curie = allergen_code.split("curie:", 1)[1].strip()
            if fam_curie in self.concepts:
                fam_en = mono_cat.format_clean_english_title(
                    fam_curie, self.concepts[fam_curie]["label_en"]
                )
                for c_id, c_info in self.concepts.items():
                    if c_info["parent_curie"] == fam_curie or c_id == fam_curie:
                        t_en = mono_cat.format_clean_english_title(c_id, c_info["label_en"])
                        if t_en not in sib_en:
                            sib_en.append(t_en)
                        if len(sib_en) >= 6:
                            break
        else:
            fam_en = mono_cat.format_code_label_en(allergen_code)
            candidates = [
                (len(c_info["label_en"]), c_id, c_info["label_en"])
                for c_id, c_info in self.concepts.items()
                if allergen_code in c_info["allergens"]
            ]
            candidates.sort()
            for _, c_id, lbl in candidates:
                t_en = mono_cat.format_clean_english_title(c_id, lbl)
                if t_en not in sib_en:
                    sib_en.append(t_en)
                if len(sib_en) >= 6:
                    break

        fam_final = fam_en or fallback_food_en
        rel_final = (
            ", ".join(sib_en)
            if sib_en
            else f"Ingredients and derivatives under {fam_final}"
        )
        return fam_final, rel_final

    def search_allergy_foods(self, query: str = "", lang: str = "en", limit: int = 12) -> dict:
        t0 = time.perf_counter()
        q = (query or "").strip()
        q_low = q.lower()
        limit = max(1, min(int(limit or 12), 30))

        items = []
        seen_curies = set()

        def _emoji_for_family(al_code: str, curie: str) -> str:
            if al_code == "milk":
                return "🧈" if curie == "FOODON:03310351" else ("🧀" if curie == "FOODON:03000287" else "🥛")
            if al_code == "peanuts":
                return "🥜"
            if al_code == "seafood":
                return "🦐"
            if al_code == "gluten":
                return "🍞"
            if al_code == "eggs":
                return "🥚"
            if al_code == "soy":
                return "🌱"
            if al_code == "tree_nuts":
                return "🌰"
            if al_code == "sesame":
                return "🌿"
            if al_code in ("curie:FOODON:00001006", "curie:FOODON:00001134", "curie:FOODON:00001038", "curie:FOODON:00001092"):
                return "🥩"
            if al_code in ("curie:FOODON:00001131", "curie:FOODON:00001040"):
                return "🍗"
            return "🍽️"

        def _make_item(curie: str, allergen_code: str) -> dict:
            seen_curies.add(curie)
            card = self._build_concept_card(curie) if curie in self.concepts else {}
            f_en = card.get("title_en") or curie
            fam_en, rel_en = self._get_dynamic_family_metadata(allergen_code, f_en)
            icon = _emoji_for_family(allergen_code, curie)
            exp_en = (
                f"Selecting \"{f_en}\" automatically links to \"{fam_en}\" via FoodOn Ontology. "
                f"Scanning labels containing: {rel_en} → Automatically triggers a RED Alert!"
            )
            return {
                "curie": curie,
                "allergen_code": allergen_code,
                "emoji": icon,
                "food_name": f_en,
                "food_name_vi": f_en,
                "food_name_en": f_en,
                "family_name": fam_en,
                "family_name_vi": fam_en,
                "family_name_en": fam_en,
                "related_ingredients": rel_en,
                "related_ingredients_vi": rel_en,
                "related_ingredients_en": rel_en,
                "explanation": exp_en,
                "explanation_vi": exp_en,
                "explanation_en": exp_en,
                "lineage_nodes": card.get("lineage_nodes", []),
            }

        if not q_low:
            default_pairs = [
                (curie, al_code)
                for al_code, curie in ALLERGEN_REPRESENTATIVE_CURIES.items()
            ] + [
                ("FOODON:00001006", "curie:FOODON:00001006"),
                ("FOODON:00001131", "curie:FOODON:00001131"),
            ]
            for curie, al_code in default_pairs:
                if curie in self.concepts and curie not in seen_curies:
                    items.append(_make_item(curie, al_code))
                    if len(items) >= limit:
                        break
        else:
            rec = self.recognize_ingredient(q)
            for m in rec.get("matches", []):
                c = m["curie"]
                if c in seen_curies or c not in self.concepts:
                    continue
                items.append(_make_item(c, self.infer_foodon_family(c)))
                if len(items) >= limit:
                    break

            if len(items) < limit:
                s_res = self.search_concepts(query=q, lang_scope="en", limit=24)
                for r in s_res.get("results", []):
                    c = r["curie"]
                    if c in seen_curies or c not in self.concepts:
                        continue
                    items.append(_make_item(c, self.infer_foodon_family(c)))
                    if len(items) >= limit:
                        break

        return {
            "query": q,
            "lang": "en",
            "count": len(items),
            "items": items,
            "latency_ms": round((time.perf_counter() - t0) * 1000, 2),
        }

    # -----------------------------------------------------------------------
    # Interactive FoodOn Ontology Graph Visualization API
    # -----------------------------------------------------------------------
    def _serialize_graph_node(
        self,
        curie: str,
        role: str = "node",
        depth: int = 0,
    ) -> dict:
        info = self.concepts[curie]
        return {
            "id": curie,
            "label": info["label_en"] or curie,
            "parent_id": info["parent_curie"] if info["parent_curie"] in self.concepts else "",
            "parent_label": info["parent_label_en"],
            "definition": info["definition_en"],
            "food_type": info["food_type"],
            "allergens": info["allergens"],
            "chronics": info["chronics"],
            "ecodes": [e.upper() for e in info["ecodes"]],
            "synonyms": self.curie_en_terms.get(curie, [])[:12],
            "child_count": len(self.children_map.get(curie, [])),
            "role": role,
            "depth": depth,
        }

    def _resolve_node_curie(self, ref: str) -> str:
        raw = (ref or "").strip()
        if not raw:
            return ""
        up = raw.upper()
        if up in self.concepts:
            return up
        if raw in self.concepts:
            return raw
        rec = self.recognize_ingredient(raw)
        if rec.get("matched") and rec.get("matches"):
            return rec["matches"][0]["curie"]
        srch = self.search_concepts(query=raw, lang_scope="all", limit=1)
        if srch.get("results"):
            return srch["results"][0]["curie"]
        return ""

    def get_graph_neighborhood(
        self,
        curie: str = "",
        ancestor_hops: int = 10,
        child_depth: int = 2,
        max_children: int = 24,
        include_siblings: bool = True,
        allergen: str = "",
    ) -> dict:
        t0 = time.perf_counter()
        ancestor_hops = max(1, min(int(ancestor_hops or 10), 20))
        child_depth = max(0, min(int(child_depth if child_depth is not None else 2), 3))
        max_children = max(1, min(int(max_children or 24), 80))
        allergen = (allergen or "").strip().lower()

        nodes_by_id: dict[str, dict] = {}
        edges_set: set[tuple[str, str]] = set()

        def add_node(cid: str, role: str, depth: int):
            if cid not in self.concepts:
                return
            if cid not in nodes_by_id:
                nodes_by_id[cid] = self._serialize_graph_node(cid, role=role, depth=depth)
            else:
                # Promote role priority: focus > ancestor > child > sibling > grandchild
                prio = {"focus": 5, "ancestor": 4, "child": 3, "sibling": 2, "grandchild": 1, "node": 0}
                if prio.get(role, 0) > prio.get(nodes_by_id[cid]["role"], 0):
                    nodes_by_id[cid]["role"] = role
                    nodes_by_id[cid]["depth"] = depth

        def add_edge(child_id: str, parent_id: str):
            if child_id in nodes_by_id and parent_id in nodes_by_id and child_id != parent_id:
                edges_set.add((child_id, parent_id))

        # Allergen / chronic domain showcase mode when allergen param given without explicit curie
        if allergen and not curie:
            roots = []
            if allergen in FOODON_ALLERGEN_ROOTS:
                roots = [c for c in FOODON_ALLERGEN_ROOTS[allergen]["include_roots"] if c in self.concepts]
            elif allergen in FOODON_CHRONIC_ROOTS:
                roots = [c for c in FOODON_CHRONIC_ROOTS[allergen] if c in self.concepts]
            focus_id = ALLERGEN_REPRESENTATIVE_CURIES.get(allergen) or (roots[0] if roots else "FOODON:00001002")
            if focus_id not in self.concepts:
                focus_id = "FOODON:00001002"
            add_node(focus_id, "focus", 0)
            for root_c in roots[:12]:
                add_node(root_c, "focus" if root_c == focus_id else "child", 0 if root_c == focus_id else 1)
                curr = root_c
                seen_up = {curr}
                for hop in range(1, 5):
                    p = self.concepts[curr]["parent_curie"]
                    if not p or p not in self.concepts or p in seen_up:
                        break
                    seen_up.add(p)
                    add_node(p, "ancestor", -hop)
                    add_edge(curr, p)
                    curr = p
                for ch in self.children_map.get(root_c, [])[: max(3, max_children // max(1, min(len(roots), 6)))]:
                    add_node(ch, "grandchild", 2)
                    add_edge(ch, root_c)
        else:
            focus_id = self._resolve_node_curie(curie) if curie else "FOODON:00001002"
            if focus_id not in self.concepts:
                return {
                    "success": False,
                    "message": f"FoodOn concept not found: {curie}",
                    "nodes": [],
                    "edges": [],
                }

            add_node(focus_id, "focus", 0)

            # 1. Walk ancestors up to root
            curr = focus_id
            seen_up = {curr}
            for hop in range(1, ancestor_hops + 1):
                p = self.concepts[curr]["parent_curie"]
                if not p or p not in self.concepts or p in seen_up:
                    break
                seen_up.add(p)
                add_node(p, "ancestor", -hop)
                add_edge(curr, p)
                curr = p

            # 2. Optional direct siblings (up to 6) for peer context
            direct_parent = self.concepts[focus_id]["parent_curie"]
            if include_siblings and direct_parent and direct_parent in self.concepts:
                sib_added = 0
                for sib in self.children_map.get(direct_parent, []):
                    if sib == focus_id or sib in nodes_by_id:
                        continue
                    add_node(sib, "sibling", 0)
                    add_edge(sib, direct_parent)
                    sib_added += 1
                    if sib_added >= 6:
                        break

            # 3. Walk descendants (BFS up to child_depth)
            if child_depth >= 1:
                lvl1 = self.children_map.get(focus_id, [])[:max_children]
                for ch in lvl1:
                    add_node(ch, "child", 1)
                    add_edge(ch, focus_id)

                if child_depth >= 2 and lvl1:
                    per_branch = max(2, min(6, max_children // max(1, min(len(lvl1), 8))))
                    gc_budget = max(20, max_children * 2)
                    gc_count = 0
                    for ch in lvl1:
                        if gc_count >= gc_budget:
                            break
                        for gc in self.children_map.get(ch, [])[:per_branch]:
                            add_node(gc, "grandchild", 2)
                            add_edge(gc, ch)
                            gc_count += 1
                            if gc_count >= gc_budget:
                                break

        # Ensure every internal parent edge between included nodes is also drawn
        for nid in list(nodes_by_id.keys()):
            pid = self.concepts[nid]["parent_curie"]
            if pid and pid in nodes_by_id and pid != nid:
                edges_set.add((nid, pid))

        lineage_chain = [
            {"id": n["curie"], "label": n["label_en"]}
            for n in reversed(self.get_lineage(focus_id, max_hops=12))
        ]
        all_children_preview = [
            {
                "id": ch,
                "label": self.concepts[ch]["label_en"],
                "child_count": len(self.children_map.get(ch, [])),
                "allergens": self.concepts[ch]["allergens"],
                "ecodes": [e.upper() for e in self.concepts[ch]["ecodes"]],
            }
            for ch in self.children_map.get(focus_id, [])[:40]
        ]

        edges = [
            {"source": src, "target": tgt, "relation": "subClassOf"}
            for src, tgt in sorted(edges_set)
        ]

        return {
            "success": True,
            "focus": nodes_by_id[focus_id],
            "lineage": lineage_chain,
            "children_preview": all_children_preview,
            "nodes": list(nodes_by_id.values()),
            "edges": edges,
            "latency_ms": round((time.perf_counter() - t0) * 1000, 2),
            "db_stats": {
                "total_concepts": len(self.concepts),
                "total_edges": sum(len(v) for v in self.children_map.values()),
                "total_en_terms": len(self.en_exact),
                "total_ecodes": len(self.ecode_map),
            },
        }

    def expand_graph_node(self, curie: str, limit: int = 24, offset: int = 0) -> dict:
        cid = self._resolve_node_curie(curie)
        if not cid or cid not in self.concepts:
            return {"success": False, "message": f"Concept not found: {curie}"}

        limit = max(1, min(int(limit or 24), 80))
        offset = max(0, int(offset or 0))
        all_ch = self.children_map.get(cid, [])
        slice_ch = all_ch[offset : offset + limit]

        nodes = [self._serialize_graph_node(cid, role="focus", depth=0)]
        edges = []

        parent_id = self.concepts[cid]["parent_curie"]
        if parent_id and parent_id in self.concepts and parent_id != cid:
            nodes.append(self._serialize_graph_node(parent_id, role="ancestor", depth=-1))
            edges.append({"source": cid, "target": parent_id, "relation": "subClassOf"})

        children_nodes = []
        for ch in slice_ch:
            n = self._serialize_graph_node(ch, role="child", depth=1)
            children_nodes.append(n)
            nodes.append(n)
            edges.append({"source": ch, "target": cid, "relation": "subClassOf"})

        return {
            "success": True,
            "node": nodes[0],
            "children": children_nodes,
            "nodes": nodes,
            "edges": edges,
            "total_children": len(all_ch),
            "offset": offset,
            "limit": limit,
            "has_more": (offset + len(slice_ch)) < len(all_ch),
        }

    def find_ontology_path(self, source_ref: str, target_ref: str) -> dict:
        t0 = time.perf_counter()
        a = self._resolve_node_curie(source_ref)
        b = self._resolve_node_curie(target_ref)
        if not a or a not in self.concepts:
            return {"success": False, "connected": False, "message": f"Start node not found: {source_ref}"}
        if not b or b not in self.concepts:
            return {"success": False, "connected": False, "message": f"Target node not found: {target_ref}"}

        def _ancestors_list(start: str) -> list[str]:
            chain = []
            curr = start
            seen = set()
            while curr and curr in self.concepts and curr not in seen:
                seen.add(curr)
                chain.append(curr)
                curr = self.concepts[curr]["parent_curie"]
            return chain

        chain_a = _ancestors_list(a)
        chain_b = _ancestors_list(b)
        idx_b = {cid: i for i, cid in enumerate(chain_b)}

        lca = ""
        path_a: list[str] = []
        path_b: list[str] = []
        for i, cid in enumerate(chain_a):
            if cid in idx_b:
                lca = cid
                path_a = chain_a[: i + 1]
                path_b = chain_b[: idx_b[cid]]
                break

        if not lca:
            return {
                "success": True,
                "connected": False,
                "from": self._serialize_graph_node(a, role="focus", depth=0),
                "to": self._serialize_graph_node(b, role="focus", depth=0),
                "lca_id": "",
                "path_nodes": [],
                "edges": [],
                "message": "No shared ancestor found in the FoodOn hierarchy between these two nodes.",
                "latency_ms": round((time.perf_counter() - t0) * 1000, 2),
            }

        ordered_ids = path_a + list(reversed(path_b))
        path_nodes = []
        for idx, cid in enumerate(ordered_ids):
            role = "focus" if cid in (a, b) else ("ancestor" if cid == lca else "child")
            path_nodes.append(self._serialize_graph_node(cid, role=role, depth=idx))

        edges = []
        # Upward edges from A -> LCA
        for i in range(len(path_a) - 1):
            edges.append({"source": path_a[i], "target": path_a[i + 1], "relation": "subClassOf"})
        # Upward edges from B -> LCA (all directed child -> parent!)
        b_to_lca = path_b + [lca]
        for i in range(len(b_to_lca) - 1):
            edges.append({"source": b_to_lca[i], "target": b_to_lca[i + 1], "relation": "subClassOf"})

        return {
            "success": True,
            "connected": True,
            "from": path_nodes[0],
            "to": path_nodes[-1],
            "lca_id": lca,
            "lca_label": self.concepts[lca]["label_en"],
            "hops": len(edges),
            "path_nodes": path_nodes,
            "edges": edges,
            "latency_ms": round((time.perf_counter() - t0) * 1000, 2),
        }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build or export the Pure-English Official FoodOn database.")
    parser.add_argument("--db", default=HYBRID_DB_PATH, help="Target SQLite path (default: data/nutriviet_hybrid.db)")
    parser.add_argument("--export-csv", default="", help="Optional CSV output path ready for Kaggle translation")
    parser.add_argument("--skip-build", action="store_true", help="Skip rebuilding DB when exporting CSV")
    args = parser.parse_args()

    if not args.skip_build:
        build_hybrid_database(db_path=args.db, verbose=True)
    if args.export_csv:
        exported = export_concepts_for_kaggle(args.export_csv, db_path=args.db)
        print(f"[EXPORT] Wrote {exported:,} FoodOn concepts to {args.export_csv}")
