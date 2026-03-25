import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '@fliq/database';
import {
  calculateCommission,
  calculateGstOnCommission,
  ZERO_COMMISSION_THRESHOLD_PAISE,
  DEFAULT_COMMISSION_RATE,
  GST_RATE_ON_COMMISSION,
  WalletType,
} from '@fliq/shared';
import { WalletsService } from '../wallets/wallets.service';

/**
 * Runs daily and settles any recurring tips where Razorpay has already charged
 * the customer (status updated to ACTIVE via subscription.charged webhook).
 *
 * The primary settlement flow is webhook-driven (subscription.charged).
 * This scheduler handles the nextChargeDate tracking and catches up any
 * tips that may have missed their webhook delivery.
 */
@Injectable()
export class RecurringChargeScheduler {
  private readonly logger = new Logger(RecurringChargeScheduler.name);
  private isRunning = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly wallets: WalletsService,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async processOverdueTips() {
    if (this.isRunning) return;
    this.isRunning = true;

    try {
      // Find active recurring tips with a nextChargeDate in the past
      const overdue = await this.prisma.recurringTip.findMany({
        where: {
          status: 'ACTIVE',
          nextChargeDate: { lte: new Date() },
        },
        take: 100,
      });

      if (overdue.length === 0) return;

      this.logger.log(`Processing ${overdue.length} overdue recurring tips`);

      for (const tip of overdue) {
        try {
          await this.settleRecurringCharge(tip.id);
        } catch (err) {
          this.logger.error(`Failed to settle recurring tip ${tip.id}: ${err}`);
        }
      }
    } catch (err) {
      this.logger.error('RecurringChargeScheduler failed', err);
    } finally {
      this.isRunning = false;
    }
  }

  /**
   * Settle a single recurring charge — called either by the scheduler or
   * directly from the subscription.charged webhook handler.
   */
  async settleRecurringCharge(
    recurringTipId: string,
    gatewayPaymentId?: string,
  ) {
    const recurringTip = await this.prisma.recurringTip.findUnique({
      where: { id: recurringTipId },
    });
    if (!recurringTip) return;

    const amountPaise = recurringTip.amountPaise;
    const commissionPaise = BigInt(
      calculateCommission(
        Number(amountPaise),
        ZERO_COMMISSION_THRESHOLD_PAISE,
        DEFAULT_COMMISSION_RATE,
      ),
    );
    const gstOnCommission = BigInt(
      calculateGstOnCommission(Number(commissionPaise), GST_RATE_ON_COMMISSION),
    );
    const netAmountPaise = amountPaise - commissionPaise - gstOnCommission;

    await this.prisma.$transaction(async (tx) => {
      // Create a Tip record to preserve ledger history
      const tip = await tx.tip.create({
        data: {
          customerId: recurringTip.customerId,
          providerId: recurringTip.providerId,
          amountPaise,
          commissionPaise,
          commissionRate:
            Number(amountPaise) > ZERO_COMMISSION_THRESHOLD_PAISE
              ? DEFAULT_COMMISSION_RATE
              : 0,
          netAmountPaise,
          gstOnCommissionPaise: gstOnCommission,
          source: 'IN_APP',
          status: 'SETTLED',
          gateway: 'razorpay',
          gatewayPaymentId: gatewayPaymentId || null,
          message: `Recurring tip (${recurringTip.frequency.toLowerCase()})`,
        },
      });

      // Create transaction record
      const transaction = await tx.transaction.create({
        data: {
          type: 'TIP',
          referenceId: tip.id,
          amountPaise,
          status: 'COMPLETED',
          gateway: 'razorpay',
          gatewayTransactionId: gatewayPaymentId || null,
          metadata: {
            recurringTipId: recurringTip.id,
            frequency: recurringTip.frequency,
          },
        },
      });

      // Credit provider wallet
      const providerWallet = await this.wallets.getOrCreateWallet(
        recurringTip.providerId,
        WalletType.PROVIDER_EARNINGS,
      );
      await this.wallets.creditWallet(
        providerWallet.id,
        netAmountPaise,
        transaction.id,
        `Recurring tip (${recurringTip.frequency.toLowerCase()})`,
        tx,
      );

      // Credit platform commission wallet (if any)
      if (commissionPaise > 0n) {
        const platformWallet = await tx.wallet.findFirst({
          where: { type: 'PLATFORM_COMMISSION' },
        });
        if (platformWallet) {
          const commTx = await tx.transaction.create({
            data: {
              type: 'COMMISSION',
              referenceId: tip.id,
              amountPaise: commissionPaise,
              status: 'COMPLETED',
            },
          });
          await this.wallets.creditWallet(
            platformWallet.id,
            commissionPaise,
            commTx.id,
            `Commission on recurring tip ${recurringTip.id}`,
            tx,
          );
        }
      }

      // Advance nextChargeDate and increment charge counter
      const nextCharge = this.nextChargeDate(recurringTip.frequency as 'WEEKLY' | 'MONTHLY');
      await tx.recurringTip.update({
        where: { id: recurringTip.id },
        data: {
          totalCharges: { increment: 1 },
          nextChargeDate: nextCharge,
        },
      });

      // Outbox event for Kafka
      await tx.outboxEvent.create({
        data: {
          aggregateType: 'recurring_tip',
          aggregateId: recurringTip.id,
          eventType: 'recurring_tip.charged',
          payload: {
            recurringTipId: recurringTip.id,
            tipId: tip.id,
            providerId: recurringTip.providerId,
            customerId: recurringTip.customerId,
            amountPaise: Number(amountPaise),
            netAmountPaise: Number(netAmountPaise),
          },
        },
      });
    });

    this.logger.log(
      `Recurring tip ${recurringTipId} settled. Provider: ${recurringTip.providerId}, ` +
        `amount: ${recurringTip.amountPaise} paise`,
    );
  }

  private nextChargeDate(frequency: 'WEEKLY' | 'MONTHLY'): Date {
    const now = new Date();
    if (frequency === 'WEEKLY') {
      now.setDate(now.getDate() + 7);
    } else {
      now.setMonth(now.getMonth() + 1);
    }
    return now;
  }
}
