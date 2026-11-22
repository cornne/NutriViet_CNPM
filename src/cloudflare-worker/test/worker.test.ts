import { describe, expect, it } from "vitest";
import { calculateMetricsInfo } from "../src/auth_profile";
import { hashPassword, verifyPassword } from "../src/crypto";
import { formatCleanEnglishTitle, normalizeEnKey, splitRawIngredients } from "../src/foodon";
import { extractCleanOcrText } from "../src/ocr_proxy";

describe("NutriViet Cloudflare Worker core utilities", () => {
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
});

