import { Injectable, Logger, ForbiddenException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '@fliq/database';
import { WalletType } from '@fliq/shared';

const TEST_TIPPER_PHONE = '+919999999999';
const TEST_WORKER_PHONE = '+919999999998';
const TEST_BALANCE_PAISE = BigInt(1_000_000); // ₹10,000

@Injectable()
export class DevService {
  private readonly logger = new Logger(DevService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  private guardBypass(): void {
    if (this.config.get<string>('DEV_BYPASS_ENABLED', 'false') !== 'true') {
      throw new ForbiddenException('DEV_BYPASS_ENABLED is not enabled');
    }
  }

  async getStatus() {
    this.guardBypass();

    const tipper = await this.prisma.user.findUnique({
      where: { phone: TEST_TIPPER_PHONE },
      include: { wallets: true },
    });
    const worker = await this.prisma.user.findUnique({
      where: { phone: TEST_WORKER_PHONE },
      include: {
        wallets: true,
        providerProfile: { include: { paymentLinks: true, qrCodes: true } },
      },
    });
    const tipCount = worker
      ? await this.prisma.tip.count({ where: { providerId: worker.id } })
      : 0;

    return {
      bypass: true,
      testTipper: tipper
        ? {
            id: tipper.id,
            phone: tipper.phone,
            name: tipper.name,
            type: tipper.type,
            wallets: tipper.wallets.map((w) => ({
              type: w.type,
              balanceRupees: Number(w.balancePaise) / 100,
            })),
          }
        : null,
      testWorker: worker
        ? {
            id: worker.id,
            phone: worker.phone,
            name: worker.name,
            type: worker.type,
            paymentLinks: worker.providerProfile?.paymentLinks?.map((l) => l.shortCode) ?? [],
            qrCodes: worker.providerProfile?.qrCodes?.length ?? 0,
            tipsReceived: tipCount,
            wallets: worker.wallets.map((w) => ({
              type: w.type,
              balanceRupees: Number(w.balancePaise) / 100,
            })),
          }
        : null,
      hint: 'POST /dev/seed to create or refresh test data',
    };
  }

  async seedTestData() {
    this.guardBypass();
    this.logger.warn('[DEV] Seeding test accounts...');

    // ── Test Tipper (+919999999999) — ADMIN ───────────────────────────
    const tipper = await this.prisma.user.upsert({
      where: { phone: TEST_TIPPER_PHONE },
      update: { name: 'Test Tipper', type: 'ADMIN' as any, status: 'ACTIVE' as any, kycStatus: 'FULL' as any },
      create: {
        phone: TEST_TIPPER_PHONE,
        name: 'Test Tipper',
        type: 'ADMIN' as any,
        status: 'ACTIVE' as any,
        kycStatus: 'FULL' as any,
      },
    });

    // ── Test Worker (+919999999998) — PROVIDER ────────────────────────
    const workerUser = await this.prisma.user.upsert({
      where: { phone: TEST_WORKER_PHONE },
      update: { name: 'Test Worker', type: 'PROVIDER' as any, status: 'ACTIVE' as any, kycStatus: 'BASIC' as any },
      create: {
        phone: TEST_WORKER_PHONE,
        name: 'Test Worker',
        type: 'PROVIDER' as any,
        status: 'ACTIVE' as any,
        kycStatus: 'BASIC' as any,
      },
    });

    await this.prisma.provider.upsert({
      where: { id: workerUser.id },
      update: { upiVpa: 'testworker@okicici', displayName: 'Test Worker' },
      create: {
        id: workerUser.id,
        upiVpa: 'testworker@okicici',
        displayName: 'Test Worker',
        bio: 'Fliq test service worker account',
        category: 'RESTAURANT' as any,
        payoutPreference: 'DAILY_BATCH' as any,
        totalTipsReceived: 0,
      },
    });

    // ── Pre-funded wallets ────────────────────────────────────────────
    await this.prisma.wallet.upsert({
      where: { userId_type: { userId: tipper.id, type: WalletType.PROVIDER_EARNINGS } },
      update: { balancePaise: TEST_BALANCE_PAISE },
      create: { userId: tipper.id, type: WalletType.PROVIDER_EARNINGS, balancePaise: TEST_BALANCE_PAISE },
    });
    await this.prisma.wallet.upsert({
      where: { userId_type: { userId: workerUser.id, type: WalletType.PROVIDER_EARNINGS } },
      update: { balancePaise: TEST_BALANCE_PAISE },
      create: { userId: workerUser.id, type: WalletType.PROVIDER_EARNINGS, balancePaise: TEST_BALANCE_PAISE },
    });

    // ── Payment link for Test Worker ──────────────────────────────────
    const paymentLink = await this.prisma.paymentLink.upsert({
      where: { shortCode: 'testwrkr' },
      update: {},
      create: {
        providerId: workerUser.id,
        shortCode: 'testwrkr',
        role: 'Waiter',
        workplace: 'Test Cafe',
        description: 'Test Worker at Test Cafe — tip via Fliq',
        suggestedAmountPaise: 5000,
        allowCustomAmount: true,
      },
    });

    const baseUrl = this.config.get('APP_URL', 'https://fliq.co.in');
    this.logger.warn('[DEV] Test data seeded successfully');

    return {
      seeded: true,
      testTipper: {
        phone: TEST_TIPPER_PHONE,
        otp: '123456',
        name: tipper.name,
        type: tipper.type,
        id: tipper.id,
        note: 'ADMIN type — can access /admin/* endpoints',
      },
      testWorker: {
        phone: TEST_WORKER_PHONE,
        otp: '123456',
        name: workerUser.name,
        type: workerUser.type,
        id: workerUser.id,
        paymentLinkShortCode: paymentLink.shortCode,
        tipUrl: `${baseUrl}/app/tip.html?code=${paymentLink.shortCode}`,
      },
      walletBalance: '₹10,000 each account',
      note: 'Both phones accept OTP 123456.',
    };
  }
}
