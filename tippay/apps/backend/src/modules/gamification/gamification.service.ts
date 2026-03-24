import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '@fliq/database';

interface NewlyEarnedBadge {
  code: string;
  name: string;
  description: string;
  category: string;
  earnedAt: Date;
}

@Injectable()
export class GamificationService {
  private readonly logger = new Logger(GamificationService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Check all badge conditions for a user and award any new badges.
   * Called after every successful tip settlement.
   */
  async checkAndAwardBadges(
    userId: string,
    role: 'TIPPER' | 'PROVIDER',
    tipAmountPaise?: number,
  ): Promise<NewlyEarnedBadge[]> {
    const allBadges = await this.prisma.badge.findMany();
    const earnedBadgeIds = (
      await this.prisma.userBadge.findMany({
        where: { userId },
        select: { badgeId: true },
      })
    ).map((ub) => ub.badgeId);

    const unearnedBadges = allBadges.filter(
      (b) => !earnedBadgeIds.includes(b.id),
    );

    const newlyEarned: NewlyEarnedBadge[] = [];

    for (const badge of unearnedBadges) {
      const qualified = await this.checkBadgeCondition(
        userId,
        badge,
        role,
        tipAmountPaise,
      );
      if (qualified) {
        await this.prisma.userBadge.create({
          data: { userId, badgeId: badge.id },
        });
        newlyEarned.push({
          code: badge.code,
          name: badge.name,
          description: badge.description,
          category: badge.category,
          earnedAt: new Date(),
        });
        this.logger.log(`Badge "${badge.code}" awarded to user ${userId}`);
      }
    }

    return newlyEarned;
  }

  private async checkBadgeCondition(
    userId: string,
    badge: { code: string; category: string; threshold: number },
    role: 'TIPPER' | 'PROVIDER',
    tipAmountPaise?: number,
  ): Promise<boolean> {
    switch (badge.code) {
      // ── Tipper badges ──────────────────────────────────────────────
      case 'first_tip':
      case 'tip_10':
      case 'tip_50':
      case 'tip_100': {
        if (role !== 'TIPPER') return false;
        const count = await this.prisma.tip.count({
          where: {
            customerId: userId,
            status: { in: ['PAID', 'SETTLED'] },
          },
        });
        return count >= badge.threshold;
      }

      case 'big_tipper':
      case 'mega_tipper': {
        if (role !== 'TIPPER') return false;
        // Check if the current tip amount qualifies
        if (tipAmountPaise && tipAmountPaise >= badge.threshold) return true;
        // Also check historical tips
        const bigTip = await this.prisma.tip.findFirst({
          where: {
            customerId: userId,
            amountPaise: { gte: BigInt(badge.threshold) },
            status: { in: ['PAID', 'SETTLED'] },
          },
        });
        return !!bigTip;
      }

      // ── Streak badges ──────────────────────────────────────────────
      case 'streak_3':
      case 'streak_7':
      case 'streak_30': {
        if (role !== 'TIPPER') return false;
        const streak = await this.prisma.tipStreak.findUnique({
          where: { userId },
        });
        if (!streak) return false;
        return (
          streak.currentStreak >= badge.threshold ||
          streak.longestStreak >= badge.threshold
        );
      }

      // ── Provider badges ────────────────────────────────────────────
      case 'first_earned':
      case 'tips_50': {
        if (role !== 'PROVIDER') return false;
        const received = await this.prisma.tip.count({
          where: {
            providerId: userId,
            status: { in: ['PAID', 'SETTLED'] },
          },
        });
        return received >= badge.threshold;
      }

      case 'top_rated': {
        if (role !== 'PROVIDER') return false;
        const provider = await this.prisma.provider.findUnique({
          where: { id: userId },
        });
        if (!provider || !provider.ratingAverage) return false;
        // threshold is 45 meaning 4.5 * 10
        const minRating = badge.threshold / 10;
        return (
          Number(provider.ratingAverage) >= minRating &&
          provider.totalTipsReceived >= 20
        );
      }

      case 'earned_10k': {
        if (role !== 'PROVIDER') return false;
        const result = await this.prisma.tip.aggregate({
          where: {
            providerId: userId,
            status: { in: ['PAID', 'SETTLED'] },
          },
          _sum: { netAmountPaise: true },
        });
        const totalEarned = Number(result._sum.netAmountPaise || 0n);
        return totalEarned >= badge.threshold;
      }

      default:
        return false;
    }
  }

  /**
   * Update the user's tipping streak.
   * Called after each successful tip for the tipper (customer).
   */
  async updateStreak(userId: string): Promise<void> {
    const now = new Date();
    const todayStart = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
    );

    let streak = await this.prisma.tipStreak.findUnique({
      where: { userId },
    });

    if (!streak) {
      // First tip ever — create streak record
      await this.prisma.tipStreak.create({
        data: {
          userId,
          currentStreak: 1,
          longestStreak: 1,
          lastTipDate: todayStart,
        },
      });
      return;
    }

    // If already tipped today, no change
    if (streak.lastTipDate) {
      const lastDate = new Date(streak.lastTipDate);
      const lastDayStart = new Date(
        lastDate.getFullYear(),
        lastDate.getMonth(),
        lastDate.getDate(),
      );

      if (lastDayStart.getTime() === todayStart.getTime()) {
        return; // Already tipped today
      }

      const yesterdayStart = new Date(todayStart);
      yesterdayStart.setDate(yesterdayStart.getDate() - 1);

      if (lastDayStart.getTime() === yesterdayStart.getTime()) {
        // Tipped yesterday — extend streak
        const newCurrent = streak.currentStreak + 1;
        const newLongest = Math.max(newCurrent, streak.longestStreak);
        await this.prisma.tipStreak.update({
          where: { userId },
          data: {
            currentStreak: newCurrent,
            longestStreak: newLongest,
            lastTipDate: todayStart,
          },
        });
      } else {
        // Gap > 1 day — reset streak
        await this.prisma.tipStreak.update({
          where: { userId },
          data: {
            currentStreak: 1,
            longestStreak: Math.max(1, streak.longestStreak),
            lastTipDate: todayStart,
          },
        });
      }
    } else {
      // No last tip date, start fresh
      await this.prisma.tipStreak.update({
        where: { userId },
        data: {
          currentStreak: 1,
          longestStreak: Math.max(1, streak.longestStreak),
          lastTipDate: todayStart,
        },
      });
    }
  }

  /**
   * Get leaderboard: top tippers or providers for a given period.
   */
  async getLeaderboard(
    period: 'week' | 'month',
    type: 'tippers' | 'providers',
    limit: number = 20,
  ) {
    const now = new Date();
    let startDate: Date;

    if (period === 'week') {
      startDate = new Date(now);
      startDate.setDate(startDate.getDate() - 7);
    } else {
      startDate = new Date(now.getFullYear(), now.getMonth(), 1);
    }

    if (type === 'tippers') {
      const results = await this.prisma.tip.groupBy({
        by: ['customerId'],
        where: {
          status: { in: ['PAID', 'SETTLED'] },
          createdAt: { gte: startDate },
          customerId: { not: null },
        },
        _count: { id: true },
        _sum: { amountPaise: true },
        orderBy: { _count: { id: 'desc' } },
        take: limit,
      });

      const userIds = results
        .map((r) => r.customerId)
        .filter(Boolean) as string[];
      const users = await this.prisma.user.findMany({
        where: { id: { in: userIds } },
        select: { id: true, name: true },
      });
      const userMap = new Map(users.map((u) => [u.id, u.name]));

      return results.map((r, index) => ({
        rank: index + 1,
        userId: r.customerId,
        name: userMap.get(r.customerId!) || 'Anonymous',
        tipCount: r._count.id,
        totalAmountPaise: Number(r._sum.amountPaise || 0n),
      }));
    } else {
      const results = await this.prisma.tip.groupBy({
        by: ['providerId'],
        where: {
          status: { in: ['PAID', 'SETTLED'] },
          createdAt: { gte: startDate },
        },
        _count: { id: true },
        _sum: { netAmountPaise: true },
        orderBy: { _count: { id: 'desc' } },
        take: limit,
      });

      const userIds = results.map((r) => r.providerId);
      const users = await this.prisma.user.findMany({
        where: { id: { in: userIds } },
        select: { id: true, name: true },
      });
      const userMap = new Map(users.map((u) => [u.id, u.name]));

      return results.map((r, index) => ({
        rank: index + 1,
        userId: r.providerId,
        name: userMap.get(r.providerId) || 'Provider',
        tipCount: r._count.id,
        totalEarnedPaise: Number(r._sum.netAmountPaise || 0n),
      }));
    }
  }

  /**
   * Get all badges with earned/unearned status for a user.
   */
  async getUserBadges(userId: string) {
    const [allBadges, userBadges] = await Promise.all([
      this.prisma.badge.findMany({ orderBy: { category: 'asc' } }),
      this.prisma.userBadge.findMany({
        where: { userId },
        select: { badgeId: true, earnedAt: true },
      }),
    ]);

    const earnedMap = new Map(
      userBadges.map((ub) => [ub.badgeId, ub.earnedAt]),
    );

    return allBadges.map((badge) => ({
      id: badge.id,
      code: badge.code,
      name: badge.name,
      description: badge.description,
      iconUrl: badge.iconUrl,
      category: badge.category,
      threshold: badge.threshold,
      earned: earnedMap.has(badge.id),
      earnedAt: earnedMap.get(badge.id) || null,
    }));
  }

  /**
   * Get user's streak info.
   */
  async getUserStreak(userId: string) {
    const streak = await this.prisma.tipStreak.findUnique({
      where: { userId },
    });

    if (!streak) {
      return {
        currentStreak: 0,
        longestStreak: 0,
        lastTipDate: null,
      };
    }

    return {
      currentStreak: streak.currentStreak,
      longestStreak: streak.longestStreak,
      lastTipDate: streak.lastTipDate,
    };
  }

  /**
   * Seed the default badges. Idempotent — skips existing ones.
   */
  async seedBadges(): Promise<void> {
    const badges = [
      // Tipper badges
      { code: 'first_tip', name: 'First Tip', description: 'Give your first tip', category: 'TIPPER', threshold: 1 },
      { code: 'tip_10', name: 'Generous Soul', description: 'Give 10 tips', category: 'TIPPER', threshold: 10 },
      { code: 'tip_50', name: 'Tip Master', description: 'Give 50 tips', category: 'TIPPER', threshold: 50 },
      { code: 'tip_100', name: 'Tip Legend', description: 'Give 100 tips', category: 'TIPPER', threshold: 100 },
      { code: 'big_tipper', name: 'Big Tipper', description: 'Give a tip of Rs 500+', category: 'TIPPER', threshold: 50000 },
      { code: 'mega_tipper', name: 'Mega Tipper', description: 'Give a tip of Rs 1000+', category: 'TIPPER', threshold: 100000 },
      // Streak badges
      { code: 'streak_3', name: 'On Fire', description: '3-day tipping streak', category: 'STREAK', threshold: 3 },
      { code: 'streak_7', name: 'Week Warrior', description: '7-day tipping streak', category: 'STREAK', threshold: 7 },
      { code: 'streak_30', name: 'Monthly Champion', description: '30-day tipping streak', category: 'STREAK', threshold: 30 },
      // Provider badges
      { code: 'first_earned', name: 'First Earnings', description: 'Receive your first tip', category: 'PROVIDER', threshold: 1 },
      { code: 'tips_50', name: 'Popular', description: 'Receive 50 tips', category: 'PROVIDER', threshold: 50 },
      { code: 'top_rated', name: 'Top Rated', description: 'Maintain 4.5+ rating with 20+ tips', category: 'PROVIDER', threshold: 45 },
      { code: 'earned_10k', name: '10K Earner', description: 'Earn Rs 10,000 total', category: 'PROVIDER', threshold: 1000000 },
    ];

    for (const badge of badges) {
      await this.prisma.badge.upsert({
        where: { code: badge.code },
        update: {},
        create: badge,
      });
    }

    this.logger.log(`Seeded ${badges.length} badges`);
  }
}
