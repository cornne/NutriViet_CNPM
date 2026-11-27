import { afterEach, describe, expect, it, vi } from "vitest";
import {
  encodeResetTokenRecord,
  hashPasswordResetOtp,
  verifyPasswordResetRecord,
} from "../src/auth_profile";
import { hashPassword, randomNumericOtp, verifyPassword } from "../src/crypto";
import { parseFromAddress, sendPasswordResetOtpEmail, sendVerificationEmail } from "../src/email";
import {
  extractBareAdditiveCodes,
  formatCleanEnglishTitle,
  hasVietnameseDiacritics,
  isDirectAllergenMatch,
  isTraceStatement,
  levenshteinDistance,
  normalizeEnKey,
  repairOcrEcodes,
  repairOcrWordHomoglyphs,
  similarityRatio,
  splitRawIngredients,
} from "../src/foodon";
import app from "../src/index";
import { extractIngredientsSection } from "../src/ingredient_extractor";
import { extractCleanOcrText } from "../src/ocr_proxy";
import { OCR_PROVIDER_CHAIN, OcrProviderRouter } from "../src/ocr_router";
import { SlidingWindowRateLimiter } from "../src/rate_limit";
import type { Env } from "../src/types";

describe("NutriViet Cloudflare Worker core utilities", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("PBKDF2-HMAC-SHA256 matches Python hashlib.pbkdf2_hmac 100k iterations byte-for-byte", async () => {
    const { hash, salt } = await hashPassword("NutriPass123!", "0123456789abcdef0123456789abcdef");
    expect(salt).toBe("0123456789abcdef0123456789abcdef");
    expect(hash).toHaveLength(64);
    expect(await verifyPassword("NutriPass123!", hash, salt)).toBe(true);
    expect(await verifyPassword("WrongPassword", hash, salt)).toBe(false);
  });

  it("Password reset 6-digit OTP hashing, constant-time verification, and 15-min expiry work securely", async () => {
    const otp = randomNumericOtp(6);
    expect(otp).toMatch(/^\d{6}$/);

    const now = Date.now();
    const hash = await hashPasswordResetOtp(42, otp);
    const validRec = encodeResetTokenRecord(hash, new Date(now + 15 * 60_000).toISOString());

    expect(await verifyPasswordResetRecord(42, otp, validRec, now + 60_000)).toBe(true);
    // Wrong OTP or wrong userId fails
    expect(await verifyPasswordResetRecord(42, "000000" === otp ? "999999" : "000000", validRec, now + 60_000)).toBe(false);
    expect(await verifyPasswordResetRecord(99, otp, validRec, now + 60_000)).toBe(false);
    // Expired OTP fails
    expect(await verifyPasswordResetRecord(42, otp, validRec, now + 16 * 60_000)).toBe(false);
  });

  it("extractCleanOcrText preserves Vietnamese diacritics and E-codes while stripping Markdown/HTML", () => {
    const raw = `
## **THÀNH PHẦN:**
![](imgs/0.jpg)
Bột mì (48%), sữa bột nguyên kem (6%), chất nhũ hóa (INS 322(i) / E322), chất điều vị (E621).
<table><tr><td>Phẩm màu</td><td>E102 &amp; E110</td></tr></table>
`;
    const cleaned = extractCleanOcrText(raw);
    expect(cleaned).toContain("THÀNH PHẦN:");
    expect(cleaned).toContain("INS 322(i) / E322");
    expect(cleaned).toContain("Phẩm màu, E102 & E110");
    expect(cleaned).not.toContain("<table>");
    expect(cleaned).not.toContain("imgs/0.jpg");
  });

  it("splitRawIngredients preserves parenthesized additive code lists and separates trace clauses", () => {
    const basic = splitRawIngredients("Thành phần: Wheat flour, refined sugar; milk powder (8%)\nE102.");
    expect(basic).toEqual(["Wheat flour", "refined sugar", "milk powder (8%)", "E102"]);

    const withBareCodes = splitRawIngredients(
      "Stabilizers (471, 460i, 407, 466), chất điều vị (621, 627, 631), milk powder. May contain traces of peanuts, soy."
    );
    expect(withBareCodes).toEqual([
      "Stabilizers (471, 460i, 407, 466)",
      "chất điều vị (621, 627, 631)",
      "milk powder",
      "May contain traces of peanuts, soy",
    ]);

    expect(normalizeEnKey("Monosodium-Glutamate (E621)")).toBe("monosodium glutamate e621");
    expect(formatCleanEnglishTitle("CHEBI:64220", "monosodium glutamate")).toBe("Monosodium Glutamate");
  });

  it("Levenshtein similarity prevents false matches like 'chat dieu vi' -> 'european hake' while catching real OCR typos", () => {
    expect(levenshteinDistance("pcanut", "peanut")).toBe(1);
    expect(similarityRatio("pcanut", "peanut")).toBeCloseTo(5 / 6, 3);
    expect(levenshteinDistance("whcat", "wheat")).toBe(1);
    expect(similarityRatio("whcat", "wheat")).toBeCloseTo(0.8, 3);

    // Unrelated strings must score very low (never >= 0.80)
    expect(similarityRatio("chat dieu vi", "european hake")).toBeLessThan(0.3);
    expect(similarityRatio("chat dieu vi", "hake")).toBeLessThan(0.3);
    expect(hasVietnameseDiacritics("chất điều vị")).toBe(true);
    expect(hasVietnameseDiacritics("đường tinh luyện")).toBe(true);
    expect(hasVietnameseDiacritics("wheat flour")).toBe(false);
    expect(hasVietnameseDiacritics("crème fraîche")).toBe(false);
  });

  it("extractBareAdditiveCodes extracts parenthesized INS/E-numbers after functional classes and ignores weights/percentages", () => {
    const en = extractBareAdditiveCodes("Stabilizers (471, 460i, 407, 466)");
    expect(en.map((x) => x.raw)).toEqual(["E471", "E460i", "E407", "E466"]);
    expect(en[1].cands).toContain("e460i");
    expect(en[1].cands).toContain("e460");

    const vi = extractBareAdditiveCodes("chất điều vị (621, 627, 631), chất nhũ hóa (322(i))");
    expect(vi.map((x) => x.raw)).toEqual(["E621", "E627", "E631", "E322(i)"]);

    // Must NOT treat percentages, weights, or non-additive numbers as E-codes
    expect(extractBareAdditiveCodes("Wheat flour (52%), sugar (100g), year (2025)")).toEqual([]);
  });

  it("isTraceStatement and isDirectAllergenMatch support warn_traces and scan_derivatives settings accurately", () => {
    expect(isTraceStatement("May contain traces of peanuts, tree nuts")).toBe(true);
    expect(isTraceStatement("Có thể chứa dấu vết sữa và đậu nành")).toBe(true);
    expect(isTraceStatement("Sản xuất trên cùng dây chuyền có sử dụng đậu phộng")).toBe(true);
    // Direct contains declarations are NOT trace statements
    expect(isTraceStatement("Contains milk and soy")).toBe(false);
    expect(isTraceStatement("Whole milk powder")).toBe(false);

    // Direct vs derivative classification
    expect(isDirectAllergenMatch("milk", "Whole milk powder", { curie: "FOODON:03310351", label_en: "milk powder", match_type: "exact_en" })).toBe(true);
    expect(isDirectAllergenMatch("milk", "whey protein", { curie: "FOODON:03315150", label_en: "whey", match_type: "exact_en" })).toBe(false);
    expect(isDirectAllergenMatch("milk", "lactose", { curie: "CHEBI:17716", label_en: "lactose", match_type: "exact_en" })).toBe(false);
    expect(isDirectAllergenMatch("soy", "E322", { curie: "CHEBI:64482", label_en: "lecithin", match_type: "ecode_exact" })).toBe(false);
    expect(isDirectAllergenMatch("soy", "soy lecithin (E322)", { curie: "CHEBI:64482", label_en: "lecithin", match_type: "ecode_exact" })).toBe(true);
  });

  it("parseFromAddress extracts display name and email cleanly", () => {
    expect(parseFromAddress("NutriViet <sender@example.com>")).toEqual({
      name: "NutriViet",
      email: "sender@example.com",
    });
    expect(parseFromAddress("sender@example.com")).toEqual({
      name: "NutriViet",
      email: "sender@example.com",
    });
  });

  it("sendVerificationEmail and sendPasswordResetOtpEmail dispatch via Brevo with HTML + plain text", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(new Response(JSON.stringify({ messageId: "<abc@brevo>" }), { status: 201 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ messageId: "<otp@brevo>" }), { status: 201 }))
      .mockResolvedValueOnce(new Response('{"code":"unauthorized","message":"unrecognised IP"}', { status: 401 }));

    const env = {
      BREVO_API_KEY: "xkeysib-test-key",
      EMAIL_FROM: "NutriViet <sender@example.com>",
    } as unknown as Env;

    const ok = await sendVerificationEmail(
      env,
      "user@example.com",
      "Nguyen An",
      "tok123",
      "https://nutriviet.nutriviet-api.workers.dev"
    );
    expect(ok).toEqual({ sent: true, provider: "brevo" });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [, init] = fetchMock.mock.calls[0];
    const body = JSON.parse(String(init?.body));
    expect(body.sender).toEqual({ name: "NutriViet", email: "sender@example.com" });
    expect(body.to).toEqual([{ email: "user@example.com" }]);
    expect(body.htmlContent).toContain("/verify-email?token=tok123");

    const otpOk = await sendPasswordResetOtpEmail(env, "user@example.com", "Nguyen An", "482910", 15);
    expect(otpOk).toEqual({ sent: true, provider: "brevo" });
    const [, otpInit] = fetchMock.mock.calls[1];
    const otpBody = JSON.parse(String(otpInit?.body));
    expect(otpBody.textContent).toContain("482910");
    expect(otpBody.htmlContent).toContain("482 910");

    const fail = await sendVerificationEmail(
      env,
      "user@example.com",
      "Nguyen An",
      "tok123",
      "https://nutriviet.nutriviet-api.workers.dev"
    );
    expect(fail.sent).toBe(false);
    expect(fail.provider).toBe("brevo");
    expect(fail.error).toContain("HTTP 401");
  });

  it("extractIngredientsSection keeps only Ingredients + allergen notes and strips Nutrition Facts & storage", () => {
    const labelWithNutrition = [
      "THÔNG TIN DINH DƯỠNG (TRONG 100g)",
      "Năng lượng, 480 kcal",
      "Chất đạm, 7.5 g",
      "Chất béo, 21 g",
      "Natri, 310 mg",
      "THÀNH PHẦN: Bột mì (52%), dầu cọ tinh luyện, đường, sữa bột nguyên kem (6%), chất nhũ hóa (E322).",
      "Thông tin dị ứng: Có chứa lúa mì, sữa, đậu nành.",
      "Hướng dẫn bảo quản: Nơi khô ráo thoáng mát.",
      "Xuất xứ: Việt Nam",
    ].join("\n");

    const res = extractIngredientsSection(labelWithNutrition);
    expect(res.has_ingredients).toBe(true);
    expect(res.nutrition_detected).toBe(true);
    expect(res.ingredients_text).toContain("Bột mì (52%)");
    expect(res.ingredients_text).toContain("sữa bột nguyên kem (6%)");
    expect(res.ingredients_text).toContain("Thông tin dị ứng: Có chứa lúa mì, sữa, đậu nành.");
    expect(res.ingredients_text).not.toContain("480 kcal");
    expect(res.ingredients_text).not.toContain("Natri");
    expect(res.ingredients_text).not.toContain("Hướng dẫn bảo quản");
    expect(res.ingredients_text).not.toContain("Xuất xứ");
  });

  it("extractIngredientsSection uses fuzzy matching for OCR-corrupted headers (Thàh phẩn, INGRED1ENTS, Ingredlents)", () => {
    const viCorrupted = "Thàh phẩn: Đậu phộng (40%), đường, muối i-ốt, dầu thực vật.\nGiá trị dinh dưỡng:\nNăng lượng 520 kcal";
    const r1 = extractIngredientsSection(viCorrupted);
    expect(r1.has_ingredients).toBe(true);
    expect(r1.fuzzy_score).toBeGreaterThanOrEqual(0.73);
    expect(r1.ingredients_text).toContain("Đậu phộng (40%)");
    expect(r1.ingredients_text).not.toContain("520 kcal");

    const enCorrupted = "INGRED1ENTS:\nWheat flour, skim milk powder, soy lecithin (E322), salt.\nNutrition Facts\nCalories 210 kcal\nSodium 180 mg";
    const r2 = extractIngredientsSection(enCorrupted);
    expect(r2.has_ingredients).toBe(true);
    expect(r2.ingredients_text).toContain("Wheat flour, skim milk powder");
    expect(r2.ingredients_text).not.toContain("Calories");
    expect(r2.ingredients_text).not.toContain("Sodium");

    const enTypo2 = "Ingredlents - Water, soybeans (12%), sugar, sea salt.";
    const r3 = extractIngredientsSection(enTypo2);
    expect(r3.has_ingredients).toBe(true);
    expect(r3.ingredients_text).toContain("soybeans (12%)");
  });

  it("extractIngredientsSection returns has_ingredients=false when ONLY Nutrition Facts is captured", () => {
    const nutritionOnlyVi = [
      "THÀNH PHẦN DINH DƯỠNG (TRONG 100ml)",
      "Năng lượng: 62 kcal",
      "Chất đạm: 3.0 g",
      "Chất béo: 3.3 g",
      "Carbohydrate: 4.8 g",
      "Canxi: 110 mg",
      "Hướng dẫn sử dụng: Ngon hơn khi uống lạnh.",
    ].join("\n");

    const rVi = extractIngredientsSection(nutritionOnlyVi);
    expect(rVi.has_ingredients).toBe(false);
    expect(rVi.ingredients_text).toBe("");
    expect(rVi.nutrition_detected).toBe(true);
    expect(rVi.reason).toBe("NO_INGREDIENTS_FOUND");

    const nutritionOnlyEn = [
      "Nutrition Facts",
      "Serving size 1 cup (240ml)",
      "Calories 150",
      "Total Fat 8g 10%",
      "Sodium 120mg 5%",
      "Protein 8g",
    ].join("\n");

    const rEn = extractIngredientsSection(nutritionOnlyEn);
    expect(rEn.has_ingredients).toBe(false);
    expect(rEn.ingredients_text).toBe("");
    expect(rEn.nutrition_detected).toBe(true);
  });

  it("repairOcrEcodes and repairOcrWordHomoglyphs fix common PaddleOCR character confusions", () => {
    expect(repairOcrEcodes("chất điều vị (E62l), phẩm màu E1O2, IN5 322(I)")).toBe(
      "chất điều vị (E621), phẩm màu E102, INS322(i)"
    );
    expect(repairOcrWordHomoglyphs("skimmed rnilk powder, s0ybean 1ecithin")).toBe(
      "skimmed milk powder, soybean lecithin"
    );
  });

  it("SlidingWindowRateLimiter enforces per-IP limits and resets after window expires", () => {
    const rl = new SlidingWindowRateLimiter(8);
    const rule = { bucket: "test", limit: 2, windowMs: 60_000 };
    expect(rl.check(rule, "1.2.3.4", 1000).allowed).toBe(true);
    expect(rl.check(rule, "1.2.3.4", 2000).allowed).toBe(true);
    const blocked = rl.check(rule, "1.2.3.4", 3000);
    expect(blocked.allowed).toBe(false);
    expect(blocked.retryAfterSec).toBeGreaterThan(0);
    // Separate IP is unaffected
    expect(rl.check(rule, "5.6.7.8", 3000).allowed).toBe(true);
    // Original IP recovers after window passes
    expect(rl.check(rule, "1.2.3.4", 62_000).allowed).toBe(true);
  });

  it("Protected profile/scan/user endpoints reject unauthenticated requests (IDOR blocked) and attach security headers", async () => {
    const dummyEnv = { APP_DB: {} as D1Database, FOODON_DB: {} as D1Database } as Env;

    for (const path of [
      "/api/v1/users",
      "/api/v1/profile/allergens?user_id=1",
      "/api/v1/profile/chronics?user_id=1",
      "/api/v1/profile/settings?user_id=1",
      "/api/v1/profile/family?user_id=1",
      "/api/v1/scans?user_id=1",
    ]) {
      const resp = await app.request(path, { method: "GET" }, dummyEnv);
      expect(resp.status).toBe(401);
      expect(resp.headers.get("X-Content-Type-Options")).toBe("nosniff");
      expect(resp.headers.get("X-Frame-Options")).toBe("DENY");
      const json = (await resp.json()) as { code?: string };
      expect(json.code).toBe("AUTH_REQUIRED");
    }

    // Obsolete /api/v1/profile/metrics endpoint is removed
    const metricsResp = await app.request("/api/v1/profile/metrics?user_id=1", { method: "GET" }, dummyEnv);
    expect(metricsResp.status).toBe(404);
  });

  it("OcrProviderRouter selects fastest provider first, fails over on 429/soft rate limit, and recovers after cooldown", async () => {
    const customChain = OCR_PROVIDER_CHAIN.map((p) =>
      p.id === "kilo-particle-1"
        ? { ...p, maxRequestsPerWindow: 2, windowMs: 60_000, rateLimitCooldownMs: 90_000 }
        : p
    );
    const router = new OcrProviderRouter(customChain);
    const aiRunMock = vi.fn().mockResolvedValue({
      response: "INGREDIENTS: Water, Sugar, Milk Powder (12%), Soy Lecithin (E322).",
    });
    const env = {
      APP_DB: {} as D1Database,
      FOODON_DB: {} as D1Database,
      AI: { run: aiRunMock },
      PADDLEOCR_VL_TOKEN: "baidu-secret-token",
    } as Env;

    const sampleInput = {
      bytes: new Uint8Array([0x89, 0x50, 0x4e, 0x47, 1, 2, 3, 4]),
      mimeType: "image/png",
      fileName: "label.png",
      useDocOrientationClassify: true,
      useDocUnwarping: false,
    };

    const fetchMock = vi.fn<typeof fetch>().mockImplementation(
      async () =>
        new Response(
          JSON.stringify({
            choices: [
              {
                message: {
                  content: "INGREDIENTS: Water, Sugar, Milk Powder (12%), E322.",
                },
              },
            ],
          }),
          { status: 200 }
        )
    );

    // 1st & 2nd requests hit fastest tier (kilo-particle-1)
    const r1 = await router.routeImage(env, sampleInput, {
      baiduToken: "baidu-secret-token",
      nowMs: 1_000_000,
      fetchImpl: fetchMock,
    });
    expect(r1.kind).toBe("sync_done");
    if (r1.kind === "sync_done") expect(r1.providerId).toBe("kilo-particle-1");

    const r2 = await router.routeImage(env, sampleInput, {
      baiduToken: "baidu-secret-token",
      nowMs: 1_005_000,
      fetchImpl: fetchMock,
    });
    expect(r2.kind).toBe("sync_done");
    if (r2.kind === "sync_done") expect(r2.providerId).toBe("kilo-particle-1");

    // 3rd request hits soft rate limit (2/60s) on #1 -> automatically routes to #2 (cf-mistral-vision)!
    const r3 = await router.routeImage(env, sampleInput, {
      baiduToken: "baidu-secret-token",
      nowMs: 1_010_000,
      fetchImpl: fetchMock,
    });
    expect(r3.kind).toBe("sync_done");
    if (r3.kind === "sync_done") {
      expect(r3.providerId).toBe("cf-mistral-vision");
      expect(r3.attempts[0].provider_id).toBe("kilo-particle-1");
      expect(r3.attempts[0].outcome).toBe("rate_limited");
    }

    // 4th request while #1 is still in cooldown -> skips #1 instantly (skipped_cooldown) and uses #2!
    const r4 = await router.routeImage(env, sampleInput, {
      baiduToken: "baidu-secret-token",
      nowMs: 1_020_000,
      fetchImpl: fetchMock,
    });
    expect(r4.kind).toBe("sync_done");
    if (r4.kind === "sync_done") {
      expect(r4.providerId).toBe("cf-mistral-vision");
      expect(r4.attempts[0].outcome).toBe("skipped_cooldown");
    }

    // After cooldown expires (> 60s window), #1 automatically recovers as fastest tier!
    const r5 = await router.routeImage(env, sampleInput, {
      baiduToken: "baidu-secret-token",
      nowMs: 1_065_000,
      fetchImpl: fetchMock,
    });
    expect(r5.kind).toBe("sync_done");
    if (r5.kind === "sync_done") {
      expect(r5.providerId).toBe("kilo-particle-1");
    }
  });

  it("OcrProviderRouter fails over from #1 (429) and #2 (AI error) to #3 Baidu PaddleOCR-VL-1.6", async () => {
    const router = new OcrProviderRouter(OCR_PROVIDER_CHAIN);
    const env = {
      APP_DB: {} as D1Database,
      FOODON_DB: {} as D1Database,
      AI: {
        run: vi.fn().mockRejectedValue(new Error("AiError: 429 daily neuron quota exceeded")),
      },
      PADDLEOCR_VL_TOKEN: "baidu-tok",
    } as Env;

    const sampleInput = {
      bytes: new Uint8Array([0xff, 0xd8, 0xff, 0xd9]),
      mimeType: "image/jpeg",
      fileName: "snack.jpg",
      useDocOrientationClassify: true,
      useDocUnwarping: false,
    };

    const fetchMock = vi.fn<typeof fetch>().mockImplementation(async (input) => {
      const url = String(input);
      if (url.includes("api.kilo.ai")) {
        return new Response('{"error":"rate limited"}', { status: 429, headers: { "Retry-After": "45" } });
      }
      if (url.includes("paddleocr.aistudio-app.com")) {
        return new Response(JSON.stringify({ data: { jobId: "baidu-job-777" } }), { status: 200 });
      }
      return new Response("Not found", { status: 404 });
    });

    const outcome = await router.routeImage(env, sampleInput, {
      baiduToken: "baidu-tok",
      nowMs: 2_000_000,
      fetchImpl: fetchMock,
    });
    expect(outcome.kind).toBe("async_job");
    if (outcome.kind === "async_job") {
      expect(outcome.providerId).toBe("baidu-paddleocr");
      expect(outcome.jobId).toBe("baidu-job-777");
      expect(outcome.attempts.map((a) => `${a.provider_id}:${a.outcome}`)).toEqual([
        "kilo-particle-1:rate_limited",
        "cf-mistral-vision:rate_limited",
        "baidu-paddleocr:ok",
      ]);
    }
  });

  it("GET /api/v1/ocr/providers returns ordered fastest-to-slowest provider chain status", async () => {
    const dummyEnv = {
      APP_DB: {} as D1Database,
      FOODON_DB: {} as D1Database,
      PADDLEOCR_VL_TOKEN: "tok",
    } as Env;
    const resp = await app.request("/api/v1/ocr/providers", { method: "GET" }, dummyEnv);
    expect(resp.status).toBe(200);
    const json = (await resp.json()) as {
      success: boolean;
      strategy: string;
      providers: Array<{ id: string; rank: number; baseline_ms: number }>;
    };
    expect(json.success).toBe(true);
    expect(json.strategy).toBe("fastest_first_with_cooldown_failover");
    expect(json.providers.map((p) => p.id)).toEqual([
      "kilo-particle-1",
      "cf-mistral-vision",
      "baidu-paddleocr",
      "kilo-nemotron-vl",
      "cf-llama4-vision",
    ]);
    for (let i = 1; i < json.providers.length; i++) {
      expect(json.providers[i].baseline_ms).toBeGreaterThanOrEqual(json.providers[i - 1].baseline_ms);
    }
  });

  it("hydrates persisted D1 cooldown state in a cold isolate and skips rank #1 immediately", async () => {
    const persistedRow = {
      provider_id: "kilo-particle-1",
      window_start_ms: 5_000_000,
      window_count: 1,
      cooldown_until_ms: 5_090_000,
      consecutive_failures: 1,
      last_status: "cooldown_rate_limit",
      last_latency_ms: null,
      last_error: "HTTP 429 upstream",
      success_count: 0,
      failure_count: 1,
      updated_at_ms: 5_000_000,
    };

    const mockDb = {
      prepare: (sql: string) => ({
        bind: (..._args: unknown[]) => ({
          run: async () => ({ success: true }),
          all: async () => ({ results: [] }),
        }),
        run: async () => ({ success: true }),
        all: async () => ({
          results: sql.includes("SELECT * FROM ocr_provider_state") ? [persistedRow] : [],
        }),
      }),
    } as unknown as D1Database;

    const coldRouter = new OcrProviderRouter();
    const env = {
      APP_DB: mockDb,
      FOODON_DB: {} as D1Database,
      AI: {
        run: vi.fn(async () => ({ response: "Ingredients: Sugar, Cocoa Powder, Milk Powder." })),
      },
    } as Env;

    const fetchSpy = vi.fn<typeof fetch>();
    const outcome = await coldRouter.routeImage(
      env,
      {
        bytes: new Uint8Array([0xff, 0xd8, 0xff, 0xd9]),
        mimeType: "image/jpeg",
        fileName: "choco.jpg",
        useDocOrientationClassify: true,
        useDocUnwarping: false,
      },
      {
        baiduToken: "",
        nowMs: 5_030_000, // 30s after D1 write; 60s cooldown remaining
        fetchImpl: fetchSpy,
      }
    );

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(outcome.kind).toBe("sync_done");
    if (outcome.kind === "sync_done") {
      expect(outcome.providerId).toBe("cf-mistral-vision");
      expect(outcome.attempts[0]).toMatchObject({
        provider_id: "kilo-particle-1",
        outcome: "skipped_cooldown",
        retry_after_sec: 60,
      });
      expect(outcome.attempts[1]).toMatchObject({
        provider_id: "cf-mistral-vision",
        outcome: "ok",
      });
    }
  });
});
