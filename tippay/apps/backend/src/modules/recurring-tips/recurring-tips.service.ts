import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ServiceUnavailableException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '@fliq/database';
import { RazorpayService } from '../payments/razorpay.service';
import { CreateRecurringTipDto, RecurringTipFrequency } from './dto/create-recurring-tip.dto';

@Injectable()
export class RecurringTipsService {
  private readonly logger = new Logger(RecurringTipsService.name);
  private readonly isDev: boolean;

  constructor(
    private readonly prisma: PrismaService,
    private readonly razorpay: RazorpayService,
    private readonly config: ConfigService,
  ) {
    this.isDev = this.config.get<string>('APP_ENV', 'development') === 'development';
  }

  /**
   * Create a recurring tip mandate via Razorpay Subscriptions (UPI Autopay).
   * Returns the subscription short_url for the customer to authorize the mandate.
   */
  async createRecurringTip(dto: CreateRecurringTipDto, customerId: string) {
    if (!this.razorpay.isConfigured()) {
      throw new ServiceUnavailableException(
        'Payment system not configured. Please contact support.',
      );
    }

    // Validate provider
    const provider = await this.prisma.provider.findUnique({
      where: { id: dto.providerId },
      include: { user: true },
    });
    if (!provider || provider.user.status !== 'ACTIVE') {
      throw new BadRequestException('Provider not found or inactive');
    }

    // Check for existing active mandate for same customer+provider
    const existing = await this.prisma.recurringTip.findFirst({
      where: {
        customerId,
        providerId: dto.providerId,
        status: { in: ['PENDING_AUTHORIZATION', 'ACTIVE', 'PAUSED'] },
      },
    });
    if (existing) {
      throw new BadRequestException(
        'An active recurring tip already exists for this provider. Pause or cancel it first.',
      );
    }

    const periodMap: Record<RecurringTipFrequency, 'weekly' | 'monthly'> = {
      [RecurringTipFrequency.WEEKLY]: 'weekly',
      [RecurringTipFrequency.MONTHLY]: 'monthly',
    };
    const period = periodMap[dto.frequency];
    const providerName = provider.user.name || 'Service Provider';

    // Create Razorpay plan
    const plan = await this.razorpay.createPlan({
      period,
      interval: 1,
      amountPaise: dto.amountPaise,
      name: `Recurring tip for ${providerName}`,
      description: `${dto.frequency.toLowerCase()} tip of Rs ${dto.amountPaise / 100} to ${providerName}`,
    });

    // Create Razorpay subscription (120 cycles ≈ 10 years for monthly; effectively perpetual)
    const totalCount = dto.frequency === RecurringTipFrequency.WEEKLY ? 520 : 120;
    const subscription = await this.razorpay.createSubscription({
      planId: plan.id,
      totalCount,
      notes: {
        providerId: dto.providerId,
        customerId,
        frequency: dto.frequency,
      },
    });

    // Persist the RecurringTip record
    const recurringTip = await this.prisma.recurringTip.create({
      data: {
        customerId,
        providerId: dto.providerId,
        amountPaise: BigInt(dto.amountPaise),
        frequency: dto.frequency,
        status: 'PENDING_AUTHORIZATION',
        razorpayPlanId: plan.id,
        razorpaySubscriptionId: subscription.id,
      },
    });

    return {
      recurringTipId: recurringTip.id,
      subscriptionId: subscription.id,
      authorizationUrl: subscription.short_url,
      razorpayKeyId: this.isDev ? 'rzp_test_dev' : this.razorpay.getRazorpayKeyId(),
      provider: {
        name: providerName,
        category: provider.category,
      },
    };
  }

  async getRecurringTipsByCustomer(customerId: string) {
    const tips = await this.prisma.recurringTip.findMany({
      where: { customerId },
      orderBy: { createdAt: 'desc' },
      include: {
        provider: {
          select: {
            name: true,
            providerProfile: { select: { category: true, displayName: true, avatarUrl: true } },
          },
        },
      },
    });
    return tips;
  }

  async getRecurringTipsByProvider(providerId: string) {
    const tips = await this.prisma.recurringTip.findMany({
      where: { providerId, status: 'ACTIVE' },
      orderBy: { createdAt: 'desc' },
      include: {
        customer: { select: { name: true } },
      },
    });
    return tips;
  }

  async pauseRecurringTip(recurringTipId: string, customerId: string) {
    const tip = await this.findAndAuthorize(recurringTipId, customerId);

    if (tip.status !== 'ACTIVE') {
      throw new BadRequestException('Only active recurring tips can be paused');
    }

    if (tip.razorpaySubscriptionId) {
      await this.razorpay.pauseSubscription(tip.razorpaySubscriptionId);
    }

    await this.prisma.recurringTip.update({
      where: { id: recurringTipId },
      data: { status: 'PAUSED' },
    });

    return { status: 'paused' };
  }

  async resumeRecurringTip(recurringTipId: string, customerId: string) {
    const tip = await this.findAndAuthorize(recurringTipId, customerId);

    if (tip.status !== 'PAUSED') {
      throw new BadRequestException('Only paused recurring tips can be resumed');
    }

    if (tip.razorpaySubscriptionId) {
      await this.razorpay.resumeSubscription(tip.razorpaySubscriptionId);
    }

    await this.prisma.recurringTip.update({
      where: { id: recurringTipId },
      data: { status: 'ACTIVE' },
    });

    return { status: 'active' };
  }

  async cancelRecurringTip(recurringTipId: string, customerId: string) {
    const tip = await this.findAndAuthorize(recurringTipId, customerId);

    if (tip.status === 'CANCELLED' || tip.status === 'COMPLETED') {
      throw new BadRequestException('Recurring tip is already cancelled or completed');
    }

    if (tip.razorpaySubscriptionId) {
      await this.razorpay.cancelSubscription(tip.razorpaySubscriptionId, false);
    }

    await this.prisma.recurringTip.update({
      where: { id: recurringTipId },
      data: { status: 'CANCELLED' },
    });

    return { status: 'cancelled' };
  }

  private async findAndAuthorize(recurringTipId: string, customerId: string) {
    const tip = await this.prisma.recurringTip.findUnique({
      where: { id: recurringTipId },
    });
    if (!tip) throw new NotFoundException('Recurring tip not found');
    if (tip.customerId !== customerId) {
      throw new BadRequestException('Not authorized');
    }
    return tip;
  }
}
