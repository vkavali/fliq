import { Module, forwardRef } from '@nestjs/common';
import { TipLaterController } from './tip-later.controller';
import { TipLaterService } from './tip-later.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { PaymentsModule } from '../payments/payments.module';

@Module({
  imports: [NotificationsModule, forwardRef(() => PaymentsModule)],
  controllers: [TipLaterController],
  providers: [TipLaterService],
  exports: [TipLaterService],
})
export class TipLaterModule {}
