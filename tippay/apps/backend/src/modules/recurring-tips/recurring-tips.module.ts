import { Module, forwardRef } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { RecurringTipsController } from './recurring-tips.controller';
import { RecurringTipsService } from './recurring-tips.service';
import { RecurringChargeScheduler } from './recurring-charge.scheduler';
import { PaymentsModule } from '../payments/payments.module';
import { WalletsModule } from '../wallets/wallets.module';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    forwardRef(() => PaymentsModule),
    WalletsModule,
  ],
  controllers: [RecurringTipsController],
  providers: [RecurringTipsService, RecurringChargeScheduler],
  exports: [RecurringTipsService, RecurringChargeScheduler],
})
export class RecurringTipsModule {}
