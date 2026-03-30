import { PrismaClient, UserType, UserStatus, KycStatus, ProviderCategory, PayoutPreference, WalletType, QrCodeType } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // ── Platform system user (commission + tax wallets) ───────────────────────
  const platformUser = await prisma.user.upsert({
    where: { phone: '+910000000000' },
    update: {},
    create: {
      phone: '+910000000000',
      name: 'Fliq Platform',
      type: UserType.ADMIN,
      status: UserStatus.ACTIVE,
      kycStatus: KycStatus.FULL,
    },
  });

  await prisma.wallet.upsert({
    where: { userId_type: { userId: platformUser.id, type: WalletType.PLATFORM_COMMISSION } },
    update: {},
    create: { userId: platformUser.id, type: WalletType.PLATFORM_COMMISSION, balancePaise: 0 },
  });
  await prisma.wallet.upsert({
    where: { userId_type: { userId: platformUser.id, type: WalletType.TAX_RESERVE } },
    update: {},
    create: { userId: platformUser.id, type: WalletType.TAX_RESERVE, balancePaise: 0 },
  });
  console.log(`Platform wallets created for: ${platformUser.id}`);

  // ── Test Tipper (+919999999999) — ADMIN for full UI access ───────────────
  // OTP bypass: accepts magic OTP "123456" when DEV_BYPASS_ENABLED=true
  const tipper = await prisma.user.upsert({
    where: { phone: '+919999999999' },
    update: { name: 'Test Tipper', type: UserType.ADMIN, kycStatus: KycStatus.FULL },
    create: {
      phone: '+919999999999',
      name: 'Test Tipper',
      type: UserType.ADMIN,
      status: UserStatus.ACTIVE,
      kycStatus: KycStatus.FULL,
    },
  });
  console.log(`Test Tipper (admin): ${tipper.id}`);

  // ── Test Worker (+919999999998) — PROVIDER ───────────────────────────────
  // OTP bypass: accepts magic OTP "123456" when DEV_BYPASS_ENABLED=true
  const workerUser = await prisma.user.upsert({
    where: { phone: '+919999999998' },
    update: { name: 'Test Worker', type: UserType.PROVIDER, kycStatus: KycStatus.BASIC },
    create: {
      phone: '+919999999998',
      name: 'Test Worker',
      type: UserType.PROVIDER,
      status: UserStatus.ACTIVE,
      kycStatus: KycStatus.BASIC,
    },
  });

  await prisma.provider.upsert({
    where: { id: workerUser.id },
    update: {
      upiVpa: 'testworker@okicici',
      displayName: 'Test Worker',
      bio: 'Fliq test service worker account',
      category: ProviderCategory.RESTAURANT,
      payoutPreference: PayoutPreference.DAILY_BATCH,
    },
    create: {
      id: workerUser.id,
      upiVpa: 'testworker@okicici',
      displayName: 'Test Worker',
      bio: 'Fliq test service worker account',
      category: ProviderCategory.RESTAURANT,
      payoutPreference: PayoutPreference.DAILY_BATCH,
      totalTipsReceived: 0,
    },
  });

  // Pre-funded wallets (₹10,000 each)
  await prisma.wallet.upsert({
    where: { userId_type: { userId: tipper.id, type: WalletType.PROVIDER_EARNINGS } },
    update: {},
    create: { userId: tipper.id, type: WalletType.PROVIDER_EARNINGS, balancePaise: 1_000_000 },
  });
  await prisma.wallet.upsert({
    where: { userId_type: { userId: workerUser.id, type: WalletType.PROVIDER_EARNINGS } },
    update: {},
    create: { userId: workerUser.id, type: WalletType.PROVIDER_EARNINGS, balancePaise: 1_000_000 },
  });
  console.log(`Test Worker (provider): ${workerUser.id}`);

  // ── Payment link for Test Worker ─────────────────────────────────────────
  await prisma.paymentLink.upsert({
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

  // ── QR code for Test Worker ──────────────────────────────────────────────
  const existingQr = await prisma.qrCode.findFirst({ where: { providerId: workerUser.id } });
  if (!existingQr) {
    await prisma.qrCode.create({
      data: {
        providerId: workerUser.id,
        type: QrCodeType.STATIC,
        locationLabel: 'Table 1 — Test Cafe',
        isActive: true,
      },
    });
  }
  console.log('Payment link + QR code created for Test Worker');

  // ── Existing test providers ──────────────────────────────────────────────
  const provider1User = await prisma.user.upsert({
    where: { phone: '+919123456780' },
    update: {},
    create: {
      phone: '+919123456780',
      name: 'Amit Kumar',
      type: UserType.PROVIDER,
      status: UserStatus.ACTIVE,
      kycStatus: KycStatus.BASIC,
    },
  });

  await prisma.provider.upsert({
    where: { id: provider1User.id },
    update: {},
    create: {
      id: provider1User.id,
      upiVpa: 'amit.kumar@okicici',
      category: ProviderCategory.RESTAURANT,
      payoutPreference: PayoutPreference.DAILY_BATCH,
      totalTipsReceived: 0,
    },
  });

  await prisma.wallet.upsert({
    where: { userId_type: { userId: provider1User.id, type: WalletType.PROVIDER_EARNINGS } },
    update: {},
    create: { userId: provider1User.id, type: WalletType.PROVIDER_EARNINGS, balancePaise: 0 },
  });

  const provider2User = await prisma.user.upsert({
    where: { phone: '+919123456781' },
    update: {},
    create: {
      phone: '+919123456781',
      name: 'Sunita Devi',
      type: UserType.PROVIDER,
      status: UserStatus.ACTIVE,
      kycStatus: KycStatus.BASIC,
    },
  });

  await prisma.provider.upsert({
    where: { id: provider2User.id },
    update: {},
    create: {
      id: provider2User.id,
      upiVpa: 'sunita.devi@oksbi',
      category: ProviderCategory.SALON,
      payoutPreference: PayoutPreference.DAILY_BATCH,
      totalTipsReceived: 0,
    },
  });

  await prisma.wallet.upsert({
    where: { userId_type: { userId: provider2User.id, type: WalletType.PROVIDER_EARNINGS } },
    update: {},
    create: { userId: provider2User.id, type: WalletType.PROVIDER_EARNINGS, balancePaise: 0 },
  });
  console.log(`Provider 1 (Restaurant): ${provider1User.id}`);
  console.log(`Provider 2 (Salon): ${provider2User.id}`);

  // ── QR codes for legacy providers ───────────────────────────────────────
  const qr1 = await prisma.qrCode.findFirst({ where: { providerId: provider1User.id } });
  if (!qr1) {
    await prisma.qrCode.create({
      data: { providerId: provider1User.id, type: QrCodeType.STATIC, locationLabel: 'Counter A', isActive: true },
    });
  }
  const qr2 = await prisma.qrCode.findFirst({ where: { providerId: provider2User.id } });
  if (!qr2) {
    await prisma.qrCode.create({
      data: { providerId: provider2User.id, type: QrCodeType.STATIC, locationLabel: 'Station 1', isActive: true },
    });
  }
  console.log('QR codes created');

  console.log('\nSeeding complete.');
  console.log('\n--- TEST ACCOUNTS (DEV_BYPASS_ENABLED=true) ---');
  console.log('  Test Tipper  : +919999999999  OTP: 123456  (ADMIN)');
  console.log('  Test Worker  : +919999999998  OTP: 123456  (PROVIDER)');
  console.log('  Tip URL      : /app/tip.html?code=testwrkr');
  console.log('  Seed endpoint: POST /dev/seed');
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
