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

    // ── Platform system user (commission + tax wallets) ─────────────────
    const platformUser = await this.prisma.user.upsert({
      where: { phone: '+910000000000' },
      update: {},
      create: {
        phone: '+910000000000',
        name: 'Fliq Platform',
        type: 'ADMIN' as any,
        status: 'ACTIVE' as any,
        kycStatus: 'FULL' as any,
      },
    });

    await this.prisma.wallet.upsert({
      where: { userId_type: { userId: platformUser.id, type: WalletType.PLATFORM_COMMISSION } },
      update: {},
      create: { userId: platformUser.id, type: WalletType.PLATFORM_COMMISSION, balancePaise: 0 },
    });
    await this.prisma.wallet.upsert({
      where: { userId_type: { userId: platformUser.id, type: WalletType.TAX_RESERVE } },
      update: {},
      create: { userId: platformUser.id, type: WalletType.TAX_RESERVE, balancePaise: 0 },
    });

    // ── Test Tipper (+919999999999) — ADMIN so he can also hit /admin/* ──
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
      update: {
        upiVpa: 'testworker@okicici',
        displayName: 'Test Worker',
        bio: 'Fliq test service worker account',
        category: 'RESTAURANT' as any,
        payoutPreference: 'DAILY_BATCH' as any,
      },
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

    const workerWallet = await this.prisma.wallet.upsert({
      where: { userId_type: { userId: workerUser.id, type: WalletType.PROVIDER_EARNINGS } },
      update: { balancePaise: TEST_BALANCE_PAISE },
      create: { userId: workerUser.id, type: WalletType.PROVIDER_EARNINGS, balancePaise: TEST_BALANCE_PAISE },
    });
    void workerWallet;

    // ── Payment link for Test Worker (shortCode max 8 chars) ──────────
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

    // ── QR code for Test Worker (find-or-create) ──────────────────────
    const existingQr = await this.prisma.qrCode.findFirst({
      where: { providerId: workerUser.id },
    });
    if (!existingQr) {
      await this.prisma.qrCode.create({
        data: {
          providerId: workerUser.id,
          type: 'STATIC' as any,
          locationLabel: 'Table 1 — Test Cafe',
          isActive: true,
        },
      });
    }

    // ── Test Business: Test Cafe (find-or-create by owner) ────────────
    let business = await this.prisma.business.findFirst({
      where: { ownerId: tipper.id, name: 'Test Cafe' },
    });
    if (!business) {
      business = await this.prisma.business.create({
        data: {
          name: 'Test Cafe',
          type: 'CAFE' as any,
          isActive: true,
          ownerId: tipper.id,
        },
      });
    }

    // Assign Test Worker as member of Test Cafe
    const existingMember = await this.prisma.businessMember.findUnique({
      where: { businessId_providerId: { businessId: business.id, providerId: workerUser.id } },
    });
    if (!existingMember) {
      await this.prisma.businessMember.create({
        data: {
          businessId: business.id,
          providerId: workerUser.id,
          role: 'STAFF' as any,
          isActive: true,
        },
      });
    }

    // ── Sample tips (past history) ────────────────────────────────────
    const existingTipCount = await this.prisma.tip.count({
      where: { providerId: workerUser.id, gateway: 'mock' },
    });
    if (existingTipCount === 0) {
      const sampleTips = [
        { amountPaise: BigInt(5000), message: 'Great service!', rating: 5 },
        { amountPaise: BigInt(10000), message: 'Keep it up', rating: 4 },
        { amountPaise: BigInt(2000), message: null, rating: null },
      ];
      for (const t of sampleTips) {
        const commission =
          t.amountPaise > BigInt(10000)
            ? (t.amountPaise * BigInt(5)) / BigInt(100)
            : BigInt(0);
        const gst = commission > 0n ? (commission * BigInt(18)) / BigInt(100) : BigInt(0);
        await this.prisma.tip.create({
          data: {
            customerId: tipper.id,
            providerId: workerUser.id,
            amountPaise: t.amountPaise,
            commissionPaise: commission,
            commissionRate: t.amountPaise > BigInt(10000) ? 5 : 0,
            netAmountPaise: t.amountPaise - commission - gst,
            gstOnCommissionPaise: gst,
            source: 'PAYMENT_LINK' as any,
            message: t.message,
            rating: t.rating,
            status: 'PAID' as any,
            gateway: 'mock',
            gatewayOrderId: `mock_seed_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`,
            gatewayPaymentId: `mock_pay_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`,
          },
        });
      }
    }

    // ── Tip Jar: Test Wedding Fund (shortCode max 8 chars) ────────────
    await this.prisma.tipJar.upsert({
      where: { shortCode: 'test-jar' },
      update: {},
      create: {
        shortCode: 'test-jar',
        name: 'Test Wedding Fund',
        eventType: 'WEDDING' as any,
        targetAmount: BigInt(500000),
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        createdById: tipper.id,
        isActive: true,
        members: {
          create: [
            { providerId: workerUser.id, splitPercentage: 50 },
            { providerId: tipper.id, splitPercentage: 50 },
          ],
        },
      },
    });

    // ── Tip Pool: Test Cafe Pool (find-or-create) ─────────────────────
    const existingPool = await this.prisma.tipPool.findFirst({
      where: { ownerId: tipper.id, name: 'Test Cafe Tip Pool' },
    });
    if (!existingPool) {
      await this.prisma.tipPool.create({
        data: {
          name: 'Test Cafe Tip Pool',
          ownerId: tipper.id,
          splitMethod: 'EQUAL',
          isActive: true,
          members: {
            create: [{ userId: workerUser.id, isActive: true }],
          },
        },
      });
    }

    const baseUrl = this.config.get('APP_BASE_URL', 'https://fliq.co.in');

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
      business: { id: business.id, name: business.name },
      walletBalance: '₹10,000 each account',
      note: 'Both phones accept OTP 123456. Payments are mocked — full wallet lifecycle completes without Razorpay.',
    };
  }
}
