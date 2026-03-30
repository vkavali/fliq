import { Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { PushNotificationsModule } from '../push-notifications/push-notifications.module';
import { WhatsAppModule } from '../whatsapp/whatsapp.module';

@Module({
  imports: [PushNotificationsModule, WhatsAppModule],
  providers: [NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
