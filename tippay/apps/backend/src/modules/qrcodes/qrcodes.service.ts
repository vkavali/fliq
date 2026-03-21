import {
  Injectable,
  BadRequestException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '@fliq/database';
import { QrCodeType } from '@fliq/shared';
import { RazorpayService } from '../payments/razorpay.service';
import { CreateQrCodeDto } from './dto/create-qrcode.dto';

@Injectable()
export class QrCodesService {
  private readonly logger = new Logger(QrCodesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly razorpay: RazorpayService,
  ) {}

  async createQrCode(userId: string, dto: CreateQrCodeDto) {
    const provider = await this.prisma.provider.findUnique({
      where: { id: userId },
      include: { user: true },
    });
    if (!provider) {
      throw new BadRequestException('Provider profile not found');
    }

    const type = dto.type || QrCodeType.STATIC;

    // Create Razorpay QR code
    let razorpayQr: any = null;
    try {
      razorpayQr = await this.razorpay.createQrCode({
        name: `${provider.user.name || 'Provider'} - ${dto.locationLabel || 'Default'}`,
        usage: 'multiple_use',
        fixedAmount: false,
        description: `Fliq QR for provider ${userId}`,
        notes: {
          providerId: userId,
          locationLabel: dto.locationLabel || '',
        },
      });
    } catch (error) {
      this.logger.error(`Razorpay QR creation failed for ${userId}`, error);
      // Continue — store record without Razorpay QR (can retry later)
    }

    const qrCode = await this.prisma.qrCode.create({
      data: {
        providerId: userId,
        type,
        razorpayQrId: razorpayQr?.id || null,
        qrImageUrl: razorpayQr?.image_url || null,
        upiUrl: razorpayQr?.short_url || null,
        locationLabel: dto.locationLabel,
      },
    });

    return {
      id: qrCode.id,
      type: qrCode.type,
      qrImageUrl: qrCode.qrImageUrl,
      upiUrl: qrCode.upiUrl,
      locationLabel: qrCode.locationLabel,
    };
  }

  async getQrCodesByProvider(providerId: string) {
    return this.prisma.qrCode.findMany({
      where: { providerId, isActive: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async resolveQrCode(qrCodeId: string) {
    const qrCode = await this.prisma.qrCode.findUnique({
      where: { id: qrCodeId },
      include: {
        provider: {
          include: { user: { select: { name: true } } },
        },
      },
    });
    if (!qrCode || !qrCode.isActive) {
      throw new NotFoundException('QR code not found or inactive');
    }

    // Increment scan count
    await this.prisma.qrCode.update({
      where: { id: qrCodeId },
      data: { scanCount: { increment: 1 } },
    });

    return {
      qrCodeId: qrCode.id,
      providerId: qrCode.providerId,
      providerName: qrCode.provider.user.name,
      category: qrCode.provider.category,
      locationLabel: qrCode.locationLabel,
    };
  }
}
