import { Injectable, Logger } from '@nestjs/common';
import { PrismaService, PaymentMethod } from '@tippay/database';
import { RAZORPAY_EVENTS, WalletType } from '@tippay/shared';
import { WalletsService } from '../wallets/wallets.service';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly wallets: WalletsService,
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
      default:
        this.logger.log(`Unhandled webhook event: ${eventType}`);
    }
  }

  private async handlePaymentCaptured(payload: any): Promise<void> {
    const payment = payload?.payment?.entity;
    if (!payment) return;

    const tip = await this.prisma.tip.findFirst({
      where: { gatewayOrderId: payment.order_id },
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

      // Credit provider wallet
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
    });

    this.logger.log(`Tip ${tip.id} settled successfully`);
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
