import { Hono } from "hono";
import { authenticateViewer, extractBearerToken, requireAdmin } from "./community";
import {
  hashPassword,
  randomNumericOtp,
  randomUrlSafeToken,
  sha256Hex,
  timingSafeEqualHex,
  verifyPassword,
} from "./crypto";
import { isEmailProviderConfigured, sendPasswordResetOtpEmail, sendVerificationEmail } from "./email";
import { D1FoodOnEngine, splitRawIngredients, type EvaluationOptions } from "./foodon";
import type { Env, UserRow } from "./types";

const HTML_VERIFIED_SUCCESS = `<!DOCTYPE html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Xác Thực Thành Công - NutriViet</title>
<style>body{font-family:-apple-system,sans-serif;background:#ECFDF5;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:20px}.card{background:#fff;padding:40px 30px;border-radius:20px;box-shadow:0 10px 25px rgba(16,185,129,.12);max-width:420px;text-align:center}.icon{width:72px;height:72px;background:#10B981;color:#fff;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:36px;margin:0 auto 20px}h1{color:#065F46;font-size:22px;margin:0 0 12px}p{color:#4B5563;font-size:15px;line-height:1.6}</style>
</head><body><div class="card"><div class="icon">✓</div><h1>Tài Khoản Đã Kích Hoạt!</h1><p>Email của bạn đã được xác thực thành công. Bạn có thể quay lại ứng dụng <strong>NutriViet</strong> và đăng nhập ngay bây giờ.</p></div></body></html>`;

const HTML_VERIFIED_FAIL = `<!DOCTYPE html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Liên Kết Không Hợp Lệ - NutriViet</title>
<style>body{font-family:-apple-system,sans-serif;background:#FEF2F2;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:20px}.card{background:#fff;padding:40px 30px;border-radius:20px;box-shadow:0 10px 25px rgba(239,68,68,.12);max-width:420px;text-align:center}.icon{width:72px;height:72px;background:#EF4444;color:#fff;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:36px;margin:0 auto 20px}h1{color:#991B1B;font-size:22px;margin:0 0 12px}p{color:#4B5563;font-size:15px;line-height:1.6}</style>
</head><body><div class="card"><div class="icon">✕</div><h1>Liên Kết Không Hợp Lệ</h1><p>Liên kết xác thực không tồn tại hoặc đã hết hạn. Vui lòng mở ứng dụng NutriViet và yêu cầu gửi lại.</p></div></body></html>`;

const PASSWORD_RESET_TTL_MINUTES = 15;

function utcNowIso(): string {
  return new Date().toISOString();
}

export function encodeResetTokenRecord(otpHash: string, expiresAtIso: string): string {
  return `${otpHash}|${expiresAtIso}`;
}

export function parseResetTokenRecord(stored: string | null | undefined): { otpHash: string; expiresAtMs: number } | null {
  if (!stored || !stored.includes("|")) return null;
  const [otpHash, expiresIso] = stored.split("|", 2);
  if (!otpHash || !expiresIso || otpHash.length !== 64) return null;
  const expiresAtMs = Date.parse(expiresIso);
  if (!Number.isFinite(expiresAtMs)) return null;
  return { otpHash: otpHash.toLowerCase(), expiresAtMs };
}

export async function hashPasswordResetOtp(userId: number, otp: string): Promise<string> {
  return sha256Hex(`nv-reset:${userId}:${otp.replace(/\s+/g, "")}`);
}

export async function verifyPasswordResetRecord(
  userId: number,
  otpInput: string,
  storedRecord: string | null | undefined,
  nowMs = Date.now()
): Promise<boolean> {
  const parsed = parseResetTokenRecord(storedRecord);
  if (!parsed || nowMs > parsed.expiresAtMs) return false;
  const cleanOtp = (otpInput || "").replace(/\s+/g, "");
  if (!/^\d{6}$/.test(cleanOtp)) return false;
  const candidateHash = await hashPasswordResetOtp(userId, cleanOtp);
  return timingSafeEqualHex(candidateHash, parsed.otpHash);
}

async function fetchUserEvalOptions(db: D1Database, uid: number): Promise<EvaluationOptions> {
  const row = await db
    .prepare("SELECT scan_derivatives, warn_traces FROM user_settings WHERE user_id = ?")
    .bind(uid)
    .first<{ scan_derivatives: number; warn_traces: number }>();
  if (!row) return { scanDerivatives: true, warnTraces: true };
  return {
    scanDerivatives: Number(row.scan_derivatives) !== 0,
    warnTraces: Number(row.warn_traces) !== 0,
  };
}

async function fetchUserScanSummary(db: D1Database, uid: number) {
  const res = await db
    .prepare(
      "SELECT id, member_name, label_title, raw_text, verdict, risk_level, risk_label_vi, additive_count, warning_count, result_json, created_at FROM scan_history WHERE user_id = ? ORDER BY id DESC LIMIT 50"
    )
    .bind(uid)
    .all<Record<string, unknown>>();

  const monthPrefix = new Date().toISOString().slice(0, 7);
  let monthlyScans = 0;
  let monthlyWarnings = 0;
  let warningScans = 0;

  const scans = res.results.map((r) => {
    const copy: Record<string, unknown> = { ...r };
    const rawJson = String(copy.result_json ?? "{}");
    delete copy.result_json;
    try {
      copy.evaluation = JSON.parse(rawJson);
    } catch {
      copy.evaluation = {};
    }
    const wc = Number(copy.warning_count ?? 0);
    if (wc > 0 || copy.risk_level === "high") warningScans++;
    if (String(copy.created_at ?? "").startsWith(monthPrefix)) {
      monthlyScans++;
      monthlyWarnings += wc;
    }
    return copy;
  });

  return {
    scans,
    total_scans: scans.length,
    warning_scans: warningScans,
    monthly_scans: monthlyScans,
    monthly_warnings: monthlyWarnings,
  };
}

export async function issueSessionToken(db: D1Database, userId: number): Promise<string> {
  const token = randomUrlSafeToken(32);
  await db
    .prepare("INSERT INTO user_sessions (token, user_id, created_at) VALUES (?, ?, ?)")
    .bind(token, userId, utcNowIso())
    .run();
  return token;
}

export function registerAuthAndProfileRoutes(app: Hono<{ Bindings: Env }>) {
  // 1. Email Verification Web Click Route
  app.get("/verify-email", async (c) => {
    const token = (c.req.query("token") || "").trim();
    if (token) {
      const row = await c.env.APP_DB.prepare("SELECT id FROM users WHERE verification_token = ?")
        .bind(token)
        .first<{ id: number }>();
      if (row) {
        await c.env.APP_DB.prepare("UPDATE users SET is_verified = 1, verification_token = NULL WHERE id = ?")
          .bind(row.id)
          .run();
        return c.html(HTML_VERIFIED_SUCCESS, 200);
      }
    }
    return c.html(HTML_VERIFIED_FAIL, 400);
  });

  // 2. Users inspection endpoint (Strictly Admin-only — eliminates PII/IDOR leak)
  app.get("/api/v1/users", async (c) => {
    const auth = await requireAdmin(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const uidParam = c.req.query("user_id");
    const emailParam = c.req.query("email");

    if (uidParam || emailParam) {
      const uRow = uidParam
        ? await c.env.APP_DB.prepare("SELECT id, full_name, email, is_verified, role, is_banned, created_at FROM users WHERE id = ?")
            .bind(Number(uidParam))
            .first<Record<string, unknown>>()
        : await c.env.APP_DB.prepare("SELECT id, full_name, email, is_verified, role, is_banned, created_at FROM users WHERE email = ?")
            .bind(String(emailParam).trim().toLowerCase())
            .first<Record<string, unknown>>();
      if (!uRow) return c.json({ success: false, message: "Không tìm thấy người dùng." }, 404);

      const targetUid = Number(uRow.id);
      const als = await c.env.APP_DB.prepare(
        "SELECT allergen_code as code, allergen_name as name, severity FROM user_allergens WHERE user_id = ? ORDER BY id ASC"
      )
        .bind(targetUid)
        .all();

      uRow.allergens = als.results;
      return c.json({ success: true, user: uRow });
    }

    const usersRes = await c.env.APP_DB.prepare(
      "SELECT id, full_name, email, is_verified, role, is_banned, created_at FROM users ORDER BY id ASC"
    ).all<Record<string, unknown>>();
    return c.json({ success: true, users: usersRes.results });
  });

  // 3. Register
  app.post("/api/v1/auth/register", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const fullName = String(body.full_name || "").trim();
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");

    if (!fullName || !email || !password) {
      return c.json({ success: false, message: "Vui lòng nhập đầy đủ thông tin", code: "MISSING_FIELDS" }, 400);
    }
    if (password.length < 6) {
      return c.json({ success: false, message: "Mật khẩu phải từ 6 ký tự trở lên", code: "WEAK_PASSWORD" }, 400);
    }

    const dup = await c.env.APP_DB.prepare("SELECT id FROM users WHERE email = ?").bind(email).first();
    if (dup) {
      return c.json({ success: false, message: "Email này đã được sử dụng", code: "EMAIL_ALREADY_EXISTS" }, 409);
    }

    const { hash, salt } = await hashPassword(password);
    const verifyToken = randomUrlSafeToken(32);
    const now = utcNowIso();

    const hasMailProvider = isEmailProviderConfigured(c.env);
    const autoVerify = !hasMailProvider || String(c.env.AUTO_VERIFY_EMAIL || "").toLowerCase() === "true";
    const isVerified = autoVerify ? 1 : 0;

    const ins = await c.env.APP_DB.prepare(
      "INSERT INTO users (full_name, email, password_hash, salt, is_verified, verification_token, role, is_banned, created_at) VALUES (?, ?, ?, ?, ?, ?, 'user', 0, ?)"
    )
      .bind(fullName, email, hash, salt, isVerified, verifyToken, now)
      .run();
    const userId = Number(ins.meta.last_row_id);

    if (hasMailProvider && !autoVerify) {
      const origin = c.env.PUBLIC_BASE_URL || new URL(c.req.url).origin;
      const mailRes = await sendVerificationEmail(c.env, email, fullName, verifyToken, origin);
      if (!mailRes.sent) {
        await c.env.APP_DB.prepare("DELETE FROM users WHERE id = ?").bind(userId).run();
        return c.json(
          {
            success: false,
            code: "EMAIL_DISPATCH_FAILED",
            message: "Không thể gửi email xác thực lúc này. Vui lòng thử lại sau.",
            provider: mailRes.provider,
            detail: mailRes.error,
          },
          502
        );
      }
    }

    return c.json(
      {
        success: true,
        requires_verification: !autoVerify,
        message: autoVerify
          ? "Đăng ký thành công! Tài khoản của bạn đã được kích hoạt tự động — bạn có thể đăng nhập ngay."
          : "Đăng ký thành công! Vui lòng kiểm tra hộp thư để kích hoạt tài khoản.",
        user: {
          id: userId,
          full_name: fullName,
          email,
          is_verified: isVerified,
          role: "user",
          is_banned: 0,
        },
      },
      201
    );
  });

  // 4. Login
  app.post("/api/v1/auth/login", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");

    const user = await c.env.APP_DB.prepare(
      "SELECT id, full_name, email, password_hash, salt, is_verified, role, is_banned FROM users WHERE email = ?"
    )
      .bind(email)
      .first<UserRow>();

    if (!user || !(await verifyPassword(password, user.password_hash, user.salt))) {
      return c.json(
        { success: false, code: "INVALID_CREDENTIALS", message: "Email hoặc mật khẩu không chính xác." },
        401
      );
    }
    if (Number(user.is_banned || 0) === 1) {
      return c.json(
        { success: false, code: "ACCOUNT_BANNED", message: "Tài khoản này đã bị quản trị viên tạm khóa." },
        403
      );
    }
    if (Number(user.is_verified || 0) !== 1) {
      return c.json(
        {
          success: false,
          code: "EMAIL_NOT_VERIFIED",
          message: "Tài khoản chưa được kích hoạt qua email. Vui lòng xác thực email trước khi đăng nhập.",
        },
        403
      );
    }

    const token = await issueSessionToken(c.env.APP_DB, user.id);
    return c.json({
      success: true,
      token,
      user: {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        is_verified: 1,
        role: user.role || "user",
        is_banned: 0,
      },
    });
  });

  // 4b. Logout (revokes active session token in D1)
  app.post("/api/v1/auth/logout", async (c) => {
    const token = extractBearerToken(c.req.raw);
    if (token) {
      await c.env.APP_DB.prepare("DELETE FROM user_sessions WHERE token = ?").bind(token).run();
    }
    return c.json({ success: true, message: "Đã đăng xuất thành công." });
  });

  // 5. Resend Verification
  app.post("/api/v1/auth/resend-verification", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const email = String(body.email || "").trim().toLowerCase();
    const user = await c.env.APP_DB.prepare("SELECT id, full_name, email, is_verified FROM users WHERE email = ?")
      .bind(email)
      .first<UserRow>();

    if (!user) return c.json({ success: false, message: "Không tìm thấy tài khoản với email này." }, 404);
    if (Number(user.is_verified) === 1) {
      return c.json({ success: true, message: "Tài khoản này đã được kích hoạt rồi. Bạn có thể đăng nhập ngay!" });
    }

    if (!isEmailProviderConfigured(c.env)) {
      await c.env.APP_DB.prepare("UPDATE users SET is_verified = 1 WHERE id = ?").bind(user.id).run();
      return c.json({ success: true, message: "Tài khoản đã được kích hoạt tự động. Bạn có thể đăng nhập ngay!" });
    }

    const newToken = randomUrlSafeToken(32);
    await c.env.APP_DB.prepare("UPDATE users SET verification_token = ? WHERE id = ?")
      .bind(newToken, user.id)
      .run();
    const origin = c.env.PUBLIC_BASE_URL || new URL(c.req.url).origin;
    const mailRes = await sendVerificationEmail(c.env, user.email, user.full_name, newToken, origin);
    if (!mailRes.sent) {
      return c.json(
        {
          success: false,
          code: "EMAIL_DISPATCH_FAILED",
          message: "Không thể gửi lại email kích hoạt lúc này. Vui lòng thử lại sau.",
          provider: mailRes.provider,
          detail: mailRes.error,
        },
        502
      );
    }
    return c.json({ success: true, message: "Đã gửi lại email kích hoạt vào hộp thư của bạn." });
  });

  // 6. Forgot Password (6-digit 15-minute OTP, NEVER overwrites real password or leaks OTP in JSON)
  app.post("/api/v1/auth/forgot-password", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const email = String(body.email || "").trim().toLowerCase();
    if (!email || !email.includes("@")) {
      return c.json({ success: false, message: "Vui lòng nhập địa chỉ email hợp lệ." }, 400);
    }

    const user = await c.env.APP_DB.prepare("SELECT id, full_name, email FROM users WHERE email = ?")
      .bind(email)
      .first<UserRow>();

    if (user) {
      if (!isEmailProviderConfigured(c.env)) {
        return c.json(
          {
            success: false,
            code: "EMAIL_NOT_CONFIGURED",
            message: "Hệ thống gửi email chưa sẵn sàng nên chưa thể cấp mã khôi phục mật khẩu.",
          },
          503
        );
      }

      const otp = randomNumericOtp(6);
      const otpHash = await hashPasswordResetOtp(user.id, otp);
      const expiresAtIso = new Date(Date.now() + PASSWORD_RESET_TTL_MINUTES * 60_000).toISOString();
      const record = encodeResetTokenRecord(otpHash, expiresAtIso);

      await c.env.APP_DB.prepare("UPDATE users SET reset_token = ? WHERE id = ?")
        .bind(record, user.id)
        .run();

      const mailRes = await sendPasswordResetOtpEmail(
        c.env,
        user.email,
        user.full_name,
        otp,
        PASSWORD_RESET_TTL_MINUTES
      );
      if (!mailRes.sent) {
        await c.env.APP_DB.prepare("UPDATE users SET reset_token = NULL WHERE id = ?").bind(user.id).run();
        return c.json(
          {
            success: false,
            code: "EMAIL_DISPATCH_FAILED",
            message: "Không thể gửi mã xác thực tới hộp thư lúc này. Vui lòng thử lại sau.",
          },
          502
        );
      }
    }

    return c.json({
      success: true,
      otp_sent: true,
      expires_in_minutes: PASSWORD_RESET_TTL_MINUTES,
      message:
        "Nếu email tồn tại trong hệ thống, mã OTP 6 chữ số đã được gửi tới hộp thư của bạn (hiệu lực 15 phút).",
    });
  });

  // 6b. Reset Password with 6-digit OTP
  app.post("/api/v1/auth/reset-password", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const email = String(body.email || "").trim().toLowerCase();
    const otp = String(body.otp || "").replace(/\s+/g, "");
    const newPwd = String(body.new_password || "");

    if (!email || !otp || !newPwd) {
      return c.json({ success: false, message: "Vui lòng nhập đầy đủ email, mã OTP và mật khẩu mới." }, 400);
    }
    if (newPwd.length < 6) {
      return c.json({ success: false, message: "Mật khẩu mới phải từ 6 ký tự trở lên." }, 400);
    }

    const user = await c.env.APP_DB.prepare("SELECT id, reset_token FROM users WHERE email = ?")
      .bind(email)
      .first<Pick<UserRow, "id" | "reset_token">>();

    const valid = user ? await verifyPasswordResetRecord(user.id, otp, user.reset_token) : false;
    if (!user || !valid) {
      return c.json(
        {
          success: false,
          code: "INVALID_OR_EXPIRED_OTP",
          message: "Mã OTP không chính xác hoặc đã hết hạn. Vui lòng kiểm tra lại.",
        },
        400
      );
    }

    const { hash, salt } = await hashPassword(newPwd);
    await c.env.APP_DB.batch([
      c.env.APP_DB.prepare(
        "UPDATE users SET password_hash = ?, salt = ?, reset_token = NULL, is_verified = 1 WHERE id = ?"
      ).bind(hash, salt, user.id),
      c.env.APP_DB.prepare("DELETE FROM user_sessions WHERE user_id = ?").bind(user.id),
    ]);

    return c.json({
      success: true,
      message: "Đặt lại mật khẩu thành công! Vui lòng đăng nhập bằng mật khẩu mới.",
    });
  });

  // 7. Change Password (Authenticated — derives user solely from session token)
  app.post("/api/v1/auth/change-password", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const currentPwd = String(body.current_password || "");
    const newPwd = String(body.new_password || "");

    if (!currentPwd || !newPwd) {
      return c.json({ success: false, message: "Vui lòng nhập mật khẩu hiện tại và mật khẩu mới." }, 400);
    }
    if (newPwd.length < 6) {
      return c.json({ success: false, message: "Mật khẩu mới phải từ 6 ký tự trở lên." }, 400);
    }

    const user = await c.env.APP_DB.prepare("SELECT id, password_hash, salt FROM users WHERE id = ?")
      .bind(auth.viewer.id)
      .first<UserRow>();

    if (!user || !(await verifyPassword(currentPwd, user.password_hash, user.salt))) {
      return c.json({ success: false, message: "Mật khẩu hiện tại không chính xác." }, 400);
    }

    const { hash, salt } = await hashPassword(newPwd);
    await c.env.APP_DB.batch([
      c.env.APP_DB.prepare("UPDATE users SET password_hash = ?, salt = ?, is_verified = 1 WHERE id = ?").bind(
        hash,
        salt,
        user.id
      ),
      c.env.APP_DB.prepare("DELETE FROM user_sessions WHERE user_id = ? AND token != ?").bind(
        user.id,
        auth.token || ""
      ),
    ]);
    return c.json({ success: true, message: "Đổi mật khẩu thành công! Hãy ghi nhớ mật khẩu mới của bạn." });
  });

  // 8. Update Profile Name (Authenticated — derives user solely from session token)
  app.post("/api/v1/auth/update-profile", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const fullName = String(body.full_name || "").trim();
    if (!fullName) return c.json({ success: false, message: "Vui lòng nhập họ và tên hợp lệ." }, 400);

    await c.env.APP_DB.prepare("UPDATE users SET full_name = ? WHERE id = ?")
      .bind(fullName.slice(0, 120), auth.viewer.id)
      .run();
    const user = await c.env.APP_DB.prepare("SELECT id, full_name, email, is_verified, role, is_banned FROM users WHERE id = ?")
      .bind(auth.viewer.id)
      .first();
    return c.json({ success: true, message: "Cập nhật họ và tên thành công!", user: user ?? {} });
  });

  // 9. Profile Allergens (Authenticated + re-evaluates existing scans using user settings)
  app.get("/api/v1/profile/allergens", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const res = await c.env.APP_DB.prepare(
      "SELECT allergen_code as code, allergen_name as name, severity, updated_at FROM user_allergens WHERE user_id = ? ORDER BY id ASC"
    )
      .bind(auth.viewer.id)
      .all();
    return c.json({ success: true, allergens: res.results });
  });

  app.post("/api/v1/profile/allergens", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const uid = auth.viewer.id;
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const alList = Array.isArray(body.allergens) ? body.allergens : [];
    const now = utcNowIso();

    const stmts: D1PreparedStatement[] = [
      c.env.APP_DB.prepare("DELETE FROM user_allergens WHERE user_id = ?").bind(uid),
    ];
    const normalizedAls: Array<Record<string, unknown>> = [];
    for (const item of alList) {
      let code = "";
      let name = "";
      let sev = "high";
      if (item && typeof item === "object") {
        const rec = item as Record<string, unknown>;
        code = String(rec.code ?? rec.allergen_code ?? "").trim();
        name = String(rec.name ?? rec.allergen_name ?? code).trim();
        sev = String(rec.severity ?? "high").toLowerCase();
      } else {
        code = String(item || "").trim();
        name = code;
      }
      if (code) {
        normalizedAls.push({ code, name, severity: sev });
        stmts.push(
          c.env.APP_DB.prepare(
            "INSERT INTO user_allergens (user_id, allergen_code, allergen_name, severity, updated_at) VALUES (?, ?, ?, ?, ?)"
          ).bind(uid, code, name, sev, now)
        );
      }
    }
    await c.env.APP_DB.batch(stmts);

    // Re-evaluate existing scan_history rows so previous labels immediately reflect new allergy profile & settings
    const [chRes, scanRes, evalOpts] = await Promise.all([
      c.env.APP_DB.prepare("SELECT chronic_code FROM user_chronics WHERE user_id = ?")
        .bind(uid)
        .all<{ chronic_code: string }>(),
      c.env.APP_DB.prepare("SELECT id, raw_text FROM scan_history WHERE user_id = ? ORDER BY id DESC LIMIT 25")
        .bind(uid)
        .all<{ id: number; raw_text: string }>(),
      fetchUserEvalOptions(c.env.APP_DB, uid),
    ]);
    const userChs = chRes.results.map((r) => r.chronic_code);
    if (scanRes.results.length > 0) {
      const eng = new D1FoodOnEngine(c.env.FOODON_DB);
      const updStmts: D1PreparedStatement[] = [];
      for (const srow of scanRes.results) {
        const toks = splitRawIngredients(srow.raw_text || "");
        const ev = await eng.evaluatePackagingLabel(toks, normalizedAls, userChs, evalOpts);
        updStmts.push(
          c.env.APP_DB.prepare(
            "UPDATE scan_history SET verdict = ?, risk_level = ?, risk_label_vi = ?, warning_count = ?, result_json = ? WHERE id = ?"
          ).bind(
            String(ev.verdict),
            String(ev.risk_level),
            String(ev.risk_label_vi),
            Number(ev.warning_count),
            JSON.stringify(ev),
            srow.id
          )
        );
      }
      if (updStmts.length > 0) await c.env.APP_DB.batch(updStmts);
    }

    return c.json({ success: true, message: "Đã lưu hồ sơ dị ứng thành công." });
  });

  // 10. Profile Chronics (Authenticated)
  app.get("/api/v1/profile/chronics", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const res = await c.env.APP_DB.prepare(
      "SELECT chronic_code as code, chronic_name as name, updated_at FROM user_chronics WHERE user_id = ? ORDER BY id ASC"
    )
      .bind(auth.viewer.id)
      .all();
    return c.json({ success: true, chronics: res.results });
  });

  app.post("/api/v1/profile/chronics", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const uid = auth.viewer.id;
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const chList = Array.isArray(body.chronics) ? body.chronics : [];
    const now = utcNowIso();

    const stmts: D1PreparedStatement[] = [
      c.env.APP_DB.prepare("DELETE FROM user_chronics WHERE user_id = ?").bind(uid),
    ];
    for (const item of chList) {
      let code = "";
      let name = "";
      if (item && typeof item === "object") {
        const rec = item as Record<string, unknown>;
        code = String(rec.code ?? rec.chronic_code ?? "").trim();
        name = String(rec.name ?? rec.chronic_name ?? code).trim();
      } else {
        code = String(item || "").trim();
        name = code;
      }
      if (code) {
        stmts.push(
          c.env.APP_DB.prepare(
            "INSERT INTO user_chronics (user_id, chronic_code, chronic_name, updated_at) VALUES (?, ?, ?, ?)"
          ).bind(uid, code, name, now)
        );
      }
    }
    await c.env.APP_DB.batch(stmts);

    return c.json({ success: true, message: "Đã lưu tình trạng sức khỏe thành công." });
  });

  // 11. Profile Settings (Authenticated)
  app.get("/api/v1/profile/settings", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const defaults = {
      language: "system",
      notify_badges: true,
      notify_reminders: false,
      scan_derivatives: true,
      warn_traces: true,
    };
    const row = await c.env.APP_DB.prepare(
      "SELECT language, notify_badges, notify_reminders, scan_derivatives, warn_traces FROM user_settings WHERE user_id = ?"
    )
      .bind(auth.viewer.id)
      .first<Record<string, unknown>>();
    if (row) {
      return c.json({
        success: true,
        settings: {
          language: String(row.language ?? "system"),
          notify_badges: Boolean(row.notify_badges),
          notify_reminders: Boolean(row.notify_reminders),
          scan_derivatives: Boolean(row.scan_derivatives),
          warn_traces: Boolean(row.warn_traces),
        },
      });
    }
    return c.json({ success: true, settings: defaults });
  });

  app.post("/api/v1/profile/settings", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    await c.env.APP_DB.prepare(
      `INSERT INTO user_settings (user_id, language, notify_badges, notify_reminders, scan_derivatives, warn_traces, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         language = excluded.language, notify_badges = excluded.notify_badges,
         notify_reminders = excluded.notify_reminders, scan_derivatives = excluded.scan_derivatives,
         warn_traces = excluded.warn_traces, updated_at = excluded.updated_at`
    )
      .bind(
        auth.viewer.id,
        String(body.language ?? "system"),
        body.notify_badges === false ? 0 : 1,
        body.notify_reminders ? 1 : 0,
        body.scan_derivatives === false ? 0 : 1,
        body.warn_traces === false ? 0 : 1,
        utcNowIso()
      )
      .run();
    return c.json({ success: true, message: "Đã lưu cài đặt thành công." });
  });

  // 12. Family Profiles (Authenticated)
  app.get("/api/v1/profile/family", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const uidInt = auth.viewer.id;
    let res = await c.env.APP_DB.prepare(
      "SELECT id, member_name, relationship, is_primary, created_at FROM family_members WHERE user_id = ? ORDER BY is_primary DESC, id ASC"
    )
      .bind(uidInt)
      .all();

    if (res.results.length === 0) {
      const parts = (auth.viewer.full_name || "Tôi").trim().split(/\s+/);
      const rawShort = parts[parts.length - 1] || "Tôi";
      const shortName = rawShort[0].toUpperCase() + rawShort.slice(1);
      await c.env.APP_DB.prepare(
        "INSERT INTO family_members (user_id, member_name, relationship, is_primary, created_at) VALUES (?, ?, 'Bản thân', 1, ?)"
      )
        .bind(uidInt, shortName, utcNowIso())
        .run();
      res = await c.env.APP_DB.prepare(
        "SELECT id, member_name, relationship, is_primary, created_at FROM family_members WHERE user_id = ? ORDER BY is_primary DESC, id ASC"
      )
        .bind(uidInt)
        .all();
    }
    return c.json({ success: true, members: res.results });
  });

  app.post("/api/v1/profile/family", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const uid = auth.viewer.id;
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const action = String(body.action ?? "add").toLowerCase();

    if (action === "delete" && body.member_id) {
      await c.env.APP_DB.prepare("DELETE FROM family_members WHERE id = ? AND user_id = ? AND is_primary = 0")
        .bind(Number(body.member_id), uid)
        .run();
    } else {
      const mName = String(body.member_name || "").trim();
      const rel = String(body.relationship || "Thành viên").trim();
      if (mName) {
        await c.env.APP_DB.prepare(
          "INSERT INTO family_members (user_id, member_name, relationship, is_primary, created_at) VALUES (?, ?, ?, 0, ?)"
        )
          .bind(uid, mName.slice(0, 80), rel.slice(0, 60), utcNowIso())
          .run();
      }
    }
    const res = await c.env.APP_DB.prepare(
      "SELECT id, member_name, relationship, is_primary, created_at FROM family_members WHERE user_id = ? ORDER BY is_primary DESC, id ASC"
    )
      .bind(uid)
      .all();
    return c.json({ success: true, members: res.results });
  });

  // 13. Scan History (Strictly Authenticated — owner-scoped via session token)
  app.get("/api/v1/scans", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const summary = await fetchUserScanSummary(c.env.APP_DB, auth.viewer.id);
    return c.json({ success: true, ...summary });
  });

  app.delete("/api/v1/scans/:id", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const rawId = c.req.param("id");
    if (!/^\d+$/.test(rawId)) return c.json({ success: false, message: "Invalid scan_id" }, 400);

    const uidInt = auth.viewer.id;
    const scanId = Number(rawId);
    const del = await c.env.APP_DB.prepare("DELETE FROM scan_history WHERE id = ? AND user_id = ?")
      .bind(scanId, uidInt)
      .run();
    if ((del.meta.changes ?? 0) === 0) {
      return c.json({ success: false, message: "Không tìm thấy bản ghi lịch sử quét." }, 404);
    }
    const summary = await fetchUserScanSummary(c.env.APP_DB, uidInt);
    return c.json({ success: true, deleted_id: scanId, ...summary });
  });

  app.delete("/api/v1/scans", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const uidInt = auth.viewer.id;
    const del = await c.env.APP_DB.prepare("DELETE FROM scan_history WHERE user_id = ?").bind(uidInt).run();
    const summary = await fetchUserScanSummary(c.env.APP_DB, uidInt);
    return c.json({ success: true, deleted_count: del.meta.changes ?? 0, ...summary });
  });

  app.post("/api/v1/scans", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const uid = auth.viewer.id;
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const action = String(body.action || "").trim().toLowerCase();

    if (action === "delete" || action === "clear") {
      if (action === "delete") {
        if (body.scan_id === undefined || body.scan_id === null) {
          return c.json({ success: false, message: "scan_id is required" }, 400);
        }
        const scanId = Number(body.scan_id);
        const del = await c.env.APP_DB.prepare("DELETE FROM scan_history WHERE id = ? AND user_id = ?")
          .bind(scanId, uid)
          .run();
        if ((del.meta.changes ?? 0) === 0) {
          return c.json({ success: false, message: "Không tìm thấy bản ghi lịch sử quét." }, 404);
        }
        const summary = await fetchUserScanSummary(c.env.APP_DB, uid);
        return c.json({ success: true, deleted_id: scanId, ...summary });
      }
      const del = await c.env.APP_DB.prepare("DELETE FROM scan_history WHERE user_id = ?").bind(uid).run();
      const summary = await fetchUserScanSummary(c.env.APP_DB, uid);
      return c.json({ success: true, deleted_count: del.meta.changes ?? 0, ...summary });
    }

    const rawText = String(body.raw_text ?? body.ingredients ?? "").trim();
    const lang = String(body.lang ?? "vi").toLowerCase();
    const isEn = lang.startsWith("en");
    const labelTitle = String(body.label_title || (isEn ? "Scan result" : "Kết quả quét")).trim();
    const memberName = String(body.member_name || "").trim();

    if (!rawText) {
      return c.json(
        {
          success: false,
          message: isEn
            ? "Please enter or scan packaging ingredients."
            : "Vui lòng nhập hoặc quét thành phần trên nhãn bao bì.",
        },
        400
      );
    }

    const [alsRes, chsRes, evalOpts] = await Promise.all([
      c.env.APP_DB.prepare("SELECT allergen_code as code, allergen_name as name, severity FROM user_allergens WHERE user_id = ?")
        .bind(uid)
        .all<Record<string, unknown>>(),
      c.env.APP_DB.prepare("SELECT chronic_code FROM user_chronics WHERE user_id = ?")
        .bind(uid)
        .all<{ chronic_code: string }>(),
      fetchUserEvalOptions(c.env.APP_DB, uid),
    ]);

    const eng = new D1FoodOnEngine(c.env.FOODON_DB);
    const tokens = splitRawIngredients(rawText);
    const ev = await eng.evaluatePackagingLabel(
      tokens,
      alsRes.results,
      chsRes.results.map((r) => r.chronic_code),
      evalOpts
    );

    await c.env.APP_DB.prepare(
      `INSERT INTO scan_history
       (user_id, member_name, label_title, raw_text, verdict, risk_level, risk_label_vi, additive_count, warning_count, result_json, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        uid,
        memberName,
        labelTitle,
        rawText,
        String(ev.verdict),
        String(ev.risk_level),
        String(ev.risk_label_vi),
        Number(ev.additive_count),
        Number(ev.warning_count),
        JSON.stringify(ev),
        utcNowIso()
      )
      .run();

    const summary = await fetchUserScanSummary(c.env.APP_DB, uid);
    return c.json({
      success: true,
      latest_scan: summary.scans[0] ?? null,
      ...summary,
    });
  });
}
