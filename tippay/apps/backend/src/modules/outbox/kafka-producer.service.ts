import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Kafka, Producer } from 'kafkajs';

@Injectable()
export class KafkaProducerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(KafkaProducerService.name);
  private producer: Producer | null = null;
  private readonly enabled: boolean;

  constructor(private readonly config: ConfigService) {
    const brokers = this.config.get<string>('KAFKA_BROKERS', '');
    this.enabled = brokers.length > 0;
  }

  async onModuleInit() {
    if (!this.enabled) {
      this.logger.warn('Kafka not configured — outbox events will be logged only');
      return;
    }

    try {
      const brokers = this.config.get<string>('KAFKA_BROKERS', 'localhost:9092');
      const kafka = new Kafka({
        clientId: 'fliq-backend',
        brokers: brokers.split(','),
      });
      this.producer = kafka.producer();
      await this.producer.connect();
      this.logger.log('Kafka producer connected');
    } catch (error) {
      this.logger.error('Failed to connect Kafka producer — falling back to logging', error);
      this.producer = null;
    }
  }

  async onModuleDestroy() {
    if (this.producer) {
      await this.producer.disconnect();
    }
  }

  async publish(topic: string, key: string, value: Record<string, unknown>): Promise<boolean> {
    if (!this.producer) {
      this.logger.log(`[OUTBOX] topic=${topic} key=${key} payload=${JSON.stringify(value)}`);
      return true; // Consider it "published" to logs
    }

    try {
      await this.producer.send({
        topic,
        messages: [{ key, value: JSON.stringify(value) }],
      });
      return true;
    } catch (error) {
      this.logger.error(`Failed to publish to ${topic}`, error);
      return false;
    }
  }
}
