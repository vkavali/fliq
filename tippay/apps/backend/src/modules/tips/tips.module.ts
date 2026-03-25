import { Module } from '@nestjs/common';
import { TipsController } from './tips.controller';
import { TipsService } from './tips.service';
import { PaymentsModule } from '../payments/payments.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { IdempotencyInterceptor } from '../../common/interceptors/idempotency.interceptor';

@Module({
  imports: [PaymentsModule, NotificationsModule],
  controllers: [TipsController],
  providers: [TipsService, IdempotencyInterceptor],
  exports: [TipsService],
})
export class TipsModule {}
