import { Injectable, ConflictException, NotFoundException, BadRequestException, PayloadTooLargeException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '@fliq/database';
import { WalletType, UserType } from '@fliq/shared';
import { encryptToBuffer } from '../../common/utils/encryption.util';
import { CreateProviderProfileDto } from './dto/create-provider-profile.dto';
import { UpdateProviderProfileDto } from './dto/update-provider-profile.dto';

@Injectable()
export class ProvidersService {
  private readonly encryptionKey: string | undefined;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {
    this.encryptionKey = this.config.get<string>('ENCRYPTION_KEY');
  }

  async createProfile(userId: string, dto: CreateProviderProfileDto) {
    // Check if provider profile already exists
    const existing = await this.prisma.provider.findUnique({ where: { id: userId } });
    if (existing) {
      throw new ConflictException('Provider profile already exists');
    }

    // Create provider profile and earnings wallet in a single transaction
    const [provider] = await this.prisma.$transaction([
      this.prisma.provider.create({
        data: {
          id: userId,
          category: dto.category,
          displayName: dto.displayName,
          bio: dto.bio,
          upiVpa: dto.upiVpa,
        },
      }),
      // Upgrade user type to PROVIDER and set name for backward compat
      this.prisma.user.update({
        where: { id: userId },
        data: { type: UserType.PROVIDER, name: dto.displayName },
      }),
      // Create or reuse earnings wallet
      this.prisma.wallet.upsert({
        where: {
          userId_type: { userId, type: WalletType.PROVIDER_EARNINGS },
        },
        create: {
          userId,
          type: WalletType.PROVIDER_EARNINGS,
          balancePaise: 0,
        },
        update: {}, // wallet already exists, no changes needed
      }),
    ]);

    return provider;
  }

  async getProfile(userId: string) {
    const provider = await this.prisma.provider.findUnique({
      where: { id: userId },
      include: { user: { select: { name: true, phone: true, kycStatus: true } } },
    });
    if (!provider) throw new NotFoundException('Provider profile not found');
    return provider;
  }

  async getPublicProfile(providerId: string) {
    const provider = await this.prisma.provider.findUnique({
      where: { id: providerId },
      include: { user: { select: { name: true } } },
    });
    if (!provider) throw new NotFoundException('Provider not found');

    // Get today's stats
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const [tipsToday, recentAppreciations] = await Promise.all([
      this.prisma.tip.count({
        where: {
          providerId,
          status: { in: ['PAID', 'SETTLED'] },
          createdAt: { gte: todayStart },
        },
      }),
      this.prisma.tip.count({
        where: {
          providerId,
          status: { in: ['PAID', 'SETTLED'] },
          createdAt: {
            gte: new Date(Date.now() - 60 * 60 * 1000), // last hour
          },
        },
      }),
    ]);

    // Get active dream
    const dream = await this.prisma.dream.findFirst({
      where: { workerId: providerId, isActive: true },
    });

    // Get reputation
    const reputation = await this.prisma.reputation.findUnique({
      where: { workerId: providerId },
    });

    return {
      id: provider.id,
      name: provider.displayName || provider.user.name,
      displayName: provider.displayName || provider.user.name,
      bio: provider.bio,
      avatarUrl: provider.avatarUrl,
      category: provider.category,
      ratingAverage: provider.ratingAverage,
      totalTipsReceived: provider.totalTipsReceived,
      qrCodeUrl: provider.qrCodeUrl,
      upiVpa: provider.upiVpa,
      stats: {
        tipsToday,
        recentAppreciations,
      },
      dream: dream
        ? {
            id: dream.id,
            title: dream.title,
            description: dream.description,
            goalAmount: Number(dream.goalAmount),
            currentAmount: Number(dream.currentAmount),
            percentage:
              Number(dream.goalAmount) > 0
                ? Math.min(
                    Math.round(
                      (Number(dream.currentAmount) / Number(dream.goalAmount)) *
                        100,
                    ),
                    100,
                  )
                : 0,
            mediaUrl: dream.mediaUrl,
            verified: dream.verified,
          }
        : null,
      reputation: reputation
        ? {
            score: Number(reputation.score),
            consistency: Number(reputation.consistency),
            uniqueTippers: reputation.uniqueTippers,
          }
        : null,
    };
  }

  async updateProfile(userId: string, dto: UpdateProviderProfileDto) {
    await this.getProfile(userId);

    const { bankAccountNumber, ifscCode, pan, ...rest } = dto;
    const updateData: Record<string, unknown> = { ...rest };

    if (bankAccountNumber) {
      if (!this.encryptionKey) throw new BadRequestException('Encryption not configured');
      updateData.bankAccountNumberEncrypted = encryptToBuffer(bankAccountNumber, this.encryptionKey);
    }
    if (ifscCode) {
      updateData.bankIfsc = ifscCode;
    }
    if (pan) {
      if (!this.encryptionKey) throw new BadRequestException('Encryption not configured');
      updateData.panEncrypted = encryptToBuffer(pan, this.encryptionKey);
    }

    return this.prisma.provider.update({
      where: { id: userId },
      data: updateData,
    });
  }

  async searchProviders(query: string, category?: string, page = 1, limit = 20) {
    if (!query || query.trim().length < 2) {
      throw new BadRequestException('Search query must be at least 2 characters');
    }

    const sanitized = query.trim();
    const skip = (page - 1) * limit;
    const take = Math.min(limit, 50); // cap at 50

    const where: any = {
      OR: [
        { displayName: { contains: sanitized, mode: 'insensitive' } },
        {
          user: {
            OR: [
              { name: { contains: sanitized, mode: 'insensitive' } },
              { phone: { contains: sanitized } },
            ],
          },
        },
      ],
      user: {
        status: 'ACTIVE',
        type: 'PROVIDER',
      },
    };

    if (category) {
      where.category = category.toUpperCase();
    }

    const [providers, total] = await Promise.all([
      this.prisma.provider.findMany({
        where,
        skip,
        take,
        orderBy: { totalTipsReceived: 'desc' },
        include: {
          user: { select: { name: true, phone: true } },
        },
      }),
      this.prisma.provider.count({ where }),
    ]);

    return {
      providers: providers.map((p) => ({
        id: p.id,
        name: p.displayName || p.user.name,
        phone: p.user.phone.replace(/(\d{2})\d{6}(\d{4})/, '$1******$2'), // mask phone
        category: p.category,
        ratingAverage: p.ratingAverage,
        totalTipsReceived: p.totalTipsReceived,
      })),
      total,
      page,
      limit: take,
    };
  }

  async updateAvatar(userId: string, file: Express.Multer.File) {
    await this.getProfile(userId);

    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    // Convert to base64 data URL
    const mimeType = file.mimetype;
    if (!mimeType.startsWith('image/')) {
      throw new BadRequestException('File must be an image');
    }

    const base64 = file.buffer.toString('base64');
    const dataUrl = `data:${mimeType};base64,${base64}`;

    // Reject if encoded data exceeds 100KB
    if (dataUrl.length > 100_000) {
      throw new PayloadTooLargeException('Avatar image too large. Please use an image under 75KB.');
    }

    return this.prisma.provider.update({
      where: { id: userId },
      data: { avatarUrl: dataUrl },
      select: { avatarUrl: true },
    });
  }
}
