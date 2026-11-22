import type { Env } from "./types";

export interface EmailDispatchResult {
  sent: boolean;
  provider: "resend" | "brevo" | "auto-verify-noop";
  error?: string;
}

export function isEmailProviderConfigured(env: Env): boolean {
  return Boolean(env.RESEND_API_KEY?.trim() || env.BREVO_API_KEY?.trim());
}

export async function sendEmail(
  env: Env,
  toEmail: string,
  subject: string,
  html: string
): Promise<EmailDispatchResult> {
  const fromAddress = env.EMAIL_FROM?.trim() || "NutriViet <onboarding@resend.dev>";

  // Provider 1: Resend HTTP API (3,000 free emails/month)
  const resendKey = env.RESEND_API_KEY?.trim();
  if (resendKey) {
    try {
      const resp = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: fromAddress,
          to: [toEmail],
          subject,
          html,
        }),
      });
      if (resp.ok) {
        return { sent: true, provider: "resend" };
      }
      return { sent: false, provider: "resend", error: `HTTP ${resp.status}` };
    } catch (e) {
      return { sent: false, provider: "resend", error: String(e) };
    }
  }

  // Provider 2: Brevo Transactional HTTP API (300 free emails/day)
  const brevoKey = env.BREVO_API_KEY?.trim();
  if (brevoKey) {
    try {
      const senderEmail = fromAddress.includes("<")
        ? fromAddress.split("<")[1].replace(">", "").trim()
        : fromAddress;
      const resp = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
          "api-key": brevoKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          sender: { name: "NutriViet", email: senderEmail },
          to: [{ email: toEmail }],
          subject,
          htmlContent: html,
        }),
      });
      if (resp.ok) {
        return { sent: true, provider: "brevo" };
      }
      return { sent: false, provider: "brevo", error: `HTTP ${resp.status}` };
    } catch (e) {
      return { sent: false, provider: "brevo", error: String(e) };
    }
  }

  // Auto-verify fallback mode until RESEND_API_KEY or BREVO_API_KEY secret is attached
  return { sent: false, provider: "auto-verify-noop" };
}

export async function sendVerificationEmail(
  env: Env,
  toEmail: string,
  fullName: string,
  token: string,
  publicBaseUrl: string
): Promise<EmailDispatchResult> {
  const verifyUrl = `${publicBaseUrl.replace(/\/+$/, "")}/verify-email?token=${encodeURIComponent(token)}`;
  const html = `<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="font-family:-apple-system,sans-serif;background:#f8fafc;margin:0;padding:24px;">
  <div style="max-width:500px;margin:0 auto;background:#fff;border-radius:16px;padding:32px;box-shadow:0 4px 12px rgba(0,0,0,0.06);">
    <div style="font-size:26px;font-weight:800;color:#10B981;text-align:center;margin-bottom:20px;">NutriViet</div>
    <h2 style="color:#0F172A;font-size:20px;margin-top:0;">Xác thực tài khoản NutriViet</h2>
    <p style="color:#334155;font-size:14px;line-height:1.6;">Xin chào <strong>${escapeHtml(fullName)}</strong>,</p>
    <p style="color:#475569;font-size:14px;line-height:1.6;">Vui lòng bấm vào nút bên dưới để xác thực email và kích hoạt tài khoản của bạn:</p>
    <div style="text-align:center;margin:28px 0;">
      <a href="${verifyUrl}" style="background:#10B981;color:#fff;text-decoration:none;font-weight:700;font-size:15px;padding:14px 28px;border-radius:12px;display:inline-block;">Kích Hoạt Tài Khoản Ngay</a>
    </div>
    <p style="font-size:12px;color:#94A3B8;word-break:break-all;">Hoặc truy cập: ${verifyUrl}</p>
  </div>
</body></html>`;
  return sendEmail(env, toEmail, "[NutriViet] Xác thực địa chỉ email tài khoản", html);
}

export async function sendPasswordResetEmail(
  env: Env,
  toEmail: string,
  fullName: string,
  tempPassword: string
): Promise<EmailDispatchResult> {
  const html = `<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="font-family:-apple-system,sans-serif;background:#f8fafc;margin:0;padding:24px;">
  <div style="max-width:500px;margin:0 auto;background:#fff;border-radius:16px;padding:32px;box-shadow:0 4px 12px rgba(0,0,0,0.06);">
    <div style="font-size:26px;font-weight:800;color:#10B981;text-align:center;margin-bottom:20px;">NutriViet</div>
    <h2 style="color:#0F172A;font-size:20px;margin-top:0;">Khôi phục mật khẩu tài khoản</h2>
    <p style="color:#334155;font-size:14px;">Xin chào <strong>${escapeHtml(fullName)}</strong>,</p>
    <p style="color:#475569;font-size:14px;">Mật khẩu tạm thời của bạn là:</p>
    <div style="background:#F1F5F9;border:1.5px dashed #10B981;border-radius:12px;padding:16px;text-align:center;font-size:24px;font-weight:800;letter-spacing:3px;color:#0F172A;margin:20px 0;">${escapeHtml(tempPassword)}</div>
    <p style="color:#475569;font-size:13px;">Vui lòng đăng nhập và đổi mật khẩu mới trong Cài đặt.</p>
  </div>
</body></html>`;
  return sendEmail(env, toEmail, "[NutriViet] Khôi phục mật khẩu tài khoản", html);
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

