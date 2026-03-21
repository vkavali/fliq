import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService, Prisma } from '@tippay/database';
import { WalletType, LedgerEntryType } from '@tippay/shared';

const MAX_OPTIMISTIC_LOCK_RETRIES = 3;

@Injectable()
export class WalletsService {
  private readonly logger = new Logger(WalletsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async getOrCreateWallet(userId: string, type: WalletType) {
    const existing = await this.prisma.wallet.findUnique({
      where: { userId_type: { userId, type } },
    });
    if (existing) return existing;

    return this.prisma.wallet.create({
      data: { userId, type, balancePaise: 0 },
    });
  }

  async getBalance(walletId: string): Promise<bigint> {
    const wallet = await this.prisma.wallet.findUnique({ where: { id: walletId } });
    if (!wallet) throw new BadRequestException('Wallet not found');
    return wallet.balancePaise;
  }

  /**
   * Credit a wallet using optimistic locking.
   * Creates a ledger entry in the same transaction.
   */
  async creditWallet(
    walletId: string,
    amountPaise: bigint,
    transactionId: string,
    description: string,
    prismaClient?: Prisma.TransactionClient,
  ): Promise<void> {
    const client = prismaClient || this.prisma;
    await this.updateWalletWithRetry(
      client,
      walletId,
      amountPaise,
      LedgerEntryType.CREDIT,
      transactionId,
      description,
    );
  }

  /**
   * Debit a wallet using optimistic locking.
   * Fails if insufficient balance.
   */
  async debitWallet(
    walletId: string,
    amountPaise: bigint,
    transactionId: string,
    description: string,
    prismaClient?: Prisma.TransactionClient,
  ): Promise<void> {
    const client = prismaClient || this.prisma;
    await this.updateWalletWithRetry(
      client,
      walletId,
      amountPaise,
      LedgerEntryType.DEBIT,
      transactionId,
      description,
    );
  }

  private async updateWalletWithRetry(
    client: Prisma.TransactionClient | PrismaService,
    walletId: string,
    amountPaise: bigint,
    entryType: LedgerEntryType,
    transactionId: string,
    description: string,
  ): Promise<void> {
    for (let attempt = 0; attempt < MAX_OPTIMISTIC_LOCK_RETRIES; attempt++) {
      const wallet = await client.wallet.findUnique({ where: { id: walletId } });
      if (!wallet) throw new BadRequestException('Wallet not found');

      const newBalance =
        entryType === LedgerEntryType.CREDIT
          ? wallet.balancePaise + amountPaise
          : wallet.balancePaise - amountPaise;

      if (newBalance < 0n) {
        throw new BadRequestException('Insufficient wallet balance');
      }

      // Optimistic lock: update only if version matches
      const updated = await client.wallet.updateMany({
        where: { id: walletId, version: wallet.version },
        data: {
          balancePaise: newBalance,
          version: { increment: 1 },
        },
      });

      if (updated.count === 0) {
        // Version mismatch — retry
        this.logger.warn(`Optimistic lock conflict on wallet ${walletId}, attempt ${attempt + 1}`);
        continue;
      }

      // Create ledger entry
      await client.ledgerEntry.create({
        data: {
          walletId,
          transactionId,
          entryType,
          amountPaise,
          balanceAfterPaise: newBalance,
          description,
        },
      });

      return;
    }

    throw new BadRequestException('Wallet update failed after retries (concurrent modification)');
  }
}
