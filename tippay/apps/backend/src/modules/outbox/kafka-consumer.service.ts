import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Kafka, Consumer } from 'kafkajs';
import { KAFKA_TOPICS } from '@tippay/shared';

/**
 * Kafka consumer that subscribes to platform events.
 * For MVP, it logs events. In production, this would trigger
 * analytics, notifications, and downstream processing.
 */
@Injectable()
export class KafkaConsumerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(KafkaConsumerService.name);
  private consumer: Consumer | null = null;
  private readonly enabled: boolean;

  constructor(private readonly config: ConfigService) {
    const brokers = this.config.get<string>('KAFKA_BROKERS', '');
    this.enabled = brokers.length > 0;
  }

  async onModuleInit() {
    if (!this.enabled) {
      this.logger.warn('Kafka not configured — consumer not started');
      return;
    }

    try {
      const brokers = this.config.get<string>('KAFKA_BROKERS', 'localhost:9092');
      const kafka = new Kafka({
        clientId: 'tippay-consumer',
        brokers: brokers.split(','),
      });

      this.consumer = kafka.consumer({ groupId: 'tippay-backend-group' });
      await this.consumer.connect();

      // Subscribe to all platform topics
      await this.consumer.subscribe({ topic: KAFKA_TOPICS.TIP_EVENTS, fromBeginning: false });
      await this.consumer.subscribe({ topic: KAFKA_TOPICS.PAYOUT_EVENTS, fromBeginning: false });
      await this.consumer.subscribe({ topic: KAFKA_TOPICS.NOTIFICATION_EVENTS, fromBeginning: false });

      await this.consumer.run({
        eachMessage: async ({ topic, partition, message }) => {
          const key = message.key?.toString();
          const value = message.value?.toString();
          this.logger.log(
            `[Kafka] topic=${topic} partition=${partition} key=${key} value=${value}`,
          );
          await this.handleMessage(topic, key, value ? JSON.parse(value) : null);
        },
      });

      this.logger.log('Kafka consumer started');
    } catch (error) {
      this.logger.error('Failed to start Kafka consumer', error);
    }
  }

  async onModuleDestroy() {
    if (this.consumer) {
      await this.consumer.disconnect();
    }
  }

  private async handleMessage(topic: string, key: string | undefined, payload: any) {
    switch (topic) {
      case KAFKA_TOPICS.TIP_EVENTS:
        this.logger.log(`Tip event: ${payload?.eventType || 'unknown'} for tip ${key}`);
        // TODO: trigger notification, update analytics
        break;
      case KAFKA_TOPICS.PAYOUT_EVENTS:
        this.logger.log(`Payout event for provider ${key}`);
        break;
      case KAFKA_TOPICS.NOTIFICATION_EVENTS:
        this.logger.log(`Notification event: ${JSON.stringify(payload)}`);
        break;
      default:
        this.logger.warn(`Unhandled Kafka topic: ${topic}`);
    }
  }
}
