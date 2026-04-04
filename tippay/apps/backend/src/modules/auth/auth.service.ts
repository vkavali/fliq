import {
  Injectable,
  BadRequestException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '@fliq/database';
import { UserType } from '@fliq/shared';
import { RedisService } from '../redis/redis.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EmailService } from '../email/email.service';
import * as crypto from 'crypto';

const OTP_EXPIRY_MINUTES = 5;
const OTP_MAX_ATTEMPTS = 3;
const OTP_RATE_LIMIT_HOUR = 5;
const OTP_RATE_LIMIT_DAY = 10;

// Test accounts that bypass real OTP when DEV_BYPASS_ENABLED=true
const BYPASS_TEST_PHONES = ['+919999999999', '+919999999998', '+19999999999', '+19999999998'];
const BYPASS_TEST_OTP = '123456';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly redis: RedisService,
    private readonly notifications: NotificationsService,
    private readonly email: EmailService,
  ) {}

  private isBypassEnabled(): boolean {
    return this.config.get<string>('DEV_BYPASS_ENABLED', 'false') === 'true';
  }

  async sendOtp(phone: string): Promise<{ message: string; otp?: string }> {
    // Dev bypass: test phones always accept OTP "123456" — no SMS/WhatsApp sent
    if (this.isBypassEnabled() && BYPASS_TEST_PHONES.includes(phone)) {
      this.logger.warn(`[DEV BYPASS] OTP for ${phone} is always: ${BYPASS_TEST_OTP}`);
      return { message: `OTP sent (dev bypass active — use ${BYPASS_TEST_OTP})`, otp: BYPASS_TEST_OTP };
    }

    await this.checkOtpRateLimit(phone);

    const code = this.generateOtp();
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

    // Find existing user for this phone (may not exist yet)
    const existingUser = await this.prisma.user.findUnique({ where: { phone } });

    await this.prisma.otpCode.create({
      data: {
        phone,
        code,
        expiresAt,
        userId: existingUser?.id ?? null,
      },
    });

    // Increment rate limit counters
    const hourKey = `otp_rate:hour:${phone}`;
    const dayKey = `otp_rate:day:${phone}`;
    await this.redis.incr(hourKey);
    await this.redis.setex(hourKey, 3600, (await this.redis.get(hourKey)) || '1');
    await this.redis.incr(dayKey);
    await this.redis.setex(dayKey, 86400, (await this.redis.get(dayKey)) || '1');

    await this.notifications.sendOtpNotification(phone, code);
    this.logger.log(`OTP dispatched to ${phone}`);

    return { message: 'OTP sent successfully' };
  }

  async verifyOtp(
    phone: string,
    code: string,
  ): Promise<{ accessToken: string; refreshToken: string; user: Record<string, unknown> }> {
    // Dev bypass: test phones accept magic OTP without a DB record
    if (this.isBypassEnabled() && BYPASS_TEST_PHONES.includes(phone) && code === BYPASS_TEST_OTP) {
      this.logger.warn(`[DEV BYPASS] Accepting magic OTP for ${phone}`);
      let user = await this.prisma.user.findUnique({ where: { phone } });
      if (!user) {
        user = await this.prisma.user.create({
          data: { phone, type: 'CUSTOMER' as any, status: 'ACTIVE' },
        });
      }
      const accessToken = this.generateAccessToken(user.id, user.type as UserType);
      const refreshToken = this.generateRefreshToken(user.id);
      return {
        accessToken,
        refreshToken,
        user: { id: user.id, phone: user.phone, name: user.name, type: user.type, kycStatus: user.kycStatus },
      };
    }

    const otpRecord = await this.prisma.otpCode.findFirst({
      where: {
        phone,
        verified: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otpRecord) {
      throw new BadRequestException('No valid OTP found. Request a new one.');
    }

    if (otpRecord.attempts >= OTP_MAX_ATTEMPTS) {
      throw new BadRequestException('Too many failed attempts. Request a new OTP.');
    }

    if (otpRecord.code !== code) {
      await this.prisma.otpCode.update({
        where: { id: otpRecord.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Invalid OTP');
    }

    // Mark OTP as verified
    await this.prisma.otpCode.update({
      where: { id: otpRecord.id },
      data: { verified: true },
    });

    // Find or create user
    let user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) {
      user = await this.prisma.user.create({
        data: {
          phone,
          type: UserType.CUSTOMER, // Default; can upgrade to PROVIDER later
          status: 'ACTIVE',
        },
      });
    }

    const accessToken = this.generateAccessToken(user.id, user.type as UserType);
    const refreshToken = this.generateRefreshToken(user.id);

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        type: user.type,
        kycStatus: user.kycStatus,
      },
    };
  }

  async sendEmailOtp(email: string): Promise<{ message: string; otp?: string }> {
    // Dev bypass test emails
    const testEmails = ['test@fliq.co.in', 'business@fliq.co.in'];
    if (this.isBypassEnabled() && testEmails.includes(email)) {
      this.logger.warn(`[DEV BYPASS] OTP for ${email} is always: ${BYPASS_TEST_OTP}`);
      return { message: `OTP sent (dev bypass active — use ${BYPASS_TEST_OTP})`, otp: BYPASS_TEST_OTP };
    }

    // Rate limiting (simplified for email)
    const hourKey = `otp_email_rate:hour:${email}`;
    const hourCount = parseInt((await this.redis.get(hourKey)) || '0', 10);
    if (hourCount >= OTP_RATE_LIMIT_HOUR) {
      throw new HttpException('Too many OTP requests. Try again in an hour.', HttpStatus.TOO_MANY_REQUESTS);
    }

    const code = this.generateOtp();
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

    const existingUser = await this.prisma.user.findUnique({ where: { email } });

    await this.prisma.otpCode.create({
      data: {
        phone: null, // No phone
        email,
        code,
        expiresAt,
        userId: existingUser?.id ?? null,
      },
    });

    await this.redis.incr(hourKey);
    await this.redis.setex(hourKey, 3600, (await this.redis.get(hourKey)) || '1');

    // Send OTP via email (Hostinger SMTP)
    const emailSent = await this.email.sendOtp(email, code);

    if (emailSent) {
      return { message: 'Access code sent to your email' };
    }

    // Fallback: return OTP in response if SMTP not configured (dev/testing)
    this.logger.warn(`SMTP not configured — returning OTP in response for ${email}`);
    return { message: 'Access code generated (check below)', otp: code };
  }

  async verifyEmailOtp(
    email: string,
    code: string,
  ): Promise<{ accessToken: string; refreshToken: string; user: Record<string, unknown> }> {
    
    // Dev Bypass
    const testEmails = ['test@fliq.co.in', 'business@fliq.co.in'];
    if (this.isBypassEnabled() && testEmails.includes(email) && code === BYPASS_TEST_OTP) {
      this.logger.warn(`[DEV BYPASS] Accepting magic OTP for ${email}`);
      let user = await this.prisma.user.findUnique({ where: { email } });
      if (!user) {
        const emailName = email.split('@')[0].replace(/[._-]/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
        user = await this.prisma.user.create({
          data: { email, name: emailName, type: 'BUSINESS_ADMIN' as any, status: 'ACTIVE' },
        });
      }
      const accessToken = this.generateAccessToken(user.id, user.type as UserType);
      const refreshToken = this.generateRefreshToken(user.id);
      return { accessToken, refreshToken, user: { id: user.id, email: user.email, name: user.name, type: user.type, kycStatus: user.kycStatus } };
    }

    const otpRecord = await this.prisma.otpCode.findFirst({
      where: {
        email,
        verified: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otpRecord) throw new BadRequestException('No valid OTP found. Request a new one.');
    if (otpRecord.attempts >= OTP_MAX_ATTEMPTS) throw new BadRequestException('Too many failed attempts. Request a new OTP.');

    if (otpRecord.code !== code) {
      await this.prisma.otpCode.update({ where: { id: otpRecord.id }, data: { attempts: { increment: 1 } } });
      throw new BadRequestException('Invalid OTP');
    }

    await this.prisma.otpCode.update({ where: { id: otpRecord.id }, data: { verified: true } });

    let user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) {
      // Derive a display name from the email prefix (e.g. "venkatesh" from "venkatesh@hotel.com")
      const emailName = email.split('@')[0].replace(/[._-]/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
      user = await this.prisma.user.create({
        data: {
          email,
          name: emailName,
          type: UserType.BUSINESS_ADMIN,
          status: 'ACTIVE',
        },
      });
    }

    const accessToken = this.generateAccessToken(user.id, user.type as UserType);
    const refreshToken = this.generateRefreshToken(user.id);

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        type: user.type,
        kycStatus: user.kycStatus,
      },
    };
  }


  private generateOtp(): string {
    // Cryptographically random 6-digit OTP
    const buffer = crypto.randomBytes(4);
    const num = buffer.readUInt32BE(0) % 900000 + 100000;
    return num.toString();
  }

  private generateAccessToken(userId: string, userType: UserType): string {
    return this.jwt.sign(
      { sub: userId, type: userType },
      {
        secret: this.config.get<string>('JWT_SECRET'),
        expiresIn: this.config.get<string>('JWT_ACCESS_EXPIRY', '15m'),
      },
    );
  }

  private generateRefreshToken(userId: string): string {
    return this.jwt.sign(
      { sub: userId, tokenType: 'refresh' },
      {
        secret: this.config.get<string>('JWT_SECRET'),
        expiresIn: this.config.get<string>('JWT_REFRESH_EXPIRY', '7d'),
      },
    );
  }

  async refreshAccessToken(refreshToken: string): Promise<{ accessToken: string }> {
    try {
      const payload = this.jwt.verify(refreshToken, {
        secret: this.config.get<string>('JWT_SECRET'),
      });

      if (payload.tokenType !== 'refresh') {
        throw new BadRequestException('Invalid token type');
      }

      const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user || user.status !== 'ACTIVE') {
        throw new BadRequestException('User not found or inactive');
      }

      const accessToken = this.generateAccessToken(user.id, user.type as UserType);
      return { accessToken };
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      throw new BadRequestException('Invalid or expired refresh token');
    }
  }

  private async checkOtpRateLimit(phone: string): Promise<void> {
    const hourKey = `otp_rate:hour:${phone}`;
    const dayKey = `otp_rate:day:${phone}`;

    const hourCount = parseInt((await this.redis.get(hourKey)) || '0', 10);
    if (hourCount >= OTP_RATE_LIMIT_HOUR) {
      throw new HttpException('Too many OTP requests. Try again in an hour.', HttpStatus.TOO_MANY_REQUESTS);
    }

    const dayCount = parseInt((await this.redis.get(dayKey)) || '0', 10);
    if (dayCount >= OTP_RATE_LIMIT_DAY) {
      throw new HttpException('Daily OTP limit reached. Try again tomorrow.', HttpStatus.TOO_MANY_REQUESTS);
    }
  }
}
