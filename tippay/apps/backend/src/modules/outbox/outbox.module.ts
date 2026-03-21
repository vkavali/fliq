import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { OutboxPollerService } from './outbox-poller.service';
import { KafkaProducerService } from './kafka-producer.service';

@Module({
  imports: [ScheduleModule.forRoot()],
  providers: [OutboxPollerService, KafkaProducerService],
  exports: [KafkaProducerService],
})
export class OutboxModule {}
