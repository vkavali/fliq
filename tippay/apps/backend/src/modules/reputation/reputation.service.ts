import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '@fliq/database';

/**
 * Reputation Engine — computes worker trust score from appreciation patterns.
 *
 * Formula (from V5 spec):
 *   score = (consistency × 0.4) + (frequency × 0.3) + (uniqueTippers × 0.3)
 *
 * Where:
 *   consistency = (days with tips / total days active), 0–1
 *   frequency   = min(tips per day / 10, 1), 0–1 (capped at 10/day)
 *   uniqueTippers = min(unique tippers / 50, 1), 0–1 (capped at 50)
 *
 * Final score = weighted sum × 100 → 0–100
 */
@Injectable()
export class ReputationService {
  private readonly logger = new Logger(ReputationService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Refresh the reputation score for a single worker.
   * Called after each tip settlement (non-blocking) and daily by scheduler.
   */
  async refreshReputation(workerId: string): Promise<void> {
    const provider = await this.prisma.provider.findUnique({
      where: { id: workerId },
    });
    if (!provider) return;

    // Gather all settled tips for this worker
    const tips = await this.prisma.tip.findMany({
      where: {
        providerId: workerId,
        status: { in: ['PAID', 'SETTLED'] },
      },
      select: {
        customerId: true,
        createdAt: true,
      },
    });

    if (tips.length === 0) {
      // No tips yet — set all zeros
      await this.upsertReputation(workerId, 0, 0, 0, 0);
      return;
    }

    // ── Consistency: ratio of days with tips / total days active ──
    const firstTipDate = tips.reduce(
      (min, t) => (t.createdAt < min ? t.createdAt : min),
      tips[0].createdAt,
    );
    const now = new Date();
    const totalDaysActive = Math.max(
      1,
      Math.ceil(
        (now.getTime() - firstTipDate.getTime()) / (1000 * 60 * 60 * 24),
      ),
    );

    const uniqueDaysWithTips = new Set(
      tips.map((t) => {
        const d = t.createdAt;
        return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
      }),
    ).size;

    const consistency = Math.min(uniqueDaysWithTips / totalDaysActive, 1);

    // ── Frequency: tips per day, capped at 10 ──
    const tipsPerDay = tips.length / totalDaysActive;
    const frequency = Math.min(tipsPerDay / 10, 1);

    // ── Unique tippers: capped at 50 ──
    const uniqueTipperIds = new Set(
      tips.filter((t) => t.customerId).map((t) => t.customerId),
    );
    const uniqueTipperCount = uniqueTipperIds.size;
    const uniqueTipperNormalized = Math.min(uniqueTipperCount / 50, 1);

    // ── Final score ──
    const score =
      (consistency * 0.4 + frequency * 0.3 + uniqueTipperNormalized * 0.3) *
      100;

    await this.upsertReputation(
      workerId,
      Math.round(score * 100) / 100, // 2 decimal places
      Math.round(consistency * 10000) / 10000, // 4 decimal places
      Math.round(frequency * 10000) / 10000,
      uniqueTipperCount,
    );

    this.logger.debug(
      `Reputation refreshed for worker ${workerId}: score=${score.toFixed(2)}`,
    );
  }

  /**
   * Get the reputation for a worker (public-facing).
   */
  async getReputation(workerId: string) {
    const rep = await this.prisma.reputation.findUnique({
      where: { workerId },
    });

    if (!rep) {
      return {
        score: 0,
        consistency: 0,
        frequency: 0,
        uniqueTippers: 0,
      };
    }

    return {
      score: Number(rep.score),
      consistency: Number(rep.consistency),
      frequency: Number(rep.frequency),
      uniqueTippers: rep.uniqueTippers,
    };
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  private async upsertReputation(
    workerId: string,
    score: number,
    consistency: number,
    frequency: number,
    uniqueTippers: number,
  ): Promise<void> {
    await this.prisma.reputation.upsert({
      where: { workerId },
      update: {
        score,
        consistency,
        frequency,
        uniqueTippers,
        lastComputed: new Date(),
      },
      create: {
        workerId,
        score,
        consistency,
        frequency,
        uniqueTippers,
        lastComputed: new Date(),
      },
    });
  }
}
