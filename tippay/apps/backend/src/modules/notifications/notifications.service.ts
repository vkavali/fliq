import { Injectable, Logger, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PushNotificationsService } from '../push-notifications/push-notifications.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private readonly isDev: boolean;

  constructor(
    private readonly config: ConfigService,
    @Optional() private readonly push: PushNotificationsService,
  ) {
    this.isDev = this.config.get<string>('APP_ENV', 'development') !== 'production';
  }

  /**
   * Send an SMS notification.
   * In dev mode, logs to console instead of sending via SMS gateway.
   */
  async sendSms(phone: string, message: string): Promise<void> {
    if (this.isDev) {
      this.logger.log(`[DEV SMS] To: ${phone} | Message: ${message}`);
      return;
    }

    // Production: integrate MSG91 or similar
    // const apiKey = this.config.get<string>('MSG91_API_KEY');
    // TODO: implement MSG91 HTTP call
    this.logger.warn('SMS sending not implemented for production');
  }

  async notifyTipReceived(
    providerId: string,
    phone: string,
    amountPaise: number,
    customerName?: string,
    tipMessage?: string,
  ): Promise<void> {
    const rupees = (amountPaise / 100).toFixed(2);
    const from = customerName ? ` from ${customerName}` : '';
    await this.sendSms(phone, `You received a tip of Rs ${rupees}${from} on Fliq!`);
    await this.push?.sendTipReceived(providerId, amountPaise, customerName, tipMessage);
  }

  async notifyPayoutProcessed(providerId: string, phone: string, amountPaise: number): Promise<void> {
    const rupees = (amountPaise / 100).toFixed(2);
    await this.sendSms(phone, `Your Fliq payout of Rs ${rupees} has been processed.`);
    await this.push?.sendPayoutProcessed(providerId, amountPaise);
  }

  async notifyPayoutFailed(providerId: string, phone: string, amountPaise: number): Promise<void> {
    const rupees = (amountPaise / 100).toFixed(2);
    await this.sendSms(phone, `Your Fliq payout of Rs ${rupees} failed. Please try again.`);
    await this.push?.sendPayoutFailed(providerId, amountPaise);
  }

  async notifyBadgeEarned(userId: string, badgeName: string): Promise<void> {
    await this.push?.sendBadgeEarned(userId, badgeName);
  }
}
