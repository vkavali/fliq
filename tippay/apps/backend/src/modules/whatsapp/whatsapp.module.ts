import { Module } from '@nestjs/common';
import { WhatsAppController } from './whatsapp.controller';
import { WhatsAppService } from './whatsapp.service';
import { WhatsAppBotService } from './whatsapp-bot.service';
import { WhatsAppOutboxService } from './whatsapp-outbox.service';
import { WalletsModule } from '../wallets/wallets.module';
import { PayoutsModule } from '../payouts/payouts.module';

@Module({
  imports: [WalletsModule, PayoutsModule],
  controllers: [WhatsAppController],
  providers: [WhatsAppService, WhatsAppBotService, WhatsAppOutboxService],
  exports: [WhatsAppService],
})
export class WhatsAppModule {}
