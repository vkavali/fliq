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
  private readonly keyId: string;
  private readonly keySecret: string;

  constructor(private readonly config: ConfigService) {
    // Lazy-init to avoid import issues in test
    this.webhookSecret = this.config.get<string>('RAZORPAY_WEBHOOK_SECRET', '');
    this.keyId = this.config.get<string>('RAZORPAY_KEY_ID', '');
    this.keySecret = this.config.get<string>('RAZORPAY_KEY_SECRET', '');

    if (!this.keyId || !this.keySecret) {
      this.logger.warn(
        'RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET not set — payment endpoints will return 503',
      );
    }
  }

  /** Returns true only when both Razorpay API keys are present. */
  isConfigured(): boolean {
    return Boolean(this.keyId && this.keySecret);
  }

  private async getClient() {
    if (!this.razorpay) {
      const Razorpay = (await import('razorpay')).default;
      this.razorpay = new Razorpay({
        key_id: this.keyId,
        key_secret: this.keySecret,
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
    const body = `${orderId}|${paymentId}`;
    const expected = crypto.createHmac('sha256', this.keySecret).update(body).digest('hex');
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

  /**
   * Create a Razorpay Plan for recurring billing.
   * Returns the plan ID used when creating a subscription.
   */
  async createPlan(params: {
    period: 'weekly' | 'monthly';
    interval: number;
    amountPaise: number;
    name: string;
    description?: string;
  }): Promise<{ id: string }> {
    const client = await this.getClient();
    const plan = await client.plans.create({
      period: params.period,
      interval: params.interval,
      item: {
        name: params.name,
        amount: params.amountPaise,
        currency: 'INR',
        description: params.description || params.name,
      },
    });
    this.logger.log(`Razorpay plan created: ${plan.id}`);
    return plan;
  }

  /**
   * Create a Razorpay Subscription (UPI Autopay mandate).
   * Returns the subscription object including the short_url for mandate setup.
   */
  async createSubscription(params: {
    planId: string;
    totalCount: number;
    startAt?: number; // Unix timestamp
    notes?: Record<string, string>;
  }): Promise<{ id: string; short_url: string; status: string }> {
    const client = await this.getClient();
    const subscription = await client.subscriptions.create({
      plan_id: params.planId,
      total_count: params.totalCount,
      quantity: 1,
      ...(params.startAt ? { start_at: params.startAt } : {}),
      customer_notify: 1,
      notes: params.notes || {},
    });
    this.logger.log(`Razorpay subscription created: ${subscription.id}`);
    return subscription;
  }

  /**
   * Cancel a Razorpay Subscription.
   * cancelAtCycleEnd: if true, cancels after the current billing cycle.
   */
  async cancelSubscription(subscriptionId: string, cancelAtCycleEnd = false): Promise<void> {
    const client = await this.getClient();
    await client.subscriptions.cancel(subscriptionId, cancelAtCycleEnd);
    this.logger.log(`Razorpay subscription cancelled: ${subscriptionId}`);
  }

  /**
   * Pause a Razorpay Subscription.
   */
  async pauseSubscription(subscriptionId: string): Promise<void> {
    const client = await this.getClient();
    await client.subscriptions.pause(subscriptionId, { pause_at: 'now' });
    this.logger.log(`Razorpay subscription paused: ${subscriptionId}`);
  }

  /**
   * Resume a paused Razorpay Subscription.
   */
  async resumeSubscription(subscriptionId: string): Promise<void> {
    const client = await this.getClient();
    await client.subscriptions.resume(subscriptionId, { resume_at: 'now' });
    this.logger.log(`Razorpay subscription resumed: ${subscriptionId}`);
  }

  getRazorpayKeyId(): string {
    return this.keyId;
  }
}
