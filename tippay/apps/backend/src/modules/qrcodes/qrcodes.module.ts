import { Module } from '@nestjs/common';
import { QrCodesController } from './qrcodes.controller';
import { QrCodesService } from './qrcodes.service';
import { PaymentsModule } from '../payments/payments.module';

@Module({
  imports: [PaymentsModule],
  controllers: [QrCodesController],
  providers: [QrCodesService],
  exports: [QrCodesService],
})
export class QrCodesModule {}
