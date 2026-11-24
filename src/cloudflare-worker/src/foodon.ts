import type { FoodOnConceptRow } from "./types";

// Official FoodOn Ontology Root Anchors (matching hybrid_ontology.py)
export const FOODON_ALLERGEN_ROOTS: Record<string, string[]> = {
  peanuts: ["FOODON:00003206", "FOODON:00002099", "FOODON:03411270", "NCBITaxon:3818", "FOODON:03510218"],
  soy: ["FOODON:03301415", "FOODON:00002266", "FOODON:03411452", "NCBITaxon:3847", "FOODON:03510219"],
  milk: [
    "FOODON:00001256", "FOODON:02010012", "FOODON:03315150", "FOODON:00001257",
    "FOODON:00001771", "FOODON:03420180", "CHEBI:17716", "FOODON:03542650", "FOODON:03510220",
  ],
  eggs: [
    "FOODON:02010002", "FOODON:00001274", "FOODON:00001105", "FOODON:03420194",
    "UBERON:0008944", "UBERON:0007378", "CHEBI:166964", "FOODON:00001234", "FOODON:03510216",
  ],
  seafood: [
    "FOODON:03411433", "FOODON:03411374", "FOODON:03412112", "FOODON:00005704",
    "FOODON:00005702", "FOODON:00002581", "FOODON:03411021", "FOODON:00001248",
    "FOODON:03411365", "FOODON:00005506", "FOODON:00001293", "FOODON:03510215",
    "FOODON:03510217", "FOODON:03510232",
  ],
  gluten: [
    "FOODON:03420177", "FOODON:00001907", "CHEBI:166887", "FOODON:00001141",
    "FOODON:03411312", "NCBITaxon:4564", "FOODON:00001138", "FOODON:03411598",
    "NCBITaxon:4513", "FOODON:00005788", "FOODON:00001222", "FOODON:03411599",
    "NCBITaxon:4550", "FOODON:00001189", "FOODON:00003429", "FOODON:03411414",
    "NCBITaxon:4498", "FOODON:03544161", "FOODON:03510214",
  ],
  tree_nuts: [
    "FOODON:00001172", "FOODON:03411213", "FOODON:00005735", "FOODON:00003523",
    "FOODON:00001587", "FOODON:00002338", "FOODON:03301364", "FOODON:03411221",
    "FOODON:00001746", "FOODON:00003615", "FOODON:00001925", "FOODON:00002933",
    "FOODON:03411273", "FOODON:00002116", "FOODON:00003691", "FOODON:03411420",
    "FOODON:00002016", "FOODON:00003003", "FOODON:03411357", "NCBITaxon:4329",
    "FOODON:00002096", "FOODON:00001718", "FOODON:03510221",
  ],
  sesame: ["FOODON:00002232", "FOODON:03411226", "FOODON:03310306", "NCBITaxon:4182", "FOODON:03510224"],
};

export const FOODON_CHRONIC_ROOTS: Record<string, string[]> = {
  diabetes: [
    "FOODON:00002300", "FOODON:00001083", "FOODON:03420108", "FOODON:03303225",
    "CHEBI:17992", "CHEBI:17234", "CHEBI:15824", "CHEBI:17306",
  ],
  hypertension: [
    "FOODON:00002215", "FOODON:03309954", "CHEBI:24866", "CHEBI:26710",
    "CHEBI:38700", "CHEBI:26708", "CHEBI:64220",
  ],
  gout: ["CHEBI:64220", "CHEBI:26385", "FOODON:03411433", "FOODON:00001258"],
  cholesterol: [
    "FOODON:00001040", "FOODON:02010033", "FOODON:03302051", "CHEBI:16113",
    "CHEBI:26607", "FOODON:03310232", "FOODON:03301829", "FOODON:03411286",
  ],
};

export const ALLERGEN_REPRESENTATIVE_CURIES: Record<string, string> = {
  milk: "FOODON:03310351",
  peanuts: "FOODON:00003206",
  seafood: "FOODON:03411237",
  eggs: "FOODON:02010002",
  soy: "FOODON:03301415",
  gluten: "FOODON:03420177",
  tree_nuts: "FOODON:00003523",
  sesame: "FOODON:03310306",
};

const STOPWORDS = new Set([
  "and", "or", "of", "in", "with", "from", "the", "a", "an", "to", "for",
  "contains", "contain", "may", "less", "than", "ingredients", "ingredient",
  "natural", "artificial", "added", "pure", "refined", "raw", "fresh", "dried",
  "extract", "powder", "oil", "protein", "acid", "water", "flavor", "flavour",
  "color", "colour", "emulsifier", "stabilizer", "thickener", "preservative",
  "antioxidant", "sweetener", "acidity", "regulator", "enhancer", "agent",
]);

const GENERIC_ROOTS = new Set([
  "FOODON:00001002", "FOODON:00002403", "FOODON:00001714", "FOODON:00001015",
  "FOODON:00004242", "FOODON:00004328", "FOODON:03420116", "FOODON:03420164",
  "FOODON:00002196", "FOODON:00002131", "FOODON:03311737",
]);

const ACRONYMS = new Set([
  "FCF", "AC", "BN", "PN", "FK", "HT", "BK", "DC", "PVA", "TBHQ", "EDTA", "IMP", "MSG", "II", "III", "IV",
]);
const MINOR_WORDS = new Set(["of", "and", "or", "in", "with", "from", "to", "for"]);

export function removeAccents(input: string): string {
  return input
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

export function normalizeEnKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[_\-/]+/g, " ")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function formatCleanEnglishTitle(curie: string, labelEn: string): string {
  const raw = (labelEn || curie).replace(/\//g, " / ").replace(/\s*\(ec\)\s*/gi, "").trim();
  if (!raw) return curie;
  const words = raw.split(" ").filter(Boolean);
  const out: string[] = [];
  for (const w of words) {
    if (MINOR_WORDS.has(w.toLowerCase()) && out.length > 0) {
      out.push(w.toLowerCase());
    } else if (ACRONYMS.has(w.toUpperCase())) {
      out.push(w.toUpperCase());
    } else {
      out.push(w[0].toUpperCase() + w.slice(1));
    }
  }
  return out.join(" ");
}

export function formatCodeLabelEn(code: string): string {
  const clean = (code || "").trim();
  if (clean.startsWith("curie:")) return clean.slice(6).trim();
  if (!clean) return "";
  return clean
    .replace(/_/g, " ")
    .split(" ")
    .filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1).toLowerCase())
    .join(" ");
}

function splitCsv(v: string | null | undefined): string[] {
  if (!v) return [];
  return v.split(",").map((s) => s.trim()).filter(Boolean);
}

const VIETNAMESE_SPECIFIC_DIACRITIC_RE = /[\u0102\u0103\u0110\u0111\u01A0\u01A1\u01AF\u01B0\u1EA0-\u1EF9]/;

export function hasVietnameseDiacritics(input: string): boolean {
  return VIETNAMESE_SPECIFIC_DIACRITIC_RE.test(input || "");
}

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
    const ac = a.charCodeAt(i - 1);
    for (let j = 1; j <= n; j++) {
      const cost = ac === b.charCodeAt(j - 1) ? 0 : 1;
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

export function similarityRatio(a: string, b: string): number {
  if (a === b) return 1.0;
  if (!a || !b) return 0.0;
  const maxLen = Math.max(a.length, b.length);
  return Math.max(0, 1 - levenshteinDistance(a, b) / maxLen);
}

function sortEcodeTuple(ec: string): [number, number, string, string] {
  const m = ec.toLowerCase().match(/^(?:e|ins)(\d+)([a-z]?)(.*)$/);
  if (m) return [0, parseInt(m[1], 10), m[2] || "", m[3] || ""];
  return [1, 999999, ec, ""];
}

function compareEcodes(a: string, b: string): number {
  const ta = sortEcodeTuple(a);
  const tb = sortEcodeTuple(b);
  if (ta[0] !== tb[0]) return ta[0] - tb[0];
  if (ta[1] !== tb[1]) return ta[1] - tb[1];
  if (ta[2] !== tb[2]) return ta[2].localeCompare(tb[2]);
  return ta[3].localeCompare(tb[3]);
}

export function repairOcrEcodes(text: string): string {
  // Repair frequent PaddleOCR digit/letter confusions inside E-numbers / INS codes:
  // e.g. "E62l" -> "E621", "E1O2" -> "E102", "IN5 322(I)" -> "INS322(i)"
  return (text || "").replace(
    /\b(e|ins|in5)\s*([0-9oOlIiS]{3,4})([a-z]?)(?:\(([ivx1lI]+)\))?(?![A-Za-z0-9])/gi,
    (_, p, digits, suf, roman) => {
      const cleanPrefix = String(p).toLowerCase() === "in5" ? "INS" : String(p).toUpperCase();
      const cleanDigits = String(digits)
        .replace(/[oO]/g, "0")
        .replace(/[lIi]/g, "1")
        .replace(/S/g, "5");
      if (!/^\d{3,4}$/.test(cleanDigits)) return _;
      const cleanRoman = roman ? `(${String(roman).replace(/[1l]/g, "i").toLowerCase()})` : "";
      return `${cleanPrefix}${cleanDigits}${suf || ""}${cleanRoman}`;
    }
  );
}

export function repairOcrWordHomoglyphs(text: string): string {
  // Repair visual OCR homoglyphs inside alphabetic ingredient words (e.g. "rnilk" -> "milk", "s0y" -> "soy")
  return (text || "")
    .replace(/\b(?=[a-z0-9]*[a-z])[a-z0-9]+\b/gi, (word) => {
      // Leave E-codes / INS codes untouched
      if (/^(?:e|ins)\d{3,4}/i.test(word)) return word;
      return word
        .replace(/rn/gi, "m")
        .replace(/0/g, "o")
        .replace(/5/g, "s")
        .replace(/1/g, "l");
    });
}

const ADDITIVE_FUNCTIONAL_CLASS_RE =
  /(?:emulsifier|stabiliz(?:er|ing)|thickener|preservative|antioxidant|sweetener|acidity\s+regulator|flavour?\s+enhancer|flavor\s+enhancer|colou?r(?:ing)?|raising\s+agent|leavening|anti-?caking|glazing\s+agent|humectant|sequestrant|firming\s+agent|foaming\s+agent|gelling\s+agent|bulking\s+agent|propellant|flour\s+treatment|additive|chat\s+on\s+dinh|chat\s+nhu\s+hoa|chat\s+dieu\s+vi|chat\s+dieu\s+chinh\s+do\s+acid|chat\s+bao\s+quan|chat\s+chong\s+oxy\s+hoa|chat\s+tao\s+xop|chat\s+lam\s+day|chat\s+tao\s+ngot|chat\s+tao\s+mau|pham\s+mau|chat\s+chong\s+dong\s+von|chat\s+lam\s+bong|chat\s+giu\s+am|phu\s+gia)s?\s*\(((?:[^()]|\([ivx1lI]+\))+)\)/gi;

const CODE_LIST_PAREN_RE =
  /\(((?:(?:e|ins|in5)\s*)?[0-9oOlIiS]{3,4}[a-z]?(?:\([ivx1lI]+\))?(?:\s*[,;/]\s*(?:(?:e|ins|in5)\s*)?[0-9oOlIiS]{3,4}[a-z]?(?:\([ivx1lI]+\))?)+)\)/gi;

const TRACE_CLAUSE_RE =
  /\b(?:may\s+contain|traces?\s+of|trace\s+amounts?|processed\s+in\s+a\s+facility|manufactured\s+(?:in\s+a\s+facility|on\s+(?:shared\s+)?equipment)|shared\s+(?:equipment|lines?|facility)|cross[- ]?contact|cross[- ]?contamination|produced\s+on\s+a\s+line|co\s+the\s+chua|co\s+chua\s+vet|dau\s+vet|vet\s+cua|san\s+xuat\s+tren\s+(?:cung\s+)?day\s+chuyen|day\s+chuyen\s+co\s+su\s+dung|cung\s+day\s+chuyen|nha\s+may\s+co\s+su\s+dung|che\s+bien\s+cung\s+thiet\s+bi)\b/i;

const DIRECT_ALLERGEN_WORDS: Record<string, string[]> = {
  milk: ["milk", "dairy", "butter", "cheese", "cream", "yogurt", "yoghurt", "buttermilk"],
  peanuts: ["peanut", "groundnut", "arachis"],
  soy: ["soy", "soya", "soybean"],
  eggs: ["egg"],
  seafood: [
    "fish", "seafood", "shrimp", "prawn", "crab", "lobster", "shellfish", "squid",
    "octopus", "clam", "oyster", "mussel", "scallop", "salmon", "tuna", "mackerel",
    "sardine", "anchovy", "cod", "tilapia", "catfish", "hake", "pollock", "krill",
  ],
  gluten: ["gluten", "wheat", "barley", "rye", "oat", "flour"],
  tree_nuts: [
    "nut", "almond", "walnut", "cashew", "hazelnut", "pecan", "pistachio",
    "macadamia", "chestnut", "pine nut", "brazil nut",
  ],
  sesame: ["sesame"],
};

export interface EvaluationOptions {
  scanDerivatives?: boolean;
  warnTraces?: boolean;
}

export function isTraceStatement(token: string): boolean {
  const folded = removeAccents((token || "").toLowerCase()).replace(/\s+/g, " ").trim();
  if (!folded) return false;
  return TRACE_CLAUSE_RE.test(folded);
}

export function isDirectAllergenMatch(
  allergenCode: string,
  token: string,
  primaryMatch: Record<string, unknown>
): boolean {
  const normTok = normalizeEnKey(repairOcrWordHomoglyphs(token));
  const words = DIRECT_ALLERGEN_WORDS[allergenCode];
  if (words && words.length > 0) {
    for (const w of words) {
      const re = new RegExp(`\\b${w.replace(/\s+/g, "\\s+")}s?\\b`, "i");
      if (re.test(normTok)) return true;
    }
  }
  const mType = String(primaryMatch.match_type ?? "");
  if (mType === "ecode_exact" || mType === "ecode_bare") {
    return false;
  }
  const curie = String(primaryMatch.curie ?? "");
  if (curie.startsWith("CHEBI:") || curie.startsWith("UBERON:")) {
    return false;
  }
  const repCurie = ALLERGEN_REPRESENTATIVE_CURIES[allergenCode];
  if (repCurie && curie === repCurie) return true;
  if (words && words.length > 0) {
    const labelNorm = normalizeEnKey(String(primaryMatch.label_en ?? primaryMatch.title_en ?? ""));
    for (const w of words) {
      const re = new RegExp(`\\b${w.replace(/\s+/g, "\\s+")}s?\\b`, "i");
      if (re.test(labelNorm)) return true;
    }
  }
  return false;
}

export function extractBareAdditiveCodes(token: string): Array<{ raw: string; cands: string[] }> {
  const folded = removeAccents(token || "");
  const out: Array<{ raw: string; cands: string[] }> = [];
  const seen = new Set<string>();

  for (const m of folded.matchAll(ADDITIVE_FUNCTIONAL_CLASS_RE)) {
    const inner = (m[1] || "").trim();
    if (!inner) continue;
    const rawItems = inner.split(/[,;/]+/).map((s) => s.trim()).filter(Boolean);
    const pieces: string[] = [];
    for (const item of rawItems) {
      if (/%|\b(?:g|mg|ml|kg|kcal|kj)\b/i.test(item)) continue;
      const subParts = item.split(/\s+/).filter(Boolean);
      if (subParts.length > 1 && !/^(?:e|ins|in5)$/i.test(subParts[0])) {
        pieces.push(...subParts);
      } else {
        pieces.push(item);
      }
    }
    for (const piece of pieces) {
      let cleanDigits = "";
      let suf = "";
      let roman = "";
      const direct = piece.match(/^(?:(?:e|ins|in5)\s*)?(\d{3,4})([a-z]?)(?:\(([ivx1lI]+)\))?$/i);
      if (direct) {
        cleanDigits = direct[1];
        suf = (direct[2] || "").toLowerCase();
        roman = direct[3] ? direct[3].replace(/[1l]/g, "i").toLowerCase() : "";
      } else {
        const fuzzy = piece.match(/^(?:(?:e|ins|in5)\s*)?([0-9oOlIS]{3,4})([a-z]?)(?:\(([ivx1lI]+)\))?$/i);
        if (!fuzzy) continue;
        cleanDigits = fuzzy[1]
          .replace(/[oO]/g, "0")
          .replace(/[lI]/g, "1")
          .replace(/S/g, "5");
        suf = (fuzzy[2] || "").toLowerCase();
        roman = fuzzy[3] ? fuzzy[3].replace(/[1l]/g, "i").toLowerCase() : "";
      }
      if (!/^\d{3,4}$/.test(cleanDigits)) continue;
      const numVal = parseInt(cleanDigits, 10);
      // Codex Alimentarius INS / EU E-numbers lie strictly within 100..1599
      if (numVal < 100 || numVal > 1599) continue;
      const key = `${cleanDigits}${suf}${roman ? `(${roman})` : ""}`;
      if (seen.has(key)) continue;
      seen.add(key);

      const cands: string[] = [];
      if (roman) {
        cands.push(
          `e${cleanDigits}(${roman})`,
          `ins${cleanDigits}(${roman})`,
          `e${cleanDigits}${roman}`,
          `ins${cleanDigits}${roman}`
        );
      } else if (suf) {
        cands.push(
          `e${cleanDigits}${suf}`,
          `ins${cleanDigits}${suf}`,
          `e${cleanDigits}(${suf})`,
          `ins${cleanDigits}(${suf})`
        );
      }
      cands.push(`e${cleanDigits}`, `ins${cleanDigits}`);
      out.push({
        raw: `E${cleanDigits}${suf}${roman ? `(${roman})` : ""}`,
        cands: [...new Set(cands)],
      });
    }
  }
  return out;
}

export function splitRawIngredients(rawText: string): string[] {
  const cleaned = (rawText || "").replace(/^(?:thành phần|ingredients)\s*[:\-]\s*/i, "");
  const tokens: string[] = [];
  const placeholderPrefix = "__NV_CL_";
  const traceStartRe =
    /\b(?:may\s+contain|traces?\s+of|processed\s+in\s+a\s+facility|manufactured\s+(?:in\s+a\s+facility|on\s+(?:shared\s+)?equipment)|có\s+thể\s+chứa|dấu\s+vết|sản\s+xuất\s+trên\s+(?:cùng\s+)?dây\s+chuyền)\b/i;

  for (const rawLine of cleaned.split(/\n+/)) {
    const line = rawLine.trim();
    if (!line) continue;

    // Separate a single trailing trace clause on the line (e.g. "Wheat flour, sugar. May contain traces of peanuts, soy.")
    const traceMatch = traceStartRe.exec(line);
    const segments: string[] = [];
    if (traceMatch && traceMatch.index > 0) {
      segments.push(line.slice(0, traceMatch.index).trim());
      segments.push(line.slice(traceMatch.index).trim());
    } else {
      segments.push(line);
    }

    for (const seg of segments) {
      if (!seg) continue;
      if (isTraceStatement(seg) && seg.length <= 180) {
        const cleanSeg = seg.replace(/^[\s.,;:-]+|[\s.]+$/g, "").trim();
        if (cleanSeg) tokens.push(cleanSeg);
        continue;
      }
      // Protect parenthesized additive code lists like "(471, 460i, 407, 466)" from comma splitting
      const saved: string[] = [];
      const protectedSeg = seg.replace(CODE_LIST_PAREN_RE, (match) => {
        const idx = saved.push(match) - 1;
        return `${placeholderPrefix}${idx}__`;
      });
      for (const part of protectedSeg.split(/[,;]+/)) {
        const restored = part
          .replace(/__NV_CL_(\d+)__/g, (_, i) => saved[Number(i)] ?? "")
          .replace(/^[\s.]+|[\s.]+$/g, "");
        if (restored) tokens.push(restored);
      }
    }
  }
  return tokens;
}

/**
 * Request-scoped D1-backed FoodOn Ontology Engine.
 * Zero full-table scans, zero hardcoded Vietnamese fallbacks, 100% pure English FoodOn.
 */
export class D1FoodOnEngine {
  private conceptCache = new Map<string, FoodOnConceptRow | null>();
  private synCache = new Map<string, string[]>();

  constructor(private readonly db: D1Database) {}

  async getConceptsBatch(curies: string[]): Promise<Map<string, FoodOnConceptRow>> {
    const missing: string[] = [];
    for (const c of curies) {
      if (c && !this.conceptCache.has(c)) {
        missing.push(c);
        this.conceptCache.set(c, null);
      }
    }
    const uniqueMissing = [...new Set(missing)];
    for (let i = 0; i < uniqueMissing.length; i += 80) {
      const chunk = uniqueMissing.slice(i, i + 80);
      const ph = chunk.map(() => "?").join(",");
      const res = await this.db
        .prepare(`SELECT * FROM foodon_concepts WHERE curie IN (${ph})`)
        .bind(...chunk)
        .all<FoodOnConceptRow>();
      for (const row of res.results) {
        this.conceptCache.set(row.curie, row);
      }
    }
    const out = new Map<string, FoodOnConceptRow>();
    for (const c of curies) {
      const hit = this.conceptCache.get(c);
      if (hit) out.set(c, hit);
    }
    return out;
  }

  async getConcept(curie: string): Promise<FoodOnConceptRow | null> {
    if (!curie) return null;
    if (this.conceptCache.has(curie)) return this.conceptCache.get(curie) ?? null;
    const row = await this.db
      .prepare("SELECT * FROM foodon_concepts WHERE curie = ?")
      .bind(curie)
      .first<FoodOnConceptRow>();
    this.conceptCache.set(curie, row ?? null);
    return row ?? null;
  }

  async getSynonymsBatch(curies: string[], limitPerCurie = 12): Promise<Map<string, string[]>> {
    const missing = [...new Set(curies.filter((c) => c && !this.synCache.has(c)))];
    for (const c of missing) this.synCache.set(c, []);
    for (let i = 0; i < missing.length; i += 60) {
      const chunk = missing.slice(i, i + 60);
      const ph = chunk.map(() => "?").join(",");
      const res = await this.db
        .prepare(
          `SELECT curie, term_norm FROM lexical_bridge WHERE curie IN (${ph}) ORDER BY confidence_tier ASC, term_norm ASC`
        )
        .bind(...chunk)
        .all<{ curie: string; term_norm: string }>();
      for (const row of res.results) {
        const list = this.synCache.get(row.curie)!;
        if (list.length < limitPerCurie && !list.includes(row.term_norm)) {
          list.push(row.term_norm);
        }
      }
    }
    const out = new Map<string, string[]>();
    for (const c of curies) out.set(c, this.synCache.get(c) ?? []);
    return out;
  }

  async getLineage(curie: string, maxHops = 4): Promise<Array<{ curie: string; label_en: string; label_vi: string; terms_vi: string[] }>> {
    const chain: Array<{ curie: string; label_en: string; label_vi: string; terms_vi: string[] }> = [];
    const seen = new Set<string>();
    let curr = curie;
    for (let hop = 0; hop <= maxHops; hop++) {
      if (!curr || seen.has(curr)) break;
      const info = await this.getConcept(curr);
      if (!info) break;
      seen.add(curr);
      chain.push({
        curie: info.curie,
        label_en: info.label_en,
        label_vi: info.label_en,
        terms_vi: [],
      });
      curr = info.parent_curie;
    }
    return chain;
  }

  formatLineageString(chain: Array<{ curie: string; label_en: string }>): string {
    return chain.map((n) => `${n.curie} (${n.label_en})`).join(" -> ");
  }

  async classifyConceptRisk(curie: string): Promise<{ risk_level: string; risk_label_vi: string; risk_label_en: string }> {
    const info = await this.getConcept(curie);
    if (!info) return { risk_level: "low", risk_label_vi: "Low risk", risk_label_en: "Low risk" };

    const ft = info.food_type || "";
    const par = info.parent_curie || "";
    const als = splitCsv(info.allergen_codes);
    const chs = splitCsv(info.chronic_codes);
    const lblLow = (info.label_en || "").toLowerCase();
    const lineage = await this.getLineage(curie, 4);
    const lineageSet = new Set(lineage.map((n) => n.curie));

    if (als.length === 0 && chs.length === 0) {
      const isVit =
        lineageSet.has("CHEBI:176838") ||
        lineageSet.has("CHEBI:30527") ||
        lineageSet.has("CHEBI:33229") ||
        lblLow.includes("vitamin") ||
        (ft.includes("nutrient") &&
          !["CHEBI:26195", "CHEBI:38700", "CHEBI:22723", "FOODON:03412972"].includes(par));
      if (isVit) return { risk_level: "safe", risk_label_vi: "Safe", risk_label_en: "Safe" };
    }

    if (
      als.length > 0 ||
      chs.length > 0 ||
      (ft.includes("chemical") && !ft.includes("nutrient")) ||
      ["FOODON:03412972", "CHEBI:38700", "CHEBI:26513", "CHEBI:50860", "CHEBI:35286", "CHEBI:22723"].includes(par)
    ) {
      return { risk_level: "high", risk_label_vi: "High risk", risk_label_en: "High risk" };
    }

    return { risk_level: "low", risk_label_vi: "Low risk", risk_label_en: "Low risk" };
  }

  async buildConceptCard(curie: string, primaryCode = ""): Promise<Record<string, unknown>> {
    const info = await this.getConcept(curie);
    if (!info) return { code: primaryCode || curie, curie, title: curie, title_en: curie, title_vi: curie };
    const synsMap = await this.getSynonymsBatch([curie], 8);
    const enTerms = synsMap.get(curie) ?? [];
    const lineageNodes = await this.getLineage(curie, 4);
    const risk = await this.classifyConceptRisk(curie);

    const als = splitCsv(info.allergen_codes);
    const chs = splitCsv(info.chronic_codes);
    const ecs = splitCsv(info.ecodes);
    const codeBadge = (primaryCode || ecs[0] || curie).toUpperCase();
    const titleEn = formatCleanEnglishTitle(curie, info.label_en);

    const enrichedLineage = lineageNodes.map((node, idx) => {
      const disp = idx === 0 ? titleEn : formatCleanEnglishTitle(node.curie, node.label_en);
      return { ...node, label_vi: disp, display_label_vi: disp, display_label_en: disp };
    });

    const descParts: string[] = [];
    const cleanDef = (info.definition_en || "").trim();
    if (cleanDef) descParts.push(cleanDef.endsWith(".") ? cleanDef : `${cleanDef}.`);
    const parentNames = enrichedLineage
      .slice(1, 3)
      .map((n) => n.display_label_en)
      .filter((n) => n && n.toLowerCase() !== titleEn.toLowerCase());
    if (parentNames.length > 0) {
      descParts.push(`Ontology classification: ${parentNames.join(" → ")}.`);
    }
    if (als.length > 0) descParts.push(`Allergen group: ${als.map(formatCodeLabelEn).join(", ")}.`);
    if (chs.length > 0) descParts.push(`Health advisory: ${chs.map(formatCodeLabelEn).join(", ")}.`);
    const descEn = descParts.join(" ");

    const cleanEn = (enTerms.length ? enTerms : [info.label_en])
      .slice(0, 8)
      .filter(Boolean)
      .map((t) => formatCleanEnglishTitle("", t));

    return {
      code: codeBadge,
      curie,
      title: titleEn,
      title_vi: titleEn,
      title_en: titleEn,
      label_en: titleEn,
      label_vi: titleEn,
      definition_en: info.definition_en,
      terms_vi: [],
      terms_en: cleanEn,
      description: descEn,
      description_vi: descEn,
      description_en: descEn,
      food_type: info.food_type,
      allergens: als,
      chronics: chs,
      ecodes: ecs.map((e) => e.toUpperCase()),
      risk_level: risk.risk_level,
      risk_label: risk.risk_label_en,
      risk_label_vi: risk.risk_label_en,
      risk_label_en: risk.risk_label_en,
      lineage: this.formatLineageString(lineageNodes),
      lineage_nodes: enrichedLineage,
    };
  }

  private async lookupExactLex(normKey: string): Promise<{ curie: string; matchType: string; confidence: number } | null> {
    if (!normKey) return null;
    const candidates = [normKey];
    if (normKey.endsWith("s") && normKey.length > 4) candidates.push(normKey.slice(0, -1));
    if (normKey.endsWith("es") && normKey.length > 5) candidates.push(normKey.slice(0, -2));

    const ph = candidates.map(() => "?").join(",");
    const res = await this.db
      .prepare(`SELECT term_norm, curie, confidence_tier FROM lexical_bridge WHERE term_norm IN (${ph}) ORDER BY confidence_tier ASC`)
      .bind(...candidates)
      .all<{ term_norm: string; curie: string; confidence_tier: number }>();

    if (res.results.length === 0) return null;
    const exact = res.results.find((r) => r.term_norm === normKey);
    if (exact) return { curie: exact.curie, matchType: "exact_en", confidence: 1.0 };
    return { curie: res.results[0].curie, matchType: "exact_en_singular", confidence: 0.98 };
  }

  private async lookupAsciiOrFuzzy(rawToken: string, threshold = 0.82): Promise<{ curie: string; term: string; matchType: string; confidence: number } | null> {
    // Keep FoodOn strictly pure English: skip fuzzy English matching on Vietnamese-diacritic tokens
    if (hasVietnameseDiacritics(rawToken)) return null;
    const repaired = repairOcrWordHomoglyphs(rawToken);
    const tNorm = normalizeEnKey(repaired);
    const tAscii = removeAccents(tNorm);
    if (tAscii.length < 3) return null;

    const exactAscii = await this.db
      .prepare("SELECT term_norm, lang, curie, confidence_tier FROM lexical_bridge WHERE term_ascii = ? ORDER BY confidence_tier ASC LIMIT 10")
      .bind(tAscii)
      .all<{ term_norm: string; lang: string; curie: string; confidence_tier: number }>();
    if (exactAscii.results.length > 0) {
      let best = exactAscii.results[0];
      let bestScore = -1;
      for (const c of exactAscii.results) {
        const s = 0.6 * similarityRatio(tNorm, c.term_norm) + 0.4 - (c.confidence_tier - 1) * 0.03;
        if (s > bestScore) {
          bestScore = s;
          best = c;
        }
      }
      return {
        curie: best.curie,
        term: best.term_norm,
        matchType: "ascii_fold_match",
        confidence: Math.round(Math.min(bestScore, 0.99) * 1000) / 1000,
      };
    }

    // Require >= 5 chars for Levenshtein fuzzy search to prevent short non-English false positives
    if (tAscii.length < 5) return null;
    const tokenWordCount = tAscii.split(" ").filter(Boolean).length;
    const maxEdits = tAscii.length <= 7 ? 1 : 2;
    const minSim = tAscii.length === 5 ? 0.8 : Math.max(threshold, 0.82);

    const scoreRows = (
      rows: Array<{ term_norm: string; term_ascii: string; lang: string; curie: string; confidence_tier: number }>
    ) => {
      let bestMatch: { curie: string; term: string; matchType: string; confidence: number } | null = null;
      let bestSim = minSim;
      for (const c of rows) {
        if (Math.abs(c.term_ascii.length - tAscii.length) > maxEdits) continue;
        if (c.term_ascii.split(" ").filter(Boolean).length !== tokenWordCount) continue;
        const distAscii = levenshteinDistance(tAscii, c.term_ascii);
        if (distAscii > maxEdits) continue;
        const simAscii = 1 - distAscii / Math.max(tAscii.length, c.term_ascii.length);
        if (simAscii < minSim) continue;
        const simAcc = similarityRatio(tNorm, c.term_norm);
        const weighted = 0.6 * simAcc + 0.4 * simAscii;
        const effective = weighted - (c.confidence_tier - 1) * 0.02;
        if (effective >= bestSim) {
          bestSim = effective;
          bestMatch = {
            curie: c.curie,
            term: c.term_norm,
            matchType: `fuzzy_${c.lang}`,
            confidence: Math.round(weighted * 1000) / 1000,
          };
        }
      }
      return bestMatch;
    };

    // Indexed 3-char prefix candidate lookup for OCR typos (avoids scanning 53k rows)
    const prefix3 = tAscii.slice(0, 3);
    const cand3 = await this.db
      .prepare("SELECT term_norm, term_ascii, lang, curie, confidence_tier FROM lexical_bridge WHERE term_ascii >= ? AND term_ascii < ? LIMIT 80")
      .bind(prefix3, prefix3.slice(0, 2) + String.fromCharCode(prefix3.charCodeAt(2) + 1))
      .all<{ term_norm: string; term_ascii: string; lang: string; curie: string; confidence_tier: number }>();

    const hit3 = scoreRows(cand3.results);
    if (hit3) return hit3;

    // Indexed 2-char prefix fallback when PaddleOCR corrupts char #2 or #3 (e.g. "pcanut", "whcat")
    const prefix2 = tAscii.slice(0, 2);
    const minLen = Math.max(4, tAscii.length - maxEdits);
    const maxLen = tAscii.length + maxEdits;
    const cand2 = await this.db
      .prepare(
        "SELECT term_norm, term_ascii, lang, curie, confidence_tier FROM lexical_bridge WHERE term_ascii >= ? AND term_ascii < ? AND LENGTH(term_ascii) BETWEEN ? AND ? LIMIT 100"
      )
      .bind(prefix2, prefix2.slice(0, 1) + String.fromCharCode(prefix2.charCodeAt(1) + 1), minLen, maxLen)
      .all<{ term_norm: string; term_ascii: string; lang: string; curie: string; confidence_tier: number }>();
    return scoreRows(cand2.results);
  }

  async recognizeIngredient(rawToken: string): Promise<Record<string, unknown>> {
    const cleanToken = (rawToken || "").replace(/\s+/g, " ").trim();
    if (!cleanToken) {
      return { input: rawToken, matched: false, matches: [], allergens: [], chronics: [] };
    }

    const matchedRecords: Array<Record<string, unknown>> = [];
    const seenCuries = new Set<string>();

    const addMatch = async (curie: string, matchedTerm: string, matchType: string, confidence: number) => {
      if (!curie || seenCuries.has(curie)) return;
      const info = await this.getConcept(curie);
      if (!info) return;
      seenCuries.add(curie);
      const card = await this.buildConceptCard(curie);
      matchedRecords.push({
        curie,
        label_en: info.label_en,
        title_vi: card.title_en,
        title_en: card.title_en,
        terms_vi: [],
        terms_en: card.terms_en,
        matched_term: matchedTerm,
        matched_vi: card.title_en,
        matched_en: card.title_en,
        match_type: matchType,
        confidence,
        food_type: info.food_type,
        allergens: splitCsv(info.allergen_codes),
        chronics: splitCsv(info.chronic_codes),
        ecodes: splitCsv(info.ecodes),
        lineage: card.lineage,
        lineage_nodes: card.lineage_nodes,
      });
    };

    // Stage 1: E-numbers / INS codes (explicit prefix + bare parenthesized codes after functional class)
    const eClean = repairOcrEcodes(cleanToken);
    const eRegex = /\b(e|ins)\s*(\d{3,4}[a-z]?(?:\([ivx]+\))?)\b/gi;
    const eHits: Array<{ raw: string; cands: string[]; matchType: string }> = [];
    const seenPrimaryCodes = new Set<string>();
    for (const m of eClean.matchAll(eRegex)) {
      const prefix = m[1].toLowerCase();
      const numPart = m[2].toLowerCase();
      const baseNum = numPart.replace(/\(.*?\)/g, "");
      const primary = `e${baseNum}`;
      seenPrimaryCodes.add(primary);
      eHits.push({
        raw: m[0].toUpperCase(),
        cands: [`${prefix}${numPart}`, `e${baseNum}`, `ins${baseNum}`],
        matchType: "ecode_exact",
      });
    }
    for (const bare of extractBareAdditiveCodes(cleanToken)) {
      const firstCand = bare.cands[0] || "";
      if (firstCand && !seenPrimaryCodes.has(firstCand)) {
        seenPrimaryCodes.add(firstCand);
        eHits.push({ raw: bare.raw, cands: bare.cands, matchType: "ecode_bare" });
      }
    }
    if (eHits.length > 0) {
      const allCodes = [...new Set(eHits.flatMap((h) => h.cands))];
      const ph = allCodes.map(() => "?").join(",");
      const ecRes = await this.db
        .prepare(`SELECT ecode, curie FROM ecode_bridge WHERE ecode IN (${ph})`)
        .bind(...allCodes)
        .all<{ ecode: string; curie: string }>();
      const ecMap = new Map(ecRes.results.map((r) => [r.ecode, r.curie]));
      for (const h of eHits) {
        for (const cand of h.cands) {
          const c = ecMap.get(cand);
          if (c) {
            await addMatch(c, h.raw, h.matchType, 1.0);
            break;
          }
        }
      }
    }

    let stripped = cleanToken
      .replace(/\(\s*\d+(?:[.,]\d+)?\s*%\s*\)/g, " ")
      .replace(/\b\d+(?:[.,]\d+)?\s*%/g, " ")
      .replace(/\(\s*(?:e|ins)\s*\d{3,4}[a-z]?(?:\([ivx]+\))?\s*\)/gi, " ")
      .replace(CODE_LIST_PAREN_RE, " ");

    const subParts: string[] = [stripped];
    for (const pm of stripped.matchAll(/\(([^)]+)\)/g)) {
      if (pm[1]) subParts.push(pm[1]);
    }
    const mainNoParen = stripped.replace(/\([^)]*\)/g, " ");
    if (mainNoParen.trim() !== stripped.trim()) subParts.unshift(mainNoParen);

    const lowFull = cleanToken.toLowerCase();
    const isGlutenFree = lowFull.includes("gluten-free") || lowFull.includes("gluten free");
    const isLactoseFree = lowFull.includes("lactose-free") || lowFull.includes("lactose free");
    const isPlantMilk = ["soy milk", "soya milk", "almond milk", "oat milk", "coconut milk", "rice milk"].some((x) =>
      lowFull.includes(x)
    );
    const isPlantButter = [
      "peanut butter", "almond butter", "cocoa butter", "margarine", "cashew butter", "sunflower butter",
    ].some((x) => lowFull.includes(x));

    // Stage 2: Whole-part exact / ASCII lookup
    const unmatchedParts: string[] = [];
    for (const part of subParts) {
      const pNorm = part.trim().toLowerCase().replace(/\s+/g, " ").replace(/^[.,;:-]+|[.,;:-]+$/g, "");
      if (!pNorm) continue;
      const enKey = normalizeEnKey(pNorm);
      const exact = await this.lookupExactLex(enKey);
      if (exact) {
        await addMatch(exact.curie, pNorm, exact.matchType, exact.confidence);
        continue;
      }
      unmatchedParts.push(pNorm);
    }

    // Stage 3: Component / sub-phrase decomposition (batched single D1 query!)
    for (const pNorm of unmatchedParts) {
      const words = normalizeEnKey(pNorm).split(" ").filter(Boolean);
      if (words.length < 2) continue;

      const candidatePhrases: Array<{ phrase: string; i: number; n: number }> = [];
      for (let n = Math.min(words.length - 1, 4); n >= 1; n--) {
        for (let i = 0; i <= words.length - n; i++) {
          const phrase = words.slice(i, i + n).join(" ");
          if (n === 1) {
            if (STOPWORDS.has(phrase)) continue;
            if (phrase === "milk" && isPlantMilk) continue;
            if (phrase === "butter" && isPlantButter) continue;
          }
          candidatePhrases.push({ phrase, i, n });
        }
      }
      if (candidatePhrases.length === 0) continue;

      const lookupTerms = new Set<string>();
      for (const cp of candidatePhrases) {
        lookupTerms.add(cp.phrase);
        if (cp.phrase.endsWith("s") && cp.phrase.length > 4) lookupTerms.add(cp.phrase.slice(0, -1));
        if (cp.phrase.endsWith("es") && cp.phrase.length > 5) lookupTerms.add(cp.phrase.slice(0, -2));
      }
      const termArr = [...lookupTerms].slice(0, 75);
      const ph = termArr.map(() => "?").join(",");
      const res = await this.db
        .prepare(`SELECT term_norm, curie, confidence_tier FROM lexical_bridge WHERE term_norm IN (${ph}) ORDER BY confidence_tier ASC`)
        .bind(...termArr)
        .all<{ term_norm: string; curie: string; confidence_tier: number }>();

      const lexMap = new Map<string, string>();
      for (const r of res.results) {
        if (!lexMap.has(r.term_norm)) lexMap.set(r.term_norm, r.curie);
      }

      const covered = new Set<number>();
      for (const cp of candidatePhrases) {
        let overlap = false;
        for (let idx = cp.i; idx < cp.i + cp.n; idx++) {
          if (covered.has(idx)) {
            overlap = true;
            break;
          }
        }
        if (overlap) continue;
        const c =
          lexMap.get(cp.phrase) ||
          (cp.phrase.endsWith("s") && cp.phrase.length > 4 ? lexMap.get(cp.phrase.slice(0, -1)) : undefined) ||
          (cp.phrase.endsWith("es") && cp.phrase.length > 5 ? lexMap.get(cp.phrase.slice(0, -2)) : undefined);
        if (c) {
          await addMatch(c, cp.phrase, "component_exact_en", 0.95);
          for (let idx = cp.i; idx < cp.i + cp.n; idx++) covered.add(idx);
        }
      }
    }

    // Stage 4: Fuzzy fallback for OCR typos (whole part + meaningful English single words >= 5 chars)
    if (matchedRecords.length === 0) {
      for (const pNorm of unmatchedParts) {
        if (hasVietnameseDiacritics(pNorm)) continue;
        const fz = await this.lookupAsciiOrFuzzy(pNorm, 0.82);
        if (fz) {
          await addMatch(fz.curie, fz.term, fz.matchType, fz.confidence);
          continue;
        }
        const words = normalizeEnKey(repairOcrWordHomoglyphs(pNorm)).split(" ").filter(Boolean);
        if (words.length >= 2) {
          for (const w of words) {
            if (w.length < 5 || STOPWORDS.has(w)) continue;
            if (w === "milk" && isPlantMilk) continue;
            if (w === "butter" && isPlantButter) continue;
            const wFz = await this.lookupAsciiOrFuzzy(w, 0.82);
            if (wFz) {
              await addMatch(wFz.curie, wFz.term, wFz.matchType, wFz.confidence);
            }
          }
        }
      }
    }

    const allAllergens = new Set<string>();
    const allChronics = new Set<string>();
    for (const rec of matchedRecords) {
      const recCurie = String(rec.curie || "");
      for (const al of (rec.allergens as string[]) || []) {
        if (al === "gluten" && isGlutenFree) continue;
        if (al === "milk" && isLactoseFree && recCurie === "CHEBI:17716") continue;
        if (al === "milk" && isPlantMilk && (recCurie === "FOODON:02020891" || recCurie === "CHEBI:17716")) continue;
        allAllergens.add(al);
      }
      for (const ch of (rec.chronics as string[]) || []) {
        if (ch === "diabetes" && isLactoseFree && recCurie === "CHEBI:17716") continue;
        allChronics.add(ch);
      }
    }

    matchedRecords.sort((a, b) => {
      const aAl = ((a.allergens as string[]) || []).length > 0 ? 0 : 1;
      const bAl = ((b.allergens as string[]) || []).length > 0 ? 0 : 1;
      if (aAl !== bAl) return aAl - bAl;
      const aCh = ((a.chronics as string[]) || []).length > 0 ? 0 : 1;
      const bCh = ((b.chronics as string[]) || []).length > 0 ? 0 : 1;
      if (aCh !== bCh) return aCh - bCh;
      const aEc = ((a.ecodes as string[]) || []).length > 0 ? 0 : 1;
      const bEc = ((b.ecodes as string[]) || []).length > 0 ? 0 : 1;
      return aEc - bEc;
    });

    return {
      input: rawToken,
      matched: matchedRecords.length > 0,
      matches: matchedRecords,
      allergens: [...allAllergens].sort(),
      chronics: [...allChronics].sort(),
    };
  }

  async inferFoodOnFamily(curie: string): Promise<string> {
    const info = await this.getConcept(curie);
    if (!info) return `curie:${curie}`;
    const als = splitCsv(info.allergen_codes);
    if (als.length > 0) return als[0];

    const lineage = await this.getLineage(curie, 5);
    const ids = lineage.map((n) => n.curie);
    if (ids.includes("FOODON:00001006")) return "curie:FOODON:00001006";
    if (ids.includes("FOODON:00001131")) return "curie:FOODON:00001131";
    if (ids.includes("FOODON:00001092")) return "curie:FOODON:00001092";
    if (ids.length >= 2 && !GENERIC_ROOTS.has(ids[1])) return `curie:${ids[1]}`;
    return `curie:${curie}`;
  }

  async evaluatePackagingLabel(
    ingredientTokens: string[],
    userAllergens: Array<string | Record<string, unknown>>,
    userChronics: string[] = [],
    options: EvaluationOptions = {}
  ): Promise<Record<string, unknown>> {
    const t0 = Date.now();
    const scanDerivatives = options.scanDerivatives !== false;
    const warnTraces = options.warnTraces !== false;
    const chronicSet = new Set(userChronics || []);
    const profileSeverity = new Map<string, string>();
    const profileSourceFood = new Map<string, string>();
    const customCurieTargets = new Map<string, string>();

    for (const item of userAllergens || []) {
      if (typeof item === "string") {
        const code = item.trim();
        if (code) profileSeverity.set(code, "high");
      } else if (item && typeof item === "object") {
        const code = String(item.code ?? item.allergen_code ?? "").trim();
        const sev = String(item.severity ?? "high").toLowerCase();
        const rawName = String(item.name ?? item.allergen_name ?? "").trim();
        if (code) {
          profileSeverity.set(code, sev);
          if (rawName && rawName !== code) profileSourceFood.set(code, rawName);
          if (code.startsWith("curie:")) {
            const targetC = code.slice(6).trim().toUpperCase();
            if (targetC) customCurieTargets.set(targetC, code);
          }
        }
      }
    }

    const tokenResults: Array<Record<string, unknown>> = [];
    const redTriggers: Array<Record<string, unknown>> = [];
    const yellowTriggers: Array<Record<string, unknown>> = [];

    for (const tok of ingredientTokens.slice(0, 60)) {
      const isTrace = isTraceStatement(tok);
      const res = await this.recognizeIngredient(tok);
      const matches = (res.matches as Array<Record<string, unknown>>) || [];
      const triggeredCodes: string[] = [];
      const triggeredChronics: string[] = [];
      let derivativeSkipped = false;

      if (isTrace && !warnTraces) {
        res.is_trace = true;
        res.trace_skipped = true;
        res.is_allergy_trigger = false;
        res.triggered_allergen_codes = [];
        res.is_chronic_trigger = false;
        tokenResults.push(res);
        continue;
      }

      for (const alCode of (res.allergens as string[]) || []) {
        if (profileSeverity.has(alCode)) {
          const primary =
            matches.find((m) => ((m.allergens as string[]) || []).includes(alCode)) ?? matches[0] ?? {};
          const directHit = isDirectAllergenMatch(alCode, tok, primary);
          if (!scanDerivatives && !directHit) {
            derivativeSkipped = true;
            continue;
          }
          triggeredCodes.push(alCode);
          const alEn = formatCodeLabelEn(alCode);
          const mEn = String(primary.title_en ?? primary.label_en ?? tok);
          const srcEn = profileSourceFood.get(alCode) ?? "";
          redTriggers.push({
            token: tok,
            allergen_code: alCode,
            allergen_name: alEn,
            allergen_name_vi: alEn,
            allergen_name_en: alEn,
            source_food: srcEn,
            source_food_vi: srcEn,
            source_food_en: srcEn,
            matched_vi: mEn,
            matched_en: mEn,
            severity: profileSeverity.get(alCode) ?? "high",
            curie: String(primary.curie ?? ""),
            label_en: String(primary.label_en ?? ""),
            lineage: String(primary.lineage ?? ""),
            match_type: String(primary.match_type ?? ""),
            confidence: primary.confidence ?? 1.0,
            is_trace: isTrace,
            is_derivative: !directHit,
          });
        }
      }

      if (customCurieTargets.size > 0 && matches.length > 0) {
        for (const m of matches) {
          const mCurie = String(m.curie ?? "");
          const lNodes = (m.lineage_nodes as Array<{ curie: string }>) || [];
          const lineageSet = new Set(lNodes.map((n) => n.curie));
          lineageSet.add(mCurie);
          const mFam = await this.inferFoodOnFamily(mCurie);

          for (const [targetC, fullCode] of customCurieTargets.entries()) {
            const targetFam = await this.inferFoodOnFamily(targetC);
            const directCurieHit = mCurie.toUpperCase() === targetC;
            const inferredHit = lineageSet.has(targetC) || mFam === fullCode || mFam === targetFam;
            if (!scanDerivatives && !directCurieHit && inferredHit) {
              derivativeSkipped = true;
              continue;
            }
            const hit = scanDerivatives ? inferredHit : directCurieHit;
            if (hit && !triggeredCodes.includes(fullCode)) {
              triggeredCodes.push(fullCode);
              const targetCard = await this.buildConceptCard(targetC);
              const famEn = String(
                targetCard.title_en || profileSourceFood.get(fullCode) || formatCodeLabelEn(fullCode)
              );
              const srcEn = profileSourceFood.get(fullCode) || famEn;
              const mEn = String(m.title_en ?? tok);
              redTriggers.push({
                token: tok,
                allergen_code: fullCode,
                allergen_name: famEn,
                allergen_name_vi: famEn,
                allergen_name_en: famEn,
                source_food: srcEn,
                source_food_vi: srcEn,
                source_food_en: srcEn,
                matched_vi: mEn,
                matched_en: mEn,
                severity: "high",
                curie: mCurie,
                label_en: String(m.label_en ?? ""),
                lineage: String(m.lineage ?? ""),
                match_type: String(m.match_type ?? ""),
                confidence: m.confidence ?? 1.0,
                is_trace: isTrace,
                is_derivative: !directCurieHit,
              });
            }
          }
        }
      }

      for (const chCode of (res.chronics as string[]) || []) {
        if (chronicSet.has(chCode)) {
          triggeredChronics.push(chCode);
          const primary =
            matches.find((m) => ((m.chronics as string[]) || []).includes(chCode)) ?? matches[0] ?? {};
          const chEn = formatCodeLabelEn(chCode);
          const mEn = String(primary.title_en ?? primary.label_en ?? tok);
          yellowTriggers.push({
            token: tok,
            chronic_code: chCode,
            chronic_name: chEn,
            chronic_name_vi: chEn,
            chronic_name_en: chEn,
            matched_vi: mEn,
            matched_en: mEn,
            severity: "caution",
            curie: String(primary.curie ?? ""),
            label_en: String(primary.label_en ?? ""),
            lineage: String(primary.lineage ?? ""),
            match_type: String(primary.match_type ?? ""),
            confidence: primary.confidence ?? 1.0,
            is_trace: isTrace,
          });
        }
      }

      res.is_trace = isTrace;
      res.derivative_skipped = derivativeSkipped;
      res.is_allergy_trigger = triggeredCodes.length > 0;
      res.triggered_allergen_codes = triggeredCodes;
      res.is_chronic_trigger = triggeredChronics.length > 0;
      tokenResults.push(res);
    }

    let verdict = "GREEN";
    let wcagGlyph = "[OK]";
    let titleEn = "SAFE TO CONSUME - NO ALLERGEN TRIGGERS DETECTED";
    if (redTriggers.length > 0) {
      verdict = "RED";
      wcagGlyph = "[!X]";
      titleEn = "HIGH RISK: ALLERGEN DETECTED - DO NOT CONSUME";
    } else if (yellowTriggers.length > 0) {
      verdict = "YELLOW";
      wcagGlyph = "[!?]";
      titleEn = "CAUTION: CONTAINS INGREDIENTS TO LIMIT OR AVOID";
    }

    const detectedAdditives: Array<Record<string, unknown>> = [];
    let highestRisk = "safe";
    for (const td of tokenResults) {
      for (const m of (td.matches as Array<Record<string, unknown>>) || []) {
        const c = String(m.curie ?? "");
        const rk = (await this.classifyConceptRisk(c)).risk_level;
        if (rk === "high") highestRisk = "high";
        else if (rk === "low" && highestRisk === "safe") highestRisk = "low";
        const ecs = (m.ecodes as string[]) || [];
        const lin = String(m.lineage ?? "");
        if (ecs.length > 0 || lin.includes("FOODON:03412972")) {
          detectedAdditives.push(await this.buildConceptCard(c));
        }
      }
    }

    const warningCount = redTriggers.length + yellowTriggers.length;
    const additiveCount =
      detectedAdditives.length > 0
        ? detectedAdditives.length
        : tokenResults.filter((d) => d.matched === true).length;

    let riskLevel = "safe";
    let riskLabelVi = "An toàn";
    if (verdict === "RED" || highestRisk === "high") {
      riskLevel = "high";
      riskLabelVi = "Nguy cơ cao";
    } else if (verdict === "YELLOW" || highestRisk === "low") {
      riskLevel = "low";
      riskLabelVi = "Nguy cơ thấp";
    }

    return {
      verdict,
      wcag_glyph: wcagGlyph,
      title: titleEn,
      title_vi: titleEn,
      title_en: titleEn,
      latency_ms: Date.now() - t0,
      red_triggers: redTriggers,
      yellow_triggers: yellowTriggers,
      tokens_analyzed: ingredientTokens.length,
      details: tokenResults,
      detected_additives: detectedAdditives,
      warning_count: warningCount,
      additive_count: additiveCount,
      risk_level: riskLevel,
      risk_label_vi: riskLabelVi,
      applied_settings: {
        scan_derivatives: scanDerivatives,
        warn_traces: warnTraces,
      },
    };
  }

  async getDbStats(): Promise<{ total_concepts: number; total_edges: number; total_en_terms: number; total_ecodes: number; total_vi_terms: number }> {
    const res = await this.db.prepare("SELECT key, value FROM db_metadata").all<{ key: string; value: string }>();
    const map = new Map(res.results.map((r) => [r.key, r.value]));
    return {
      total_concepts: Number(map.get("total_concepts") ?? 33688),
      total_edges: Number(map.get("total_edges") ?? 32883),
      total_en_terms: Number(map.get("total_en_terms") ?? 53242),
      total_ecodes: Number(map.get("total_ecodes") ?? 742),
      total_vi_terms: 0,
    };
  }

  async searchConcepts(
    query = "",
    langScope = "all",
    allergenFilter = "",
    limit = 30
  ): Promise<Record<string, unknown>> {
    const t0 = Date.now();
    const qRaw = (query || "").trim();
    const qNorm = qRaw.toLowerCase().replace(/\s+/g, " ");
    const scope = (langScope || "all").toLowerCase();
    const alFilter = (allergenFilter || "").trim().toLowerCase();
    const lim = Math.max(1, Math.min(limit || 30, 100));

    const recognition = qRaw ? await this.recognizeIngredient(qRaw) : null;
    const candScores = new Map<string, { rank: number; term: string; lang: string }>();

    const recordHit = (curie: string, rank: number, term: string, lang: string) => {
      const prev = candScores.get(curie);
      if (!prev || rank < prev.rank) candScores.set(curie, { rank, term, lang });
    };

    if (!qNorm) {
      let sql = "SELECT * FROM foodon_concepts";
      const binds: unknown[] = [];
      if (alFilter) {
        sql = "SELECT c.* FROM foodon_allergen_map m JOIN foodon_concepts c ON c.curie = m.curie WHERE m.allergen_code = ? ORDER BY m.sort_len ASC LIMIT ?";
        binds.push(alFilter, lim);
      } else if (scope === "ecode") {
        sql = "SELECT * FROM foodon_concepts WHERE ecodes != '' ORDER BY LENGTH(label_en) ASC LIMIT ?";
        binds.push(lim);
      } else {
        sql = "SELECT * FROM foodon_concepts ORDER BY has_tags DESC, child_count DESC, LENGTH(label_en) ASC LIMIT ?";
        binds.push(lim);
      }
      const rows = await this.db.prepare(sql).bind(...binds).all<FoodOnConceptRow>();
      for (let i = 0; i < rows.results.length; i++) {
        const r = rows.results[i];
        this.conceptCache.set(r.curie, r);
        recordHit(r.curie, 10 + i, r.label_en, "en");
      }
    } else {
      const qUpper = qRaw.toUpperCase();
      if (scope === "all" || scope === "en") {
        const byCurie = await this.getConcept(qUpper);
        if (byCurie) recordHit(byCurie.curie, 1, qUpper, "curie");
      }

      if (scope === "all" || scope === "ecode") {
        const qEc = qNorm.replace(/\s+/g, "");
        const ecRes = await this.db
          .prepare("SELECT ecode, curie FROM ecode_bridge WHERE ecode LIKE ? LIMIT 40")
          .bind(`%${qEc}%`)
          .all<{ ecode: string; curie: string }>();
        for (const r of ecRes.results) {
          recordHit(r.curie, r.ecode === qEc ? 2 : 15, r.ecode.toUpperCase(), "ecode");
        }
      }

      if (scope === "all" || scope === "en" || scope === "vi") {
        const qEn = normalizeEnKey(qNorm);
        if (qEn) {
          // 1. Exact & prefix hits on indexed term_norm
          const prefRes = await this.db
            .prepare("SELECT term_norm, curie, confidence_tier FROM lexical_bridge WHERE term_norm = ? OR term_norm LIKE ? ORDER BY confidence_tier ASC, LENGTH(term_norm) ASC LIMIT 60")
            .bind(qEn, `${qEn}%`)
            .all<{ term_norm: string; curie: string; confidence_tier: number }>();
          for (const r of prefRes.results) {
            const rk =
              r.term_norm === qEn
                ? 4 + r.confidence_tier
                : r.term_norm.startsWith(`${qEn} `)
                  ? Math.max(6, 16 + r.confidence_tier * 2 + Math.min(r.term_norm.length, 20))
                  : Math.max(12, 34 + r.confidence_tier * 2 + Math.min(r.term_norm.length, 25));
            recordHit(r.curie, rk, r.term_norm, "en");
          }

          // 2. Substring hits on foodon_concepts.label_low if we need more results
          if (candScores.size < lim && qEn.length >= 3) {
            const subRes = await this.db
              .prepare("SELECT * FROM foodon_concepts WHERE label_low LIKE ? ORDER BY has_tags DESC, LENGTH(label_low) ASC LIMIT 50")
              .bind(`%${qEn}%`)
              .all<FoodOnConceptRow>();
            for (const r of subRes.results) {
              this.conceptCache.set(r.curie, r);
              const rk = ` ${r.label_low} `.includes(` ${qEn} `)
                ? 22 + Math.min(r.label_low.length, 25)
                : 58 + Math.min(r.label_low.length, 30);
              recordHit(r.curie, rk, r.label_en, "en");
            }
          }
        }
      }

      if (recognition && recognition.matched) {
        const matches = (recognition.matches as Array<Record<string, unknown>>) || [];
        matches.forEach((m, idx) => {
          const c = String(m.curie ?? "");
          const mt = String(m.match_type ?? "");
          recordHit(c, 10 + idx, String(m.matched_term ?? ""), mt.includes("ecode") ? "ecode" : "en");
        });
      }
    }

    const allIds = [...candScores.keys()];
    await this.getConceptsBatch(allIds);

    const filtered: Array<[string, { rank: number; term: string; lang: string }]> = [];
    for (const [cid, info] of candScores.entries()) {
      const c = this.conceptCache.get(cid);
      if (!c) continue;
      if (alFilter && !splitCsv(c.allergen_codes).includes(alFilter)) continue;
      filtered.push([cid, info]);
    }
    filtered.sort((a, b) => (a[1].rank !== b[1].rank ? a[1].rank - b[1].rank : a[0].localeCompare(b[0])));
    const topHits = filtered.slice(0, lim);
    const synsMap = await this.getSynonymsBatch(topHits.map((x) => x[0]), 10);

    const results: Array<Record<string, unknown>> = [];
    for (const [cid, hit] of topHits) {
      const info = this.conceptCache.get(cid)!;
      const lineageNodes = await this.getLineage(cid, 4);
      results.push({
        curie: cid,
        label_en: info.label_en,
        definition_en: info.definition_en,
        terms_vi: [],
        terms_en: synsMap.get(cid) ?? [],
        food_type: info.food_type,
        allergens: splitCsv(info.allergen_codes),
        chronics: splitCsv(info.chronic_codes),
        ecodes: splitCsv(info.ecodes),
        matched_term: hit.term,
        matched_lang: hit.lang,
        rank_score: hit.rank,
        lineage: this.formatLineageString(lineageNodes),
        lineage_nodes: lineageNodes,
      });
    }

    const dbStats = await this.getDbStats();
    return {
      query: qRaw,
      lang_scope: scope,
      allergen_filter: alFilter,
      latency_ms: Date.now() - t0,
      total_matched: filtered.length,
      returned_count: results.length,
      recognition,
      results,
      db_stats: dbStats,
    };
  }

  async listAdditives(query = "", limit = 60): Promise<Record<string, unknown>> {
    const t0 = Date.now();
    const q = (query || "").trim();
    const lim = Math.max(1, Math.min(limit || 60, 150));

    const ecRes = await this.db
      .prepare("SELECT ecode, curie FROM ecode_bridge")
      .all<{ ecode: string; curie: string }>();

    const eEntries = ecRes.results
      .filter((r) => r.ecode.startsWith("e") && !r.ecode.includes("("))
      .sort((a, b) => compareEcodes(a.ecode, b.ecode));

    const items: Array<Record<string, unknown>> = [];
    const seen = new Set<string>();

    if (!q) {
      const picked = eEntries.slice(0, lim * 2);
      await this.getConceptsBatch(picked.map((p) => p.curie));
      for (const p of picked) {
        if (seen.has(p.curie) || !this.conceptCache.get(p.curie)) continue;
        seen.add(p.curie);
        items.push(await this.buildConceptCard(p.curie, p.ecode.toUpperCase()));
        if (items.length >= lim) break;
      }
    } else {
      const qLow = q.toLowerCase();
      const qCompact = qLow.replace(/\s+/g, "");
      const eMatches = ecRes.results
        .filter((r) => r.ecode.includes(qCompact) || r.ecode.includes(qLow))
        .sort((a, b) => {
          const ae = a.ecode === qCompact || a.ecode === `e${qCompact}` ? 0 : 1;
          const be = b.ecode === qCompact || b.ecode === `e${qCompact}` ? 0 : 1;
          return ae !== be ? ae - be : compareEcodes(a.ecode, b.ecode);
        });
      await this.getConceptsBatch(eMatches.slice(0, lim).map((m) => m.curie));
      for (const m of eMatches) {
        if (seen.has(m.curie) || !this.conceptCache.get(m.curie)) continue;
        seen.add(m.curie);
        const dispEc = m.ecode.startsWith("e") ? m.ecode.toUpperCase() : `E${m.ecode.slice(3).toUpperCase()}`;
        items.push(await this.buildConceptCard(m.curie, dispEc));
        if (items.length >= lim) break;
      }

      if (items.length < lim) {
        const searchRes = await this.searchConcepts(q, "en", "", lim);
        const results = (searchRes.results as Array<Record<string, unknown>>) || [];
        for (const r of results) {
          const c = String(r.curie ?? "");
          if (seen.has(c)) continue;
          seen.add(c);
          const ecs = ((r.ecodes as string[]) || []).filter((e) => e.toLowerCase().startsWith("e"));
          items.push(await this.buildConceptCard(c, ecs[0]?.toUpperCase() || c));
          if (items.length >= lim) break;
        }
      }
    }

    return {
      query: q,
      lang: "en",
      count: items.length,
      latency_ms: Date.now() - t0,
      items,
    };
  }

  async getCategoryConcepts(
    category = "sugar",
    userAllergens: string[] = [],
    limit = 20
  ): Promise<Record<string, unknown>> {
    const cat = (category || "sugar").toLowerCase().trim();
    const lim = Math.max(1, Math.min(limit || 20, 40));
    const chronicMap: Record<string, string> = {
      sugar: "diabetes",
      salt: "hypertension",
      fat: "cholesterol",
    };

    const items: Array<Record<string, unknown>> = [];
    const seen = new Set<string>();

    if (chronicMap[cat]) {
      const targetCh = chronicMap[cat];
      const roots = FOODON_CHRONIC_ROOTS[targetCh] ?? [];
      await this.getConceptsBatch(roots);
      for (const c of roots) {
        if (this.conceptCache.get(c) && !seen.has(c)) {
          seen.add(c);
          items.push(await this.buildConceptCard(c));
          if (items.length >= lim) break;
        }
      }
      if (items.length < lim) {
        const res = await this.db
          .prepare("SELECT c.* FROM foodon_chronic_map m JOIN foodon_concepts c ON c.curie = m.curie WHERE m.chronic_code = ? ORDER BY m.has_ecode DESC, m.sort_len ASC, m.curie ASC LIMIT ?")
          .bind(targetCh, lim + 10)
          .all<FoodOnConceptRow>();
        for (const r of res.results) {
          this.conceptCache.set(r.curie, r);
          if (seen.has(r.curie)) continue;
          seen.add(r.curie);
          items.push(await this.buildConceptCard(r.curie));
          if (items.length >= lim) break;
        }
      }
    } else {
      let activeAls = (userAllergens || []).filter((a) => Boolean(FOODON_ALLERGEN_ROOTS[a]));
      if (activeAls.length === 0) activeAls = Object.keys(FOODON_ALLERGEN_ROOTS);
      const repCuries = activeAls.map((a) => ALLERGEN_REPRESENTATIVE_CURIES[a]).filter(Boolean);
      await this.getConceptsBatch(repCuries);
      for (const c of repCuries) {
        if (this.conceptCache.get(c) && !seen.has(c)) {
          seen.add(c);
          items.push(await this.buildConceptCard(c));
          if (items.length >= lim) break;
        }
      }
      if (items.length < lim) {
        const ph = activeAls.map(() => "?").join(",");
        const res = await this.db
          .prepare(`SELECT c.* FROM foodon_allergen_map m JOIN foodon_concepts c ON c.curie = m.curie WHERE m.allergen_code IN (${ph}) ORDER BY m.sort_len ASC, m.curie ASC LIMIT ?`)
          .bind(...activeAls, lim + 12)
          .all<FoodOnConceptRow>();
        for (const r of res.results) {
          this.conceptCache.set(r.curie, r);
          if (seen.has(r.curie)) continue;
          seen.add(r.curie);
          items.push(await this.buildConceptCard(r.curie));
          if (items.length >= lim) break;
        }
      }
    }

    return { category: cat, lang: "en", count: items.length, items };
  }

  private async getDynamicFamilyMetadata(allergenCode: string, fallbackFoodEn: string): Promise<{ famEn: string; relEn: string }> {
    const sibs: string[] = [];
    let famEn = "";

    if (allergenCode.startsWith("curie:")) {
      const famCurie = allergenCode.slice(6).trim();
      const famInfo = await this.getConcept(famCurie);
      if (famInfo) {
        famEn = formatCleanEnglishTitle(famCurie, famInfo.label_en);
        const chRes = await this.db
          .prepare("SELECT curie, label_en FROM foodon_concepts WHERE parent_curie = ? ORDER BY child_count DESC, LENGTH(label_en) ASC LIMIT 6")
          .bind(famCurie)
          .all<{ curie: string; label_en: string }>();
        sibs.push(famEn);
        for (const r of chRes.results) {
          const t = formatCleanEnglishTitle(r.curie, r.label_en);
          if (!sibs.includes(t)) sibs.push(t);
          if (sibs.length >= 6) break;
        }
      }
    } else {
      famEn = formatCodeLabelEn(allergenCode);
      const res = await this.db
        .prepare("SELECT c.curie, c.label_en FROM foodon_allergen_map m JOIN foodon_concepts c ON c.curie = m.curie WHERE m.allergen_code = ? ORDER BY m.sort_len ASC LIMIT 8")
        .bind(allergenCode)
        .all<{ curie: string; label_en: string }>();
      for (const r of res.results) {
        const t = formatCleanEnglishTitle(r.curie, r.label_en);
        if (!sibs.includes(t)) sibs.push(t);
        if (sibs.length >= 6) break;
      }
    }

    const famFinal = famEn || fallbackFoodEn;
    const relFinal = sibs.length > 0 ? sibs.join(", ") : `Ingredients and derivatives under ${famFinal}`;
    return { famEn: famFinal, relEn: relFinal };
  }

  async searchAllergyFoods(query = "", limit = 12): Promise<Record<string, unknown>> {
    const t0 = Date.now();
    const q = (query || "").trim();
    const lim = Math.max(1, Math.min(limit || 12, 30));
    const items: Array<Record<string, unknown>> = [];
    const seen = new Set<string>();

    const emojiFor = (alCode: string, curie: string): string => {
      if (alCode === "milk") return curie === "FOODON:03310351" ? "🧈" : curie === "FOODON:03000287" ? "🧀" : "🥛";
      if (alCode === "peanuts") return "🥜";
      if (alCode === "seafood") return "🦐";
      if (alCode === "gluten") return "🍞";
      if (alCode === "eggs") return "🥚";
      if (alCode === "soy") return "🌱";
      if (alCode === "tree_nuts") return "🌰";
      if (alCode === "sesame") return "🌿";
      if (["curie:FOODON:00001006", "curie:FOODON:00001134", "curie:FOODON:00001038", "curie:FOODON:00001092"].includes(alCode)) return "🥩";
      if (["curie:FOODON:00001131", "curie:FOODON:00001040"].includes(alCode)) return "🍗";
      return "🍽️";
    };

    const makeItem = async (curie: string, allergenCode: string) => {
      seen.add(curie);
      const card = await this.buildConceptCard(curie);
      const fEn = String(card.title_en ?? curie);
      const { famEn, relEn } = await this.getDynamicFamilyMetadata(allergenCode, fEn);
      const expEn = `Selecting "${fEn}" automatically links to "${famEn}" via FoodOn Ontology. Scanning labels containing: ${relEn} → Automatically triggers a RED Alert!`;
      return {
        curie,
        allergen_code: allergenCode,
        emoji: emojiFor(allergenCode, curie),
        food_name: fEn,
        food_name_vi: fEn,
        food_name_en: fEn,
        family_name: famEn,
        family_name_vi: famEn,
        family_name_en: famEn,
        related_ingredients: relEn,
        related_ingredients_vi: relEn,
        related_ingredients_en: relEn,
        explanation: expEn,
        explanation_vi: expEn,
        explanation_en: expEn,
        lineage_nodes: card.lineage_nodes ?? [],
      };
    };

    if (!q) {
      const defaults: Array<[string, string]> = [
        ...Object.entries(ALLERGEN_REPRESENTATIVE_CURIES).map(([al, c]): [string, string] => [c, al]),
        ["FOODON:00001006", "curie:FOODON:00001006"],
        ["FOODON:00001131", "curie:FOODON:00001131"],
      ];
      await this.getConceptsBatch(defaults.map((d) => d[0]));
      for (const [c, al] of defaults) {
        if (this.conceptCache.get(c) && !seen.has(c)) {
          items.push(await makeItem(c, al));
          if (items.length >= lim) break;
        }
      }
    } else {
      const rec = await this.recognizeIngredient(q);
      for (const m of (rec.matches as Array<Record<string, unknown>>) || []) {
        const c = String(m.curie ?? "");
        if (seen.has(c)) continue;
        if (await this.getConcept(c)) {
          items.push(await makeItem(c, await this.inferFoodOnFamily(c)));
          if (items.length >= lim) break;
        }
      }
      if (items.length < lim) {
        const sRes = await this.searchConcepts(q, "en", "", 24);
        for (const r of (sRes.results as Array<Record<string, unknown>>) || []) {
          const c = String(r.curie ?? "");
          if (seen.has(c)) continue;
          items.push(await makeItem(c, await this.inferFoodOnFamily(c)));
          if (items.length >= lim) break;
        }
      }
    }

    return { query: q, lang: "en", count: items.length, items, latency_ms: Date.now() - t0 };
  }

  // ---------------------------------------------------------------------------
  // Interactive FoodOn Graph Visualization API (Indexed D1 queries!)
  // ---------------------------------------------------------------------------
  private async serializeGraphNode(info: FoodOnConceptRow, role = "node", depth = 0): Promise<Record<string, unknown>> {
    const synsMap = await this.getSynonymsBatch([info.curie], 12);
    return {
      id: info.curie,
      label: info.label_en || info.curie,
      parent_id: info.parent_curie || "",
      parent_label: info.parent_label_en || "",
      definition: info.definition_en || "",
      food_type: info.food_type || "",
      allergens: splitCsv(info.allergen_codes),
      chronics: splitCsv(info.chronic_codes),
      ecodes: splitCsv(info.ecodes).map((e) => e.toUpperCase()),
      synonyms: synsMap.get(info.curie) ?? [],
      child_count: Number(info.child_count ?? 0),
      role,
      depth,
    };
  }

  private async resolveNodeCurie(ref: string): Promise<string> {
    const raw = (ref || "").trim();
    if (!raw) return "";
    const up = raw.toUpperCase();
    if (await this.getConcept(up)) return up;
    if (await this.getConcept(raw)) return raw;
    const rec = await this.recognizeIngredient(raw);
    const matches = (rec.matches as Array<Record<string, unknown>>) || [];
    if (rec.matched && matches.length > 0) return String(matches[0].curie ?? "");
    const srch = await this.searchConcepts(raw, "all", "", 1);
    const results = (srch.results as Array<Record<string, unknown>>) || [];
    if (results.length > 0) return String(results[0].curie ?? "");
    return "";
  }

  private async getChildrenRows(parentCurie: string, limit: number, offset = 0): Promise<FoodOnConceptRow[]> {
    const res = await this.db
      .prepare(
        "SELECT * FROM foodon_concepts WHERE parent_curie = ? AND curie != ? ORDER BY child_count DESC, has_tags DESC, LENGTH(label_low) ASC, label_low ASC LIMIT ? OFFSET ?"
      )
      .bind(parentCurie, parentCurie, limit, offset)
      .all<FoodOnConceptRow>();
    for (const r of res.results) this.conceptCache.set(r.curie, r);
    return res.results;
  }

  async getGraphNeighborhood(opts: {
    curie?: string;
    ancestorHops?: number;
    childDepth?: number;
    maxChildren?: number;
    includeSiblings?: boolean;
    allergen?: string;
  }): Promise<Record<string, unknown>> {
    const t0 = Date.now();
    const ancestorHops = Math.max(1, Math.min(opts.ancestorHops ?? 10, 20));
    const childDepth = Math.max(0, Math.min(opts.childDepth ?? 2, 3));
    const maxChildren = Math.max(1, Math.min(opts.maxChildren ?? 24, 80));
    const includeSiblings = opts.includeSiblings ?? true;
    const allergen = (opts.allergen || "").trim().toLowerCase();
    const rawCurie = (opts.curie || "").trim();

    const nodesById = new Map<string, Record<string, unknown>>();
    const edgesSet = new Set<string>();
    const prio: Record<string, number> = { focus: 5, ancestor: 4, child: 3, sibling: 2, grandchild: 1, node: 0 };

    const addNode = async (info: FoodOnConceptRow, role: string, depth: number) => {
      const existing = nodesById.get(info.curie);
      if (!existing) {
        nodesById.set(info.curie, await this.serializeGraphNode(info, role, depth));
      } else if ((prio[role] ?? 0) > (prio[String(existing.role)] ?? 0)) {
        existing.role = role;
        existing.depth = depth;
      }
    };
    const addEdge = (childId: string, parentId: string) => {
      if (nodesById.has(childId) && nodesById.has(parentId) && childId !== parentId) {
        edgesSet.add(`${childId}||${parentId}`);
      }
    };

    let focusId = "FOODON:00001002";

    if (allergen && !rawCurie) {
      const roots = FOODON_ALLERGEN_ROOTS[allergen] ?? FOODON_CHRONIC_ROOTS[allergen] ?? [];
      await this.getConceptsBatch(roots);
      focusId = ALLERGEN_REPRESENTATIVE_CURIES[allergen] || roots[0] || "FOODON:00001002";
      let focusInfo = await this.getConcept(focusId);
      if (!focusInfo) {
        focusId = "FOODON:00001002";
        focusInfo = await this.getConcept(focusId);
      }
      if (!focusInfo) return { success: false, message: "FoodOn root not found", nodes: [], edges: [] };
      await addNode(focusInfo, "focus", 0);

      for (const rootC of roots.slice(0, 12)) {
        const rInfo = await this.getConcept(rootC);
        if (!rInfo) continue;
        await addNode(rInfo, rootC === focusId ? "focus" : "child", rootC === focusId ? 0 : 1);
        let curr = rInfo;
        const seenUp = new Set([curr.curie]);
        for (let hop = 1; hop <= 4; hop++) {
          if (!curr.parent_curie || seenUp.has(curr.parent_curie)) break;
          const pInfo = await this.getConcept(curr.parent_curie);
          if (!pInfo) break;
          seenUp.add(pInfo.curie);
          await addNode(pInfo, "ancestor", -hop);
          addEdge(curr.curie, pInfo.curie);
          curr = pInfo;
        }
        const chLimit = Math.max(3, Math.floor(maxChildren / Math.max(1, Math.min(roots.length, 6))));
        const children = await this.getChildrenRows(rootC, chLimit);
        for (const ch of children) {
          await addNode(ch, "grandchild", 2);
          addEdge(ch.curie, rootC);
        }
      }
    } else {
      focusId = rawCurie ? await this.resolveNodeCurie(rawCurie) : "FOODON:00001002";
      const focusInfo = await this.getConcept(focusId);
      if (!focusInfo) {
        return { success: false, message: `FoodOn concept not found: ${rawCurie}`, nodes: [], edges: [] };
      }
      await addNode(focusInfo, "focus", 0);

      // 1. Ancestors
      let curr = focusInfo;
      const seenUp = new Set([curr.curie]);
      for (let hop = 1; hop <= ancestorHops; hop++) {
        if (!curr.parent_curie || seenUp.has(curr.parent_curie)) break;
        const pInfo = await this.getConcept(curr.parent_curie);
        if (!pInfo) break;
        seenUp.add(pInfo.curie);
        await addNode(pInfo, "ancestor", -hop);
        addEdge(curr.curie, pInfo.curie);
        curr = pInfo;
      }

      // 2. Siblings
      if (includeSiblings && focusInfo.parent_curie) {
        const sibs = await this.getChildrenRows(focusInfo.parent_curie, 8);
        let added = 0;
        for (const sib of sibs) {
          if (sib.curie === focusId || nodesById.has(sib.curie)) continue;
          await addNode(sib, "sibling", 0);
          addEdge(sib.curie, focusInfo.parent_curie);
          added++;
          if (added >= 6) break;
        }
      }

      // 3. Descendants
      if (childDepth >= 1) {
        const lvl1 = await this.getChildrenRows(focusId, maxChildren);
        for (const ch of lvl1) {
          await addNode(ch, "child", 1);
          addEdge(ch.curie, focusId);
        }
        if (childDepth >= 2 && lvl1.length > 0) {
          const perBranch = Math.max(2, Math.min(6, Math.floor(maxChildren / Math.max(1, Math.min(lvl1.length, 8)))));
          const gcBudget = Math.max(20, maxChildren * 2);
          let gcCount = 0;
          for (const ch of lvl1.slice(0, 12)) {
            if (gcCount >= gcBudget) break;
            const gcs = await this.getChildrenRows(ch.curie, perBranch);
            for (const gc of gcs) {
              await addNode(gc, "grandchild", 2);
              addEdge(gc.curie, ch.curie);
              gcCount++;
              if (gcCount >= gcBudget) break;
            }
          }
        }
      }
    }

    for (const [nid] of nodesById) {
      const info = this.conceptCache.get(nid);
      if (info?.parent_curie && nodesById.has(info.parent_curie) && info.parent_curie !== nid) {
        edgesSet.add(`${nid}||${info.parent_curie}`);
      }
    }

    const lineageChain = (await this.getLineage(focusId, 12)).reverse().map((n) => ({
      id: n.curie,
      label: n.label_en,
    }));
    const previewChildren = await this.getChildrenRows(focusId, 40);
    const childrenPreview = previewChildren.map((ch) => ({
      id: ch.curie,
      label: ch.label_en,
      child_count: Number(ch.child_count ?? 0),
      allergens: splitCsv(ch.allergen_codes),
      ecodes: splitCsv(ch.ecodes).map((e) => e.toUpperCase()),
    }));

    const edges = [...edgesSet].sort().map((pair) => {
      const [source, target] = pair.split("||");
      return { source, target, relation: "subClassOf" };
    });

    const dbStats = await this.getDbStats();
    return {
      success: true,
      focus: nodesById.get(focusId),
      lineage: lineageChain,
      children_preview: childrenPreview,
      nodes: [...nodesById.values()],
      edges,
      latency_ms: Date.now() - t0,
      db_stats: dbStats,
    };
  }

  async expandGraphNode(curie: string, limit = 24, offset = 0): Promise<Record<string, unknown>> {
    const cid = await this.resolveNodeCurie(curie);
    const info = await this.getConcept(cid);
    if (!info) return { success: false, message: `Concept not found: ${curie}` };

    const lim = Math.max(1, Math.min(limit || 24, 80));
    const off = Math.max(0, offset || 0);
    const sliceCh = await this.getChildrenRows(cid, lim, off);
    const totalChildren = Number(info.child_count ?? sliceCh.length);

    const focusNode = await this.serializeGraphNode(info, "focus", 0);
    const nodes: Array<Record<string, unknown>> = [focusNode];
    const edges: Array<{ source: string; target: string; relation: string }> = [];

    if (info.parent_curie && info.parent_curie !== cid) {
      const parentInfo = await this.getConcept(info.parent_curie);
      if (parentInfo) {
        nodes.push(await this.serializeGraphNode(parentInfo, "ancestor", -1));
        edges.push({ source: cid, target: parentInfo.curie, relation: "subClassOf" });
      }
    }

    const childrenNodes: Array<Record<string, unknown>> = [];
    for (const ch of sliceCh) {
      const n = await this.serializeGraphNode(ch, "child", 1);
      childrenNodes.push(n);
      nodes.push(n);
      edges.push({ source: ch.curie, target: cid, relation: "subClassOf" });
    }

    return {
      success: true,
      node: focusNode,
      children: childrenNodes,
      nodes,
      edges,
      total_children: totalChildren,
      offset: off,
      limit: lim,
      has_more: off + sliceCh.length < totalChildren,
    };
  }

  async findOntologyPath(sourceRef: string, targetRef: string): Promise<Record<string, unknown>> {
    const t0 = Date.now();
    const a = await this.resolveNodeCurie(sourceRef);
    const b = await this.resolveNodeCurie(targetRef);
    const infoA = await this.getConcept(a);
    const infoB = await this.getConcept(b);
    if (!infoA) return { success: false, connected: false, message: `Start node not found: ${sourceRef}` };
    if (!infoB) return { success: false, connected: false, message: `Target node not found: ${targetRef}` };

    const chainA = (await this.getLineage(a, 24)).map((n) => n.curie);
    const chainB = (await this.getLineage(b, 24)).map((n) => n.curie);
    const idxB = new Map(chainB.map((id, i) => [id, i]));

    let lca = "";
    let pathA: string[] = [];
    let pathB: string[] = [];
    for (let i = 0; i < chainA.length; i++) {
      const cid = chainA[i];
      if (idxB.has(cid)) {
        lca = cid;
        pathA = chainA.slice(0, i + 1);
        pathB = chainB.slice(0, idxB.get(cid)!);
        break;
      }
    }

    if (!lca) {
      return {
        success: true,
        connected: false,
        from: await this.serializeGraphNode(infoA, "focus", 0),
        to: await this.serializeGraphNode(infoB, "focus", 0),
        lca_id: "",
        path_nodes: [],
        edges: [],
        message: "No shared ancestor found in the FoodOn hierarchy between these two nodes.",
        latency_ms: Date.now() - t0,
      };
    }

    const orderedIds = [...pathA, ...[...pathB].reverse()];
    await this.getConceptsBatch(orderedIds);
    const pathNodes: Array<Record<string, unknown>> = [];
    for (let i = 0; i < orderedIds.length; i++) {
      const cid = orderedIds[i];
      const info = this.conceptCache.get(cid)!;
      const role = cid === a || cid === b ? "focus" : cid === lca ? "ancestor" : "child";
      pathNodes.push(await this.serializeGraphNode(info, role, i));
    }

    const edges: Array<{ source: string; target: string; relation: string }> = [];
    for (let i = 0; i < pathA.length - 1; i++) {
      edges.push({ source: pathA[i], target: pathA[i + 1], relation: "subClassOf" });
    }
    const bToLca = [...pathB, lca];
    for (let i = 0; i < bToLca.length - 1; i++) {
      edges.push({ source: bToLca[i], target: bToLca[i + 1], relation: "subClassOf" });
    }

    const lcaInfo = this.conceptCache.get(lca)!;
    return {
      success: true,
      connected: true,
      from: pathNodes[0],
      to: pathNodes[pathNodes.length - 1],
      lca_id: lca,
      lca_label: lcaInfo.label_en,
      hops: edges.length,
      path_nodes: pathNodes,
      edges,
      latency_ms: Date.now() - t0,
    };
  }
}

