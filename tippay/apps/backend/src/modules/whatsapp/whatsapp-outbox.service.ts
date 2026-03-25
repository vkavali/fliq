import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '@fliq/database';
import { WhatsAppService } from './whatsapp.service';

/**
 * WhatsApp Outbox Poller.
 *
 * Polls OutboxEvent records where aggregateType = 'whatsapp' and published = false.
 * For each event, dispatches the message via WhatsAppService, then marks it published.
 *
 * Supported event types and their payload shapes:
 *
 *   tip.notify.provider
 *     { to, text }
 *
 *   tip.notify.customer
 *     { to, text }
 *
 *   generic.text
 *     { to, text }
 *
 *   generic.image
 *     { to, imageUrl, caption? }
 */
@Injectable()
export class WhatsAppOutboxService {
  private readonly logger = new Logger(WhatsAppOutboxService.name);
  private isProcessing = false;
  private disabled = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly whatsapp: WhatsAppService,
  ) {}

  @Cron(CronExpression.EVERY_30_SECONDS)
  async pollOutbox(): Promise<void> {
    if (this.isProcessing || this.disabled) return;
    this.isProcessing = true;

    try {
      const events = await this.prisma.outboxEvent.findMany({
        where: { aggregateType: 'whatsapp', published: false },
        orderBy: { createdAt: 'asc' },
        take: 50,
      });

      if (events.length === 0) return;

      this.logger.log(`Processing ${events.length} WhatsApp outbox events`);

      for (const event of events) {
        const sent = await this.dispatchEvent(event.eventType, event.payload as Record<string, unknown>);
        if (sent) {
          await this.prisma.outboxEvent.update({
            where: { id: event.id },
            data: { published: true },
          });
        }
      }
    } catch (error) {
      const msg = (error as Error).message || '';
      if (msg.includes('does not exist')) {
        this.logger.warn('Outbox table not found — disabling WhatsApp poller. Run migrations to enable.');
        this.disabled = true;
        return;
      }
      this.logger.error('WhatsApp outbox polling failed', error);
    } finally {
      this.isProcessing = false;
    }
  }

  private async dispatchEvent(
    eventType: string,
    payload: Record<string, unknown>,
  ): Promise<boolean> {
    try {
      const to = payload['to'] as string;
      if (!to) {
        this.logger.warn(`WhatsApp outbox event missing 'to' field — skipping`);
        return true; // mark published so we don't retry a bad event
      }

      switch (eventType) {
        case 'tip.notify.provider':
        case 'tip.notify.customer':
        case 'generic.text': {
          const text = payload['text'] as string;
          if (text) await this.whatsapp.sendTextMessage(to, text);
          break;
        }
        case 'generic.image': {
          const imageUrl = payload['imageUrl'] as string;
          const caption = payload['caption'] as string | undefined;
          if (imageUrl) await this.whatsapp.sendImageMessage(to, imageUrl, caption);
          break;
        }
        default:
          this.logger.warn(`Unknown WhatsApp outbox event type: ${eventType}`);
      }
      return true;
    } catch (error) {
      this.logger.error(`Failed to send WhatsApp outbox event (${eventType}): ${error}`);
      return false; // will retry next poll cycle
    }
  }
}
