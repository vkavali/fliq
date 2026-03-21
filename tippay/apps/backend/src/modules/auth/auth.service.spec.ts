import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { PrismaService } from '@fliq/database';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { RedisService } from '../redis/redis.service';
import { BadRequestException, HttpException } from '@nestjs/common';

describe('AuthService', () => {
  let service: AuthService;
  let prisma: any;
  let redis: any;
  let jwt: any;

  beforeEach(async () => {
    prisma = {
      user: { findUnique: jest.fn(), create: jest.fn() },
      otpCode: {
        create: jest.fn(),
        findFirst: jest.fn(),
        update: jest.fn(),
      },
    };

    redis = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn(),
      setex: jest.fn(),
      incr: jest.fn().mockResolvedValue(1),
    };

    jwt = {
      sign: jest.fn().mockReturnValue('test-jwt-token'),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: jwt },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string, defaultValue?: string) => {
              const config: Record<string, string> = {
                JWT_SECRET: 'test-secret',
                JWT_ACCESS_EXPIRY: '15m',
                JWT_REFRESH_EXPIRY: '7d',
                APP_ENV: 'development',
              };
              return config[key] || defaultValue;
            }),
          },
        },
        { provide: RedisService, useValue: redis },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  describe('sendOtp', () => {
    it('sends OTP successfully', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      prisma.otpCode.create.mockResolvedValue({});

      const result = await service.sendOtp('+919876543210');
      expect(result.message).toBe('OTP sent successfully');
      expect(prisma.otpCode.create).toHaveBeenCalled();
    });

    it('throws when hourly rate limit exceeded', async () => {
      redis.get.mockResolvedValue('5'); // at limit

      await expect(service.sendOtp('+919876543210')).rejects.toThrow(HttpException);
    });
  });

  describe('verifyOtp', () => {
    it('returns tokens for valid OTP', async () => {
      prisma.otpCode.findFirst.mockResolvedValue({
        id: 'otp-1',
        code: '123456',
        attempts: 0,
      });
      prisma.otpCode.update.mockResolvedValue({});
      prisma.user.findUnique.mockResolvedValue({
        id: 'user-1',
        phone: '+919876543210',
        name: 'Test',
        type: 'CUSTOMER',
        kycStatus: 'PENDING',
      });

      const result = await service.verifyOtp('+919876543210', '123456');

      expect(result.accessToken).toBe('test-jwt-token');
      expect(result.refreshToken).toBe('test-jwt-token');
      expect(result.user.id).toBe('user-1');
    });

    it('creates new user if not found', async () => {
      prisma.otpCode.findFirst.mockResolvedValue({
        id: 'otp-1',
        code: '123456',
        attempts: 0,
      });
      prisma.otpCode.update.mockResolvedValue({});
      prisma.user.findUnique.mockResolvedValue(null);
      prisma.user.create.mockResolvedValue({
        id: 'new-user',
        phone: '+919876543210',
        name: null,
        type: 'CUSTOMER',
        kycStatus: 'PENDING',
      });

      const result = await service.verifyOtp('+919876543210', '123456');
      expect(prisma.user.create).toHaveBeenCalled();
      expect(result.user.id).toBe('new-user');
    });

    it('throws for wrong OTP', async () => {
      prisma.otpCode.findFirst.mockResolvedValue({
        id: 'otp-1',
        code: '123456',
        attempts: 0,
      });
      prisma.otpCode.update.mockResolvedValue({});

      await expect(service.verifyOtp('+919876543210', '999999')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('throws for expired/missing OTP', async () => {
      prisma.otpCode.findFirst.mockResolvedValue(null);

      await expect(service.verifyOtp('+919876543210', '123456')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('throws when max attempts exceeded', async () => {
      prisma.otpCode.findFirst.mockResolvedValue({
        id: 'otp-1',
        code: '123456',
        attempts: 3,
      });

      await expect(service.verifyOtp('+919876543210', '123456')).rejects.toThrow(
        BadRequestException,
      );
    });
  });
});
