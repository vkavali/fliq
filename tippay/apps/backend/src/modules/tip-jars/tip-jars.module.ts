import { Module, forwardRef } from '@nestjs/common';
import { TipJarsController } from './tip-jars.controller';
import { TipJarsService } from './tip-jars.service';
import { WalletsModule } from '../wallets/wallets.module';
import { PaymentsModule } from '../payments/payments.module';

@Module({
  imports: [WalletsModule, forwardRef(() => PaymentsModule)],
  controllers: [TipJarsController],
  providers: [TipJarsService],
  exports: [TipJarsService],
})
export class TipJarsModule {}
