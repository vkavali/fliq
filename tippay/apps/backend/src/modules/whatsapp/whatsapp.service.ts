import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '@fliq/database';
import * as crypto from 'crypto';

export interface WhatsAppButton {
  id: string;
  title: string;
}

/**
 * Low-level WhatsApp Business API (Meta Cloud API) service.
 * Handles HTTP calls to Meta graph API and signature verification.
 * All outbound messages should go through this service.
 */
@Injectable()
export class WhatsAppService {
  private readonly logger = new Logger(WhatsAppService.name);
  private readonly isDev: boolean;
  private readonly accessToken: string | undefined;
  private readonly phoneNumberId: string | undefined;
  private readonly appSecret: string | undefined;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    this.isDev = this.config.get<string>('APP_ENV', 'development') !== 'production';
    this.accessToken = this.config.get<string>('WHATSAPP_ACCESS_TOKEN');
    this.phoneNumberId = this.config.get<string>('WHATSAPP_PHONE_NUMBER_ID');
    this.appSecret = this.config.get<string>('WHATSAPP_APP_SECRET');
  }

  /**
   * Verify the X-Hub-Signature-256 header from Meta webhook.
   * Uses HMAC-SHA256 with the App Secret.
   */
  verifyWebhookSignature(rawBody: string, signature: string): boolean {
    if (!this.appSecret) return this.isDev; // skip verification in dev if not configured
    const expected = `sha256=${crypto.createHmac('sha256', this.appSecret).update(rawBody).digest('hex')}`;
    return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
  }

  /**
   * Normalize a phone number to E.164 without '+' prefix for WhatsApp API.
   * Strips non-digit characters. Adds '91' India prefix if 10-digit number.
   */
  normalizePhone(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    if (digits.length === 10) return `91${digits}`;
    return digits;
  }

  /**
   * Send a plain text message.
   */
  async sendTextMessage(to: string, body: string): Promise<void> {
    const phone = this.normalizePhone(to);
    if (this.isDev && !this.accessToken) {
      this.logger.log(`[DEV WhatsApp] To: ${phone} | ${body}`);
      return;
    }
    await this.callMessagesApi({
      messaging_product: 'whatsapp',
      to: phone,
      type: 'text',
      text: { preview_url: false, body },
    });
  }

  /**
   * Send an image message (by URL).
   */
  async sendImageMessage(to: string, imageUrl: string, caption?: string): Promise<void> {
    const phone = this.normalizePhone(to);
    if (this.isDev && !this.accessToken) {
      this.logger.log(`[DEV WhatsApp] Image to: ${phone} | ${imageUrl} | ${caption ?? ''}`);
      return;
    }
    await this.callMessagesApi({
      messaging_product: 'whatsapp',
      to: phone,
      type: 'image',
      image: { link: imageUrl, ...(caption ? { caption } : {}) },
    });
  }

  /**
   * Send an interactive message with up to 3 reply buttons.
   */
  async sendInteractiveButtons(
    to: string,
    bodyText: string,
    buttons: WhatsAppButton[],
    headerText?: string,
  ): Promise<void> {
    const phone = this.normalizePhone(to);
    if (this.isDev && !this.accessToken) {
      this.logger.log(
        `[DEV WhatsApp] Interactive to: ${phone} | ${bodyText} | buttons: ${buttons.map((b) => b.title).join(', ')}`,
      );
      return;
    }
    await this.callMessagesApi({
      messaging_product: 'whatsapp',
      to: phone,
      type: 'interactive',
      interactive: {
        type: 'button',
        ...(headerText ? { header: { type: 'text', text: headerText } } : {}),
        body: { text: bodyText },
        action: {
          buttons: buttons.map((b) => ({
            type: 'reply',
            reply: { id: b.id, title: b.title },
          })),
        },
      },
    });
  }

  /**
   * Mark an incoming message as read (good UX — shows double blue ticks).
   */
  async markMessageRead(messageId: string): Promise<void> {
    if (this.isDev && !this.accessToken) return;
    await this.callMessagesApi({
      messaging_product: 'whatsapp',
      status: 'read',
      message_id: messageId,
    });
  }

  /**
   * Queue a WhatsApp message via the transactional outbox (for reliable async delivery).
   * Used for tip notifications triggered from payment webhooks.
   */
  async enqueueOutboxMessage(
    phone: string,
    eventType: string,
    messagePayload: Record<string, unknown>,
  ): Promise<void> {
    const normalizedPhone = this.normalizePhone(phone);
    await this.prisma.outboxEvent.create({
      data: {
        aggregateType: 'whatsapp',
        aggregateId: crypto.randomUUID(),
        eventType,
        payload: { to: normalizedPhone, ...messagePayload },
      },
    });
  }

  /**
   * Send an OTP verification template message.
   * Uses the pre-approved "otp_verification" WhatsApp Business template.
   * Template body: "Your Fliq verification code is: {{1}}. It expires in 5 minutes."
   */
  async sendOtpTemplate(to: string, otp: string): Promise<void> {
    const phone = this.normalizePhone(to);
    if (this.isDev && !this.accessToken) {
      this.logger.log(`[DEV WhatsApp] OTP to: ${phone} | code: ${otp}`);
      return;
    }
    await this.callMessagesApi({
      messaging_product: 'whatsapp',
      to: phone,
      type: 'template',
      template: {
        name: 'otp_verification',
        language: { code: 'en' },
        components: [
          {
            type: 'body',
            parameters: [{ type: 'text', text: otp }],
          },
        ],
      },
    });
  }

  private async callMessagesApi(body: Record<string, unknown>): Promise<void> {
    if (!this.accessToken || !this.phoneNumberId) {
      this.logger.warn('WhatsApp credentials not configured — skipping message send');
      return;
    }

    const url = `https://graph.facebook.com/v21.0/${this.phoneNumberId}/messages`;
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        const err = await response.text();
        this.logger.error(`WhatsApp API error ${response.status}: ${err}`);
      }
    } catch (error) {
      this.logger.error('WhatsApp API call failed', error);
    }
  }
}
