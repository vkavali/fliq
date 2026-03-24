import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '@fliq/database';
import { CreatePaymentLinkDto } from './dto/create-payment-link.dto';
import { randomBytes } from 'crypto';

@Injectable()
export class PaymentLinksService {
  private readonly logger = new Logger(PaymentLinksService.name);
  private readonly baseUrl: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {
    this.baseUrl = this.config.get<string>(
      'APP_BASE_URL',
      'https://fliq-production-9ac7.up.railway.app',
    );
  }

  /**
   * Generate a short alphanumeric code (8 chars).
   */
  private generateShortCode(): string {
    return randomBytes(6).toString('base64url').replace(/[^a-zA-Z0-9]/g, '').substring(0, 8);
  }

  /**
   * Create a new payment link for the provider.
   */
  async createPaymentLink(userId: string, dto: CreatePaymentLinkDto) {
    const provider = await this.prisma.provider.findUnique({
      where: { id: userId },
      include: { user: true },
    });
    if (!provider) {
      throw new BadRequestException('Provider profile not found');
    }

    // Generate a unique short code (retry on collision)
    let shortCode: string;
    let attempts = 0;
    do {
      shortCode = this.generateShortCode();
      const existing = await this.prisma.paymentLink.findUnique({ where: { shortCode } });
      if (!existing) break;
      attempts++;
    } while (attempts < 5);

    if (attempts >= 5) {
      throw new BadRequestException('Could not generate unique link, please try again');
    }

    const paymentLink = await this.prisma.paymentLink.create({
      data: {
        providerId: userId,
        shortCode,
        description: dto.description,
        suggestedAmountPaise: dto.suggestedAmountPaise,
        allowCustomAmount: dto.allowCustomAmount ?? true,
      },
    });

    const shareableUrl = `${this.baseUrl}/tip/${shortCode}`;

    return {
      id: paymentLink.id,
      shortCode: paymentLink.shortCode,
      description: paymentLink.description,
      suggestedAmountPaise: paymentLink.suggestedAmountPaise,
      allowCustomAmount: paymentLink.allowCustomAmount,
      shareableUrl,
      createdAt: paymentLink.createdAt,
    };
  }

  /**
   * List all payment links for a provider.
   */
  async getMyPaymentLinks(userId: string) {
    const links = await this.prisma.paymentLink.findMany({
      where: { providerId: userId, isActive: true },
      orderBy: { createdAt: 'desc' },
    });

    return links.map((link) => ({
      id: link.id,
      shortCode: link.shortCode,
      description: link.description,
      suggestedAmountPaise: link.suggestedAmountPaise,
      allowCustomAmount: link.allowCustomAmount,
      clickCount: link.clickCount,
      shareableUrl: `${this.baseUrl}/tip/${link.shortCode}`,
      createdAt: link.createdAt,
    }));
  }

  /**
   * Resolve a short code to provider info (public endpoint).
   */
  async resolvePaymentLink(shortCodeOrId: string) {
    const paymentLink = await this.prisma.paymentLink.findFirst({
      where: {
        OR: [{ shortCode: shortCodeOrId }, { id: shortCodeOrId }],
        isActive: true,
      },
      include: {
        provider: {
          include: { user: { select: { name: true } } },
        },
      },
    });

    if (!paymentLink) {
      throw new NotFoundException('Payment link not found or inactive');
    }

    // Increment click count
    await this.prisma.paymentLink.update({
      where: { id: paymentLink.id },
      data: { clickCount: { increment: 1 } },
    });

    return {
      paymentLinkId: paymentLink.id,
      shortCode: paymentLink.shortCode,
      providerId: paymentLink.providerId,
      providerName: paymentLink.provider.user.name,
      category: paymentLink.provider.category,
      ratingAverage: paymentLink.provider.ratingAverage,
      totalTipsReceived: paymentLink.provider.totalTipsReceived,
      description: paymentLink.description,
      suggestedAmountPaise: paymentLink.suggestedAmountPaise,
      allowCustomAmount: paymentLink.allowCustomAmount,
    };
  }

  /**
   * Deactivate a payment link.
   */
  async deletePaymentLink(userId: string, linkId: string) {
    const link = await this.prisma.paymentLink.findUnique({ where: { id: linkId } });
    if (!link) {
      throw new NotFoundException('Payment link not found');
    }
    if (link.providerId !== userId) {
      throw new ForbiddenException('Not your payment link');
    }

    await this.prisma.paymentLink.update({
      where: { id: linkId },
      data: { isActive: false },
    });

    return { message: 'Payment link deactivated' };
  }
}
