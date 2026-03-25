import { Module, forwardRef } from '@nestjs/common';
import { RazorpayService } from './razorpay.service';
import { PaymentsService } from './payments.service';
import { WebhooksController } from './webhooks.controller';
import { WalletsModule } from '../wallets/wallets.module';
import { GamificationModule } from '../gamification/gamification.module';
import { RecurringTipsModule } from '../recurring-tips/recurring-tips.module';

@Module({
  imports: [
    WalletsModule,
    forwardRef(() => GamificationModule),
    forwardRef(() => RecurringTipsModule),
  ],
  controllers: [WebhooksController],
  providers: [RazorpayService, PaymentsService],
  exports: [RazorpayService, PaymentsService],
})
export class PaymentsModule {}
