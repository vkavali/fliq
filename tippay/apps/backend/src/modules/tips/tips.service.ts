import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ServiceUnavailableException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '@fliq/database';
import {
  calculateCommission,
  calculateGstOnCommission,
  ZERO_COMMISSION_THRESHOLD_PAISE,
  DEFAULT_COMMISSION_RATE,
  GST_RATE_ON_COMMISSION,
  CURRENCY,
} from '@fliq/shared';
import { RazorpayService } from '../payments/razorpay.service';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateTipDto } from './dto/create-tip.dto';
import { VerifyPaymentDto } from './dto/verify-payment.dto';


@Injectable()
export class TipsService {
  private readonly logger = new Logger(TipsService.name);
  private readonly isDev: boolean;

  constructor(
    private readonly prisma: PrismaService,
    private readonly razorpay: RazorpayService,
    private readonly payments: PaymentsService,
    private readonly config: ConfigService,
    private readonly notifications: NotificationsService,
  ) {
    this.isDev = this.config.get<string>('APP_ENV', 'development') === 'development';
  }

  /**
   * Create a tip: calculate commission, create DB record, create Razorpay order.
   * Returns tipId + orderId for the mobile client to open Razorpay checkout.
   */
  async createTip(dto: CreateTipDto, customerId?: string) {
    if (!this.razorpay.isConfigured()) {
      throw new ServiceUnavailableException(
        'Payment system not configured. Please contact support.',
      );
    }

    // Validate provider exists
    const provider = await this.prisma.provider.findUnique({
      where: { id: dto.providerId },
      include: { user: true },
    });
    if (!provider || provider.user.status !== 'ACTIVE') {
      throw new BadRequestException('Provider not found or inactive');
    }

    const amountPaise = BigInt(dto.amountPaise);
    const commissionPaise = BigInt(
      calculateCommission(dto.amountPaise, ZERO_COMMISSION_THRESHOLD_PAISE, DEFAULT_COMMISSION_RATE),
    );
    const gstOnCommission = BigInt(
      calculateGstOnCommission(Number(commissionPaise), GST_RATE_ON_COMMISSION),
    );
    const netAmountPaise = amountPaise - commissionPaise - gstOnCommission;

    // Check if the provider belongs to an active tip pool
    const poolMembership = await this.prisma.tipPoolMember.findFirst({
      where: {
        userId: dto.providerId,
        isActive: true,
        pool: { isActive: true },
      },
      include: { pool: true },
    });
    const tipPoolId = poolMembership?.poolId ?? null;

    // Create tip record
    const tip = await this.prisma.tip.create({
      data: {
        customerId: customerId || null,
        providerId: dto.providerId,
        amountPaise,
        commissionPaise,
        commissionRate: dto.amountPaise > ZERO_COMMISSION_THRESHOLD_PAISE
          ? DEFAULT_COMMISSION_RATE
          : 0,
        netAmountPaise,
        gstOnCommissionPaise: gstOnCommission,
        source: dto.source,
        intent: dto.intent || null,
        message: dto.message,
        rating: dto.rating,
        gateway: 'razorpay',
        tipPoolId,
      },
    });

    // Create Razorpay order
    const order = await this.razorpay.createOrder({
      amount: dto.amountPaise,
      currency: CURRENCY,
      receipt: tip.id,
      notes: {
        tipId: tip.id,
        providerId: dto.providerId,
      },
    });
    const orderId = order.id;

    // Store order ID on tip
    await this.prisma.tip.update({
      where: { id: tip.id },
      data: { gatewayOrderId: orderId },
    });

    return {
      tipId: tip.id,
      orderId,
      amount: dto.amountPaise,
      currency: CURRENCY,
      razorpayKeyId: this.isDev ? 'rzp_test_dev' : this.razorpay.getRazorpayKeyId(),
      provider: {
        name: provider.user.name,
        category: provider.category,
      },
    };
  }

  /**
   * Verify payment after Razorpay checkout completes on the client side.
   * This is a client-side verification; the authoritative confirmation comes via webhook.
   * When DEV_BYPASS_ENABLED=true and the order is a mock order, settlement runs immediately
   * (no webhook needed — full tip lifecycle completes in this call).
   */
  async verifyPayment(tipId: string, dto: VerifyPaymentDto) {
    const tip = await this.prisma.tip.findUnique({ where: { id: tipId } });
    if (!tip) throw new NotFoundException('Tip not found');
    if (tip.status !== 'INITIATED') {
      throw new BadRequestException('Tip already processed');
    }

    const isMockOrder = dto.razorpay_order_id.startsWith('mock_order_');

    const isValid = this.razorpay.verifyPaymentSignature(
      dto.razorpay_order_id,
      dto.razorpay_payment_id,
      dto.razorpay_signature,
    );

    if (!isValid) {
      throw new BadRequestException('Invalid payment signature');
    }

    // When bypass is active with a mock order, run the full settlement immediately
    // so wallets are credited without needing a real Razorpay webhook.
    if (isMockOrder && this.razorpay.isBypassEnabled()) {
      this.logger.warn(`[DEV BYPASS] Auto-settling mock tip ${tipId}`);
      const mockPayload = {
        payment: {
          entity: {
            id: dto.razorpay_payment_id,
            order_id: dto.razorpay_order_id,
            method: 'upi',
          },
        },
      };
      await this.payments.handleWebhookEvent('payment.captured', mockPayload);
      return { status: 'verified', tipId, bypass: true };
    }

    // Mark as paid (webhook will handle full settlement, but this gives immediate feedback)
    const paidTip = await this.prisma.tip.update({
      where: { id: tipId },
      data: {
        status: 'PAID',
        gatewayPaymentId: dto.razorpay_payment_id,
      },
      include: {
        provider: { select: { phone: true, name: true } },
        customer: { select: { name: true } },
      },
    });

    // Fire push + SMS notification (non-blocking)
    this.notifications
      .notifyTipReceived(
        paidTip.providerId,
        paidTip.provider.phone,
        Number(paidTip.amountPaise),
        paidTip.customer?.name ?? undefined,
        paidTip.message ?? undefined,
      )
      .catch((err) => this.logger.error('Failed to send tip notification', err));

    return { status: 'verified', tipId };
  }

  async getTipsByProvider(providerId: string, page: number = 1, limit: number = 20) {
    const skip = (page - 1) * limit;
    const [tips, total] = await Promise.all([
      this.prisma.tip.findMany({
        where: { providerId },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          customer: { select: { name: true } },
        },
      }),
      this.prisma.tip.count({ where: { providerId } }),
    ]);
    return { tips, total, page, limit };
  }

  async getTipsByCustomer(customerId: string, page: number = 1, limit: number = 20) {
    const skip = (page - 1) * limit;
    const [tips, total] = await Promise.all([
      this.prisma.tip.findMany({
        where: { customerId },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          provider: { select: { name: true, providerProfile: { select: { category: true } } } },
        },
      }),
      this.prisma.tip.count({ where: { customerId } }),
    ]);
    return { tips, total, page, limit };
  }

  /**
   * Get the impact of a specific tip — used for the V5 Impact Screen.
   * Returns dream progress before/after + emotional message.
   */
  async getTipImpact(tipId: string) {
    const tip = await this.prisma.tip.findUnique({
      where: { id: tipId },
      include: {
        provider: { select: { name: true } },
        dreamContributions: {
          include: {
            dream: {
              select: {
                id: true,
                title: true,
                goalAmount: true,
                currentAmount: true,
              },
            },
          },
        },
      },
    });

    if (!tip) throw new NotFoundException('Tip not found');

    const workerName = tip.provider.name || 'the worker';
    const amount = Number(tip.amountPaise);
    const netAmount = Number(tip.netAmountPaise);

    // Build dream impact if a contribution was made
    let dream = null;
    if (tip.dreamContributions.length > 0) {
      const contrib = tip.dreamContributions[0];
      const goalAmount = Number(contrib.dream.goalAmount);
      const currentAmount = Number(contrib.dream.currentAmount);
      const contributedAmount = Number(contrib.amountPaise);
      const previousAmount = currentAmount - contributedAmount;

      dream = {
        title: contrib.dream.title,
        previousProgress: goalAmount > 0 ? Math.round((previousAmount / goalAmount) * 100) : 0,
        newProgress: goalAmount > 0 ? Math.min(Math.round((currentAmount / goalAmount) * 100), 100) : 0,
        goalAmount,
        currentAmount,
      };
    }

    // Build emotional message
    let message: string;
    if (dream) {
      message = `You helped ${workerName} reach ${dream.newProgress}% of their dream`;
    } else {
      message = `Your appreciation of ₹${Math.round(netAmount / 100)} made ${workerName}'s day!`;
    }

    return {
      tipId: tip.id,
      workerName,
      amount,
      intent: tip.intent || null,
      dream,
      message,
    };
  }

  /**
   * Get the current status of a tip — used for polling after UPI handoff.
   */
  async getTipStatus(tipId: string) {
    const tip = await this.prisma.tip.findUnique({
      where: { id: tipId },
      select: { id: true, status: true, updatedAt: true },
    });

    if (!tip) throw new NotFoundException('Tip not found');

    return {
      tipId: tip.id,
      status: tip.status,
      updatedAt: tip.updatedAt,
    };
  }
}
