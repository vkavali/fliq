import {
  Injectable,
  BadRequestException,
  GoneException,
  Logger,
  InternalServerErrorException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService, KycMethod, KycStatus } from '@fliq/database';
import * as crypto from 'crypto';
import { RedisService } from '../redis/redis.service';
import { encrypt } from '../../common/utils/encryption.util';
import { InitiateEkycDto } from './dto/initiate-ekyc.dto';
import { VerifyEkycOtpDto } from './dto/verify-ekyc-otp.dto';

const SESSION_TTL_SECONDS = 10 * 60; // 10 minutes

interface EkycSession {
  userId: string;
  /** Last four digits of Aadhaar — never store full number */
  aadhaarLast4: string;
  /** Whether this ID is a VID (16-digit) or Aadhaar (12-digit) */
  isVid: boolean;
  createdAt: number;
}

interface EkycData {
  name: string;
  dob: string;        // DD-MM-YYYY
  gender: string;     // M / F / T
  address: string;
  pincode: string;
  photo?: string;     // base64 JPEG, omitted if not present
}

@Injectable()
export class EkycService {
  private readonly logger = new Logger(EkycService.name);
  private readonly isDev: boolean;
  private readonly encryptionKeyHex: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly config: ConfigService,
  ) {
    this.isDev = config.get<string>('APP_ENV', 'development') !== 'production';

    const key = config.get<string>('ENCRYPTION_KEY', '');
    if (!key && !this.isDev) {
      throw new Error('ENCRYPTION_KEY env var is required in production');
    }
    // In dev, fall back to a fixed 32-byte key so the app still boots
    this.encryptionKeyHex =
      key || 'a'.repeat(64); // 32 zero-bytes as hex — dev only
  }

  // ---------------------------------------------------------------------------
  // POST /ekyc/initiate
  // ---------------------------------------------------------------------------

  async initiateEkyc(
    userId: string,
    dto: InitiateEkycDto,
  ): Promise<{ sessionToken: string; maskedPhone: string }> {
    const id = dto.aadhaarOrVid.replace(/\s/g, '');
    const isVid = id.length === 16;

    // Prevent re-initiation if already verified
    const provider = await this.prisma.provider.findUnique({ where: { id: userId } });
    if (provider?.kycVerified) {
      throw new BadRequestException('KYC is already verified for this account');
    }

    // Rate-limit: at most 3 initiation attempts per user per hour
    const rateLimitKey = `ekyc_init:${userId}`;
    const attempts = parseInt((await this.redis.get(rateLimitKey)) ?? '0', 10);
    if (attempts >= 3) {
      throw new BadRequestException('Too many eKYC attempts. Try again in an hour.');
    }
    await this.redis.incr(rateLimitKey);
    await this.redis.setex(rateLimitKey, 3600, String(attempts + 1));

    // In production: call UIDAI/DigiLocker sandbox to trigger OTP
    // The API returns a transaction ID and the masked mobile number.
    let maskedPhone = 'XXXXXXXX' + id.slice(-2); // fallback

    if (!this.isDev) {
      maskedPhone = await this.callUidaiInitiate(id, isVid);
    } else {
      this.logger.warn(`[DEV] eKYC initiate for ...${id.slice(-4)} — skipping UIDAI call`);
      maskedPhone = 'XXXXXX' + id.slice(-4, -2) + 'XX';
    }

    // Store session in Redis
    const sessionToken = `ekyc_${crypto.randomBytes(16).toString('hex')}`;
    const session: EkycSession = {
      userId,
      aadhaarLast4: id.slice(-4),
      isVid,
      createdAt: Date.now(),
    };
    await this.redis.setex(sessionToken, SESSION_TTL_SECONDS, JSON.stringify(session));

    return { sessionToken, maskedPhone };
  }

  // ---------------------------------------------------------------------------
  // POST /ekyc/verify-otp
  // ---------------------------------------------------------------------------

  async verifyEkycOtp(
    userId: string,
    dto: VerifyEkycOtpDto,
  ): Promise<{
    success: true;
    profile: { name: string; dob: string; gender: string; address: string };
  }> {
    const sessionRaw = await this.redis.get(dto.sessionToken);
    if (!sessionRaw) {
      throw new GoneException('eKYC session expired or not found. Please start again.');
    }

    const session = JSON.parse(sessionRaw) as EkycSession;

    if (session.userId !== userId) {
      throw new BadRequestException('Session does not belong to this user');
    }

    let ekycData: EkycData;

    if (!this.isDev) {
      ekycData = await this.callUidaiVerifyOtp(dto.sessionToken, dto.otp);
    } else {
      // Dev: accept any 6-digit OTP and return synthetic data
      if (!/^\d{6}$/.test(dto.otp)) {
        throw new BadRequestException('Invalid OTP');
      }
      this.logger.warn(`[DEV] eKYC OTP verified for session ${dto.sessionToken.slice(-8)}`);
      ekycData = this.generateDevEkycData(session.aadhaarLast4);
    }

    // Persist eKYC-derived data to Provider + mark as verified
    await this.applyEkycDataToProvider(userId, ekycData);

    // Clean up session
    await this.redis.del(dto.sessionToken);

    return {
      success: true,
      profile: {
        name: ekycData.name,
        dob: ekycData.dob,
        gender: ekycData.gender,
        address: ekycData.address,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // GET /ekyc/status
  // ---------------------------------------------------------------------------

  async getKycStatus(userId: string) {
    const provider = await this.prisma.provider.findUnique({
      where: { id: userId },
      select: {
        kycVerified: true,
        kycMethod: true,
        kycCompletedAt: true,
        user: { select: { kycStatus: true } },
      },
    });

    return {
      kycVerified: provider?.kycVerified ?? false,
      kycMethod: provider?.kycMethod ?? null,
      kycCompletedAt: provider?.kycCompletedAt ?? null,
      kycStatus: provider?.user?.kycStatus ?? 'PENDING',
    };
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private async applyEkycDataToProvider(userId: string, data: EkycData): Promise<void> {
    // Update provider: mark verified, store name/category stays, no Aadhaar stored
    await this.prisma.$transaction([
      this.prisma.provider.update({
        where: { id: userId },
        data: {
          displayName: data.name,
          kycVerified: true,
          kycMethod: KycMethod.AADHAAR,
          kycCompletedAt: new Date(),
        },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: {
          name: data.name,
          kycStatus: KycStatus.FULL,
        },
      }),
    ]);
  }

  /**
   * Call the UIDAI Aadhaar OTP eKYC sandbox to trigger OTP delivery.
   *
   * Replace this stub with the actual UIDAI / DigiLocker SDK call once
   * you have production AUA credentials (`UIDAI_AUA_CODE`, `UIDAI_ASA_CODE`,
   * `UIDAI_API_KEY`, and the UIDAI signing certificate).
   *
   * Reference: https://uidai.gov.in/ecosystem/authentication-devices-documents/developers-section
   */
  private async callUidaiInitiate(id: string, isVid: boolean): Promise<string> {
    const endpoint = this.config.get<string>(
      'UIDAI_SANDBOX_URL',
      'https://developer.uidai.gov.in/aadhaarkyc/2.5',
    );

    this.logger.log(`Calling UIDAI initiate at ${endpoint} for ...${id.slice(-4)}`);

    // TODO: Replace with actual UIDAI AUA XML request (encrypted PID block)
    // For now throw to prevent accidental production calls without credentials
    throw new InternalServerErrorException(
      'UIDAI production integration not yet wired — set APP_ENV=development for sandbox mode',
    );
  }

  /**
   * Call UIDAI API with OTP to receive eKYC XML, then parse it.
   */
  private async callUidaiVerifyOtp(sessionToken: string, otp: string): Promise<EkycData> {
    // TODO: Build encrypted PID block with OTP and call UIDAI eKYC endpoint
    // Parse the returned KYC XML for <Poi>, <Poa>, <Pht> elements
    throw new InternalServerErrorException(
      'UIDAI production integration not yet wired',
    );
  }

  /** Synthetic eKYC data for development / sandbox testing */
  private generateDevEkycData(aadhaarLast4: string): EkycData {
    return {
      name: `Dev User ${aadhaarLast4}`,
      dob: '01-01-1990',
      gender: 'M',
      address: '123, Dev Nagar, Bengaluru, Karnataka',
      pincode: '560001',
    };
  }
}
