"""
NutriViet OCR Text Normalization & Additive Extraction Engine
FG3 Deliverable (UC06, UC07, UC08) - Section E Implementation
Performer: Le Tat Nam | Reviewer: Nguyen Hoang Phuc Thinh
"""

import re
import unicodedata
from typing import List, Dict, Any, Tuple

# Comprehensive Standard Additive Dictionary (E-number / INS in Vietnam & Codex)
STANDARD_ADDITIVES = {
    # Emulsifiers, Stabilizers, Thickeners
    "E322": {"name": "Lecithin", "name_vi": "Lecithin (từ đậu nành/trứng)", "category": "Chất nhũ hóa", "category_en": "Emulsifier", "risk": "safe", "allergen_source": "soy/egg"},
    "E322i": {"name": "Lecithin", "name_vi": "Lecithin", "category": "Chất nhũ hóa", "category_en": "Emulsifier", "risk": "safe", "allergen_source": "soy/egg"},
    "E407": {"name": "Carrageenan", "name_vi": "Carrageenan", "category": "Chất làm dày / Ổn định", "category_en": "Thickener / Stabilizer", "risk": "safe"},
    "E412": {"name": "Guar gum", "name_vi": "Gôm guar", "category": "Chất làm dày / Ổn định", "category_en": "Thickener / Stabilizer", "risk": "safe"},
    "E415": {"name": "Xanthan gum", "name_vi": "Gôm xanthan", "category": "Chất làm dày / Ổn định", "category_en": "Thickener / Stabilizer", "risk": "safe"},
    "E420": {"name": "Sorbitol", "name_vi": "Sorbitol", "category": "Chất giữ ẩm / Tạo ngọt", "category_en": "Humectant / Sweetener", "risk": "safe"},
    "E440": {"name": "Pectin", "name_vi": "Pectin", "category": "Chất tạo gel / Làm dày", "category_en": "Gelling agent", "risk": "safe"},
    "E450": {"name": "Diphosphates", "name_vi": "Diphosphat", "category": "Chất tạo xốp / Giữ ẩm", "category_en": "Emulsifier / Raising agent", "risk": "safe"},
    "E451": {"name": "Triphosphates", "name_vi": "Triphosphat", "category": "Chất giữ ẩm / Ổn định", "category_en": "Sequestrant / Stabilizer", "risk": "safe"},
    "E451i": {"name": "Pentasodium triphosphate", "name_vi": "Pentanatri triphosphat", "category": "Chất ổn định / Giữ ẩm", "category_en": "Stabilizer", "risk": "safe"},
    "E452": {"name": "Polyphosphates", "name_vi": "Polyphosphat", "category": "Chất nhũ hóa / Giữ ẩm", "category_en": "Stabilizer / Emulsifier", "risk": "safe"},
    "E471": {"name": "Mono- and diglycerides of fatty acids", "name_vi": "Mono- và diglycerid của acid béo", "category": "Chất nhũ hóa", "category_en": "Emulsifier", "risk": "safe"},
    "E472e": {"name": "Diacetyl tartaric acid esters of mono- and diglycerides", "name_vi": "DATEM", "category": "Chất nhũ hóa", "category_en": "Emulsifier", "risk": "safe"},
    "E475": {"name": "Polyglycerol esters of fatty acids", "name_vi": "Este của polyglycerol với acid béo", "category": "Chất nhũ hóa", "category_en": "Emulsifier", "risk": "safe"},

    # Flavor Enhancers
    "E621": {"name": "Monosodium glutamate (MSG)", "name_vi": "Bột ngọt (Mononatri glutamat)", "category": "Chất điều vị", "category_en": "Flavor enhancer", "risk": "safe"},
    "E627": {"name": "Disodium guanylate", "name_vi": "Dinatri guanylat", "category": "Chất điều vị", "category_en": "Flavor enhancer", "risk": "safe"},
    "E631": {"name": "Disodium inosinate", "name_vi": "Dinatri inosinat", "category": "Chất điều vị", "category_en": "Flavor enhancer", "risk": "safe"},
    "E635": {"name": "Disodium 5'-ribonucleotides", "name_vi": "Dinatri 5'-ribonucleotid (I+G)", "category": "Chất điều vị", "category_en": "Flavor enhancer", "risk": "safe"},

    # Preservatives
    "E200": {"name": "Sorbic acid", "name_vi": "Acid sorbic", "category": "Chất bảo quản", "category_en": "Preservative", "risk": "safe"},
    "E202": {"name": "Potassium sorbate", "name_vi": "Kali sorbat", "category": "Chất bảo quản", "category_en": "Preservative", "risk": "safe"},
    "E211": {"name": "Sodium benzoate", "name_vi": "Natri benzoat", "category": "Chất bảo quản", "category_en": "Preservative", "risk": "safe"},
    "E220": {"name": "Sulfur dioxide", "name_vi": "Lưu huỳnh dioxid", "category": "Chất bảo quản / Sulfit", "category_en": "Preservative / Sulfite", "risk": "low", "allergen_source": "sulfites"},
    "E223": {"name": "Sodium metabisulfite", "name_vi": "Natri metabisulfit", "category": "Chất bảo quản / Sulfit", "category_en": "Preservative / Sulfite", "risk": "low", "allergen_source": "sulfites"},
    "E250": {"name": "Sodium nitrite", "name_vi": "Natri nitrit (Muối diêm)", "category": "Chất bảo quản / Giữ màu", "category_en": "Preservative / Color fixative", "risk": "low"},

    # Food Colors
    "E102": {"name": "Tartrazine", "name_vi": "Tartrazine (Vàng chanh)", "category": "Phẩm màu tổng hợp", "category_en": "Color (Yellow)", "risk": "low"},
    "E110": {"name": "Sunset Yellow FCF", "name_vi": "Vàng hoàng hôn FCF", "category": "Phẩm màu tổng hợp", "category_en": "Color (Sunset Yellow)", "risk": "low"},
    "E124": {"name": "Ponceau 4R", "name_vi": "Ponceau 4R (Đỏ tươi)", "category": "Phẩm màu tổng hợp", "category_en": "Color (Red)", "risk": "low"},
    "E129": {"name": "Allura Red AC", "name_vi": "Đỏ Allura AC", "category": "Phẩm màu tổng hợp", "category_en": "Color (Red)", "risk": "low"},
    "E133": {"name": "Brilliant Blue FCF", "name_vi": "Xanh Brilliant FCF", "category": "Phẩm màu tổng hợp", "category_en": "Color (Blue)", "risk": "safe"},
    "E150a": {"name": "Plain caramel", "name_vi": "Caramen nguyên chất", "category": "Phẩm màu tự nhiên", "category_en": "Color (Caramel I)", "risk": "safe"},
    "E150c": {"name": "Ammonia caramel", "name_vi": "Caramen amoni", "category": "Phẩm màu", "category_en": "Color (Caramel III)", "risk": "safe"},
    "E150d": {"name": "Sulfite ammonia caramel", "name_vi": "Caramen amoni sulfit (Caramel IV)", "category": "Phẩm màu", "category_en": "Color (Caramel IV)", "risk": "safe"},
    "E160a": {"name": "Beta-carotene", "name_vi": "Beta-caroten (Tiền vitamin A)", "category": "Phẩm màu tự nhiên", "category_en": "Color (Beta-carotene)", "risk": "safe"},
    "E171": {"name": "Titanium dioxide", "name_vi": "Titan dioxyd", "category": "Phẩm màu trắng", "category_en": "Color (White)", "risk": "low"},

    # Antioxidants & Acidity Regulators
    "E300": {"name": "Ascorbic acid", "name_vi": "Acid ascorbic (Vitamin C)", "category": "Chất chống oxy hóa", "category_en": "Antioxidant", "risk": "safe"},
    "E307": {"name": "Alpha-tocopherol", "name_vi": "Vitamin E (Tocopherol)", "category": "Chất chống oxy hóa", "category_en": "Antioxidant", "risk": "safe"},
    "E319": {"name": "Tert-butylhydroquinone (TBHQ)", "name_vi": "TBHQ", "category": "Chất chống oxy hóa", "category_en": "Antioxidant", "risk": "low"},
    "E320": {"name": "Butylated hydroxyanisole (BHA)", "name_vi": "BHA", "category": "Chất chống oxy hóa", "category_en": "Antioxidant", "risk": "low"},
    "E321": {"name": "Butylated hydroxytoluene (BHT)", "name_vi": "BHT", "category": "Chất chống oxy hóa", "category_en": "Antioxidant", "risk": "low"},
    "E330": {"name": "Citric acid", "name_vi": "Acid citric (Acid chanh)", "category": "Chất điều chỉnh độ acid", "category_en": "Acidity regulator", "risk": "safe"},
    "E338": {"name": "Phosphoric acid", "name_vi": "Acid phosphoric", "category": "Chất điều chỉnh độ acid", "category_en": "Acidity regulator", "risk": "safe"},
    "E500": {"name": "Sodium carbonates", "name_vi": "Natri carbonat / Natri hydro carbonat", "category": "Chất tạo xốp", "category_en": "Raising agent", "risk": "safe"},
    "E500ii": {"name": "Sodium hydrogen carbonate (Baking soda)", "name_vi": "Natri hydro carbonat (Baking soda)", "category": "Chất tạo xốp", "category_en": "Raising agent", "risk": "safe"},
    "E503": {"name": "Ammonium carbonates", "name_vi": "Amoni carbonat", "category": "Chất tạo xốp", "category_en": "Raising agent", "risk": "safe"},
    "E503ii": {"name": "Ammonium hydrogen carbonate", "name_vi": "Amoni hydro carbonat", "category": "Chất tạo xốp", "category_en": "Raising agent", "risk": "safe"},

    # Sweeteners
    "E950": {"name": "Acesulfame potassium", "name_vi": "Acesulfam K", "category": "Chất tạo ngọt tổng hợp", "category_en": "Artificial sweetener", "risk": "safe"},
    "E951": {"name": "Aspartame", "name_vi": "Aspartam", "category": "Chất tạo ngọt (Cảnh báo Phenylketonuria)", "category_en": "Artificial sweetener", "risk": "low"},
    "E955": {"name": "Sucralose", "name_vi": "Sucralose", "category": "Chất tạo ngọt tổng hợp", "category_en": "Artificial sweetener", "risk": "safe"},
    "E960": {"name": "Steviol glycosides", "name_vi": "Stevia (Chiết xuất cỏ ngọt)", "category": "Chất tạo ngọt tự nhiên", "category_en": "Natural sweetener", "risk": "safe"},
}

# Regex to strip packaging noise at the beginning (prefix headers)
PREFIX_PATTERN = re.compile(
    r"^(?:[\s\*\-\•\|#]*)"
    r"(?:thành\s*phần(?:\s*cấu\s*tạo)?|nguyên\s*liệu|ingredients|ingredient\s*list|composition|thành\s*phần\s*/\s*ingredients)"
    r"(?:\s*chính)?\s*[:\-\.=\)]*\s*",
    re.IGNORECASE | re.UNICODE
)

# Regex to strip packaging noise at the end (expiry, manufacturing, net weight, barcodes)
SUFFIX_PATTERN = re.compile(
    r"(?:\s*[\.\;\|\n]+\s*|\s+)"
    r"(?:(?:\b(?:nsx|hsd|hạn\s*dùng|ngày\s*sản\s*xuất|klt|khối\s*lượng\s*tịnh|net\s*wt|exp|mfg|best\s*before|use\s*by|lot|số\s*lô)\b[\s\S]*$)"
    r"|(?:\b(?:sản\s*xuất\s*(?:tại|bởi)|công\s*ty\s*(?:tnhh|cổ\s*phần)|xuất\s*xứ|chế\s*biến\s*tại|địa\s*chỉ|nhà\s*máy|hướng\s*dẫn\s*bảo\s*quản|bảo\s*quản\s*(?:nơi|ở)|chỉ\s*tiêu\s*chất\s*lượng)\b[\s\S]*$))",
    re.IGNORECASE | re.UNICODE
)

def clean_raw_ocr_text(raw_text: str) -> str:
    """
    Cleans raw OCR output from Google ML Kit:
    1. Standardizes Unicode into NFC form.
    2. Repairs hyphenated word wraps across lines (e.g. 'đậu-\nphộng' -> 'đậu phộng').
    3. Strips introductory packaging banners ('Thành phần: ...').
    4. Strips trailing manufacturing/expiry/weight noise.
    5. Cleans invalid OCR glitch characters (| ~ _ ` ^ etc.).
    """
    if not raw_text or not isinstance(raw_text, str):
        return ""

    # 1. Normalize Unicode to NFC
    text = unicodedata.normalize('NFC', raw_text.strip())

    # 2. Repair hyphenated linebreaks (packaging word/syllable splits)
    text = re.sub(r'(\w+)[\-\u2010\u2013]\s*[\r\n]+\s*(\w+)', r'\1 \2', text)

    # 3. Standardize whitespace & newlines (prevent duplicate commas if newline preceded by comma)
    text = re.sub(r'[,;]\s*[\r\n]+', ', ', text)
    text = re.sub(r'[\r\n]+', ', ', text)
    text = re.sub(r'[\t\f\v]+', ' ', text)

    # 4. Remove packaging header prefix
    text = PREFIX_PATTERN.sub('', text)

    # 5. Remove trailing packaging noise (HSD, NSX, KLT, Công ty...)
    text = SUFFIX_PATTERN.sub('', text)

    # 6. Remove OCR glitch symbols
    text = re.sub(r'[\|~_`\^•\*\#\«\»]+', ' ', text)

    # 7. Standardize multiple separators and spaces
    text = re.sub(r'\s*([,;])\s*', r'\1 ', text)
    text = re.sub(r'[,;]{2,}', ',', text)
    text = re.sub(r'\s{2,}', ' ', text)

    # 8. Clean leading/trailing punctuation
    text = text.strip(" ,;.-:\t\n")
    return text

def normalize_vietnamese_diacritics(text: str) -> str:
    """
    Standardizes Vietnamese diacritics and repair common typography variations:
    - Normalizes tone mark placements (e.g. 'oà' vs 'òa', 'uý' vs 'úy')
    - Standardizes quotes and dashes.
    """
    if not text:
        return ""
    
    text = unicodedata.normalize('NFC', text)

    # Standardize common packaging tone variations
    tone_map = {
        "oà": "òa", "oá": "óa", "oả": "ỏa", "oã": "õa", "oạ": "ọa",
        "oè": "òe", "oé": "óe", "oẻ": "ỏe", "oẽ": "õe", "oẹ": "ọe",
        "uỳ": "ùy", "uý": "úy", "uỷ": "ủy", "uỹ": "ũy", "uỵ": "ụy",
    }
    for old, new in tone_map.items():
        text = text.replace(old, new)
        text = text.replace(old.upper(), new.upper())

    # Replace typographical quotes and dashes
    text = text.replace('“', '"').replace('”', '"').replace('‘', "'").replace('’', "'")
    text = text.replace('–', '-').replace('—', '-')

    return text

def extract_e_numbers(text: str, lang: str = "vi") -> List[Dict[str, Any]]:
    """
    Scans text for European E-numbers and Codex INS additive codes.
    Returns structured additive objects enriched with functional classification.
    """
    if not text:
        return []

    results = []
    seen_codes = set()

    # Match patterns: E322, E322i, INS 471, INS471, E-322, mã số quốc tế 621, etc.
    patterns = [
        r'\b[Ee][-\s]?(\d{3,4}[a-zA-Z]?)\b',
        r'\b(?:INS|ins)[-\s]?(\d{3,4}[a-zA-Z]?)\b',
        r'\bmã\s*số\s*quốc\s*tế\s*[:\s]*(\d{3,4}[a-zA-Z]?)\b',
    ]

    for pat in patterns:
        for match in re.finditer(pat, text, re.IGNORECASE):
            raw_match = match.group(0).strip()
            num_suffix = match.group(1).strip()
            standard_code = f"E{num_suffix.upper()}"
            base_code = f"E{re.sub(r'[a-zA-Z]+$', '', num_suffix)}"

            if standard_code in seen_codes:
                continue
            seen_codes.add(standard_code)

            # Lookup catalog info
            info = STANDARD_ADDITIVES.get(standard_code) or STANDARD_ADDITIVES.get(base_code)
            if info:
                name = info.get("name_vi" if lang == "vi" else "name")
                category = info.get("category" if lang == "vi" else "category_en")
                risk = info.get("risk", "safe")
                allergen_src = info.get("allergen_source", "")
            else:
                name = f"Phụ gia thực phẩm {standard_code}" if lang == "vi" else f"Food additive {standard_code}"
                category = "Phụ gia thực phẩm" if lang == "vi" else "Food additive"
                risk = "safe"
                allergen_src = ""

            results.append({
                "code": raw_match,
                "standard_code": standard_code,
                "name": name,
                "category": category,
                "risk": risk,
                "allergen_source": allergen_src
            })

    return results

def tokenize_ingredients(cleaned_text: str) -> List[str]:
    """
    Segments cleaned ingredient text into structured tokens.
    Handles parenthetical ingredient lists (e.g., 'Chất nhũ hóa (E322i, INS 471)').
    """
    if not cleaned_text:
        return []

    tokens = []
    current_token = []
    paren_depth = 0

    # Character-by-character scan to preserve parentheses
    for char in cleaned_text:
        if char == '(':
            paren_depth += 1
            current_token.append(char)
        elif char == ')':
            if paren_depth > 0:
                paren_depth -= 1
            current_token.append(char)
        elif char in (',', ';', '\n') and paren_depth == 0:
            token_str = "".join(current_token).strip(" .:,;-\t\n")
            if token_str:
                tokens.append(token_str)
            current_token = []
        else:
            current_token.append(char)

    # Add last token
    last_str = "".join(current_token).strip(" .:,;-\t\n")
    if last_str:
        tokens.append(last_str)

    # Filter out empty or trivially short tokens
    final_tokens = []
    for t in tokens:
        cleaned_t = re.sub(r'\s+', ' ', t).strip()
        if len(cleaned_t) >= 2:
            final_tokens.append(cleaned_t)

    return final_tokens

def normalize_ocr_payload(raw_text: str, lang: str = "vi") -> Dict[str, Any]:
    """
    Orchestrates complete OCR normalization pipeline (UC06, UC07):
    - Cleans raw input text.
    - Normalizes Vietnamese diacritics.
    - Extracts food additive E-numbers and INS codes.
    - Segments into ingredient tokens.
    """
    cleaned = clean_raw_ocr_text(raw_text)
    normalized = normalize_vietnamese_diacritics(cleaned)
    tokens = tokenize_ingredients(normalized)
    additives = extract_e_numbers(normalized, lang=lang)

    return {
        "success": True,
        "raw_text": raw_text,
        "cleaned_text": cleaned,
        "normalized_text": normalized,
        "tokens": tokens,
        "extracted_e_numbers": additives,
        "token_count": len(tokens),
        "additive_count": len(additives)
    }
