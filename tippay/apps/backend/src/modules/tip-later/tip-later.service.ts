import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  Logger,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '@fliq/database';
import {
  calculateCommission,
  calculateGstOnCommission,
  ZERO_COMMISSION_THRESHOLD_PAISE,
  DEFAULT_COMMISSION_RATE,
  GST_RATE_ON_COMMISSION,
} from '@fliq/shared';
import { NotificationsService } from '../notifications/notifications.service';
import { RazorpayService } from '../payments/razorpay.service';
import { CreateDeferredTipDto } from './dto/create-deferred-tip.dto';

const DEFERRED_TIP_HOURS = 24;
const REMINDER_HOURS_BEFORE_DUE = 2;

@Injectable()
export class TipLaterService {
  private readonly logger = new Logger(TipLaterService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly config: ConfigService,
    @Inject(forwardRef(() => RazorpayService))
    private readonly razorpay: RazorpayService,
  ) {}

  // ─── Create a deferred tip promise ───────────────────────────────────────

  async createDeferredTip(customerId: string, dto: CreateDeferredTipDto) {
    const provider = await this.prisma.user.findUnique({
      where: { id: dto.providerId },
      select: { id: true, name: true, phone: true },
    });
    if (!provider) throw new NotFoundException('Provider not found');

    const customer = await this.prisma.user.findUnique({
      where: { id: customerId },
      select: { id: true, name: true, phone: true },
    });
    if (!customer) throw new NotFoundException('Customer not found');

    const dueAt = new Date(Date.now() + DEFERRED_TIP_HOURS * 60 * 60 * 1000);

    const deferred = await this.prisma.deferredTip.create({
      data: {
        customerId,
        providerId: dto.providerId,
        amountPaise: BigInt(dto.amountPaise),
        message: dto.message,
        rating: dto.rating,
        dueAt,
      },
      include: {
        provider: { select: { id: true, name: true, phone: true } },
        customer: { select: { id: true, name: true } },
      },
    });

    // Notify provider about the promise
    try {
      const rupees = (dto.amountPaise / 100).toFixed(2);
      await this.notifications.sendSms(
        provider.phone ?? '',
        `${customer.name ?? 'A customer'} has promised to tip you Rs ${rupees} on Fliq — arriving within ${DEFERRED_TIP_HOURS}h!`,
      );
    } catch (err) {
      this.logger.error(`Failed to notify provider of deferred tip promise: ${err}`);
    }

    return {
      ...deferred,
      amountPaise: Number(deferred.amountPaise),
      dueAt: deferred.dueAt.toISOString(),
    };
  }

  // ─── List my deferred tips (as customer) ─────────────────────────────────

  async getMyDeferredTips(customerId: string) {
    const tips = await this.prisma.deferredTip.findMany({
      where: { customerId },
      include: {
        provider: {
          select: {
            id: true,
            name: true,
            providerProfile: { select: { category: true, displayName: true, avatarUrl: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return tips.map((t) => ({
      ...t,
      amountPaise: Number(t.amountPaise),
    }));
  }

  // ─── List promised tips for a provider ───────────────────────────────────

  async getProviderPromises(providerId: string) {
    const tips = await this.prisma.deferredTip.findMany({
      where: {
        providerId,
        status: { in: ['PROMISED', 'COLLECTED'] },
      },
      include: {
        customer: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return tips.map((t) => ({
      ...t,
      amountPaise: Number(t.amountPaise),
    }));
  }

  // ─── Pay a deferred tip now ───────────────────────────────────────────────

  async payDeferredTip(deferredTipId: string, customerId: string) {
    const deferred = await this.prisma.deferredTip.findUnique({
      where: { id: deferredTipId },
      include: { provider: { select: { id: true, name: true } } },
    });

    if (!deferred) throw new NotFoundException('Deferred tip not found');
    if (deferred.customerId !== customerId) throw new ForbiddenException('Not your deferred tip');
    if (deferred.status !== 'PROMISED') {
      throw new BadRequestException(`Cannot pay a deferred tip with status ${deferred.status}`);
    }

    const amountPaise = Number(deferred.amountPaise);
    const commissionPaise = BigInt(
      calculateCommission(amountPaise, ZERO_COMMISSION_THRESHOLD_PAISE, DEFAULT_COMMISSION_RATE),
    );
    const gstOnCommissionPaise = BigInt(calculateGstOnCommission(Number(commissionPaise), GST_RATE_ON_COMMISSION));
    const netAmountPaise = BigInt(amountPaise) - commissionPaise - gstOnCommissionPaise;

    // Create a real tip record for payment
    const tip = await this.prisma.tip.create({
      data: {
        customerId,
        providerId: deferred.providerId,
        amountPaise: deferred.amountPaise,
        commissionPaise,
        netAmountPaise,
        gstOnCommissionPaise,
        source: 'IN_APP',
        gateway: 'razorpay',
        message: deferred.message,
        rating: deferred.rating,
      },
    });

    // Create Razorpay order so client can open checkout
    const order = await this.razorpay.createOrder({
      amount: amountPaise,
      currency: 'INR',
      receipt: tip.id,
      notes: { tipId: tip.id, deferredTipId },
    });

    await this.prisma.tip.update({
      where: { id: tip.id },
      data: { gatewayOrderId: order.id },
    });

    // Mark the deferred tip as having a pending tip
    await this.prisma.deferredTip.update({
      where: { id: deferredTipId },
      data: { tipId: tip.id },
    });

    return {
      tipId: tip.id,
      orderId: order.id,
      razorpayKeyId: this.config.get<string>('RAZORPAY_KEY_ID'),
      amount: amountPaise,
      currency: 'INR',
      deferredTipId,
      amountPaise,
      commissionPaise: Number(commissionPaise),
      netAmountPaise: Number(netAmountPaise),
      providerName: deferred.provider.name,
    };
  }

  // ─── Cancel a deferred tip ────────────────────────────────────────────────

  async cancelDeferredTip(deferredTipId: string, customerId: string) {
    const deferred = await this.prisma.deferredTip.findUnique({ where: { id: deferredTipId } });
    if (!deferred) throw new NotFoundException('Deferred tip not found');
    if (deferred.customerId !== customerId) throw new ForbiddenException('Not your deferred tip');
    if (deferred.status !== 'PROMISED') {
      throw new BadRequestException(`Cannot cancel a deferred tip with status ${deferred.status}`);
    }

    await this.prisma.deferredTip.update({
      where: { id: deferredTipId },
      data: { status: 'CANCELLED' },
    });

    return { cancelled: true };
  }

  // ─── Mark as collected (called by payments webhook after tip settles) ─────

  async markAsCollected(tipId: string) {
    const deferred = await this.prisma.deferredTip.findFirst({
      where: { tipId, status: 'PROMISED' },
    });
    if (!deferred) return; // No matching deferred tip

    await this.prisma.deferredTip.update({
      where: { id: deferred.id },
      data: { status: 'COLLECTED' },
    });

    this.logger.log(`Deferred tip ${deferred.id} marked as collected via tip ${tipId}`);
  }

  // ─── Cron: expire overdue promises & send reminders ──────────────────────

  @Cron(CronExpression.EVERY_30_MINUTES)
  async processExpiredAndReminders() {
    await this.expireOverdue();
    await this.sendDueReminders();
  }

  private async expireOverdue() {
    const result = await this.prisma.deferredTip.updateMany({
      where: {
        status: 'PROMISED',
        dueAt: { lt: new Date() },
        tipId: null, // Not yet paid
      },
      data: { status: 'EXPIRED' },
    });

    if (result.count > 0) {
      this.logger.log(`Expired ${result.count} overdue deferred tips`);
    }
  }

  private async sendDueReminders() {
    const reminderCutoff = new Date(Date.now() + REMINDER_HOURS_BEFORE_DUE * 60 * 60 * 1000);
    const nowPlus1Min = new Date(Date.now() + 60 * 1000);

    // Tips due within the next 2 hours that haven't been paid yet and haven't gotten a reminder
    // We use a simple approach: find tips where dueAt is close, status PROMISED, tipId null
    const upcoming = await this.prisma.deferredTip.findMany({
      where: {
        status: 'PROMISED',
        tipId: null,
        dueAt: { gte: nowPlus1Min, lte: reminderCutoff },
      },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        provider: { select: { id: true, name: true } },
      },
    });

    for (const tip of upcoming) {
      try {
        const rupees = (Number(tip.amountPaise) / 100).toFixed(2);
        await this.notifications.sendSms(
          tip.customer.phone ?? '',
          `Reminder: You promised Rs ${rupees} to ${tip.provider.name ?? 'a provider'} on Fliq. Tap to pay now before it expires!`,
        );
      } catch (err) {
        this.logger.error(`Reminder SMS failed for deferred tip ${tip.id}: ${err}`);
      }
    }

    if (upcoming.length > 0) {
      this.logger.log(`Sent ${upcoming.length} deferred tip reminders`);
    }
  }
}
