import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '@tippay/database';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(private readonly prisma: PrismaService) {}

  async getPlatformStats() {
    const [
      totalUsers,
      totalProviders,
      totalTips,
      totalPayouts,
      tipStats,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.provider.count(),
      this.prisma.tip.count(),
      this.prisma.payout.count(),
      this.prisma.tip.aggregate({
        _sum: { amountPaise: true, commissionPaise: true, netAmountPaise: true },
        where: { status: { in: ['PAID', 'SETTLED'] } },
      }),
    ]);

    return {
      totalUsers,
      totalProviders,
      totalTips,
      totalPayouts,
      totalTipAmountPaise: tipStats._sum.amountPaise ?? 0,
      totalCommissionPaise: tipStats._sum.commissionPaise ?? 0,
      totalNetAmountPaise: tipStats._sum.netAmountPaise ?? 0,
    };
  }

  async listTips(page: number = 1, limit: number = 50, status?: string) {
    const skip = (page - 1) * limit;
    const where = status ? { status: status as any } : {};
    const [tips, total] = await Promise.all([
      this.prisma.tip.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          customer: { select: { name: true, phone: true } },
          provider: { select: { name: true, phone: true } },
        },
      }),
      this.prisma.tip.count({ where }),
    ]);
    return { tips, total, page, limit };
  }

  async listProviders(page: number = 1, limit: number = 50) {
    const skip = (page - 1) * limit;
    const [providers, total] = await Promise.all([
      this.prisma.provider.findMany({
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          user: { select: { name: true, phone: true, status: true, kycStatus: true } },
        },
      }),
      this.prisma.provider.count(),
    ]);
    return { providers, total, page, limit };
  }

  async listPayouts(page: number = 1, limit: number = 50, status?: string) {
    const skip = (page - 1) * limit;
    const where = status ? { status: status as any } : {};
    const [payouts, total] = await Promise.all([
      this.prisma.payout.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          provider: { select: { name: true, phone: true } },
        },
      }),
      this.prisma.payout.count({ where }),
    ]);
    return { payouts, total, page, limit };
  }

  async getPlatformWallets() {
    const wallets = await this.prisma.wallet.findMany({
      where: { type: { in: ['PLATFORM_COMMISSION', 'TAX_RESERVE'] } },
      include: { user: { select: { name: true } } },
    });
    return wallets;
  }

  async triggerBatchPayouts() {
    const pendingPayouts = await this.prisma.payout.findMany({
      where: { status: 'PENDING_BATCH' },
      take: 100,
    });

    this.logger.log(`Batch payout: ${pendingPayouts.length} pending payouts found`);

    // Mark them as INITIATED (actual RazorpayX calls would happen here)
    const updated = await this.prisma.payout.updateMany({
      where: {
        id: { in: pendingPayouts.map((p) => p.id) },
        status: 'PENDING_BATCH',
      },
      data: { status: 'INITIATED' },
    });

    return {
      processed: updated.count,
      message: `${updated.count} payouts moved to INITIATED`,
    };
  }
}
