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
import { randomBytes } from 'crypto';
import { PrismaService } from '@fliq/database';
import {
  WalletType,
  calculateCommission,
  calculateGstOnCommission,
  ZERO_COMMISSION_THRESHOLD_PAISE,
  DEFAULT_COMMISSION_RATE,
  GST_RATE_ON_COMMISSION,
} from '@fliq/shared';
import { WalletsService } from '../wallets/wallets.service';
import { RazorpayService } from '../payments/razorpay.service';
import { CreateTipJarDto } from './dto/create-tip-jar.dto';
import { AddJarMemberDto } from './dto/add-jar-member.dto';
import { TipJarTipDto } from './dto/tip-jar-tip.dto';

@Injectable()
export class TipJarsService {
  private readonly logger = new Logger(TipJarsService.name);
  private readonly baseUrl: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly walletsService: WalletsService,
    private readonly config: ConfigService,
    @Inject(forwardRef(() => RazorpayService))
    private readonly razorpay: RazorpayService,
  ) {
    this.baseUrl = this.config.get<string>('APP_URL', 'https://fliq.co.in');
  }

  // ─── Create / Manage ──────────────────────────────────────────────────────

  async createJar(createdById: string, dto: CreateTipJarDto) {
    const shortCode = await this.generateUniqueShortCode();

    const jar = await this.prisma.tipJar.create({
      data: {
        name: dto.name,
        description: dto.description,
        eventType: dto.eventType,
        shortCode,
        createdById,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
        targetAmount: dto.targetAmountPaise ? BigInt(dto.targetAmountPaise) : null,
        members: {
          create: {
            providerId: createdById,
            splitPercentage: 100,
            roleLabel: 'Organizer',
          },
        },
      },
      include: {
        members: {
          include: {
            provider: { select: { id: true, name: true, phone: true } },
          },
        },
      },
    });

    return { ...jar, shareableUrl: `${this.baseUrl}/jar/${jar.shortCode}` };
  }

  async getMyJars(userId: string) {
    const owned = await this.prisma.tipJar.findMany({
      where: { createdById: userId, isActive: true },
      include: {
        members: {
          where: { isActive: true },
          include: {
            provider: { select: { id: true, name: true, phone: true } },
          },
        },
        _count: { select: { contributions: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const memberships = await this.prisma.tipJarMember.findMany({
      where: {
        providerId: userId,
        isActive: true,
        tipJar: { isActive: true, createdById: { not: userId } },
      },
      include: {
        tipJar: {
          include: {
            members: {
              where: { isActive: true },
              include: {
                provider: { select: { id: true, name: true, phone: true } },
              },
            },
            createdBy: { select: { id: true, name: true } },
            _count: { select: { contributions: true } },
          },
        },
      },
    });

    return {
      owned: owned.map((j) => ({ ...j, shareableUrl: `${this.baseUrl}/jar/${j.shortCode}` })),
      memberOf: memberships.map((m) => ({
        ...m.tipJar,
        shareableUrl: `${this.baseUrl}/jar/${m.tipJar.shortCode}`,
      })),
    };
  }

  async resolveJar(shortCode: string) {
    const jar = await this.prisma.tipJar.findUnique({
      where: { shortCode },
      include: {
        createdBy: { select: { id: true, name: true } },
        members: {
          where: { isActive: true },
          include: {
            provider: {
              select: {
                id: true,
                name: true,
                providerProfile: {
                  select: { category: true, displayName: true, avatarUrl: true },
                },
              },
            },
          },
        },
        _count: { select: { contributions: true } },
      },
    });

    if (!jar || !jar.isActive) {
      throw new NotFoundException('Tip jar not found or inactive');
    }

    if (jar.expiresAt && jar.expiresAt < new Date()) {
      throw new BadRequestException('This tip jar has expired');
    }

    return {
      ...jar,
      totalCollected: Number(jar.totalCollected),
      targetAmount: jar.targetAmount ? Number(jar.targetAmount) : null,
      shareableUrl: `${this.baseUrl}/jar/${jar.shortCode}`,
    };
  }

  async getJarById(jarId: string, userId: string) {
    const jar = await this.prisma.tipJar.findUnique({
      where: { id: jarId },
      include: {
        createdBy: { select: { id: true, name: true } },
        members: {
          where: { isActive: true },
          include: {
            provider: { select: { id: true, name: true, phone: true } },
          },
        },
        contributions: {
          orderBy: { createdAt: 'desc' },
          take: 20,
          include: {
            customer: { select: { id: true, name: true } },
          },
        },
        _count: { select: { contributions: true } },
      },
    });

    if (!jar || !jar.isActive) throw new NotFoundException('Tip jar not found');

    const isMember = jar.members.some((m) => m.providerId === userId);
    if (jar.createdById !== userId && !isMember) {
      throw new ForbiddenException('You are not part of this tip jar');
    }

    return {
      ...jar,
      totalCollected: Number(jar.totalCollected),
      targetAmount: jar.targetAmount ? Number(jar.targetAmount) : null,
      shareableUrl: `${this.baseUrl}/jar/${jar.shortCode}`,
    };
  }

  async addMember(jarId: string, creatorId: string, dto: AddJarMemberDto) {
    const jar = await this.prisma.tipJar.findUnique({ where: { id: jarId } });
    if (!jar || !jar.isActive) throw new NotFoundException('Tip jar not found');
    if (jar.createdById !== creatorId) throw new ForbiddenException('Only the jar creator can add members');

    const existing = await this.prisma.tipJarMember.findUnique({
      where: { tipJarId_providerId: { tipJarId: jarId, providerId: dto.providerId } },
    });

    if (existing?.isActive) throw new BadRequestException('Provider is already a member');

    if (existing && !existing.isActive) {
      return this.prisma.tipJarMember.update({
        where: { id: existing.id },
        data: {
          isActive: true,
          splitPercentage: dto.splitPercentage,
          roleLabel: dto.roleLabel ?? existing.roleLabel,
        },
        include: { provider: { select: { id: true, name: true, phone: true } } },
      });
    }

    return this.prisma.tipJarMember.create({
      data: {
        tipJarId: jarId,
        providerId: dto.providerId,
        splitPercentage: dto.splitPercentage,
        roleLabel: dto.roleLabel,
      },
      include: { provider: { select: { id: true, name: true, phone: true } } },
    });
  }

  async removeMember(jarId: string, memberId: string, creatorId: string) {
    const jar = await this.prisma.tipJar.findUnique({ where: { id: jarId } });
    if (!jar || !jar.isActive) throw new NotFoundException('Tip jar not found');
    if (jar.createdById !== creatorId) throw new ForbiddenException('Only the jar creator can remove members');

    const member = await this.prisma.tipJarMember.findFirst({ where: { id: memberId, tipJarId: jarId } });
    if (!member) throw new NotFoundException('Member not found');
    if (member.providerId === creatorId) throw new BadRequestException('Cannot remove the jar creator');

    await this.prisma.tipJarMember.update({ where: { id: memberId }, data: { isActive: false } });
    return { removed: true };
  }

  async updateSplits(
    jarId: string,
    creatorId: string,
    splits: Array<{ memberId: string; splitPercentage: number; roleLabel?: string }>,
  ) {
    const jar = await this.prisma.tipJar.findUnique({ where: { id: jarId } });
    if (!jar || !jar.isActive) throw new NotFoundException('Tip jar not found');
    if (jar.createdById !== creatorId) throw new ForbiddenException('Only the jar creator can update splits');

    const total = splits.reduce((sum, s) => sum + s.splitPercentage, 0);
    if (Math.abs(total - 100) > 0.01) {
      throw new BadRequestException('Split percentages must add up to 100');
    }

    await this.prisma.$transaction(
      splits.map((s) =>
        this.prisma.tipJarMember.update({
          where: { id: s.memberId },
          data: {
            splitPercentage: s.splitPercentage,
            ...(s.roleLabel !== undefined && { roleLabel: s.roleLabel }),
          },
        }),
      ),
    );

    return this.getJarById(jarId, creatorId);
  }

  async closeJar(jarId: string, creatorId: string) {
    const jar = await this.prisma.tipJar.findUnique({ where: { id: jarId } });
    if (!jar || !jar.isActive) throw new NotFoundException('Tip jar not found');
    if (jar.createdById !== creatorId) throw new ForbiddenException('Only the jar creator can close it');

    await this.prisma.tipJar.update({ where: { id: jarId }, data: { isActive: false } });
    return { closed: true };
  }

  // ─── Tipping via Jar ──────────────────────────────────────────────────────

  async createJarTip(shortCode: string, dto: TipJarTipDto, customerId?: string) {
    const jar = await this.prisma.tipJar.findUnique({
      where: { shortCode },
      include: { members: { where: { isActive: true } } },
    });

    if (!jar || !jar.isActive) throw new NotFoundException('Tip jar not found or inactive');
    if (jar.expiresAt && jar.expiresAt < new Date()) throw new BadRequestException('This tip jar has expired');
    if (jar.members.length === 0) throw new BadRequestException('Tip jar has no members');

    const amountPaise = dto.amountPaise;
    const commissionPaise = BigInt(
      calculateCommission(amountPaise, ZERO_COMMISSION_THRESHOLD_PAISE, DEFAULT_COMMISSION_RATE),
    );
    const gstOnCommissionPaise = BigInt(calculateGstOnCommission(Number(commissionPaise), GST_RATE_ON_COMMISSION));
    const netAmountPaise = BigInt(amountPaise) - commissionPaise - gstOnCommissionPaise;

    // Tip is attributed to the jar creator as the primary provider
    const tip = await this.prisma.tip.create({
      data: {
        customerId: customerId ?? null,
        providerId: jar.createdById,
        amountPaise: BigInt(amountPaise),
        commissionPaise,
        netAmountPaise,
        gstOnCommissionPaise,
        source: 'IN_APP',
        gateway: 'razorpay',
        message: dto.message,
        rating: dto.rating,
        tipJarId: jar.id,
        tipJarContribution: {
          create: {
            tipJarId: jar.id,
            customerId: customerId ?? null,
            amountPaise: BigInt(amountPaise),
            message: dto.message,
          },
        },
      },
    });

    // Create Razorpay order so the client can open checkout
    const order = await this.razorpay.createOrder({
      amount: amountPaise,
      currency: 'INR',
      receipt: tip.id,
      notes: { tipId: tip.id, jarId: jar.id },
    });

    // Store orderId on tip
    await this.prisma.tip.update({
      where: { id: tip.id },
      data: { gatewayOrderId: order.id },
    });

    return {
      tipId: tip.id,
      orderId: order.id,
      razorpayKeyId: this.config.get<string>('RAZORPAY_KEY_ID'),
      amount: amountPaise,
      currency: 'INR',
      jarId: jar.id,
      jarName: jar.name,
      netAmountPaise: Number(netAmountPaise),
      commissionPaise: Number(commissionPaise),
      memberCount: jar.members.length,
    };
  }

  // ─── Distribution (called after webhook payment.captured) ────────────────

  async distributeContribution(tipId: string) {
    const tip = await this.prisma.tip.findUnique({
      where: { id: tipId },
      include: {
        tipJar: {
          include: { members: { where: { isActive: true } } },
        },
      },
    });

    if (!tip?.tipJar) {
      this.logger.warn(`distributeContribution called for tip ${tipId} with no jar`);
      return;
    }

    const jar = tip.tipJar;
    const members = jar.members;

    if (members.length === 0) {
      this.logger.warn(`Tip jar ${jar.id} has no active members for distribution`);
      return;
    }

    const netAmount = Number(tip.netAmountPaise);
    const totalPct = members.reduce((sum, m) => sum + m.splitPercentage, 0);

    // Calculate each member's share; first member absorbs rounding remainder
    const shares = members.map((m, i) => {
      const normalizedPct = totalPct > 0 ? m.splitPercentage / totalPct : 1 / members.length;
      return {
        providerId: m.providerId,
        amountPaise: i < members.length - 1
          ? Math.floor(netAmount * normalizedPct)
          : 0, // last member gets remainder
      };
    });

    // Assign remainder to last member
    const distributed = shares.slice(0, -1).reduce((sum, s) => sum + s.amountPaise, 0);
    shares[shares.length - 1].amountPaise = netAmount - distributed;

    await this.prisma.$transaction(async (tx) => {
      for (const share of shares) {
        if (share.amountPaise <= 0) continue;

        const wallet = await this.walletsService.getOrCreateWallet(
          share.providerId,
          WalletType.PROVIDER_EARNINGS,
        );
        await this.walletsService.creditWallet(
          wallet.id,
          BigInt(share.amountPaise),
          tipId,
          `Tip jar split: ${jar.name}`,
          tx,
        );
      }

      // Update jar total collected
      await tx.tipJar.update({
        where: { id: jar.id },
        data: { totalCollected: { increment: tip.netAmountPaise } },
      });
    });

    this.logger.log(`Distributed tip ${tipId} to ${shares.length} jar members`);
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  async getJarStats(jarId: string, userId: string) {
    const jar = await this.prisma.tipJar.findUnique({
      where: { id: jarId },
      include: {
        members: {
          where: { isActive: true },
          include: { provider: { select: { id: true, name: true } } },
        },
        _count: { select: { contributions: true } },
      },
    });

    if (!jar || !jar.isActive) throw new NotFoundException('Tip jar not found');

    const isMember = jar.members.some((m) => m.providerId === userId);
    if (jar.createdById !== userId && !isMember) {
      throw new ForbiddenException('You are not part of this tip jar');
    }

    const netCollected = Number(jar.totalCollected);
    const totalPct = jar.members.reduce((sum, m) => sum + m.splitPercentage, 0);

    const memberBreakdown = jar.members.map((m) => {
      const normalizedPct = totalPct > 0 ? (m.splitPercentage / totalPct) * 100 : 100 / jar.members.length;
      return {
        memberId: m.id,
        providerId: m.providerId,
        providerName: m.provider.name,
        roleLabel: m.roleLabel,
        splitPercentage: parseFloat(normalizedPct.toFixed(2)),
        earnedPaise: Math.floor(netCollected * (normalizedPct / 100)),
      };
    });

    return {
      jarId: jar.id,
      jarName: jar.name,
      eventType: jar.eventType,
      totalCollectedPaise: netCollected,
      targetAmountPaise: jar.targetAmount ? Number(jar.targetAmount) : null,
      contributionCount: jar._count.contributions,
      memberBreakdown,
    };
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  private async generateUniqueShortCode(): Promise<string> {
    for (let attempt = 0; attempt < 5; attempt++) {
      const code = randomBytes(6).toString('base64url').replace(/[^a-zA-Z0-9]/g, '').substring(0, 8);
      const existing = await this.prisma.tipJar.findUnique({ where: { shortCode: code } });
      if (!existing) return code;
    }
    throw new BadRequestException('Failed to generate unique short code');
  }
}
