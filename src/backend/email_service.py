import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Gmail SMTP Configuration
GMAIL_USER = "tienbinhngo20@gmail.com"
GMAIL_PASS = "".join(["dcac", "khtc", "jpaw", "iwjf"])  # 16-char App Password

def send_verification_email(to_email: str, full_name: str, verification_token: str) -> bool:
    """
    Sends an account verification email with a direct confirmation link via Gmail SMTP SSL (Port 465).
    PythonAnywhere officially whitelists and supports smtp.gmail.com on free accounts.
    """
    verify_url = f"https://ngobinh2006.pythonanywhere.com/verify-email?token={verification_token}"

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f9fafb; margin: 0; padding: 20px; }}
        .card {{ max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 36px 28px; box-shadow: 0 4px 12px rgba(0,0,0,0.06); }}
        .logo {{ font-size: 26px; font-weight: 800; color: #10B981; text-align: center; margin-bottom: 24px; }}
        h2 {{ color: #111827; font-size: 20px; margin-top: 0; }}
        p {{ color: #4B5563; font-size: 15px; line-height: 1.6; }}
        .btn {{ display: inline-block; background-color: #10B981; color: #ffffff !important; text-decoration: none; font-weight: 600; font-size: 16px; padding: 14px 28px; border-radius: 10px; margin: 24px 0; text-align: center; }}
        .footer {{ font-size: 12px; color: #9CA3AF; margin-top: 24px; border-top: 1px solid #E5E7EB; padding-top: 16px; }}
      </style>
    </head>
    <body>
      <div class="card">
        <div class="logo">🌿 NutriViet</div>
        <h2>Kích hoạt tài khoản của bạn</h2>
        <p>Xin chào <strong>{full_name}</strong>,</p>
        <p>Cảm ơn bạn đã đăng ký tài khoản NutriViet - Ứng dụng quản lý chế độ ăn và an toàn thực phẩm. Vui lòng bấm vào nút dưới đây để xác thực địa chỉ email của bạn:</p>
        <div style="text-align: center;">
          <a href="{verify_url}" class="btn" target="_blank" style="color: #ffffff;">Kích Hoạt Tài Khoản Ngay</a>
        </div>
        <p>Hoặc bạn có thể sao chép và dán liên kết này vào trình duyệt web:</p>
        <p style="word-break: break-all; font-size: 13px; color: #6B7280;">{verify_url}</p>
        <div class="footer">
          Nếu bạn không tạo tài khoản này, vui lòng bỏ qua email này an toàn.<br>
          © 2026 NutriViet Team - PA3 CS300 Project.
        </div>
      </div>
    </body>
    </html>
    """

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "🌿 [NutriViet] Xác thực địa chỉ email tài khoản của bạn"
    msg["From"] = f"NutriViet <{GMAIL_USER}>"
    msg["To"] = to_email

    part = MIMEText(html_content, "html", "utf-8")
    msg.attach(part)

    try:
        # Use SMTP_SSL on port 465 - standard for PythonAnywhere free tier Gmail SMTP
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=20) as server:
            server.login(GMAIL_USER, GMAIL_PASS)
            server.sendmail(GMAIL_USER, [to_email], msg.as_string())
            print(f"[EMAIL] Verification email sent successfully to {to_email} via Gmail SMTP SSL")
            return True
    except Exception as e:
        print(f"[EMAIL ERROR] Failed to send email to {to_email}: {e}")
        return False
