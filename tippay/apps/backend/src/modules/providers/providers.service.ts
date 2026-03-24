import { Injectable, ConflictException, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '@fliq/database';
import { WalletType, UserType } from '@fliq/shared';
import { CreateProviderProfileDto } from './dto/create-provider-profile.dto';
import { UpdateProviderProfileDto } from './dto/update-provider-profile.dto';

@Injectable()
export class ProvidersService {
  constructor(private readonly prisma: PrismaService) {}

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
          upiVpa: dto.upiVpa,
        },
      }),
      // Upgrade user type to PROVIDER
      this.prisma.user.update({
        where: { id: userId },
        data: { type: UserType.PROVIDER },
      }),
      // Create earnings wallet
      this.prisma.wallet.create({
        data: {
          userId,
          type: WalletType.PROVIDER_EARNINGS,
          balancePaise: 0,
        },
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
    return {
      id: provider.id,
      name: provider.user.name,
      category: provider.category,
      ratingAverage: provider.ratingAverage,
      totalTipsReceived: provider.totalTipsReceived,
      qrCodeUrl: provider.qrCodeUrl,
      upiVpa: provider.upiVpa,
    };
  }

  async updateProfile(userId: string, dto: UpdateProviderProfileDto) {
    await this.getProfile(userId);
    return this.prisma.provider.update({
      where: { id: userId },
      data: dto,
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
      user: {
        status: 'ACTIVE',
        type: 'PROVIDER',
        OR: [
          { name: { contains: sanitized, mode: 'insensitive' } },
          { phone: { contains: sanitized } },
        ],
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
        name: p.user.name,
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
}
