import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
FROM_EMAIL = os.getenv("FROM_EMAIL", SMTP_USER)


def send_otp_email(to_email: str, otp: str, full_name: str) -> None:
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "ShareMate — Email Verification Code"
    msg["From"] = FROM_EMAIL
    msg["To"] = to_email

    html_body = f"""
    <html>
    <body style="font-family:Arial,sans-serif;background:#f4f4f4;padding:30px;">
      <div style="max-width:480px;margin:auto;background:#fff;border-radius:10px;padding:32px;">
        <h2 style="color:#4F46E5;margin-bottom:4px;">Welcome to ShareMate!</h2>
        <p style="color:#555;">Hi <strong>{full_name}</strong>, please use the code below to verify your SLIIT email address.</p>
        <div style="text-align:center;margin:32px 0;">
          <span style="font-size:40px;font-weight:bold;letter-spacing:12px;color:#111;">{otp}</span>
        </div>
        <p style="color:#888;font-size:13px;">This code expires in <strong>5 minutes</strong>. Do not share it with anyone.</p>
        <hr style="border:none;border-top:1px solid #eee;margin:24px 0;">
        <p style="color:#aaa;font-size:12px;">If you did not create a ShareMate account, you can safely ignore this email.</p>
      </div>
    </body>
    </html>
    """

    msg.attach(MIMEText(html_body, "html"))

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
        server.ehlo()
        server.starttls()
        server.login(SMTP_USER, SMTP_PASSWORD)
        server.sendmail(FROM_EMAIL, to_email, msg.as_string())
