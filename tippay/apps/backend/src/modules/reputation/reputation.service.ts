import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EventBusService } from '../event-bus/event-bus.service';
import { Cron, CronExpression } from '@nestjs/schedule';

interface MeritInput {
  tipCount: number;
  totalDays: number;
  activeDays: number;
  uniqueGivers: number;
  repeatGivers: number;
  intentCounts: Record<string, number>;
}

@Injectable()
export class ReputationService {
  private readonly logger = new Logger(ReputationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly eventBus: EventBusService,
  ) {
    this.eventBus.onEvent('tip.settled', async (payload) => {
      const workerId = payload['workerId'] as string;
      if (workerId) {
        await this.recalculateWorkerMerit(workerId).catch((err) =>
          this.logger.error(`Merit recalc failed for ${workerId}: ${err.message}`),
        );
      }
    });
  }

  private calculateScore(input: MeritInput): { score: number; consistency: number; repeatGiverRate: number } {
    const consistency = input.totalDays > 0 ? Math.min(input.activeDays / input.totalDays, 1) : 0;
    const repeatGiverRate = input.uniqueGivers > 0 ? input.repeatGivers / input.uniqueGivers : 0;

    // Weighted score: 50% volume, 30% consistency, 20% repeat givers
    const volumeScore = Math.min(input.tipCount / 100, 1);
    const score = volumeScore * 50 + consistency * 30 + repeatGiverRate * 20;

    return {
      score: Math.round(score * 100) / 100,
      consistency: Math.round(consistency * 100) / 100,
      repeatGiverRate: Math.round(repeatGiverRate * 100) / 100,
    };
  }

  private dominantIntent(intentCounts: Record<string, number>): string {
    let maxCount = 0;
    let dominant = 'GRATITUDE';
    for (const [intent, count] of Object.entries(intentCounts)) {
      if (count > maxCount) {
        maxCount = count;
        dominant = intent;
      }
    }
    return dominant;
  }

  async recalculateWorkerMerit(workerId: string): Promise<void> {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const tips = await this.prisma.v5Tip.findMany({
      where: {
        session: { workerId },
        status: 'SETTLED',
        createdAt: { gte: thirtyDaysAgo },
      },
      include: { session: { select: { anonymityRequested: true, createdAt: true } } },
    });

    const intentCounts: Record<string, number> = {};
    const activeDaySet = new Set<string>();
    let uniqueGivers = tips.length;
    let repeatGivers = 0;

    for (const tip of tips) {
      const dayKey = tip.createdAt.toISOString().slice(0, 10);
      activeDaySet.add(dayKey);
      intentCounts[tip.intent] = (intentCounts[tip.intent] ?? 0) + 1;
    }

    // Approximate repeat givers as sessions on same day (proxy)
    const dayTipCounts = new Map<string, number>();
    for (const tip of tips) {
      const dayKey = tip.createdAt.toISOString().slice(0, 10);
      dayTipCounts.set(dayKey, (dayTipCounts.get(dayKey) ?? 0) + 1);
    }
    for (const count of dayTipCounts.values()) {
      if (count > 1) repeatGivers += count - 1;
    }

    const input: MeritInput = {
      tipCount: tips.length,
      totalDays: 30,
      activeDays: activeDaySet.size,
      uniqueGivers,
      repeatGivers,
      intentCounts,
    };

    const { score, consistency, repeatGiverRate } = this.calculateScore(input);
    const dominant = this.dominantIntent(intentCounts);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    await this.prisma.v5MeritSnapshot.upsert({
      where: { workerId_asOfDate: { workerId, asOfDate: today } },
      create: {
        workerId,
        asOfDate: today,
        score,
        consistency,
        repeatGiverRate,
        dominantIntent: dominant as any,
      },
      update: {
        score,
        consistency,
        repeatGiverRate,
        dominantIntent: dominant as any,
      },
    });

    this.logger.log(`Merit snapshot saved for worker ${workerId}: score=${score}`);
    this.eventBus.emit('merit.snapshot_saved', { workerId, score });
  }

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async dailyMeritRefresh(): Promise<void> {
    this.logger.log('Running daily merit refresh for all workers...');

    const workers = await this.prisma.v5Worker.findMany({
      where: { onboardingStatus: 'ACTIVE' },
      select: { workerId: true },
    });

    for (const { workerId } of workers) {
      await this.recalculateWorkerMerit(workerId).catch((err) =>
        this.logger.error(`Daily merit refresh failed for ${workerId}: ${err.message}`),
      );
    }

    this.logger.log(`Daily merit refresh complete for ${workers.length} workers`);
  }
}
