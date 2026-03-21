import { Module } from '@nestjs/common';
import { PayoutsController } from './payouts.controller';
import { PayoutsService } from './payouts.service';
import { PaymentsModule } from '../payments/payments.module';
import { WalletsModule } from '../wallets/wallets.module';

@Module({
  imports: [PaymentsModule, WalletsModule],
  controllers: [PayoutsController],
  providers: [PayoutsService],
  exports: [PayoutsService],
})
export class PayoutsModule {}
