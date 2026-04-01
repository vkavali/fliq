import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterWorkerDto } from './dto/register-worker.dto';
import { CreateGoalDto } from './dto/update-goal.dto';
import { EventBusService } from '../event-bus/event-bus.service';
import { randomBytes } from 'crypto';

@Injectable()
export class WorkersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly eventBus: EventBusService,
  ) {}

  async register(userId: string, dto: RegisterWorkerDto) {
    const existing = await this.prisma.v5Worker.findFirst({ where: { userId } });
    if (existing) throw new ConflictException('Worker profile already exists for this user');

    const qrToken = randomBytes(32).toString('hex');

    const worker = await this.prisma.v5Worker.create({
      data: {
        userId,
        businessId: dto.businessId ?? null,
        publicName: dto.publicName,
        qrToken,
        region: dto.region ?? null,
        soundPack: dto.soundPack ?? 'classic',
      },
    });

    this.eventBus.emit('worker.registered', { workerId: worker.workerId, userId });

    return worker;
  }

  async getProfile(workerId: string) {
    const worker = await this.prisma.v5Worker.findUnique({
      where: { workerId },
      include: {
        goals: { where: { status: 'ACTIVE' } },
        meritSnapshots: { orderBy: { asOfDate: 'desc' }, take: 1 },
      },
    });
    if (!worker) throw new NotFoundException('Worker not found');
    return worker;
  }

  async getProfileByToken(qrToken: string) {
    const worker = await this.prisma.v5Worker.findUnique({
      where: { qrToken },
      include: {
        goals: { where: { status: 'ACTIVE', publicFlag: true } },
        meritSnapshots: { orderBy: { asOfDate: 'desc' }, take: 1 },
      },
    });
    if (!worker) throw new NotFoundException('Worker not found');
    return worker;
  }

  async generateQr(workerId: string) {
    const worker = await this.prisma.v5Worker.findUnique({ where: { workerId } });
    if (!worker) throw new NotFoundException('Worker not found');

    // Rotate QR token
    const qrToken = randomBytes(32).toString('hex');
    const updated = await this.prisma.v5Worker.update({
      where: { workerId },
      data: { qrToken },
    });

    this.eventBus.emit('worker.qr_rotated', { workerId, qrToken });

    return {
      qrToken: updated.qrToken,
      qrUrl: `https://fliq.co.in/tip/${updated.qrToken}`,
    };
  }

  async getEarnings(workerId: string) {
    const worker = await this.prisma.v5Worker.findUnique({ where: { workerId } });
    if (!worker) throw new NotFoundException('Worker not found');

    const routes = await this.prisma.v5TipRoute.findMany({
      where: { workerId, recipientType: 'WORKER' },
      include: { tip: { select: { status: true, grossAmount: true, netAmount: true, createdAt: true } } },
    });

    const settled = routes.filter(r => r.tip.status === 'SETTLED');
    const totalEarned = settled.reduce((sum, r) => sum + Number(r.fixedAmount ?? 0), 0);

    return {
      workerId,
      totalEarned,
      settledCount: settled.length,
      pendingCount: routes.filter(r => r.tip.status === 'PENDING' || r.tip.status === 'CAPTURED').length,
      recent: settled.slice(-10).reverse(),
    };
  }

  async getGoals(workerId: string) {
    const worker = await this.prisma.v5Worker.findUnique({ where: { workerId } });
    if (!worker) throw new NotFoundException('Worker not found');

    return this.prisma.v5WorkerGoal.findMany({
      where: { workerId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createGoal(workerId: string, dto: CreateGoalDto) {
    const worker = await this.prisma.v5Worker.findUnique({ where: { workerId } });
    if (!worker) throw new NotFoundException('Worker not found');

    const goal = await this.prisma.v5WorkerGoal.create({
      data: {
        workerId,
        title: dto.title,
        targetAmount: BigInt(dto.targetAmountPaise),
        publicFlag: dto.publicFlag ?? true,
      },
    });

    this.eventBus.emit('worker.goal_created', { workerId, goalId: goal.goalId });

    return goal;
  }

  async getMerit(workerId: string) {
    const snapshot = await this.prisma.v5MeritSnapshot.findFirst({
      where: { workerId },
      orderBy: { asOfDate: 'desc' },
    });

    if (!snapshot) {
      return {
        workerId,
        score: 0,
        consistency: 0,
        repeatGiverRate: 0,
        dominantIntent: 'GRATITUDE',
        asOfDate: null,
      };
    }

    return snapshot;
  }
}
