import { Module } from '@nestjs/common';
import { TipsController } from './tips.controller';
import { TipsService } from './tips.service';
import { PaymentsModule } from '../payments/payments.module';

@Module({
  imports: [PaymentsModule],
  controllers: [TipsController],
  providers: [TipsService],
  exports: [TipsService],
})
export class TipsModule {}
