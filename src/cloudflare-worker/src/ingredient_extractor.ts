import { removeAccents } from "./foodon";

export interface IngredientExtractionResult {
  has_ingredients: boolean;
  ingredients_text: string;
  matched_header: string | null;
  fuzzy_score: number;
  nutrition_detected: boolean;
  reason: "OK" | "EMPTY_OCR" | "NO_INGREDIENTS_FOUND";
}

// Canonical Vietnamese & English headers that OPEN the Ingredients section.
// Note: "thanh phan dinh duong" is intentionally EXCLUDED here and placed in
// NUTRITION_STOP_HEADERS so Nutrition Facts tables are never mistaken for ingredients!
const INGREDIENT_START_HEADERS = [
  "thanh phan",
  "thanh phan chinh",
  "thanh phan cau tao",
  "thanh phan nguyen lieu",
  "thanh phan san pham",
  "nguyen lieu",
  "ingredients",
  "ingredient",
  "ingredient list",
  "ingredients list",
  "main ingredients",
  "composition",
];

// Canonical Nutrition Facts headers (STOP collecting and flag nutrition_detected=true).
const NUTRITION_STOP_HEADERS = [
  "thanh phan dinh duong",
  "gia tri dinh duong",
  "thong tin dinh duong",
  "bang dinh duong",
  "bang thong tin dinh duong",
  "chi tieu chat luong",
  "chi tieu chat luong chu yeu",
  "gia tri trung binh",
  "dinh duong",
  "nutrition facts",
  "nutritional facts",
  "nutrition information",
  "nutritional information",
  "nutrition declaration",
  "nutritional values",
  "nutrition value",
  "typical values",
  "supplement facts",
  "amount per serving",
  "serving size",
  "khau phan",
  "per 100g",
  "per 100ml",
  "trong 100g",
  "trong 100ml",
  "tren 100g",
  "tren 100ml",
];

// Non-ingredient packaging sections that terminate the ingredient block.
const GENERAL_STOP_HEADERS = [
  "huong dan su dung",
  "huong dan pha che",
  "huong dan che bien",
  "cach su dung",
  "cach dung",
  "cach pha",
  "directions",
  "directions for use",
  "how to use",
  "preparation",
  "instructions",
  "huong dan bao quan",
  "bao quan",
  "storage",
  "storage instructions",
  "khoi luong tinh",
  "the tich thuc",
  "net weight",
  "net wt",
  "net volume",
  "ngay san xuat",
  "han su dung",
  "nsx",
  "hsd",
  "best before",
  "use by",
  "expiry date",
  "xuat xu",
  "san xuat tai",
  "san xuat boi",
  "don vi san xuat",
  "nha san xuat",
  "thuong nhan",
  "chiu trach nhiem",
  "phan phoi boi",
  "nhap khau",
  "manufactured by",
  "produced by",
  "distributed by",
  "imported by",
  "product of",
  "made in",
  "dia chi",
  "hotline",
  "website",
  "tong dai",
  "luu y",
  "chu y",
];

// Allergen advisory lines directly tied to ingredients — KEEP these!
const ALLERGEN_KEEP_HEADERS = [
  "thong tin di ung",
  "canh bao di ung",
  "thong tin canh bao di ung",
  "canh bao chat gay di ung",
  "thong tin chat gay di ung",
  "co chua",
  "co the chua",
  "chua",
  "allergen",
  "allergens",
  "allergen information",
  "allergy advice",
  "allergy information",
  "contains",
  "may contain",
];

// Nutrient row names used to detect table-style Nutrition Facts rows without a header.
const NUTRIENT_ROW_PREFIXES = [
  "nang luong",
  "energy",
  "calories",
  "calo",
  "chat dam",
  "protein",
  "dam",
  "carbohydrate",
  "carbohydrates",
  "carb",
  "carbs",
  "chat bot duong",
  "hydrat cacbon",
  "duong tong so",
  "total sugars",
  "added sugars",
  "sugars",
  "chat beo",
  "chat beo tong",
  "chat beo bao hoa",
  "chat beo chuyen hoa",
  "total fat",
  "saturated fat",
  "trans fat",
  "fat",
  "cholesterol",
  "natri",
  "sodium",
  "chat xo",
  "dietary fiber",
  "fiber",
  "fibre",
  "canxi",
  "calcium",
  "iron",
  "sat",
  "potassium",
  "kali",
  "vitamin",
];

/**
 * Normalizes OCR text for fuzzy header comparison:
 * - Strips Vietnamese diacritics
 * - Repairs frequent PaddleOCR visual homoglyphs (1/l/I, 0/O, 5/S, rn/m, vv/w)
 */
export function normalizeOcrHeader(input: string): string {
  const folded = removeAccents((input || "").toLowerCase())
    .replace(/rn/g, "m")
    .replace(/vv/g, "w")
    .replace(/[1|!]/g, "i")
    .replace(/0/g, "o")
    .replace(/5/g, "s")
    .replace(/8/g, "b")
    .replace(/@/g, "a")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return folded;
}

/**
 * Standard Levenshtein edit distance with early length-bound pruning.
 */
export function levenshteinDistance(a: string, b: string): number {
  if (a === b) return 0;
  const m = a.length;
  const n = b.length;
  if (m === 0) return n;
  if (n === 0) return m;

  let prev = new Uint16Array(n + 1);
  let curr = new Uint16Array(n + 1);
  for (let j = 0; j <= n; j++) prev[j] = j;

  for (let i = 1; i <= m; i++) {
    curr[0] = i;
    const ca = a.charCodeAt(i - 1);
    for (let j = 1; j <= n; j++) {
      const cost = ca === b.charCodeAt(j - 1) ? 0 : 1;
      const del = prev[j] + 1;
      const ins = curr[j - 1] + 1;
      const sub = prev[j - 1] + cost;
      curr[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    const tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

export function fuzzyHeaderSimilarity(candidate: string, target: string): number {
  const a = normalizeOcrHeader(candidate);
  const b = normalizeOcrHeader(target);
  if (!a || !b) return 0;
  if (a === b) return 1.0;
  const maxLen = Math.max(a.length, b.length);
  if (Math.abs(a.length - b.length) > Math.max(4, Math.ceil(maxLen * 0.38))) {
    return 0;
  }
  const dist = levenshteinDistance(a, b);
  return 1 - dist / maxLen;
}

function bestHeaderMatch(
  candidate: string,
  targets: string[],
  minScore: number
): { target: string; score: number } | null {
  const norm = normalizeOcrHeader(candidate);
  if (norm.length < 3) return null;
  let bestTarget = "";
  let bestScore = 0;
  for (const t of targets) {
    // Guard short acronyms (nsx, hsd) against fuzzy false positives
    const effectiveMin = t.length <= 4 ? 1.0 : minScore;
    const sim = fuzzyHeaderSimilarity(norm, t);
    if (sim >= effectiveMin && sim > bestScore) {
      bestScore = sim;
      bestTarget = t;
    }
  }
  return bestScore > 0 ? { target: bestTarget, score: bestScore } : null;
}

/**
 * Detects whether a raw line is a Nutrition Facts measurement row, e.g.:
 * "Energy, 120 kcal", "Năng lượng 450 kJ / 108 kcal", "Protein 4.2 g 8%", "Total Fat: 12g"
 */
export function isNutritionMetricRow(line: string): boolean {
  const raw = (line || "").trim();
  if (!raw) return false;
  const hasUnit = /\b\d+(?:[.,]\d+)?\s*(?:kcal|kj|mg|mcg|µg|ug|g|ml|%dv|%\s*dv)\b/i.test(raw);
  const hasTrailingPct = /\b\d+(?:[.,]\d+)?\s*%$/i.test(raw);
  if (!hasUnit && !hasTrailingPct) return false;

  // Extract leading words before first digit or colon/comma
  const leadRaw = raw.split(/[\d:,\(\/]/, 1)[0]?.trim() || "";
  if (!leadRaw) return false;
  const leadNorm = normalizeOcrHeader(leadRaw);
  if (!leadNorm) return false;

  // Reject real ingredients like "Sữa bột 6%", "Bột mì (48%), đường"
  const commaCount = (raw.match(/,/g) || []).length;
  if (commaCount >= 3 && !/\b(?:kcal|kj|mg|mcg|%dv)\b/i.test(raw)) {
    return false;
  }

  for (const pref of NUTRIENT_ROW_PREFIXES) {
    if (leadNorm === pref || leadNorm.startsWith(pref + " ")) return true;
    if (pref.length >= 6 && fuzzyHeaderSimilarity(leadNorm, pref) >= 0.78) return true;
  }
  return false;
}

interface StartMatch {
  headerText: string;
  canonical: string;
  score: number;
  restOfLine: string;
}

/**
 * Returns true if any 1-to-4-word span of `text` fuzzy-matches a Nutrition Facts
 * indicator ("dinh duong", "thanh phan dinh duong", "nutrition", "nutritional").
 * This guarantees "Thành phần dinh dưỡng (trong 100ml)" is NEVER mistaken for "Thành phần".
 */
function containsNutritionIndicator(text: string): boolean {
  const norm = normalizeOcrHeader(text);
  if (!norm) return false;
  const words = norm.split(" ").filter(Boolean);
  for (let i = 0; i < words.length; i++) {
    if (words[i].length >= 6 && fuzzyHeaderSimilarity(words[i], "nutrition") >= 0.76) {
      return true;
    }
    if (words[i].length >= 8 && fuzzyHeaderSimilarity(words[i], "nutritional") >= 0.76) {
      return true;
    }
    if (i + 1 < words.length) {
      const bi = `${words[i]} ${words[i + 1]}`;
      if (fuzzyHeaderSimilarity(bi, "dinh duong") >= 0.78) return true;
      if (fuzzyHeaderSimilarity(bi, "nutrition facts") >= 0.78) return true;
      if (fuzzyHeaderSimilarity(bi, "serving size") >= 0.82) return true;
      if (fuzzyHeaderSimilarity(bi, "khau phan") >= 0.86) return true;
    }
  }
  return false;
}

function isStrongerNutritionHeader(candidate: string, ingredientScore: number): boolean {
  if (containsNutritionIndicator(candidate)) return true;
  const nutHit = bestHeaderMatch(candidate, NUTRITION_STOP_HEADERS, 0.78);
  if (!nutHit) return false;
  return nutHit.score >= ingredientScore;
}

/**
 * Inspects a line for a fuzzy-matched Ingredients / Thành phần header (at line start,
 * bilingual like "Thành phần (Ingredients):", or embedded after another clause).
 */
function detectIngredientStartOnLine(line: string): StartMatch | null {
  const trimmed = line.trim();
  if (!trimmed) return null;

  // 1. Explicit colon OR spaced-dash separator on the line:
  //    "Header: rest..." or "Header - rest..." or "THÀNH PHẦN (INGREDIENTS): rest..."
  const sepMatch = trimmed.match(/^([^:]{3,65}?)\s*(?:[:：]|[-–—]\s+)\s*(.*)$/);
  if (sepMatch) {
    const rawHeader = sepMatch[1].trim();
    const rest = sepMatch[2].trim();

    if (containsNutritionIndicator(rawHeader)) {
      return null;
    }

    // Split bilingual slash/parenthesis header e.g. "Thành phần / Ingredients" or "Thành phần (Ingredients)"
    const headerParts = [
      rawHeader,
      ...rawHeader
        .split(/[\/|()\[\]]+/)
        .map((p) => p.trim())
        .filter((p) => p.length >= 4),
    ];

    const rawNut = bestHeaderMatch(rawHeader, NUTRITION_STOP_HEADERS, 0.78);
    let bestHit: { target: string; score: number } | null = null;
    for (const part of headerParts) {
      const hit = bestHeaderMatch(part, INGREDIENT_START_HEADERS, 0.73);
      if (hit && !isStrongerNutritionHeader(part, hit.score)) {
        if (!bestHit || hit.score > bestHit.score) bestHit = hit;
      }
    }
    if (bestHit && (!rawNut || bestHit.score > rawNut.score)) {
      return {
        headerText: rawHeader,
        canonical: bestHit.target,
        score: bestHit.score,
        restOfLine: rest,
      };
    }
    if (rawNut) return null;
  }

  // 2. Standalone header line (no colon, no ingredient list commas),
  //    e.g. "THÀNH PHẦN" or "INGRED1ENTS" or "Thành phần / Ingredients"
  if (trimmed.length <= 55 && !trimmed.includes(",")) {
    if (containsNutritionIndicator(trimmed)) {
      return null;
    }
    const rawNut = bestHeaderMatch(trimmed, NUTRITION_STOP_HEADERS, 0.78);
    const headerParts = [
      trimmed,
      ...trimmed
        .split(/[\/|()\[\]]+/)
        .map((p) => p.trim())
        .filter((p) => p.length >= 4),
    ];
    let bestHit: { target: string; score: number } | null = null;
    for (const part of headerParts) {
      const hit = bestHeaderMatch(part, INGREDIENT_START_HEADERS, 0.74);
      if (hit && !isStrongerNutritionHeader(part, hit.score)) {
        if (!bestHit || hit.score > bestHit.score) bestHit = hit;
      }
    }
    if (bestHit && (!rawNut || bestHit.score > rawNut.score)) {
      return {
        headerText: trimmed,
        canonical: bestHit.target,
        score: bestHit.score,
        restOfLine: "",
      };
    }
    if (rawNut) return null;
  }

  // 3. Space-separated leading header without colon:
  //    e.g. "Thành phần Nước, đường, sữa bột" or "Ingredients Wheat flour, sugar"
  const words = trimmed.split(/\s+/);
  for (const n of [4, 3, 2, 1]) {
    if (words.length <= n) continue;
    const prefix = words.slice(0, n).join(" ").replace(/[:.\-–—]+$/, "").trim();
    if (prefix.length < 7) continue;

    const leadWindow = words.slice(0, Math.min(words.length, n + 2)).join(" ").replace(/[:.\-–—]+$/, "");
    if (containsNutritionIndicator(leadWindow)) {
      return null;
    }

    const hit = bestHeaderMatch(prefix, INGREDIENT_START_HEADERS, 0.78);
    if (
      hit &&
      !isStrongerNutritionHeader(prefix, hit.score) &&
      !bestHeaderMatch(leadWindow, NUTRITION_STOP_HEADERS, 0.8)
    ) {
      const rest = words.slice(n).join(" ").replace(/^[\s:\-–—.]+/, "").trim();
      if (rest.length >= 3) {
        return {
          headerText: prefix,
          canonical: hit.target,
          score: hit.score,
          restOfLine: rest,
        };
      }
    }
  }

  // 4. Embedded mid-line header after a sentence/separator:
  // e.g. "Khối lượng tịnh 50g. Thành phần: Bột mì, đường..."
  const embeddedRe = /(?:^|[.;|\n])\s*([^:.;|\n]{4,45}?)\s*[:：]\s*(.+)$/;
  const emb = trimmed.match(embeddedRe);
  if (emb) {
    const rawHeader = emb[1].trim();
    const rest = emb[2].trim();
    if (!containsNutritionIndicator(rawHeader)) {
      const hit = bestHeaderMatch(rawHeader, INGREDIENT_START_HEADERS, 0.75);
      if (hit && !isStrongerNutritionHeader(rawHeader, hit.score)) {
        return {
          headerText: rawHeader,
          canonical: hit.target,
          score: hit.score,
          restOfLine: rest,
        };
      }
    }
  }

  return null;
}

function classifyStopHeader(line: string): "nutrition" | "general" | "allergen" | null {
  const trimmed = line.trim();
  if (!trimmed) return null;

  const sepMatch = trimmed.match(/^([^:]{2,55}?)\s*[:：]/);
  const candidates: string[] = [];
  if (sepMatch) {
    candidates.push(sepMatch[1].trim());
  }
  if (trimmed.length <= 55) {
    candidates.push(trimmed);
  }
  // Also inspect leading 2-4 words for un-coloned section titles
  const words = trimmed.split(/\s+/);
  for (const n of [4, 3, 2]) {
    if (words.length >= n) {
      candidates.push(words.slice(0, n).join(" ").replace(/[:.\-–—]+$/, ""));
    }
  }

  // Check Allergen advisory FIRST so "Thông tin dị ứng" is KEPT (not confused with "Thông tin dinh dưỡng")
  for (const cand of candidates) {
    if (bestHeaderMatch(cand, ALLERGEN_KEEP_HEADERS, 0.78)) {
      return "allergen";
    }
  }

  // Check Nutrition Facts headers (must outscore ingredient start headers so typos like "Thàh phẩn" aren't confused with "Khẩu phần")
  if (trimmed.length <= 70 && containsNutritionIndicator(trimmed)) {
    return "nutrition";
  }
  for (const cand of candidates) {
    const nutHit = bestHeaderMatch(cand, NUTRITION_STOP_HEADERS, 0.78);
    if (nutHit) {
      const ingHit = bestHeaderMatch(cand, INGREDIENT_START_HEADERS, 0.74);
      if (!ingHit || nutHit.score >= ingHit.score) {
        return "nutrition";
      }
    }
  }

  // Check general non-ingredient sections (Storage, Usage, Origin, Net weight, Expiry)
  for (const cand of candidates) {
    const isShortLine = trimmed.length <= 65 || Boolean(sepMatch);
    if (isShortLine && bestHeaderMatch(cand, GENERAL_STOP_HEADERS, 0.78)) {
      return "general";
    }
  }

  if (isNutritionMetricRow(trimmed)) {
    return "nutrition";
  }

  return null;
}

/**
 * Strips any inline trailing stop section that PaddleOCR merged onto the same line
 * as the ingredient list, e.g.:
 * "Bột mì, đường, sữa bột. Hướng dẫn bảo quản: Nơi khô ráo. Giá trị dinh dưỡng: Năng lượng 450 kcal"
 */
function trimInlineStopClause(text: string): { cleaned: string; hitStop: boolean; hitNutrition: boolean } {
  // Split on sentence boundaries followed by a header-with-colon
  const re = /([.;|]\s*)([^:.;|]{3,45}?)\s*[:：]/g;
  let match: RegExpExecArray | null;
  while ((match = re.exec(text)) !== null) {
    const headerCand = match[2].trim();
    if (bestHeaderMatch(headerCand, ALLERGEN_KEEP_HEADERS, 0.78)) {
      continue;
    }
    if (bestHeaderMatch(headerCand, NUTRITION_STOP_HEADERS, 0.74)) {
      return {
        cleaned: text.slice(0, match.index).replace(/[.;,\s]+$/, "").trim(),
        hitStop: true,
        hitNutrition: true,
      };
    }
    if (bestHeaderMatch(headerCand, GENERAL_STOP_HEADERS, 0.78)) {
      return {
        cleaned: text.slice(0, match.index).replace(/[.;,\s]+$/, "").trim(),
        hitStop: true,
        hitNutrition: false,
      };
    }
  }
  return { cleaned: text.trim(), hitStop: false, hitNutrition: false };
}

/**
 * Strictly extracts ONLY the Ingredients / Thành phần section from cleaned OCR text
 * using fuzzy OCR-tolerant header matching, ignoring Nutrition Facts tables & other
 * packaging metadata. If no Ingredients / Thành phần section is present, returns
 * `has_ingredients: false` with empty `ingredients_text`.
 */
export function extractIngredientsSection(cleanedOcrText: string): IngredientExtractionResult {
  const raw = (cleanedOcrText || "").trim();
  if (!raw) {
    return {
      has_ingredients: false,
      ingredients_text: "",
      matched_header: null,
      fuzzy_score: 0,
      nutrition_detected: false,
      reason: "EMPTY_OCR",
    };
  }

  const lines = raw
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);

  let nutritionDetected = false;
  let startIndex = -1;
  let startMatch: StartMatch | null = null;

  // Scan all lines to detect both Nutrition presence AND the best Ingredients header
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const stopKind = classifyStopHeader(line);
    if (stopKind === "nutrition") {
      nutritionDetected = true;
    }

    if (startIndex === -1) {
      const hit = detectIngredientStartOnLine(line);
      if (hit) {
        startIndex = i;
        startMatch = hit;
      }
    }
  }

  if (startIndex === -1 || !startMatch) {
    return {
      has_ingredients: false,
      ingredients_text: "",
      matched_header: null,
      fuzzy_score: 0,
      nutrition_detected: nutritionDetected,
      reason: "NO_INGREDIENTS_FOUND",
    };
  }

  const collected: string[] = [];
  if (startMatch.restOfLine) {
    const trimmed = trimInlineStopClause(startMatch.restOfLine);
    if (trimmed.hitNutrition) nutritionDetected = true;
    if (trimmed.cleaned) collected.push(trimmed.cleaned);
    if (trimmed.hitStop) {
      const finalText = collected.join(" ").trim();
      return {
        has_ingredients: finalText.length > 0,
        ingredients_text: finalText,
        matched_header: startMatch.headerText,
        fuzzy_score: Math.round(startMatch.score * 1000) / 1000,
        nutrition_detected: nutritionDetected,
        reason: finalText.length > 0 ? "OK" : "NO_INGREDIENTS_FOUND",
      };
    }
  }

  for (let i = startIndex + 1; i < lines.length; i++) {
    const line = lines[i];
    const stopKind = classifyStopHeader(line);
    if (stopKind === "nutrition") {
      nutritionDetected = true;
      break;
    }
    if (stopKind === "general") {
      break;
    }
    // Another ingredient header (e.g. English translation right below Vietnamese): keep collecting!
    const nestedStart = detectIngredientStartOnLine(line);
    if (nestedStart) {
      if (nestedStart.restOfLine) {
        const trimmed = trimInlineStopClause(nestedStart.restOfLine);
        if (trimmed.hitNutrition) nutritionDetected = true;
        if (trimmed.cleaned) collected.push(trimmed.cleaned);
        if (trimmed.hitStop) break;
      }
      continue;
    }

    const trimmed = trimInlineStopClause(line);
    if (trimmed.hitNutrition) nutritionDetected = true;
    if (trimmed.cleaned) collected.push(trimmed.cleaned);
    if (trimmed.hitStop) break;
  }

  const finalText = collected
    .join("\n")
    .replace(/\n{2,}/g, "\n")
    .trim();

  if (!finalText) {
    return {
      has_ingredients: false,
      ingredients_text: "",
      matched_header: startMatch.headerText,
      fuzzy_score: Math.round(startMatch.score * 1000) / 1000,
      nutrition_detected: nutritionDetected,
      reason: "NO_INGREDIENTS_FOUND",
    };
  }

  return {
    has_ingredients: true,
    ingredients_text: finalText,
    matched_header: startMatch.headerText,
    fuzzy_score: Math.round(startMatch.score * 1000) / 1000,
    nutrition_detected: nutritionDetected,
    reason: "OK",
  };
}
