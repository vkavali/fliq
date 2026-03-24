import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '@fliq/database';
import { SplitMethod, WalletType } from '@fliq/shared';
import { CreateTipPoolDto } from './dto/create-tip-pool.dto';
import { UpdateTipPoolDto } from './dto/update-tip-pool.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { WalletsService } from '../wallets/wallets.service';

/** Default role-based split percentages when no custom splits are set */
const DEFAULT_ROLE_SPLITS: Record<string, number> = {
  waiter: 40,
  chef: 30,
  host: 15,
  busser: 15,
};

@Injectable()
export class TipPoolsService {
  private readonly logger = new Logger(TipPoolsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly walletsService: WalletsService,
  ) {}

  async createPool(ownerId: string, dto: CreateTipPoolDto) {
    // Create pool and auto-add owner as a member
    const pool = await this.prisma.tipPool.create({
      data: {
        name: dto.name,
        description: dto.description,
        splitMethod: dto.splitMethod,
        ownerId,
        members: {
          create: {
            userId: ownerId,
            role: 'owner',
          },
        },
      },
      include: {
        members: {
          include: { user: { select: { id: true, name: true, phone: true } } },
        },
      },
    });

    return pool;
  }

  async getMyPools(userId: string) {
    // Pools I own
    const owned = await this.prisma.tipPool.findMany({
      where: { ownerId: userId, isActive: true },
      include: {
        members: {
          where: { isActive: true },
          include: { user: { select: { id: true, name: true, phone: true } } },
        },
        _count: { select: { tips: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    // Pools I'm a member of (but don't own)
    const memberships = await this.prisma.tipPoolMember.findMany({
      where: { userId, isActive: true, pool: { isActive: true, ownerId: { not: userId } } },
      include: {
        pool: {
          include: {
            members: {
              where: { isActive: true },
              include: { user: { select: { id: true, name: true, phone: true } } },
            },
            owner: { select: { id: true, name: true } },
            _count: { select: { tips: true } },
          },
        },
      },
    });

    const memberOf = memberships.map((m) => m.pool);

    return { owned, memberOf };
  }

  async getPoolById(poolId: string, userId: string) {
    const pool = await this.prisma.tipPool.findUnique({
      where: { id: poolId },
      include: {
        owner: { select: { id: true, name: true, phone: true } },
        members: {
          where: { isActive: true },
          include: { user: { select: { id: true, name: true, phone: true } } },
        },
        _count: { select: { tips: true } },
      },
    });

    if (!pool || !pool.isActive) {
      throw new NotFoundException('Tip pool not found');
    }

    // Verify user is owner or member
    const isMember = pool.members.some((m) => m.userId === userId);
    if (pool.ownerId !== userId && !isMember) {
      throw new ForbiddenException('You are not a member of this pool');
    }

    return pool;
  }

  async addMember(poolId: string, ownerId: string, dto: AddMemberDto) {
    const pool = await this.prisma.tipPool.findUnique({ where: { id: poolId } });
    if (!pool || !pool.isActive) throw new NotFoundException('Tip pool not found');
    if (pool.ownerId !== ownerId) throw new ForbiddenException('Only the pool owner can add members');

    // Find user by phone
    const user = await this.prisma.user.findUnique({ where: { phone: dto.phone } });
    if (!user) {
      throw new BadRequestException('No user found with this phone number. They need to sign up first.');
    }

    // Check if already a member
    const existing = await this.prisma.tipPoolMember.findUnique({
      where: { poolId_userId: { poolId, userId: user.id } },
    });
    if (existing && existing.isActive) {
      throw new BadRequestException('User is already a member of this pool');
    }

    // Reactivate if previously removed, otherwise create
    if (existing && !existing.isActive) {
      const member = await this.prisma.tipPoolMember.update({
        where: { id: existing.id },
        data: {
          isActive: true,
          role: dto.role ?? existing.role,
          splitPercentage: dto.splitPercentage ?? existing.splitPercentage,
        },
        include: { user: { select: { id: true, name: true, phone: true } } },
      });
      return member;
    }

    const member = await this.prisma.tipPoolMember.create({
      data: {
        poolId,
        userId: user.id,
        role: dto.role,
        splitPercentage: dto.splitPercentage,
      },
      include: { user: { select: { id: true, name: true, phone: true } } },
    });

    return member;
  }

  async removeMember(poolId: string, memberId: string, ownerId: string) {
    const pool = await this.prisma.tipPool.findUnique({ where: { id: poolId } });
    if (!pool || !pool.isActive) throw new NotFoundException('Tip pool not found');
    if (pool.ownerId !== ownerId) throw new ForbiddenException('Only the pool owner can remove members');

    const member = await this.prisma.tipPoolMember.findFirst({
      where: { id: memberId, poolId },
    });
    if (!member) throw new NotFoundException('Member not found in this pool');

    // Can't remove the owner
    if (member.userId === ownerId) {
      throw new BadRequestException('Cannot remove the pool owner');
    }

    await this.prisma.tipPoolMember.update({
      where: { id: memberId },
      data: { isActive: false },
    });

    return { removed: true };
  }

  async updatePool(poolId: string, ownerId: string, dto: UpdateTipPoolDto) {
    const pool = await this.prisma.tipPool.findUnique({ where: { id: poolId } });
    if (!pool || !pool.isActive) throw new NotFoundException('Tip pool not found');
    if (pool.ownerId !== ownerId) throw new ForbiddenException('Only the pool owner can update the pool');

    const updated = await this.prisma.tipPool.update({
      where: { id: poolId },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.splitMethod !== undefined && { splitMethod: dto.splitMethod }),
      },
      include: {
        members: {
          where: { isActive: true },
          include: { user: { select: { id: true, name: true, phone: true } } },
        },
      },
    });

    return updated;
  }

  async deactivatePool(poolId: string, ownerId: string) {
    const pool = await this.prisma.tipPool.findUnique({ where: { id: poolId } });
    if (!pool || !pool.isActive) throw new NotFoundException('Tip pool not found');
    if (pool.ownerId !== ownerId) throw new ForbiddenException('Only the pool owner can deactivate the pool');

    await this.prisma.tipPool.update({
      where: { id: poolId },
      data: { isActive: false },
    });

    return { deactivated: true };
  }

  async getPoolEarnings(poolId: string, userId: string) {
    const pool = await this.prisma.tipPool.findUnique({
      where: { id: poolId },
      include: {
        members: {
          where: { isActive: true },
          include: { user: { select: { id: true, name: true, phone: true } } },
        },
      },
    });

    if (!pool || !pool.isActive) throw new NotFoundException('Tip pool not found');

    // Verify access
    const isMember = pool.members.some((m) => m.userId === userId);
    if (pool.ownerId !== userId && !isMember) {
      throw new ForbiddenException('You are not a member of this pool');
    }

    // Get total tips for this pool
    const tips = await this.prisma.tip.findMany({
      where: { tipPoolId: poolId, status: { in: ['PAID', 'SETTLED'] } },
    });

    const totalPaise = tips.reduce((sum, t) => sum + Number(t.netAmountPaise), 0);
    const tipCount = tips.length;

    // Calculate per-member breakdown
    const activeMembers = pool.members;
    const memberBreakdown = this.calculateSplits(
      totalPaise,
      activeMembers,
      pool.splitMethod as SplitMethod,
    );

    return {
      poolId,
      poolName: pool.name,
      splitMethod: pool.splitMethod,
      totalEarningsPaise: totalPaise,
      tipCount,
      members: memberBreakdown,
    };
  }

  /**
   * Distribute a settled tip's net amount to pool members' wallets.
   * Called by the webhook handler when a tip targeting a pool is settled.
   */
  async distributeTips(tipId: string) {
    const tip = await this.prisma.tip.findUnique({
      where: { id: tipId },
      include: {
        tipPool: {
          include: {
            members: { where: { isActive: true } },
          },
        },
      },
    });

    if (!tip || !tip.tipPool) {
      this.logger.warn(`distributeTips called for tip ${tipId} with no pool`);
      return;
    }

    const pool = tip.tipPool;
    const netAmount = Number(tip.netAmountPaise);
    const splits = this.calculateSplits(
      netAmount,
      pool.members,
      pool.splitMethod as SplitMethod,
    );

    // Credit each member's wallet in a transaction
    await this.prisma.$transaction(async (tx) => {
      for (const split of splits) {
        if (split.amountPaise <= 0) continue;

        const wallet = await this.walletsService.getOrCreateWallet(
          split.userId,
          WalletType.PROVIDER_EARNINGS,
        );

        await this.walletsService.creditWallet(
          wallet.id,
          BigInt(split.amountPaise),
          tipId, // use tip ID as transaction reference
          `Pool split: ${pool.name}`,
          tx,
        );
      }
    });

    this.logger.log(`Distributed tip ${tipId} to ${splits.length} pool members`);
  }

  private calculateSplits(
    totalPaise: number,
    members: Array<{ id: string; userId: string; role?: string | null; splitPercentage?: number | null; user?: any }>,
    splitMethod: SplitMethod,
  ) {
    if (members.length === 0) return [];

    switch (splitMethod) {
      case SplitMethod.EQUAL: {
        const perMember = Math.floor(totalPaise / members.length);
        const remainder = totalPaise - perMember * members.length;

        return members.map((m, i) => ({
          memberId: m.id,
          userId: m.userId,
          userName: m.user?.name ?? null,
          userPhone: m.user?.phone ?? null,
          role: m.role,
          splitPercentage: parseFloat((100 / members.length).toFixed(2)),
          amountPaise: perMember + (i === 0 ? remainder : 0), // first member gets remainder
        }));
      }

      case SplitMethod.PERCENTAGE: {
        return members.map((m) => {
          const pct = m.splitPercentage ?? 0;
          return {
            memberId: m.id,
            userId: m.userId,
            userName: m.user?.name ?? null,
            userPhone: m.user?.phone ?? null,
            role: m.role,
            splitPercentage: pct,
            amountPaise: Math.floor(totalPaise * (pct / 100)),
          };
        });
      }

      case SplitMethod.ROLE_BASED: {
        // Use predefined role splits; fall back to equal for unknown roles
        const membersWithRolePct = members.map((m) => {
          const roleLower = (m.role ?? '').toLowerCase();
          const pct = DEFAULT_ROLE_SPLITS[roleLower];
          return { ...m, rolePct: pct };
        });

        // If any member has an unknown role, fall back to equal split
        const allKnown = membersWithRolePct.every((m) => m.rolePct !== undefined);
        if (!allKnown) {
          // Fall back to equal
          return this.calculateSplits(totalPaise, members, SplitMethod.EQUAL);
        }

        const totalPct = membersWithRolePct.reduce((s, m) => s + (m.rolePct ?? 0), 0);

        return membersWithRolePct.map((m) => {
          const normalizedPct = totalPct > 0 ? ((m.rolePct ?? 0) / totalPct) * 100 : 0;
          return {
            memberId: m.id,
            userId: m.userId,
            userName: m.user?.name ?? null,
            userPhone: m.user?.phone ?? null,
            role: m.role,
            splitPercentage: parseFloat(normalizedPct.toFixed(2)),
            amountPaise: Math.floor(totalPaise * (normalizedPct / 100)),
          };
        });
      }

      default:
        return this.calculateSplits(totalPaise, members, SplitMethod.EQUAL);
    }
  }
}
