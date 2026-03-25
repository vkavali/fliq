import {
  Controller,
  Get,
  Post,
  Query,
  Headers,
  RawBody,
  HttpCode,
  HttpStatus,
  BadRequestException,
  Logger,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiTags, ApiOperation, ApiExcludeEndpoint } from '@nestjs/swagger';
import { WhatsAppService } from './whatsapp.service';
import { WhatsAppBotService } from './whatsapp-bot.service';
import { RateLimitGuard, RateLimit } from '../../common/guards/rate-limit.guard';

/**
 * WhatsApp Business API webhook controller.
 *
 * GET  /whatsapp/webhook — Meta webhook verification challenge
 * POST /whatsapp/webhook — Receive incoming messages & status updates
 */
@ApiTags('WhatsApp')
@Controller('whatsapp')
export class WhatsAppController {
  private readonly logger = new Logger(WhatsAppController.name);

  constructor(
    private readonly config: ConfigService,
    private readonly whatsapp: WhatsAppService,
    private readonly bot: WhatsAppBotService,
  ) {}

  /**
   * GET /whatsapp/webhook
   * Meta sends a GET request to verify the webhook URL.
   * Responds with the hub.challenge if the verify token matches.
   */
  @Get('webhook')
  @ApiOperation({ summary: 'Meta webhook verification' })
  verifyWebhook(
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') token: string,
    @Query('hub.challenge') challenge: string,
  ): string {
    const expectedToken = this.config.get<string>('WHATSAPP_WEBHOOK_VERIFY_TOKEN', 'fliq_whatsapp_verify');

    if (mode === 'subscribe' && token === expectedToken) {
      this.logger.log('WhatsApp webhook verified successfully');
      return challenge;
    }

    throw new BadRequestException('Webhook verification failed: token mismatch');
  }

  /**
   * POST /whatsapp/webhook
   * Receives incoming messages, status updates, and other events from Meta.
   * Rate limited to 300 requests per minute (burst protection).
   */
  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 300, windowSeconds: 60 })
  @ApiExcludeEndpoint()
  async handleWebhook(
    @RawBody() rawBody: Buffer,
    @Headers('x-hub-signature-256') signature: string,
  ): Promise<{ status: string }> {
    const body = rawBody.toString('utf-8');

    // Verify webhook signature (skipped in dev if WHATSAPP_APP_SECRET not set)
    if (signature && !this.whatsapp.verifyWebhookSignature(body, signature)) {
      throw new BadRequestException('Invalid webhook signature');
    }

    let payload: WhatsAppWebhookPayload;
    try {
      payload = JSON.parse(body);
    } catch {
      throw new BadRequestException('Invalid JSON payload');
    }

    // Process asynchronously — Meta requires a 200 response within 20s
    this.processWebhookPayload(payload).catch((err) => {
      this.logger.error('Error processing WhatsApp webhook', err);
    });

    return { status: 'ok' };
  }

  private async processWebhookPayload(payload: WhatsAppWebhookPayload): Promise<void> {
    if (payload.object !== 'whatsapp_business_account') return;

    for (const entry of payload.entry ?? []) {
      for (const change of entry.changes ?? []) {
        if (change.field !== 'messages') continue;

        const value = change.value;

        for (const message of value.messages ?? []) {
          const from = message.from; // sender's phone in E.164 without +

          try {
            if (message.type === 'text' && message.text?.body) {
              await this.bot.handleTextMessage(from, message.text.body, message.id);
            } else if (message.type === 'interactive' && message.interactive?.button_reply) {
              const { id: buttonId } = message.interactive.button_reply;
              await this.bot.handleInteractiveReply(from, buttonId, message.id);
            }
            // Other message types (image, audio, etc.) — ignore for now
          } catch (err) {
            this.logger.error(`Error handling message from ${from}: ${err}`);
          }
        }
      }
    }
  }
}

// ─── Meta Webhook Payload Types ─────────────────────────────────────────────

interface WhatsAppWebhookPayload {
  object: string;
  entry?: WebhookEntry[];
}

interface WebhookEntry {
  id: string;
  changes?: WebhookChange[];
}

interface WebhookChange {
  field: string;
  value: WebhookValue;
}

interface WebhookValue {
  messaging_product: string;
  metadata?: { display_phone_number: string; phone_number_id: string };
  contacts?: { profile: { name: string }; wa_id: string }[];
  messages?: IncomingMessage[];
  statuses?: MessageStatus[];
}

interface IncomingMessage {
  id: string;
  from: string;
  timestamp: string;
  type: string;
  text?: { body: string };
  interactive?: {
    type: string;
    button_reply?: { id: string; title: string };
    list_reply?: { id: string; title: string; description: string };
  };
}

interface MessageStatus {
  id: string;
  status: 'sent' | 'delivered' | 'read' | 'failed';
  timestamp: string;
  recipient_id: string;
}
