import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '@tippay/database';
import { KafkaProducerService } from './kafka-producer.service';

/**
 * Transactional outbox poller.
 * Polls the outbox_events table every 5 seconds and publishes
 * unpublished events to Kafka (or logs them if Kafka is unavailable).
 */
@Injectable()
export class OutboxPollerService {
  private readonly logger = new Logger(OutboxPollerService.name);
  private isProcessing = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly kafka: KafkaProducerService,
  ) {}

  @Cron(CronExpression.EVERY_5_SECONDS)
  async pollOutbox() {
    if (this.isProcessing) return;
    this.isProcessing = true;

    try {
      const events = await this.prisma.outboxEvent.findMany({
        where: { published: false },
        orderBy: { createdAt: 'asc' },
        take: 50,
      });

      if (events.length === 0) return;

      this.logger.log(`Processing ${events.length} outbox events`);

      for (const event of events) {
        const topic = this.resolveTopic(event.aggregateType);
        const published = await this.kafka.publish(
          topic,
          event.aggregateId,
          event.payload as Record<string, unknown>,
        );

        if (published) {
          await this.prisma.outboxEvent.update({
            where: { id: event.id },
            data: { published: true },
          });
        }
      }
    } catch (error) {
      this.logger.error('Outbox polling failed', error);
    } finally {
      this.isProcessing = false;
    }
  }

  private resolveTopic(aggregateType: string): string {
    const topicMap: Record<string, string> = {
      tip: 'tip.events',
      payout: 'payout.events',
      notification: 'notification.events',
    };
    return topicMap[aggregateType] || `${aggregateType}.events`;
  }
}
