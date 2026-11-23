import { afterEach, describe, expect, it, vi } from "vitest";
import { calculateMetricsInfo } from "../src/auth_profile";
import { hashPassword, verifyPassword } from "../src/crypto";
import { parseFromAddress, sendVerificationEmail } from "../src/email";
import {
  formatCleanEnglishTitle,
  normalizeEnKey,
  repairOcrEcodes,
  repairOcrWordHomoglyphs,
  splitRawIngredients,
} from "../src/foodon";
import { extractIngredientsSection } from "../src/ingredient_extractor";
import { extractCleanOcrText } from "../src/ocr_proxy";
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

  it("splitRawIngredients and FoodOn title formatting work cleanly", () => {
    const tokens = splitRawIngredients("Thành phần: Wheat flour, refined sugar; milk powder (8%)\nE102.");
    expect(tokens).toEqual(["Wheat flour", "refined sugar", "milk powder (8%)", "E102"]);
    expect(normalizeEnKey("Monosodium-Glutamate (E621)")).toBe("monosodium glutamate e621");
    expect(formatCleanEnglishTitle("CHEBI:64220", "monosodium glutamate")).toBe("Monosodium Glutamate");
  });

  it("calculateMetricsInfo computes WHO/VN BMI and TDEE accurately", () => {
    const info = calculateMetricsInfo(24, "male", 170, 62, "moderate");
    expect(info.bmi).toBe(21.5);
    expect(info.bmi_status).toContain("Cân đối");
    expect(info.tdee).toBeGreaterThan(2000);
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

  it("sendVerificationEmail dispatches via Brevo with HTML + plain text and surfaces HTTP errors", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(new Response(JSON.stringify({ messageId: "<abc@brevo>" }), { status: 201 }))
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
    expect(body.textContent).toContain("/verify-email?token=tok123");

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
    expect(fail.error).toContain("unrecognised IP");
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

  it("extractIngredientsSection returns has_ingredients=false when ONLY Nutrition Facts (including Thành phần dinh dưỡng) is captured", () => {
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
});

