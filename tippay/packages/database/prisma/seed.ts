import { PrismaClient, UserType, UserStatus, KycStatus, ProviderCategory, PayoutPreference, WalletType, QrCodeType } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Create admin user
  const admin = await prisma.user.upsert({
    where: { phone: '+919999999999' },
    update: {},
    create: {
      phone: '+919999999999',
      name: 'Admin User',
      type: UserType.ADMIN,
      status: UserStatus.ACTIVE,
      kycStatus: KycStatus.FULL,
    },
  });
  console.log(`Admin user: ${admin.id}`);

  // Create test customer 1
  const customer1 = await prisma.user.upsert({
    where: { phone: '+919876543210' },
    update: {},
    create: {
      phone: '+919876543210',
      name: 'Priya Sharma',
      type: UserType.CUSTOMER,
      status: UserStatus.ACTIVE,
      kycStatus: KycStatus.BASIC,
    },
  });
  console.log(`Customer 1: ${customer1.id}`);

  // Create test customer 2
  const customer2 = await prisma.user.upsert({
    where: { phone: '+919876543211' },
    update: {},
    create: {
      phone: '+919876543211',
      name: 'Rahul Verma',
      type: UserType.CUSTOMER,
      status: UserStatus.ACTIVE,
      kycStatus: KycStatus.PENDING,
    },
  });
  console.log(`Customer 2: ${customer2.id}`);

  // Create test provider 1
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

  // Create provider 1 earnings wallet
  await prisma.wallet.upsert({
    where: { userId_type: { userId: provider1User.id, type: WalletType.PROVIDER_EARNINGS } },
    update: {},
    create: {
      userId: provider1User.id,
      type: WalletType.PROVIDER_EARNINGS,
      balancePaise: 0,
    },
  });
  console.log(`Provider 1 (Restaurant): ${provider1User.id}`);

  // Create test provider 2
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

  // Create provider 2 earnings wallet
  await prisma.wallet.upsert({
    where: { userId_type: { userId: provider2User.id, type: WalletType.PROVIDER_EARNINGS } },
    update: {},
    create: {
      userId: provider2User.id,
      type: WalletType.PROVIDER_EARNINGS,
      balancePaise: 0,
    },
  });
  console.log(`Provider 2 (Salon): ${provider2User.id}`);

  // Create platform commission wallet (single system wallet)
  const platformUser = await prisma.user.upsert({
    where: { phone: '+910000000000' },
    update: {},
    create: {
      phone: '+910000000000',
      name: 'TipPay Platform',
      type: UserType.ADMIN,
      status: UserStatus.ACTIVE,
      kycStatus: KycStatus.FULL,
    },
  });

  await prisma.wallet.upsert({
    where: { userId_type: { userId: platformUser.id, type: WalletType.PLATFORM_COMMISSION } },
    update: {},
    create: {
      userId: platformUser.id,
      type: WalletType.PLATFORM_COMMISSION,
      balancePaise: 0,
    },
  });

  await prisma.wallet.upsert({
    where: { userId_type: { userId: platformUser.id, type: WalletType.TAX_RESERVE } },
    update: {},
    create: {
      userId: platformUser.id,
      type: WalletType.TAX_RESERVE,
      balancePaise: 0,
    },
  });
  console.log(`Platform wallets created for: ${platformUser.id}`);

  // Create sample QR codes for providers
  await prisma.qrCode.create({
    data: {
      providerId: provider1User.id,
      type: QrCodeType.STATIC,
      locationLabel: 'Counter A',
      isActive: true,
    },
  });

  await prisma.qrCode.create({
    data: {
      providerId: provider2User.id,
      type: QrCodeType.STATIC,
      locationLabel: 'Station 1',
      isActive: true,
    },
  });
  console.log('QR codes created');

  console.log('Seeding complete.');
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
