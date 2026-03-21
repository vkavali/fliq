import { Module } from '@nestjs/common';
import { RazorpayService } from './razorpay.service';
import { PaymentsService } from './payments.service';
import { WebhooksController } from './webhooks.controller';
import { WalletsModule } from '../wallets/wallets.module';

@Module({
  imports: [WalletsModule],
  controllers: [WebhooksController],
  providers: [RazorpayService, PaymentsService],
  exports: [RazorpayService, PaymentsService],
})
export class PaymentsModule {}
