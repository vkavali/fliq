import { Module, forwardRef } from '@nestjs/common';
import { RazorpayService } from './razorpay.service';
import { PaymentsService } from './payments.service';
import { WebhooksController } from './webhooks.controller';
import { WalletsModule } from '../wallets/wallets.module';
import { GamificationModule } from '../gamification/gamification.module';
import { RecurringTipsModule } from '../recurring-tips/recurring-tips.module';
import { TipJarsModule } from '../tip-jars/tip-jars.module';
import { TipLaterModule } from '../tip-later/tip-later.module';

@Module({
  imports: [
    WalletsModule,
    forwardRef(() => GamificationModule),
    forwardRef(() => RecurringTipsModule),
    forwardRef(() => TipJarsModule),
    forwardRef(() => TipLaterModule),
  ],
  controllers: [WebhooksController],
  providers: [RazorpayService, PaymentsService],
  exports: [RazorpayService, PaymentsService],
})
export class PaymentsModule {}
