import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private readonly isDev: boolean;

  constructor(private readonly config: ConfigService) {
    this.isDev = this.config.get<string>('NODE_ENV', 'development') !== 'production';
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
    // const senderId = this.config.get<string>('MSG91_SENDER_ID');
    // TODO: implement MSG91 HTTP call
    this.logger.warn('SMS sending not implemented for production');
  }

  async notifyTipReceived(phone: string, amount: number, customerName?: string): Promise<void> {
    const rupees = (amount / 100).toFixed(2);
    const from = customerName ? ` from ${customerName}` : '';
    await this.sendSms(phone, `You received a tip of Rs ${rupees}${from} on Fliq!`);
  }

  async notifyPayoutProcessed(phone: string, amount: number): Promise<void> {
    const rupees = (amount / 100).toFixed(2);
    await this.sendSms(phone, `Your Fliq payout of Rs ${rupees} has been processed.`);
  }

  async notifyPayoutFailed(phone: string, amount: number): Promise<void> {
    const rupees = (amount / 100).toFixed(2);
    await this.sendSms(phone, `Your Fliq payout of Rs ${rupees} failed. Please try again.`);
  }
}
