"""
Pure-English Official FoodOn Card Formatter for NutriViet Backend
=================================================================
Formats official FoodOn ontology concepts (`label_en`, `definition_en`,
lineage, E-codes, allergen/chronic tags) strictly from `nutriviet_hybrid.db`.

Zero hardcoded Vietnamese translation tables and zero fallback dictionaries.
"""

import re


def format_clean_english_title(curie: str, label_en: str, primary_code: str = "") -> str:
    raw = (label_en or curie).replace("/", " / ").strip()
    raw = re.sub(r"\s*\(ec\)\s*", "", raw, flags=re.IGNORECASE)
    if not raw:
        return curie
    words = raw.split(" ")
    out = []
    acronyms = {
        "FCF", "AC", "BN", "PN", "FK", "HT", "BK", "DC",
        "PVA", "TBHQ", "EDTA", "IMP", "MSG", "II", "III", "IV",
    }
    minor = {"of", "and", "or", "in", "with", "from", "to", "for"}
    for w in words:
        if not w:
            continue
        if w.lower() in minor and out:
            out.append(w.lower())
        elif w.upper() in acronyms:
            out.append(w.upper())
        else:
            out.append(w[0].upper() + w[1:])
    return " ".join(out)


def format_code_label_en(code: str) -> str:
    clean = (code or "").strip()
    if clean.startswith("curie:"):
        return clean.split("curie:", 1)[1].strip()
    return clean.replace("_", " ").title() if clean else ""


def build_monolingual_card_fields(
    curie: str,
    label_en: str,
    vi_terms: list[str],
    en_terms: list[str],
    lineage_nodes: list[dict],
    allergens: list[str],
    chronics: list[str],
    ecodes: list[str],
    risk_level: str,
    primary_code: str = "",
    definition_en: str = "",
    preferred_vi_term: str = "",
) -> dict:
    """
    Produces pure English FoodOn card fields from official ontology metadata.
    `title_vi` / `description_vi` mirror the English FoodOn fields so API
    consumers remain schema-compatible with zero hardcoded Vietnamese fallback.
    """
    code_up = (primary_code or (ecodes[0] if ecodes else "")).upper()
    title_en = format_clean_english_title(curie, label_en, code_up)

    enriched_lineage = []
    for idx, node in enumerate(lineage_nodes):
        n_curie = node.get("curie", "")
        n_en = node.get("label_en", "")
        disp_en = title_en if idx == 0 else format_clean_english_title(n_curie, n_en)
        enriched_lineage.append({
            **node,
            "label_vi": disp_en,
            "display_label_vi": disp_en,
            "display_label_en": disp_en,
        })

    desc_parts = []
    clean_def = (definition_en or "").strip()
    if clean_def:
        desc_parts.append(clean_def if clean_def.endswith(".") else f"{clean_def}.")

    parent_en_names = [
        n["display_label_en"]
        for n in enriched_lineage[1:3]
        if n.get("display_label_en") and n["display_label_en"].lower() != title_en.lower()
    ]
    if parent_en_names:
        desc_parts.append(f"Ontology classification: {' → '.join(parent_en_names)}.")

    if allergens:
        al_en = [format_code_label_en(a) for a in allergens]
        desc_parts.append(f"Allergen group: {', '.join(al_en)}.")
    if chronics:
        ch_en = [format_code_label_en(c) for c in chronics]
        desc_parts.append(f"Health advisory: {', '.join(ch_en)}.")

    description_en = " ".join(desc_parts)
    clean_en = [
        format_clean_english_title("", t)
        for t in (en_terms or [label_en])[:8]
        if t
    ]

    return {
        "title_vi": title_en,
        "title_en": title_en,
        "description_vi": description_en,
        "description_en": description_en,
        "clean_vi_terms": [],
        "clean_en_terms": clean_en,
        "enriched_lineage": enriched_lineage,
    }
