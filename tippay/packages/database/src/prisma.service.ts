import { PrismaClient } from '@prisma/client';

/**
 * NestJS-compatible Prisma service.
 * Extends PrismaClient and manages connection lifecycle.
 *
 * Usage in NestJS module:
 *   providers: [PrismaService]
 *   exports: [PrismaService]
 *
 * Then call onModuleInit() and onModuleDestroy() via NestJS lifecycle hooks.
 */
export class PrismaService extends PrismaClient {
  constructor() {
    super({
      log:
        process.env.APP_ENV === 'development'
          ? ['query', 'warn', 'error']
          : ['warn', 'error'],
    });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
    await this.ensureTablesExist();
  }

  private async ensureTablesExist(): Promise<void> {
    try {
      await this.$queryRawUnsafe(`SELECT 1 FROM "users" LIMIT 1`);
    } catch {
      console.log('=== Tables missing — creating schema ===');
      const statements = INIT_SQL.split(';')
        .map(s => s.trim())
        .filter(s => s.length > 0);
      for (const stmt of statements) {
        try {
          await this.$executeRawUnsafe(stmt);
        } catch (e) {
          // Ignore "already exists" errors
          const msg = (e as Error).message || '';
          if (!msg.includes('already exists')) {
            console.error('SQL error:', msg);
          }
        }
      }
      console.log('=== Schema created ===');
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}

const INIT_SQL = `
CREATE TYPE "UserType" AS ENUM ('CUSTOMER', 'PROVIDER', 'ADMIN');
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'DEACTIVATED');
CREATE TYPE "KycStatus" AS ENUM ('PENDING', 'BASIC', 'FULL');
CREATE TYPE "ProviderCategory" AS ENUM ('DELIVERY', 'SALON', 'HOUSEHOLD', 'RESTAURANT', 'HOTEL', 'OTHER');
CREATE TYPE "PayoutPreference" AS ENUM ('INSTANT', 'DAILY_BATCH', 'WEEKLY');
CREATE TYPE "WalletType" AS ENUM ('PROVIDER_EARNINGS', 'PLATFORM_COMMISSION', 'TAX_RESERVE');
CREATE TYPE "LedgerEntryType" AS ENUM ('DEBIT', 'CREDIT');
CREATE TYPE "PaymentMethod" AS ENUM ('UPI', 'CARD', 'NET_BANKING', 'WALLET');
CREATE TYPE "TipSource" AS ENUM ('QR_CODE', 'PAYMENT_LINK', 'IN_APP');
CREATE TYPE "TipStatus" AS ENUM ('INITIATED', 'PAID', 'SETTLED', 'FAILED', 'REFUNDED');
CREATE TYPE "TransactionType" AS ENUM ('TIP', 'PAYOUT', 'REFUND', 'COMMISSION', 'TAX_DEDUCTION');
CREATE TYPE "TransactionStatus" AS ENUM ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED');
CREATE TYPE "PayoutMode" AS ENUM ('UPI', 'IMPS', 'NEFT');
CREATE TYPE "PayoutStatus" AS ENUM ('PENDING_BATCH', 'INITIATED', 'PROCESSED', 'SETTLED', 'FAILED');
CREATE TYPE "QrCodeType" AS ENUM ('STATIC', 'DYNAMIC');
CREATE TABLE "users" ("id" UUID NOT NULL,"type" "UserType" NOT NULL,"phone" VARCHAR(15) NOT NULL,"email" VARCHAR(255),"name" VARCHAR(255),"languagePreference" VARCHAR(5) NOT NULL DEFAULT 'en',"kycStatus" "KycStatus" NOT NULL DEFAULT 'PENDING',"status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',"createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,"updatedAt" TIMESTAMPTZ NOT NULL,CONSTRAINT "users_pkey" PRIMARY KEY ("id"));
CREATE TABLE "providers" ("id" UUID NOT NULL,"upiVpa" VARCHAR(255),"bankAccountNumberEncrypted" BYTEA,"bankIfsc" VARCHAR(11),"panEncrypted" BYTEA,"panVerified" BOOLEAN NOT NULL DEFAULT false,"bankVerified" BOOLEAN NOT NULL DEFAULT false,"category" "ProviderCategory" NOT NULL DEFAULT 'OTHER',"ratingAverage" DECIMAL(3,2),"totalTipsReceived" INTEGER NOT NULL DEFAULT 0,"payoutPreference" "PayoutPreference" NOT NULL DEFAULT 'DAILY_BATCH',"razorpayLinkedAccountId" VARCHAR(50),"razorpayFundAccountId" VARCHAR(50),"qrCodeUrl" TEXT,"createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "providers_pkey" PRIMARY KEY ("id"));
CREATE TABLE "otp_codes" ("id" UUID NOT NULL,"userId" UUID,"phone" VARCHAR(15) NOT NULL,"code" VARCHAR(6) NOT NULL,"expiresAt" TIMESTAMPTZ NOT NULL,"verified" BOOLEAN NOT NULL DEFAULT false,"attempts" INTEGER NOT NULL DEFAULT 0,"createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "otp_codes_pkey" PRIMARY KEY ("id"));
CREATE TABLE "wallets" ("id" UUID NOT NULL,"userId" UUID NOT NULL,"type" "WalletType" NOT NULL,"balancePaise" BIGINT NOT NULL DEFAULT 0,"version" INTEGER NOT NULL DEFAULT 1,"createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,"updatedAt" TIMESTAMPTZ NOT NULL,CONSTRAINT "wallets_pkey" PRIMARY KEY ("id"));
CREATE TABLE "ledger_entries" ("id" UUID NOT NULL,"walletId" UUID NOT NULL,"transactionId" UUID NOT NULL,"entryType" "LedgerEntryType" NOT NULL,"amountPaise" BIGINT NOT NULL,"balanceAfterPaise" BIGINT NOT NULL,"description" TEXT,"createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "ledger_entries_pkey" PRIMARY KEY ("id"));
CREATE TABLE "tips" ("id" UUID NOT NULL,"customerId" UUID,"providerId" UUID NOT NULL,"amountPaise" BIGINT NOT NULL,"commissionPaise" BIGINT NOT NULL DEFAULT 0,"commissionRate" DECIMAL(5,4),"netAmountPaise" BIGINT NOT NULL,"gstOnCommissionPaise" BIGINT NOT NULL DEFAULT 0,"tdsPaise" BIGINT NOT NULL DEFAULT 0,"tcsPaise" BIGINT NOT NULL DEFAULT 0,"paymentMethod" "PaymentMethod","source" "TipSource" NOT NULL,"status" "TipStatus" NOT NULL DEFAULT 'INITIATED',"gateway" VARCHAR(20),"gatewayOrderId" VARCHAR(100),"gatewayPaymentId" VARCHAR(100),"message" TEXT,"rating" SMALLINT,"createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,"updatedAt" TIMESTAMPTZ NOT NULL,CONSTRAINT "tips_pkey" PRIMARY KEY ("id"));
CREATE TABLE "transactions" ("id" UUID NOT NULL,"type" "TransactionType" NOT NULL,"referenceId" UUID,"fromWalletId" UUID,"toWalletId" UUID,"amountPaise" BIGINT NOT NULL,"status" "TransactionStatus" NOT NULL DEFAULT 'PENDING',"idempotencyKey" VARCHAR(255),"gateway" VARCHAR(20),"gatewayTransactionId" VARCHAR(100),"metadata" JSONB,"createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,"updatedAt" TIMESTAMPTZ NOT NULL,CONSTRAINT "transactions_pkey" PRIMARY KEY ("id"));
CREATE TABLE "payouts" ("id" UUID NOT NULL,"providerId" UUID NOT NULL,"amountPaise" BIGINT NOT NULL,"mode" "PayoutMode" NOT NULL DEFAULT 'IMPS',"status" "PayoutStatus" NOT NULL DEFAULT 'PENDING_BATCH',"gateway" VARCHAR(20),"gatewayPayoutId" VARCHAR(100),"utr" VARCHAR(50),"failureReason" TEXT,"retryCount" INTEGER NOT NULL DEFAULT 0,"batchId" UUID,"createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,"settledAt" TIMESTAMPTZ,CONSTRAINT "payouts_pkey" PRIMARY KEY ("id"));
CREATE TABLE "qr_codes" ("id" UUID NOT NULL,"providerId" UUID NOT NULL,"type" "QrCodeType" NOT NULL,"razorpayQrId" VARCHAR(50),"qrImageUrl" TEXT,"upiUrl" TEXT,"locationLabel" VARCHAR(255),"scanCount" INTEGER NOT NULL DEFAULT 0,"isActive" BOOLEAN NOT NULL DEFAULT true,"createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "qr_codes_pkey" PRIMARY KEY ("id"));
CREATE TABLE "webhook_events" ("id" UUID NOT NULL,"eventId" VARCHAR(100) NOT NULL,"gateway" VARCHAR(20) NOT NULL,"eventType" VARCHAR(100) NOT NULL,"payload" JSONB NOT NULL,"processed" BOOLEAN NOT NULL DEFAULT false,"processedAt" TIMESTAMPTZ,"createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "webhook_events_pkey" PRIMARY KEY ("id"));
CREATE TABLE "outbox_events" ("id" UUID NOT NULL,"aggregateType" VARCHAR(50) NOT NULL,"aggregateId" UUID NOT NULL,"eventType" VARCHAR(100) NOT NULL,"payload" JSONB NOT NULL,"published" BOOLEAN NOT NULL DEFAULT false,"createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "outbox_events_pkey" PRIMARY KEY ("id"));
CREATE TABLE "consent_records" ("id" UUID NOT NULL,"userId" UUID NOT NULL,"purpose" VARCHAR(50) NOT NULL,"granted" BOOLEAN NOT NULL DEFAULT true,"grantedAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,"withdrawnAt" TIMESTAMPTZ,"policyVersion" VARCHAR(20) NOT NULL,"channel" VARCHAR(20) NOT NULL,CONSTRAINT "consent_records_pkey" PRIMARY KEY ("id"));
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");
CREATE INDEX "otp_codes_phone_code_idx" ON "otp_codes"("phone", "code");
CREATE UNIQUE INDEX "wallets_userId_type_key" ON "wallets"("userId", "type");
CREATE INDEX "ledger_entries_walletId_createdAt_idx" ON "ledger_entries"("walletId", "createdAt");
CREATE INDEX "tips_providerId_createdAt_idx" ON "tips"("providerId", "createdAt");
CREATE INDEX "tips_customerId_createdAt_idx" ON "tips"("customerId", "createdAt");
CREATE INDEX "tips_gatewayPaymentId_idx" ON "tips"("gatewayPaymentId");
CREATE UNIQUE INDEX "transactions_idempotencyKey_key" ON "transactions"("idempotencyKey");
CREATE INDEX "transactions_referenceId_idx" ON "transactions"("referenceId");
CREATE INDEX "payouts_providerId_createdAt_idx" ON "payouts"("providerId", "createdAt");
CREATE INDEX "qr_codes_providerId_idx" ON "qr_codes"("providerId");
CREATE UNIQUE INDEX "webhook_events_eventId_key" ON "webhook_events"("eventId");
CREATE INDEX "outbox_events_published_createdAt_idx" ON "outbox_events"("published", "createdAt");
ALTER TABLE "providers" ADD CONSTRAINT "providers_id_fkey" FOREIGN KEY ("id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "otp_codes" ADD CONSTRAINT "otp_codes_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "wallets" ADD CONSTRAINT "wallets_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "wallets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_transactionId_fkey" FOREIGN KEY ("transactionId") REFERENCES "transactions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "tips" ADD CONSTRAINT "tips_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "tips" ADD CONSTRAINT "tips_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_referenceId_fkey" FOREIGN KEY ("referenceId") REFERENCES "tips"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "payouts" ADD CONSTRAINT "payouts_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "qr_codes" ADD CONSTRAINT "qr_codes_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "providers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "consent_records" ADD CONSTRAINT "consent_records_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
`;
