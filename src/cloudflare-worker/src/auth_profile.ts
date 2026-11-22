import { Hono } from "hono";
import { hashPassword, randomHex, randomUrlSafeToken, verifyPassword } from "./crypto";
import { isEmailProviderConfigured, sendPasswordResetEmail, sendVerificationEmail } from "./email";
import { D1FoodOnEngine, splitRawIngredients } from "./foodon";
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

function utcNowIso(): string {
  return new Date().toISOString();
}

export function calculateMetricsInfo(
  age: number,
  gender: string,
  height: number,
  weight: number,
  activityLevel = "moderate"
) {
  const hM = height / 100.0;
  const bmi = hM > 0 ? Math.round((weight / (hM * hM)) * 10) / 10 : 22.0;

  let bmiStatus: string;
  let bmiColor: string;
  let bmiAdvice: string;
  if (bmi < 18.5) {
    bmiStatus = "Thiếu cân (Gầy)";
    bmiColor = "#3B82F6";
    bmiAdvice = "Tăng cường năng lượng và đạm lành mạnh trong khẩu phần.";
  } else if (bmi < 23.0) {
    bmiStatus = "Cân đối (Chuẩn WHO/VN)";
    bmiColor = "#10B981";
    bmiAdvice = "Thể trạng lý tưởng! Duy trì chế độ ăn và vận động hiện tại.";
  } else if (bmi < 25.0) {
    bmiStatus = "Tiền béo phì (Thừa cân)";
    bmiColor = "#F59E0B";
    bmiAdvice = "Kiểm soát đường, tinh bột tinh chế và chất béo bão hòa.";
  } else {
    bmiStatus = "Béo phì";
    bmiColor = "#EF4444";
    bmiAdvice = "Cần chế độ ăn giảm calo và tăng cường vận động thể chất.";
  }

  const bmr =
    gender === "female"
      ? 10 * weight + 6.25 * height - 5 * age - 161
      : 10 * weight + 6.25 * height - 5 * age + 5;

  const mults: Record<string, number> = {
    sedentary: 1.2,
    light: 1.375,
    moderate: 1.55,
    active: 1.725,
    very_active: 1.9,
  };
  const tdee = Math.round(bmr * (mults[activityLevel] ?? 1.55));

  return {
    age: Math.round(age),
    gender,
    height,
    weight,
    activity_level: activityLevel,
    bmi,
    bmi_status: bmiStatus,
    bmi_color: bmiColor,
    bmi_advice: bmiAdvice,
    bmr: Math.round(bmr),
    tdee,
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
        await c.env.APP_DB.prepare("UPDATE users SET is_verified = 1 WHERE id = ?").bind(row.id).run();
        return c.html(HTML_VERIFIED_SUCCESS, 200);
      }
    }
    return c.html(HTML_VERIFIED_FAIL, 400);
  });

  // 2. Users inspection endpoint (preserves compatibility)
  app.get("/api/v1/users", async (c) => {
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
      const [als, mRow] = await Promise.all([
        c.env.APP_DB.prepare("SELECT allergen_code as code, allergen_name as name, severity FROM user_allergens WHERE user_id = ? ORDER BY id ASC")
          .bind(targetUid)
          .all(),
        c.env.APP_DB.prepare("SELECT age, gender, height, weight, activity_level FROM user_metrics WHERE user_id = ?")
          .bind(targetUid)
          .first<Record<string, unknown>>(),
      ]);

      uRow.allergens = als.results;
      if (mRow) {
        const hM = Number(mRow.height) > 0 ? Number(mRow.height) / 100.0 : 1.0;
        uRow.metrics = { ...mRow, bmi: Math.round((Number(mRow.weight) / (hM * hM)) * 10) / 10 };
      } else {
        uRow.metrics = null;
      }
      return c.json({ success: true, user: uRow });
    }

    const usersRes = await c.env.APP_DB.prepare("SELECT id, full_name, email, is_verified, created_at FROM users ORDER BY id ASC").all<Record<string, unknown>>();
    return c.json({ users: usersRes.results });
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
      await sendVerificationEmail(c.env, email, fullName, verifyToken, origin);
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
    await sendVerificationEmail(c.env, user.email, user.full_name, newToken, origin);
    return c.json({ success: true, message: "Đã gửi lại email kích hoạt vào hộp thư của bạn." });
  });

  // 6. Forgot Password
  app.post("/api/v1/auth/forgot-password", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const email = String(body.email || "").trim().toLowerCase();
    const user = await c.env.APP_DB.prepare("SELECT id, full_name, email FROM users WHERE email = ?")
      .bind(email)
      .first<UserRow>();

    if (user) {
      const tempPwd = `Nutri@${randomHex(3).toUpperCase()}`;
      const { hash, salt } = await hashPassword(tempPwd);
      await c.env.APP_DB.prepare("UPDATE users SET password_hash = ?, salt = ?, is_verified = 1 WHERE id = ?")
        .bind(hash, salt, user.id)
        .run();

      const mailRes = await sendPasswordResetEmail(c.env, email, user.full_name, tempPwd);
      if (mailRes.sent) {
        return c.json({
          success: true,
          message: `Mật khẩu mới đã được gửi vào hộp thư: ${email}.`,
        });
      }
      return c.json({
        success: true,
        message: `Hệ thống email chưa gắn API key (Resend/Brevo). Mật khẩu tạm thời của bạn là: ${tempPwd} — hãy đổi lại ngay sau khi đăng nhập.`,
      });
    }

    return c.json({
      success: true,
      message: "Nếu email tồn tại trong hệ thống, mật khẩu mới đã được xử lý.",
    });
  });

  // 7. Change Password
  app.post("/api/v1/auth/change-password", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const userId = body.user_id;
    const email = String(body.email || "").trim().toLowerCase();
    const currentPwd = String(body.current_password || "");
    const newPwd = String(body.new_password || "");

    if (!currentPwd || !newPwd) {
      return c.json({ success: false, message: "Vui lòng nhập mật khẩu hiện tại và mật khẩu mới." }, 400);
    }
    if (newPwd.length < 6) {
      return c.json({ success: false, message: "Mật khẩu mới phải từ 6 ký tự trở lên." }, 400);
    }

    const user = userId
      ? await c.env.APP_DB.prepare("SELECT id, password_hash, salt FROM users WHERE id = ?")
          .bind(Number(userId))
          .first<UserRow>()
      : await c.env.APP_DB.prepare("SELECT id, password_hash, salt FROM users WHERE email = ?")
          .bind(email)
          .first<UserRow>();

    if (!user || !(await verifyPassword(currentPwd, user.password_hash, user.salt))) {
      return c.json({ success: false, message: "Mật khẩu hiện tại (hoặc mật khẩu tạm) không chính xác." }, 400);
    }

    const { hash, salt } = await hashPassword(newPwd);
    await c.env.APP_DB.prepare("UPDATE users SET password_hash = ?, salt = ?, is_verified = 1 WHERE id = ?")
      .bind(hash, salt, user.id)
      .run();
    return c.json({ success: true, message: "Đổi mật khẩu thành công! Hãy ghi nhớ mật khẩu mới của bạn." });
  });

  // 8. Update Profile Name
  app.post("/api/v1/auth/update-profile", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const userId = body.user_id;
    const fullName = String(body.full_name || "").trim();
    if (!userId || !fullName) return c.json({ success: false, message: "Thông tin không hợp lệ." }, 400);

    await c.env.APP_DB.prepare("UPDATE users SET full_name = ? WHERE id = ?").bind(fullName, Number(userId)).run();
    const user = await c.env.APP_DB.prepare("SELECT id, full_name, email, is_verified FROM users WHERE id = ?")
      .bind(Number(userId))
      .first();
    return c.json({ success: true, message: "Cập nhật họ và tên thành công!", user: user ?? {} });
  });

  // 9. Profile Metrics
  app.get("/api/v1/profile/metrics", async (c) => {
    const uid = c.req.query("user_id");
    if (uid) {
      const row = await c.env.APP_DB.prepare(
        "SELECT age, gender, height, weight, activity_level, updated_at FROM user_metrics WHERE user_id = ?"
      )
        .bind(Number(uid))
        .first<{ age: number; gender: string; height: number; weight: number; activity_level: string }>();
      if (row) {
        return c.json({
          success: true,
          has_metrics: true,
          metrics: calculateMetricsInfo(row.age, row.gender, row.height, row.weight, row.activity_level),
        });
      }
    }
    return c.json({ success: true, has_metrics: false, metrics: null });
  });

  app.post("/api/v1/profile/metrics", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    if (!body.user_id) return c.json({ success: false, message: "user_id is required" }, 400);

    const uid = Number(body.user_id);
    const age = Number(body.age);
    const height = Number(body.height);
    const weight = Number(body.weight);
    if (!Number.isFinite(age) || age <= 0 || !Number.isFinite(height) || height <= 0 || !Number.isFinite(weight) || weight <= 0) {
      return c.json({ success: false, message: "age, height, and weight must be positive numbers." }, 400);
    }
    const gender = String(body.gender ?? "male").toLowerCase();
    const activity = String(body.activity_level ?? "moderate");
    const info = calculateMetricsInfo(age, gender, height, weight, activity);

    await c.env.APP_DB.prepare(
      `INSERT INTO user_metrics (user_id, age, gender, height, weight, activity_level, target_calories, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         age = excluded.age, gender = excluded.gender, height = excluded.height,
         weight = excluded.weight, activity_level = excluded.activity_level,
         target_calories = excluded.target_calories, updated_at = excluded.updated_at`
    )
      .bind(uid, age, gender, height, weight, activity, info.tdee, utcNowIso())
      .run();

    return c.json({
      success: true,
      message: "Đã cập nhật chỉ số thể trạng và dinh dưỡng thành công!",
      metrics: info,
    });
  });

  // 10. Profile Allergens (+ re-evaluates existing scans via D1 FoodOn)
  app.get("/api/v1/profile/allergens", async (c) => {
    const uid = c.req.query("user_id");
    if (!uid) return c.json({ success: true, allergens: [] });
    const res = await c.env.APP_DB.prepare(
      "SELECT allergen_code as code, allergen_name as name, severity, updated_at FROM user_allergens WHERE user_id = ? ORDER BY id ASC"
    )
      .bind(Number(uid))
      .all();
    return c.json({ success: true, allergens: res.results });
  });

  app.post("/api/v1/profile/allergens", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const uid = body.user_id ? Number(body.user_id) : 0;
    const alList = Array.isArray(body.allergens) ? body.allergens : [];
    const now = utcNowIso();

    if (uid > 0) {
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

      // Re-evaluate existing scan_history rows so previous labels immediately reflect new allergy profile
      const [chRes, scanRes] = await Promise.all([
        c.env.APP_DB.prepare("SELECT chronic_code FROM user_chronics WHERE user_id = ?")
          .bind(uid)
          .all<{ chronic_code: string }>(),
        c.env.APP_DB.prepare("SELECT id, raw_text FROM scan_history WHERE user_id = ? ORDER BY id DESC LIMIT 25")
          .bind(uid)
          .all<{ id: number; raw_text: string }>(),
      ]);
      const userChs = chRes.results.map((r) => r.chronic_code);
      if (scanRes.results.length > 0) {
        const eng = new D1FoodOnEngine(c.env.FOODON_DB);
        const updStmts: D1PreparedStatement[] = [];
        for (const srow of scanRes.results) {
          const toks = splitRawIngredients(srow.raw_text || "");
          const ev = await eng.evaluatePackagingLabel(toks, normalizedAls, userChs);
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
    }

    return c.json({ success: true, message: "Đã lưu hồ sơ dị ứng thành công." });
  });

  // 11. Profile Chronics
  app.get("/api/v1/profile/chronics", async (c) => {
    const uid = c.req.query("user_id");
    if (!uid) return c.json({ success: true, chronics: [] });
    const res = await c.env.APP_DB.prepare(
      "SELECT chronic_code as code, chronic_name as name, updated_at FROM user_chronics WHERE user_id = ? ORDER BY id ASC"
    )
      .bind(Number(uid))
      .all();
    return c.json({ success: true, chronics: res.results });
  });

  app.post("/api/v1/profile/chronics", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const uid = body.user_id ? Number(body.user_id) : 0;
    const chList = Array.isArray(body.chronics) ? body.chronics : [];
    const now = utcNowIso();

    if (uid > 0) {
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
    }

    return c.json({ success: true, message: "Đã lưu tình trạng sức khỏe thành công." });
  });

  // 12. Profile Settings
  app.get("/api/v1/profile/settings", async (c) => {
    const uid = c.req.query("user_id");
    const defaults = {
      language: "system",
      notify_badges: true,
      notify_reminders: false,
      scan_derivatives: true,
      warn_traces: true,
    };
    if (uid) {
      const row = await c.env.APP_DB.prepare(
        "SELECT language, notify_badges, notify_reminders, scan_derivatives, warn_traces FROM user_settings WHERE user_id = ?"
      )
        .bind(Number(uid))
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
    }
    return c.json({ success: true, settings: defaults });
  });

  app.post("/api/v1/profile/settings", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    if (!body.user_id) return c.json({ success: false, message: "user_id is required" }, 400);
    await c.env.APP_DB.prepare(
      `INSERT INTO user_settings (user_id, language, notify_badges, notify_reminders, scan_derivatives, warn_traces, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         language = excluded.language, notify_badges = excluded.notify_badges,
         notify_reminders = excluded.notify_reminders, scan_derivatives = excluded.scan_derivatives,
         warn_traces = excluded.warn_traces, updated_at = excluded.updated_at`
    )
      .bind(
        Number(body.user_id),
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

  // 13. Family Profiles
  app.get("/api/v1/profile/family", async (c) => {
    const uid = c.req.query("user_id");
    if (!uid) return c.json({ success: true, members: [] });
    const uidInt = Number(uid);
    let res = await c.env.APP_DB.prepare(
      "SELECT id, member_name, relationship, is_primary, created_at FROM family_members WHERE user_id = ? ORDER BY is_primary DESC, id ASC"
    )
      .bind(uidInt)
      .all();

    if (res.results.length === 0) {
      const uRow = await c.env.APP_DB.prepare("SELECT full_name FROM users WHERE id = ?")
        .bind(uidInt)
        .first<{ full_name: string }>();
      const parts = (uRow?.full_name || "Tôi").trim().split(/\s+/);
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
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    if (!body.user_id) return c.json({ success: false, message: "user_id is required" }, 400);
    const uid = Number(body.user_id);
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
          .bind(uid, mName, rel, utcNowIso())
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

  // 14. Scan History (GET, POST create/delete/clear, DELETE /scans, DELETE /scans/:id)
  app.get("/api/v1/scans", async (c) => {
    const uid = c.req.query("user_id");
    if (!uid) return c.json({ success: false, message: "user_id is required" }, 400);
    const summary = await fetchUserScanSummary(c.env.APP_DB, Number(uid));
    return c.json({ success: true, ...summary });
  });

  app.delete("/api/v1/scans/:id", async (c) => {
    const rawId = c.req.param("id");
    const uid = c.req.query("user_id");
    if (!uid) return c.json({ success: false, message: "user_id is required" }, 400);
    if (!/^\d+$/.test(rawId)) return c.json({ success: false, message: "Invalid scan_id" }, 400);

    const uidInt = Number(uid);
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
    const uid = c.req.query("user_id");
    if (!uid) return c.json({ success: false, message: "user_id is required" }, 400);
    const uidInt = Number(uid);
    const del = await c.env.APP_DB.prepare("DELETE FROM scan_history WHERE user_id = ?").bind(uidInt).run();
    const summary = await fetchUserScanSummary(c.env.APP_DB, uidInt);
    return c.json({ success: true, deleted_count: del.meta.changes ?? 0, ...summary });
  });

  app.post("/api/v1/scans", async (c) => {
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const action = String(body.action || "").trim().toLowerCase();

    if (action === "delete" || action === "clear") {
      if (!body.user_id) return c.json({ success: false, message: "user_id is required" }, 400);
      const uidInt = Number(body.user_id);
      if (action === "delete") {
        if (body.scan_id === undefined || body.scan_id === null) {
          return c.json({ success: false, message: "scan_id is required" }, 400);
        }
        const scanId = Number(body.scan_id);
        const del = await c.env.APP_DB.prepare("DELETE FROM scan_history WHERE id = ? AND user_id = ?")
          .bind(scanId, uidInt)
          .run();
        if ((del.meta.changes ?? 0) === 0) {
          return c.json({ success: false, message: "Không tìm thấy bản ghi lịch sử quét." }, 404);
        }
        const summary = await fetchUserScanSummary(c.env.APP_DB, uidInt);
        return c.json({ success: true, deleted_id: scanId, ...summary });
      }
      const del = await c.env.APP_DB.prepare("DELETE FROM scan_history WHERE user_id = ?").bind(uidInt).run();
      const summary = await fetchUserScanSummary(c.env.APP_DB, uidInt);
      return c.json({ success: true, deleted_count: del.meta.changes ?? 0, ...summary });
    }

    const uid = body.user_id ? Number(body.user_id) : 0;
    const rawText = String(body.raw_text ?? body.ingredients ?? "").trim();
    const lang = String(body.lang ?? "vi").toLowerCase();
    const isEn = lang.startsWith("en");
    const labelTitle = String(body.label_title || (isEn ? "Scan result" : "Kết quả quét")).trim();
    const memberName = String(body.member_name || "").trim();

    if (!uid || !rawText) {
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

    const [alsRes, chsRes] = await Promise.all([
      c.env.APP_DB.prepare("SELECT allergen_code as code, allergen_name as name, severity FROM user_allergens WHERE user_id = ?")
        .bind(uid)
        .all<Record<string, unknown>>(),
      c.env.APP_DB.prepare("SELECT chronic_code FROM user_chronics WHERE user_id = ?")
        .bind(uid)
        .all<{ chronic_code: string }>(),
    ]);

    const eng = new D1FoodOnEngine(c.env.FOODON_DB);
    const tokens = splitRawIngredients(rawText);
    const ev = await eng.evaluatePackagingLabel(
      tokens,
      alsRes.results,
      chsRes.results.map((r) => r.chronic_code)
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

