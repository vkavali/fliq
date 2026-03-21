import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

// Razorpay SDK types are loose; we define what we use.
interface RazorpayOrderParams {
  amount: number;
  currency: string;
  receipt: string;
  notes?: Record<string, string>;
}

interface RazorpayOrder {
  id: string;
  amount: number;
  currency: string;
  receipt: string;
  status: string;
}

@Injectable()
export class RazorpayService {
  private readonly logger = new Logger(RazorpayService.name);
  private razorpay: any; // eslint-disable-line @typescript-eslint/no-explicit-any
  private readonly webhookSecret: string;

  constructor(private readonly config: ConfigService) {
    // Lazy-init to avoid import issues in test
    this.webhookSecret = this.config.get<string>('RAZORPAY_WEBHOOK_SECRET', '');
  }

  private async getClient() {
    if (!this.razorpay) {
      const Razorpay = (await import('razorpay')).default;
      this.razorpay = new Razorpay({
        key_id: this.config.get<string>('RAZORPAY_KEY_ID', ''),
        key_secret: this.config.get<string>('RAZORPAY_KEY_SECRET', ''),
      });
    }
    return this.razorpay;
  }

  async createOrder(params: RazorpayOrderParams): Promise<RazorpayOrder> {
    const client = await this.getClient();
    const order = await client.orders.create(params);
    this.logger.log(`Razorpay order created: ${order.id} for ${params.amount} paise`);
    return order;
  }

  /**
   * Verify payment signature after checkout completion.
   * The signature is HMAC SHA256 of "orderId|paymentId" using key_secret.
   */
  verifyPaymentSignature(orderId: string, paymentId: string, signature: string): boolean {
    const keySecret = this.config.get<string>('RAZORPAY_KEY_SECRET', '');
    const body = `${orderId}|${paymentId}`;
    const expected = crypto.createHmac('sha256', keySecret).update(body).digest('hex');
    return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
  }

  /**
   * Verify webhook signature.
   * The signature is HMAC SHA256 of the raw body using webhook_secret.
   */
  verifyWebhookSignature(rawBody: string, signature: string): boolean {
    const expected = crypto
      .createHmac('sha256', this.webhookSecret)
      .update(rawBody)
      .digest('hex');
    try {
      return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
    } catch {
      return false;
    }
  }

  async createTransfer(paymentId: string, linkedAccountId: string, amountPaise: number) {
    const client = await this.getClient();
    return client.payments.transfer(paymentId, {
      transfers: [
        {
          account: linkedAccountId,
          amount: amountPaise,
          currency: 'INR',
        },
      ],
    });
  }

  async createPayout(fundAccountId: string, amountPaise: number, mode: string) {
    const client = await this.getClient();
    const accountNumber = this.config.get<string>('RAZORPAYX_ACCOUNT_NUMBER', '');
    return client.payouts?.create({
      account_number: accountNumber,
      fund_account_id: fundAccountId,
      amount: amountPaise,
      currency: 'INR',
      mode: mode.toLowerCase(),
      purpose: 'payout',
    });
  }

  async createQrCode(params: {
    name: string;
    usage: 'single_use' | 'multiple_use';
    fixedAmount: boolean;
    paymentAmount?: number;
    description: string;
    notes?: Record<string, string>;
  }) {
    const client = await this.getClient();
    return client.qrCode?.create({
      type: 'upi_qr',
      name: params.name,
      usage: params.usage,
      fixed_amount: params.fixedAmount,
      payment_amount: params.paymentAmount,
      description: params.description,
      notes: params.notes,
    });
  }

  getRazorpayKeyId(): string {
    return this.config.get<string>('RAZORPAY_KEY_ID', '');
  }
}
