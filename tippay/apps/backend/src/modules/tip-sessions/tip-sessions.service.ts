import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSessionDto } from './dto/create-session.dto';
import { SettleTipDto, IntentEnum } from './dto/settle-tip.dto';
import { EventBusService } from '../event-bus/event-bus.service';

const PLATFORM_COMMISSION_RATE = 0.05; // 5%
const RULE_VERSION = 'v5.0';

@Injectable()
export class TipSessionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly eventBus: EventBusService,
  ) {}

  async createSession(dto: CreateSessionDto) {
    const worker = await this.prisma.v5Worker.findUnique({
      where: { workerId: dto.workerId },
    });
    if (!worker) throw new NotFoundException('Worker not found');

    const expiresAt = new Date(Date.now() + 30 * 60 * 1000); // 30 min

    const session = await this.prisma.v5TipSession.create({
      data: {
        workerId: dto.workerId,
        mode: (dto.mode ?? 'SOLO') as any,
        occasion: dto.occasion ?? null,
        presetSet: dto.presetSet ? JSON.parse(JSON.stringify(dto.presetSet)) : [],
        anonymityRequested: dto.anonymityRequested ?? false,
        expiresAt,
      },
      include: { worker: { select: { publicName: true, qrToken: true, meritVisibility: true } } },
    });

    this.eventBus.emit('tip_session.created', { sessionId: session.sessionId, workerId: dto.workerId });

    return session;
  }

  async getSession(sessionId: string) {
    const session = await this.prisma.v5TipSession.findUnique({
      where: { sessionId },
      include: {
        worker: {
          select: { publicName: true, meritVisibility: true, goals: { where: { status: 'ACTIVE', publicFlag: true } } },
          include: { meritSnapshots: { orderBy: { asOfDate: 'desc' }, take: 1 } },
        },
        tips: { orderBy: { createdAt: 'desc' }, take: 5 },
      },
    });
    if (!session) throw new NotFoundException('Session not found');

    if (session.expiresAt < new Date()) {
      throw new BadRequestException('Session has expired');
    }

    return session;
  }

  async settleWebhook(dto: SettleTipDto) {
    const session = await this.prisma.v5TipSession.findUnique({
      where: { sessionId: dto.sessionId },
      include: { worker: true },
    });
    if (!session) throw new NotFoundException('Session not found');

    const gross = BigInt(dto.grossAmountPaise);
    const commission = gross > 10000n ? BigInt(Math.floor(dto.grossAmountPaise * PLATFORM_COMMISSION_RATE)) : 0n;
    const net = gross - commission;

    const tip = await this.prisma.$transaction(async (tx) => {
      const newTip = await tx.v5Tip.create({
        data: {
          sessionId: dto.sessionId,
          routeType: 'SOLO',
          grossAmount: gross,
          netAmount: net,
          intent: (dto.intent ?? IntentEnum.GRATITUDE) as any,
          status: 'CAPTURED',
        },
      });

      // Worker route
      await tx.v5TipRoute.create({
        data: {
          tipId: newTip.tipId,
          recipientType: 'WORKER',
          recipientId: session.workerId,
          workerId: session.workerId,
          fixedAmount: net,
          ruleVersion: RULE_VERSION,
        },
      });

      // Platform route (if commission > 0)
      if (commission > 0n) {
        await tx.v5TipRoute.create({
          data: {
            tipId: newTip.tipId,
            recipientType: 'PLATFORM',
            recipientId: session.workerId,
            fixedAmount: commission,
            ruleVersion: RULE_VERSION,
          },
        });
      }

      // Mark as settled
      return tx.v5Tip.update({
        where: { tipId: newTip.tipId },
        data: { status: 'SETTLED', settledAt: new Date() },
      });
    });

    this.eventBus.emit('tip.settled', {
      tipId: tip.tipId,
      sessionId: dto.sessionId,
      workerId: session.workerId,
      grossAmountPaise: dto.grossAmountPaise,
      netAmountPaise: Number(net),
    });

    return tip;
  }
}
