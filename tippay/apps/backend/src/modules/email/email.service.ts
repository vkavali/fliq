import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private transporter: nodemailer.Transporter | null = null;

  constructor(private readonly config: ConfigService) {
    const host = this.config.get<string>('SMTP_HOST');
    const user = this.config.get<string>('SMTP_USER');
    const pass = this.config.get<string>('SMTP_PASS');

    if (host && user && pass) {
      const port = parseInt(this.config.get<string>('SMTP_PORT', '465'), 10);
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass },
      });
      this.logger.log(`Email service configured: ${user} via ${host}`);
    } else {
      this.logger.warn('SMTP not configured — email sending disabled. Set SMTP_HOST, SMTP_USER, SMTP_PASS env vars.');
    }
  }

  async sendOtp(to: string, code: string): Promise<boolean> {
    if (!this.transporter) {
      this.logger.warn(`No SMTP configured — cannot send OTP to ${to}. Code: ${code}`);
      return false;
    }

    const fromName = this.config.get<string>('SMTP_FROM_NAME', 'Fliq');
    const fromEmail = this.config.get<string>('SMTP_USER');

    try {
      await this.transporter.sendMail({
        from: `"${fromName}" <${fromEmail}>`,
        to,
        subject: 'Your Fliq Access Code',
        html: `
          <div style="font-family: 'Inter', -apple-system, sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 24px;">
            <div style="text-align: center; margin-bottom: 32px;">
              <h1 style="font-size: 28px; font-weight: 800; color: #6C5CE7; margin: 0;">Fliq</h1>
              <p style="color: #636E72; font-size: 14px; margin-top: 4px;">Human Value Infrastructure</p>
            </div>
            <div style="background: #F8F9FA; border-radius: 16px; padding: 32px; text-align: center; border: 1px solid #E9ECEF;">
              <p style="color: #636E72; font-size: 14px; margin-bottom: 8px;">Your access code is</p>
              <div style="font-size: 36px; font-weight: 900; letter-spacing: 8px; color: #2D3436; margin-bottom: 16px;">${code}</div>
              <p style="color: #B2BEC3; font-size: 12px;">This code expires in 10 minutes.</p>
            </div>
            <p style="color: #B2BEC3; font-size: 11px; text-align: center; margin-top: 24px;">
              If you didn't request this code, you can safely ignore this email.
            </p>
          </div>
        `,
        text: `Your Fliq access code is: ${code}. It expires in 10 minutes.`,
      });
      this.logger.log(`OTP email sent to ${to}`);
      return true;
    } catch (err) {
      this.logger.error(`Failed to send OTP email to ${to}:`, err);
      return false;
    }
  }
}
