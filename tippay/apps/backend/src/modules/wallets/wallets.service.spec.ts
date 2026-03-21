import { Test, TestingModule } from '@nestjs/testing';
import { WalletsService } from './wallets.service';
import { PrismaService } from '@fliq/database';
import { BadRequestException } from '@nestjs/common';

describe('WalletsService', () => {
  let service: WalletsService;
  let prisma: any;

  const mockWallet = {
    id: 'wallet-1',
    userId: 'user-1',
    type: 'PROVIDER_EARNINGS',
    balancePaise: 10000n,
    version: 1,
  };

  beforeEach(async () => {
    prisma = {
      wallet: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        updateMany: jest.fn(),
      },
      ledgerEntry: {
        create: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WalletsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<WalletsService>(WalletsService);
  });

  describe('getOrCreateWallet', () => {
    it('returns existing wallet', async () => {
      prisma.wallet.findUnique.mockResolvedValue(mockWallet);
      const result = await service.getOrCreateWallet('user-1', 'PROVIDER_EARNINGS' as any);
      expect(result).toEqual(mockWallet);
    });

    it('creates wallet if not found', async () => {
      prisma.wallet.findUnique.mockResolvedValue(null);
      prisma.wallet.create.mockResolvedValue(mockWallet);
      const result = await service.getOrCreateWallet('user-1', 'PROVIDER_EARNINGS' as any);
      expect(prisma.wallet.create).toHaveBeenCalled();
      expect(result).toEqual(mockWallet);
    });
  });

  describe('creditWallet', () => {
    it('credits wallet and creates ledger entry', async () => {
      prisma.wallet.findUnique.mockResolvedValue(mockWallet);
      prisma.wallet.updateMany.mockResolvedValue({ count: 1 });
      prisma.ledgerEntry.create.mockResolvedValue({});

      await service.creditWallet('wallet-1', 5000n, 'tx-1', 'Test credit');

      expect(prisma.wallet.updateMany).toHaveBeenCalledWith({
        where: { id: 'wallet-1', version: 1 },
        data: {
          balancePaise: 15000n,
          version: { increment: 1 },
        },
      });

      expect(prisma.ledgerEntry.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          walletId: 'wallet-1',
          entryType: 'CREDIT',
          amountPaise: 5000n,
          balanceAfterPaise: 15000n,
        }),
      });
    });
  });

  describe('debitWallet', () => {
    it('throws on insufficient balance', async () => {
      prisma.wallet.findUnique.mockResolvedValue(mockWallet); // 10000n balance

      await expect(
        service.debitWallet('wallet-1', 20000n, 'tx-1', 'Test debit'),
      ).rejects.toThrow(BadRequestException);
    });

    it('debits wallet and creates ledger entry', async () => {
      prisma.wallet.findUnique.mockResolvedValue(mockWallet);
      prisma.wallet.updateMany.mockResolvedValue({ count: 1 });
      prisma.ledgerEntry.create.mockResolvedValue({});

      await service.debitWallet('wallet-1', 3000n, 'tx-1', 'Test debit');

      expect(prisma.wallet.updateMany).toHaveBeenCalledWith({
        where: { id: 'wallet-1', version: 1 },
        data: {
          balancePaise: 7000n,
          version: { increment: 1 },
        },
      });
    });

    it('retries on optimistic lock conflict', async () => {
      const wallet1 = { ...mockWallet, version: 1 };
      const wallet2 = { ...mockWallet, version: 2 };

      prisma.wallet.findUnique
        .mockResolvedValueOnce(wallet1)
        .mockResolvedValueOnce(wallet2);
      prisma.wallet.updateMany
        .mockResolvedValueOnce({ count: 0 }) // First attempt fails
        .mockResolvedValueOnce({ count: 1 }); // Second attempt succeeds
      prisma.ledgerEntry.create.mockResolvedValue({});

      await service.debitWallet('wallet-1', 3000n, 'tx-1', 'Test debit');

      expect(prisma.wallet.updateMany).toHaveBeenCalledTimes(2);
    });
  });
});
