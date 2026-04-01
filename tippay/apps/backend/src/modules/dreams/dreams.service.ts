import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '@fliq/database';
import { CreateDreamDto } from './dto/create-dream.dto';
import { UpdateDreamDto } from './dto/update-dream.dto';

@Injectable()
export class DreamsService {
  private readonly logger = new Logger(DreamsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Create a new dream for a worker.
   * Business rule: only one active dream per worker at a time.
   */
  async createDream(workerId: string, dto: CreateDreamDto) {
    // Verify the user is a provider/worker
    const provider = await this.prisma.provider.findUnique({
      where: { id: workerId },
    });
    if (!provider) {
      throw new BadRequestException('Only providers (workers) can create dreams');
    }

    // Enforce one active dream at a time
    const existingActive = await this.prisma.dream.findFirst({
      where: { workerId, isActive: true },
    });
    if (existingActive) {
      throw new ConflictException(
        'You already have an active dream. Please complete or retire it before creating a new one.',
      );
    }

    const dream = await this.prisma.dream.create({
      data: {
        workerId,
        title: dto.title,
        description: dto.description,
        category: dto.category,
        goalAmount: BigInt(dto.goalAmount),
        mediaUrl: dto.mediaUrl,
      },
    });

    this.logger.log(`Dream created: ${dream.id} for worker ${workerId}`);

    return this.serializeDream(dream);
  }

  /**
   * Get the worker's active dream.
   */
  async getActiveDream(workerId: string) {
    const dream = await this.prisma.dream.findFirst({
      where: { workerId, isActive: true },
      include: {
        contributions: {
          orderBy: { createdAt: 'desc' },
          take: 5,
          select: {
            id: true,
            amountPaise: true,
            createdAt: true,
          },
        },
      },
    });

    if (!dream) return null;

    return {
      ...this.serializeDream(dream),
      recentContributions: dream.contributions.map((c) => ({
        id: c.id,
        amountPaise: Number(c.amountPaise),
        createdAt: c.createdAt,
      })),
    };
  }

  /**
   * Get the active dream for a worker (public-facing, shown to tippers).
   */
  async getPublicDream(workerId: string) {
    const dream = await this.prisma.dream.findFirst({
      where: { workerId, isActive: true },
    });

    if (!dream) return null;

    return this.serializeDream(dream);
  }

  /**
   * Update an existing dream.
   */
  async updateDream(workerId: string, dreamId: string, dto: UpdateDreamDto) {
    const dream = await this.prisma.dream.findUnique({
      where: { id: dreamId },
    });

    if (!dream) throw new NotFoundException('Dream not found');
    if (dream.workerId !== workerId) {
      throw new BadRequestException('You can only update your own dreams');
    }

    const updateData: Record<string, unknown> = {};

    if (dto.title !== undefined) updateData.title = dto.title;
    if (dto.description !== undefined) updateData.description = dto.description;
    if (dto.mediaUrl !== undefined) updateData.mediaUrl = dto.mediaUrl;
    if (dto.isActive !== undefined) updateData.isActive = dto.isActive;

    if (dto.goalAmount !== undefined) {
      if (BigInt(dto.goalAmount) < dream.currentAmount) {
        throw new BadRequestException(
          'Goal amount cannot be less than current progress',
        );
      }
      updateData.goalAmount = BigInt(dto.goalAmount);
    }

    const updated = await this.prisma.dream.update({
      where: { id: dreamId },
      data: updateData,
    });

    return this.serializeDream(updated);
  }

  /**
   * Deactivate / retire a dream.
   */
  async retireDream(workerId: string, dreamId: string) {
    const dream = await this.prisma.dream.findUnique({
      where: { id: dreamId },
    });

    if (!dream) throw new NotFoundException('Dream not found');
    if (dream.workerId !== workerId) {
      throw new BadRequestException('You can only retire your own dreams');
    }

    const updated = await this.prisma.dream.update({
      where: { id: dreamId },
      data: { isActive: false },
    });

    return this.serializeDream(updated);
  }

  /**
   * Called after tip settlement — updates dream progress.
   * Returns the before/after state for the impact screen.
   */
  async contributeFromTip(
    tipId: string,
    workerId: string,
    netAmountPaise: bigint,
  ): Promise<{
    dreamId: string;
    previousAmount: bigint;
    newAmount: bigint;
    goalAmount: bigint;
    title: string;
    completed: boolean;
  } | null> {
    // Find the worker's active dream
    const dream = await this.prisma.dream.findFirst({
      where: { workerId, isActive: true },
    });

    if (!dream) return null;

    const previousAmount = dream.currentAmount;
    const newAmount = previousAmount + netAmountPaise;
    const completed = newAmount >= dream.goalAmount;

    // Update dream progress and create contribution record atomically
    await this.prisma.$transaction([
      this.prisma.dream.update({
        where: { id: dream.id },
        data: {
          currentAmount: newAmount,
          ...(completed ? { completedAt: new Date() } : {}),
        },
      }),
      this.prisma.dreamContribution.create({
        data: {
          dreamId: dream.id,
          tipId,
          amountPaise: netAmountPaise,
        },
      }),
    ]);

    if (completed) {
      this.logger.log(
        `🎉 Dream "${dream.title}" completed for worker ${workerId}!`,
      );

      // Emit outbox event for dream completion
      await this.prisma.outboxEvent.create({
        data: {
          aggregateType: 'dream',
          aggregateId: dream.id,
          eventType: 'dream.completed',
          payload: {
            dreamId: dream.id,
            workerId,
            title: dream.title,
            goalAmount: Number(dream.goalAmount),
          },
        },
      });
    }

    return {
      dreamId: dream.id,
      previousAmount,
      newAmount,
      goalAmount: dream.goalAmount,
      title: dream.title,
      completed,
    };
  }

  /**
   * Get all dreams for a worker (active + retired).
   */
  async getWorkerDreams(workerId: string) {
    const dreams = await this.prisma.dream.findMany({
      where: { workerId },
      orderBy: { createdAt: 'desc' },
    });

    return dreams.map((d) => this.serializeDream(d));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  private serializeDream(dream: {
    id: string;
    workerId: string;
    title: string;
    description: string;
    category: string;
    goalAmount: bigint;
    currentAmount: bigint;
    mediaUrl: string | null;
    verified: boolean;
    isActive: boolean;
    completedAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
  }) {
    const goal = Number(dream.goalAmount);
    const current = Number(dream.currentAmount);
    const percentage = goal > 0 ? Math.min(Math.round((current / goal) * 100), 100) : 0;

    return {
      id: dream.id,
      workerId: dream.workerId,
      title: dream.title,
      description: dream.description,
      category: dream.category,
      goalAmount: goal,
      currentAmount: current,
      percentage,
      mediaUrl: dream.mediaUrl,
      verified: dream.verified,
      isActive: dream.isActive,
      completedAt: dream.completedAt,
      createdAt: dream.createdAt,
      updatedAt: dream.updatedAt,
    };
  }
}
