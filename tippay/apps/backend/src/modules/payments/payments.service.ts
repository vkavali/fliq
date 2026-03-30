import { Injectable, Logger, Inject, Optional, forwardRef } from '@nestjs/common';
import { PrismaService, PaymentMethod } from '@fliq/database';
import { RAZORPAY_EVENTS, WalletType } from '@fliq/shared';
import { WalletsService } from '../wallets/wallets.service';
import { GamificationService } from '../gamification/gamification.service';
import { RecurringChargeScheduler } from '../recurring-tips/recurring-charge.scheduler';
import { TipJarsService } from '../tip-jars/tip-jars.service';
import { TipLaterService } from '../tip-later/tip-later.service';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly wallets: WalletsService,
    @Inject(forwardRef(() => GamificationService))
    private readonly gamification: GamificationService,
    @Optional() @Inject(forwardRef(() => RecurringChargeScheduler))
    private readonly recurringChargeScheduler: RecurringChargeScheduler | null,
    @Inject(forwardRef(() => TipJarsService))
    private readonly tipJars: TipJarsService,
    @Inject(forwardRef(() => TipLaterService))
    private readonly tipLater: TipLaterService,
  ) {}

  /**
   * Handle a Razorpay webhook event.
   * Called by WebhooksController after signature verification and dedup.
   */
  async handleWebhookEvent(eventType: string, payload: any): Promise<void> {
    switch (eventType) {
      case RAZORPAY_EVENTS.PAYMENT_CAPTURED:
        await this.handlePaymentCaptured(payload);
        break;
      case RAZORPAY_EVENTS.PAYMENT_FAILED:
        await this.handlePaymentFailed(payload);
        break;
      case RAZORPAY_EVENTS.PAYOUT_PROCESSED:
        await this.handlePayoutProcessed(payload);
        break;
      case RAZORPAY_EVENTS.PAYOUT_FAILED:
        await this.handlePayoutFailed(payload);
        break;
      case RAZORPAY_EVENTS.SUBSCRIPTION_AUTHENTICATED:
        await this.handleSubscriptionAuthenticated(payload);
        break;
      case RAZORPAY_EVENTS.SUBSCRIPTION_CHARGED:
        await this.handleSubscriptionCharged(payload);
        break;
      case RAZORPAY_EVENTS.SUBSCRIPTION_CANCELLED:
        await this.handleSubscriptionCancelled(payload);
        break;
      case RAZORPAY_EVENTS.SUBSCRIPTION_HALTED:
        await this.handleSubscriptionHalted(payload);
        break;
      default:
        this.logger.log(`Unhandled webhook event: ${eventType}`);
    }
  }

  private async handlePaymentCaptured(payload: any): Promise<void> {
    const payment = payload?.payment?.entity;
    if (!payment) return;

    const tip = await this.prisma.tip.findFirst({
      where: { gatewayOrderId: payment.order_id },
      select: {
        id: true, status: true, providerId: true, customerId: true,
        amountPaise: true, netAmountPaise: true, commissionPaise: true,
        rating: true, message: true, tipJarId: true,
      },
    });
    if (!tip || tip.status !== 'INITIATED') return;

    // Settle the tip: update status, create transaction, credit wallets
    await this.prisma.$transaction(async (tx) => {
      // Update tip status
      await tx.tip.update({
        where: { id: tip.id },
        data: {
          status: 'PAID',
          gatewayPaymentId: payment.id,
          paymentMethod: this.mapPaymentMethod(payment.method),
        },
      });

      // Create transaction record
      const transaction = await tx.transaction.create({
        data: {
          type: 'TIP',
          referenceId: tip.id,
          amountPaise: tip.amountPaise,
          status: 'COMPLETED',
          gateway: 'razorpay',
          gatewayTransactionId: payment.id,
        },
      });

      // Credit provider wallet — skip for jar tips (distributeContribution handles splits)
      if (!tip.tipJarId) {
        const providerWallet = await this.wallets.getOrCreateWallet(
          tip.providerId,
          WalletType.PROVIDER_EARNINGS,
        );
        await this.wallets.creditWallet(
          providerWallet.id,
          tip.netAmountPaise,
          transaction.id,
          `Tip received: ${tip.amountPaise} paise`,
          tx,
        );
      }

      // Credit platform commission wallet (if commission > 0)
      if (tip.commissionPaise > 0n) {
        // Find platform wallet - use the first PLATFORM_COMMISSION wallet
        const platformWallet = await tx.wallet.findFirst({
          where: { type: 'PLATFORM_COMMISSION' },
        });
        if (platformWallet) {
          const commTx = await tx.transaction.create({
            data: {
              type: 'COMMISSION',
              referenceId: tip.id,
              amountPaise: tip.commissionPaise,
              status: 'COMPLETED',
            },
          });
          await this.wallets.creditWallet(
            platformWallet.id,
            tip.commissionPaise,
            commTx.id,
            `Commission on tip ${tip.id}`,
            tx,
          );
        }
      }

      // Update provider stats (tip count + rating)
      await tx.provider.update({
        where: { id: tip.providerId },
        data: {
          totalTipsReceived: { increment: 1 },
          ...(tip.rating ? {
            ratingAverage: await this.calculateNewRating(tx, tip.providerId, tip.rating),
          } : {}),
        },
      });

      // Insert outbox event for Kafka
      await tx.outboxEvent.create({
        data: {
          aggregateType: 'tip',
          aggregateId: tip.id,
          eventType: 'tip.settled',
          payload: {
            tipId: tip.id,
            providerId: tip.providerId,
            amountPaise: Number(tip.amountPaise),
            netAmountPaise: Number(tip.netAmountPaise),
          },
        },
      });

      // Queue WhatsApp notification for provider (if opted in)
      const providerUser = await tx.user.findUnique({
        where: { id: tip.providerId },
        select: { phone: true, name: true, whatsappOptIn: true },
      });
      if (providerUser?.whatsappOptIn && providerUser.phone) {
        const rupees = (Number(tip.amountPaise) / 100).toFixed(2);
        const stars = tip.rating ? ` ${'⭐'.repeat(tip.rating)}` : '';
        const msg = tip.message ? `\n"${tip.message}"` : '';
        await tx.outboxEvent.create({
          data: {
            aggregateType: 'whatsapp',
            aggregateId: tip.id,
            eventType: 'tip.notify.provider',
            payload: {
              to: providerUser.phone,
              text:
                `💰 *New Tip Received!*\n\n` +
                `Amount: ₹${rupees}${stars}${msg}\n\n` +
                `Reply *balance* to check your wallet.`,
            },
          },
        });
      }
    });

    this.logger.log(`Tip ${tip.id} settled successfully`);

    // ── Tip Jar: distribute contribution to all members ─────────────
    if (tip.tipJarId) {
      try {
        await this.tipJars.distributeContribution(tip.id);
      } catch (err) {
        this.logger.error(`Tip jar distribution failed for tip ${tip.id}: ${err}`);
      }
    }

    // ── Deferred Tip: mark as collected ─────────────────────────────
    try {
      await this.tipLater.markAsCollected(tip.id);
    } catch (err) {
      this.logger.error(`Deferred tip mark-collected failed for tip ${tip.id}: ${err}`);
    }

    // ── Gamification: award badges & update streak ──────────────────
    try {
      const tipAmount = Number(tip.amountPaise);

      // Process tipper (customer) gamification
      if (tip.customerId) {
        await this.gamification.updateStreak(tip.customerId);
        const tipperBadges = await this.gamification.checkAndAwardBadges(
          tip.customerId,
          'TIPPER',
          tipAmount,
        );
        if (tipperBadges.length > 0) {
          this.logger.log(
            `Tipper ${tip.customerId} earned badges: ${tipperBadges.map((b) => b.code).join(', ')}`,
          );
        }
      }

      // Process provider gamification
      const providerBadges = await this.gamification.checkAndAwardBadges(
        tip.providerId,
        'PROVIDER',
        tipAmount,
      );
      if (providerBadges.length > 0) {
        this.logger.log(
          `Provider ${tip.providerId} earned badges: ${providerBadges.map((b) => b.code).join(', ')}`,
        );
      }
    } catch (err) {
      // Gamification errors should not break tip settlement
      this.logger.error(`Gamification processing failed for tip ${tip.id}: ${err}`);
    }
  }

  private async handlePaymentFailed(payload: any): Promise<void> {
    const payment = payload?.payment?.entity;
    if (!payment) return;

    await this.prisma.tip.updateMany({
      where: { gatewayOrderId: payment.order_id, status: 'INITIATED' },
      data: { status: 'FAILED' },
    });
  }

  private async handlePayoutProcessed(payload: any): Promise<void> {
    const payout = payload?.payout?.entity;
    if (!payout) return;

    await this.prisma.payout.updateMany({
      where: { gatewayPayoutId: payout.id },
      data: {
        status: 'SETTLED',
        utr: payout.utr,
        settledAt: new Date(),
      },
    });
  }

  private async handlePayoutFailed(payload: any): Promise<void> {
    const payout = payload?.payout?.entity;
    if (!payout) return;

    await this.prisma.payout.updateMany({
      where: { gatewayPayoutId: payout.id },
      data: {
        status: 'FAILED',
        failureReason: payout.failure_reason || 'Unknown',
      },
    });
  }

  private async calculateNewRating(
    tx: any,
    providerId: string,
    newRating: number,
  ): Promise<number> {
    const provider = await tx.provider.findUnique({ where: { id: providerId } });
    if (!provider) return newRating;

    const currentAvg = provider.ratingAverage ? Number(provider.ratingAverage) : 0;
    const currentCount = provider.totalTipsReceived; // before increment
    const ratedCount = currentAvg > 0 ? currentCount : 0;

    // Weighted average including the new rating
    return Number(((currentAvg * ratedCount + newRating) / (ratedCount + 1)).toFixed(2));
  }

  private async handleSubscriptionAuthenticated(payload: any): Promise<void> {
    const subscription = payload?.subscription?.entity;
    if (!subscription) return;

    await this.prisma.recurringTip.updateMany({
      where: {
        razorpaySubscriptionId: subscription.id,
        status: 'PENDING_AUTHORIZATION',
      },
      data: {
        status: 'ACTIVE',
        // First charge happens at subscription start_at; set nextChargeDate to now+period
        nextChargeDate: new Date(),
      },
    });

    this.logger.log(`Recurring tip mandate authenticated for subscription ${subscription.id}`);
  }

  private async handleSubscriptionCharged(payload: any): Promise<void> {
    const subscription = payload?.subscription?.entity;
    const payment = payload?.payment?.entity;
    if (!subscription) return;

    const recurringTip = await this.prisma.recurringTip.findUnique({
      where: { razorpaySubscriptionId: subscription.id },
    });
    if (!recurringTip) return;

    // Settle the charge via the scheduler (reuse settlement logic)
    if (this.recurringChargeScheduler) {
      await this.recurringChargeScheduler.settleRecurringCharge(
        recurringTip.id,
        payment?.id,
      );
    }
  }

  private async handleSubscriptionCancelled(payload: any): Promise<void> {
    const subscription = payload?.subscription?.entity;
    if (!subscription) return;

    await this.prisma.recurringTip.updateMany({
      where: { razorpaySubscriptionId: subscription.id },
      data: { status: 'CANCELLED' },
    });
    this.logger.log(`Recurring tip cancelled for subscription ${subscription.id}`);
  }

  private async handleSubscriptionHalted(payload: any): Promise<void> {
    const subscription = payload?.subscription?.entity;
    if (!subscription) return;

    await this.prisma.recurringTip.updateMany({
      where: { razorpaySubscriptionId: subscription.id },
      data: { status: 'HALTED' },
    });
    this.logger.log(`Recurring tip halted for subscription ${subscription.id}`);
  }

  private mapPaymentMethod(method: string): PaymentMethod {
    const map: Record<string, PaymentMethod> = {
      upi: 'UPI',
      card: 'CARD',
      netbanking: 'NET_BANKING',
      wallet: 'WALLET',
    };
    return map[method] || 'UPI';
  }
}
