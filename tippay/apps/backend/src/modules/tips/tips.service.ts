import {
  Injectable,
  BadRequestException,
  NotFoundException,
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
import { CreateTipDto } from './dto/create-tip.dto';
import { VerifyPaymentDto } from './dto/verify-payment.dto';
import { randomUUID } from 'crypto';

@Injectable()
export class TipsService {
  private readonly logger = new Logger(TipsService.name);
  private readonly isDev: boolean;

  constructor(
    private readonly prisma: PrismaService,
    private readonly razorpay: RazorpayService,
    private readonly config: ConfigService,
  ) {
    this.isDev = this.config.get<string>('APP_ENV', 'development') === 'development';
  }

  /**
   * Create a tip: calculate commission, create DB record, create Razorpay order.
   * Returns tipId + orderId for the mobile client to open Razorpay checkout.
   */
  async createTip(dto: CreateTipDto, customerId?: string) {
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
        message: dto.message,
        rating: dto.rating,
        gateway: 'razorpay',
      },
    });

    // Create Razorpay order (or mock in dev mode)
    let orderId: string;
    try {
      const order = await this.razorpay.createOrder({
        amount: dto.amountPaise,
        currency: CURRENCY,
        receipt: tip.id,
        notes: {
          tipId: tip.id,
          providerId: dto.providerId,
        },
      });
      orderId = order.id;
    } catch (err) {
      if (this.isDev) {
        // Mock order in dev mode when Razorpay keys aren't configured
        orderId = `order_dev_${randomUUID().replace(/-/g, '').substring(0, 14)}`;
        this.logger.warn(`Dev mode: mocked Razorpay order ${orderId}`);
      } else {
        throw err;
      }
    }

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
   */
  async verifyPayment(tipId: string, dto: VerifyPaymentDto) {
    const tip = await this.prisma.tip.findUnique({ where: { id: tipId } });
    if (!tip) throw new NotFoundException('Tip not found');
    if (tip.status !== 'INITIATED') {
      throw new BadRequestException('Tip already processed');
    }

    const isValid = this.razorpay.verifyPaymentSignature(
      dto.razorpay_order_id,
      dto.razorpay_payment_id,
      dto.razorpay_signature,
    );

    if (!isValid) {
      throw new BadRequestException('Invalid payment signature');
    }

    // Mark as paid (webhook will handle full settlement, but this gives immediate feedback)
    await this.prisma.tip.update({
      where: { id: tipId },
      data: {
        status: 'PAID',
        gatewayPaymentId: dto.razorpay_payment_id,
      },
    });

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
}
