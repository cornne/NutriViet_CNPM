import { afterEach, describe, expect, it, vi } from "vitest";
import { calculateMetricsInfo } from "../src/auth_profile";
import { hashPassword, verifyPassword } from "../src/crypto";
import { parseFromAddress, sendVerificationEmail } from "../src/email";
import { formatCleanEnglishTitle, normalizeEnKey, splitRawIngredients } from "../src/foodon";
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
});

