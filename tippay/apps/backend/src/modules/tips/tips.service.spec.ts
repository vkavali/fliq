import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { TipsService } from './tips.service';
import { PrismaService } from '@fliq/database';
import { RazorpayService } from '../payments/razorpay.service';
import { BadRequestException, NotFoundException } from '@nestjs/common';

describe('TipsService', () => {
  let service: TipsService;
  let prisma: any;
  let razorpay: any;

  const mockProvider = {
    id: 'provider-1',
    user: { name: 'Test Provider', status: 'ACTIVE' },
    category: 'RESTAURANT',
  };

  beforeEach(async () => {
    prisma = {
      provider: { findUnique: jest.fn() },
      tip: {
        create: jest.fn(),
        update: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
      },
    };

    razorpay = {
      createOrder: jest.fn(),
      verifyPaymentSignature: jest.fn(),
      getRazorpayKeyId: jest.fn().mockReturnValue('rzp_test_key'),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TipsService,
        { provide: PrismaService, useValue: prisma },
        { provide: RazorpayService, useValue: razorpay },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string, defaultValue?: string) => {
              const config: Record<string, string> = {
                APP_ENV: 'test',
              };
              return config[key] || defaultValue;
            }),
          },
        },
      ],
    }).compile();

    service = module.get<TipsService>(TipsService);
  });

  describe('createTip', () => {
    it('creates a tip with zero commission for small amounts', async () => {
      prisma.provider.findUnique.mockResolvedValue(mockProvider);
      prisma.tip.create.mockResolvedValue({ id: 'tip-1' });
      razorpay.createOrder.mockResolvedValue({ id: 'order_123' });
      prisma.tip.update.mockResolvedValue({});

      const result = await service.createTip({
        providerId: 'provider-1',
        amountPaise: 5000, // Rs 50 — below threshold
        source: 'QR_CODE' as any,
      });

      expect(result.tipId).toBe('tip-1');
      expect(result.orderId).toBe('order_123');
      expect(result.razorpayKeyId).toBe('rzp_test_key');

      // Commission should be 0 for amounts <= 10000 paise
      expect(prisma.tip.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          commissionPaise: 0n,
          commissionRate: 0,
        }),
      });
    });

    it('creates a tip with 5% commission for large amounts', async () => {
      prisma.provider.findUnique.mockResolvedValue(mockProvider);
      prisma.tip.create.mockResolvedValue({ id: 'tip-2' });
      razorpay.createOrder.mockResolvedValue({ id: 'order_456' });
      prisma.tip.update.mockResolvedValue({});

      await service.createTip({
        providerId: 'provider-1',
        amountPaise: 20000, // Rs 200 — above threshold
        source: 'QR_CODE' as any,
      });

      // 5% of 20000 = 1000
      expect(prisma.tip.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          commissionPaise: 1000n,
          commissionRate: 0.05,
        }),
      });
    });

    it('throws for inactive provider', async () => {
      prisma.provider.findUnique.mockResolvedValue({
        ...mockProvider,
        user: { name: 'Inactive', status: 'SUSPENDED' },
      });

      await expect(
        service.createTip({
          providerId: 'provider-1',
          amountPaise: 5000,
          source: 'QR_CODE' as any,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('throws for missing provider', async () => {
      prisma.provider.findUnique.mockResolvedValue(null);

      await expect(
        service.createTip({
          providerId: 'nonexistent',
          amountPaise: 5000,
          source: 'QR_CODE' as any,
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('verifyPayment', () => {
    it('verifies valid payment signature', async () => {
      prisma.tip.findUnique.mockResolvedValue({ id: 'tip-1', status: 'INITIATED' });
      razorpay.verifyPaymentSignature.mockReturnValue(true);
      prisma.tip.update.mockResolvedValue({});

      const result = await service.verifyPayment('tip-1', {
        razorpay_order_id: 'order_1',
        razorpay_payment_id: 'pay_1',
        razorpay_signature: 'sig_valid',
      });

      expect(result).toEqual({ status: 'verified', tipId: 'tip-1' });
      expect(prisma.tip.update).toHaveBeenCalledWith({
        where: { id: 'tip-1' },
        data: { status: 'PAID', gatewayPaymentId: 'pay_1' },
      });
    });

    it('throws for invalid signature', async () => {
      prisma.tip.findUnique.mockResolvedValue({ id: 'tip-1', status: 'INITIATED' });
      razorpay.verifyPaymentSignature.mockReturnValue(false);

      await expect(
        service.verifyPayment('tip-1', {
          razorpay_order_id: 'order_1',
          razorpay_payment_id: 'pay_1',
          razorpay_signature: 'sig_invalid',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('throws for already processed tip', async () => {
      prisma.tip.findUnique.mockResolvedValue({ id: 'tip-1', status: 'PAID' });

      await expect(
        service.verifyPayment('tip-1', {
          razorpay_order_id: 'order_1',
          razorpay_payment_id: 'pay_1',
          razorpay_signature: 'sig',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('throws for nonexistent tip', async () => {
      prisma.tip.findUnique.mockResolvedValue(null);

      await expect(
        service.verifyPayment('nonexistent', {
          razorpay_order_id: 'order_1',
          razorpay_payment_id: 'pay_1',
          razorpay_signature: 'sig',
        }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('getTipsByProvider', () => {
    it('returns paginated tips', async () => {
      const mockTips = [{ id: 'tip-1' }, { id: 'tip-2' }];
      prisma.tip.findMany.mockResolvedValue(mockTips);
      prisma.tip.count.mockResolvedValue(2);

      const result = await service.getTipsByProvider('provider-1', 1, 20);

      expect(result.tips).toHaveLength(2);
      expect(result.total).toBe(2);
      expect(result.page).toBe(1);
    });
  });
});
