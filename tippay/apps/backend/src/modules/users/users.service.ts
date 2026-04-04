import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '@fliq/database';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(private readonly prisma: PrismaService) {}

  async findById(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async updateProfile(userId: string, dto: UpdateUserDto) {
    await this.findById(userId);
    return this.prisma.user.update({
      where: { id: userId },
      data: dto,
    });
  }

  // ─── DPDP Act: Consent Management ──────────────────────────────────────────

  /**
   * Log consent at account creation or when user opts into new features.
   * DPDP Act requires: explicit, free, specific, informed, unambiguous consent
   * with a record of when and how it was given.
   */
  async recordConsent(
    userId: string,
    purpose: string,
    channel: string,
    policyVersion: string = '1.0',
  ) {
    return this.prisma.consentRecord.create({
      data: {
        userId,
        purpose,
        granted: true,
        channel,
        policyVersion,
      },
    });
  }

  /**
   * Log all initial consents at signup.
   * Maps each data collection purpose to a consent record.
   */
  async recordSignupConsents(userId: string, channel: string) {
    const purposes = [
      'account_creation',       // Name, phone/email for authentication
      'transaction_processing', // Tip amounts, provider matching
      'push_notifications',     // FCM token for tip alerts
      'communication',          // OTP via WhatsApp/SMS
    ];

    const records = purposes.map((purpose) => ({
      userId,
      purpose,
      granted: true,
      channel,
      policyVersion: '1.0',
    }));

    return this.prisma.consentRecord.createMany({ data: records });
  }

  /**
   * Withdraw consent for a specific purpose.
   * DPDP Act: withdrawal must be as easy as giving consent.
   */
  async withdrawConsent(userId: string, purpose: string) {
    const record = await this.prisma.consentRecord.findFirst({
      where: { userId, purpose, granted: true, withdrawnAt: null },
      orderBy: { grantedAt: 'desc' },
    });

    if (!record) {
      throw new NotFoundException(`No active consent found for purpose: ${purpose}`);
    }

    await this.prisma.consentRecord.update({
      where: { id: record.id },
      data: { granted: false, withdrawnAt: new Date() },
    });

    // If withdrawing push_notifications, also delete FCM token
    if (purpose === 'push_notifications') {
      await this.prisma.fcmToken.deleteMany({ where: { userId } });
    }

    // If withdrawing communication, turn off WhatsApp opt-in
    if (purpose === 'communication') {
      await this.prisma.user.update({
        where: { id: userId },
        data: { whatsappOptIn: false },
      });
    }

    this.logger.log(`[CONSENT] Withdrawn for user ${userId}, purpose: ${purpose}`);
    return { message: `Consent withdrawn for: ${purpose}`, withdrawnAt: new Date().toISOString() };
  }

  /**
   * Get all consent records for a user.
   */
  async getConsents(userId: string) {
    return this.prisma.consentRecord.findMany({
      where: { userId },
      orderBy: { grantedAt: 'desc' },
    });
  }

  // ─── DPDP Act: Right to Access / Data Export ──────────────────────────────

  /**
   * Export all personal data for a user (DPDP Right to Access + GDPR portability).
   * Returns a structured JSON object with all data categories.
   */
  async exportUserData(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        providerProfile: {
          select: {
            category: true,
            displayName: true,
            bio: true,
            avatarUrl: true,
            ratingAverage: true,
            totalTipsReceived: true,
            payoutPreference: true,
            kycVerified: true,
            kycMethod: true,
            kycCompletedAt: true,
            // Exclude encrypted PAN/bank — user knows their own
          },
        },
        consentRecords: true,
        badges: { include: { badge: true } },
        tipStreak: true,
      },
    });

    if (!user) throw new NotFoundException('User not found');

    // Tips given (as customer)
    const tipsGiven = await this.prisma.tip.findMany({
      where: { customerId: userId },
      select: {
        id: true,
        amountPaise: true,
        status: true,
        intent: true,
        message: true,
        rating: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    // Tips received (as provider)
    const tipsReceived = await this.prisma.tip.findMany({
      where: { providerId: userId },
      select: {
        id: true,
        amountPaise: true,
        status: true,
        intent: true,
        rating: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    // Payouts
    const payouts = await this.prisma.payout.findMany({
      where: { providerId: userId },
      select: {
        id: true,
        amountPaise: true,
        status: true,
        mode: true,
        createdAt: true,
        settledAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    return {
      exportedAt: new Date().toISOString(),
      dataFormat: 'DPDP_ACT_2023_DATA_EXPORT',
      version: '1.0',
      user: {
        id: user.id,
        type: user.type,
        phone: user.phone,
        email: user.email,
        name: user.name,
        languagePreference: user.languagePreference,
        kycStatus: user.kycStatus,
        status: user.status,
        whatsappOptIn: user.whatsappOptIn,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      providerProfile: user.providerProfile || null,
      consents: user.consentRecords,
      badges: user.badges,
      tipStreak: user.tipStreak,
      tipsGiven: {
        count: tipsGiven.length,
        totalPaise: tipsGiven.reduce((sum, t) => sum + Number(t.amountPaise ?? 0), 0),
        records: tipsGiven,
      },
      tipsReceived: {
        count: tipsReceived.length,
        totalPaise: tipsReceived.reduce((sum, t) => sum + Number(t.amountPaise ?? 0), 0),
        records: tipsReceived,
      },
      payouts: {
        count: payouts.length,
        records: payouts,
      },
      dataCategories: {
        identity: 'Name, phone, email',
        profile: 'Display name, bio, avatar, category (providers)',
        preferences: 'Language, WhatsApp opt-in, notification settings',
        transactions: 'Tip amounts, dates, status, messages, ratings',
        kyc: 'PAN verification status, bank verification status (encrypted originals not exported)',
        device: 'FCM push token',
      },
      yourRights: {
        correction: 'PATCH /users/me — update your profile data',
        erasure: 'DELETE /users/me — permanently delete your account',
        consentWithdrawal: 'DELETE /users/me/consents/:purpose — withdraw consent for specific purposes',
        grievance: 'POST /users/me/grievance — file a complaint with our Grievance Officer',
        escalation: 'Data Protection Board of India — https://www.dpbi.gov.in',
      },
    };
  }

  // ─── DPDP Act: Grievance Redressal ────────────────────────────────────────

  /**
   * File a grievance with the platform.
   * DPDP Act requires a grievance mechanism with response within 72 hours.
   */
  async fileGrievance(userId: string, subject: string, description: string) {
    this.logger.warn(`[GRIEVANCE] User ${userId}: ${subject}`);

    // In production, this would create a ticket in a support system
    // For now, log it and acknowledge
    return {
      grievanceId: `GRV-${Date.now()}`,
      filedAt: new Date().toISOString(),
      subject,
      status: 'RECEIVED',
      acknowledgement: 'Your grievance has been received. Our Grievance Officer will respond within 72 hours as required by the DPDP Act, 2023.',
      grievanceOfficer: {
        email: 'grievance@fliq.co.in',
        responseDeadline: new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString(),
      },
      escalation: 'If not satisfied with the resolution, you may escalate to the Data Protection Board of India.',
    };
  }

  // ─── Account Deletion (DPDP + Apple + Google compliant) ───────────────────

  /**
   * DPDP Act compliant account deletion.
   *
   * Deletes all PII (name, phone, email, avatar, bio, KYC data, FCM tokens, OTPs).
   * Retains anonymised transaction records for 7 years (tax/legal requirement).
   * Tips are kept but customer/provider references are nullified where possible,
   * or the user record is anonymised if FK constraints prevent deletion.
   */
  async deleteAccount(userId: string): Promise<{ message: string; deletedAt: string }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { providerProfile: true },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (user.status === 'DEACTIVATED') {
      throw new BadRequestException('Account is already deleted');
    }

    // Block deletion if there are pending payouts
    const pendingPayouts = await this.prisma.payout.count({
      where: { providerId: userId, status: { in: ['PENDING_BATCH', 'INITIATED'] } },
    });
    if (pendingPayouts > 0) {
      throw new BadRequestException(
        `Cannot delete account while ${pendingPayouts} payout(s) are still processing. Please wait for them to complete.`,
      );
    }

    this.logger.warn(`[ACCOUNT DELETION] Starting deletion for user ${userId} (${user.phone || user.email})`);

    // Use a transaction to ensure atomicity
    await this.prisma.$transaction(async (tx) => {
      // 1. Delete FCM token (push notifications)
      await tx.fcmToken.deleteMany({ where: { userId } });

      // 2. Delete OTP codes
      await tx.otpCode.deleteMany({ where: { userId } });

      // 3. Mark all consents as withdrawn (keep records for legal audit trail)
      await tx.consentRecord.updateMany({
        where: { userId, granted: true },
        data: { granted: false, withdrawnAt: new Date() },
      });

      // 4. Delete badges and streaks
      await tx.userBadge.deleteMany({ where: { userId } });
      await tx.tipStreak.deleteMany({ where: { userId } });

      // 5. Delete tip pool memberships
      await tx.tipPoolMember.deleteMany({ where: { userId } });

      // 6. Delete tip jar memberships and contributions
      await tx.tipJarMember.deleteMany({ where: { providerId: userId } });
      await tx.tipJarContribution.deleteMany({ where: { customerId: userId } });

      // 7. Delete business memberships and invitations
      await tx.businessMember.deleteMany({ where: { providerId: userId } });
      await tx.businessInvitation.deleteMany({ where: { senderId: userId } });
      await tx.businessInvitation.updateMany({
        where: { recipientId: userId },
        data: { recipientId: null },
      });

      // 8. Cancel active recurring tips
      await tx.recurringTip.updateMany({
        where: { customerId: userId, status: 'ACTIVE' },
        data: { status: 'CANCELLED' },
      });
      await tx.recurringTip.updateMany({
        where: { providerId: userId, status: 'ACTIVE' },
        data: { status: 'CANCELLED' },
      });

      // 9. Delete worker responses and dreams
      await tx.workerResponse.deleteMany({ where: { workerId: userId } });
      await tx.dream.deleteMany({ where: { workerId: userId } });

      // 10. Delete reputation
      await tx.reputation.deleteMany({ where: { workerId: userId } });

      // 11. If provider: delete QR codes, payment links, and provider profile
      if (user.providerProfile) {
        await tx.qrCode.deleteMany({ where: { providerId: userId } });
        await tx.paymentLink.deleteMany({ where: { providerId: userId } });
        await tx.provider.delete({ where: { id: userId } });
      }

      // 12. Delete owned tip pools that have no other members
      const ownedPools = await tx.tipPool.findMany({
        where: { ownerId: userId },
        include: { _count: { select: { members: true } } },
      });
      for (const pool of ownedPools) {
        if (pool._count.members === 0) {
          await tx.tipPool.delete({ where: { id: pool.id } });
        }
      }

      // 13. Delete owned tip jars that have no other members
      const ownedJars = await tx.tipJar.findMany({
        where: { createdById: userId },
      });
      for (const jar of ownedJars) {
        const memberCount = await tx.tipJarMember.count({ where: { tipJarId: jar.id } });
        if (memberCount === 0) {
          await tx.tipJar.delete({ where: { id: jar.id } });
        }
      }

      // 14. Anonymise tips (keep transaction records, remove PII link)
      // Null out personal messages but keep amounts/dates for tax records
      await tx.tip.updateMany({
        where: { customerId: userId },
        data: { message: null },
      });

      // 15. Anonymise the user record (keep row for FK integrity on tips/payouts)
      await tx.user.update({
        where: { id: userId },
        data: {
          phone: null,
          email: null,
          name: '[Deleted User]',
          status: 'DEACTIVATED',
          whatsappOptIn: false,
          kycStatus: 'PENDING',
        },
      });
    });

    const deletedAt = new Date().toISOString();
    this.logger.warn(`[ACCOUNT DELETION] Completed for user ${userId} at ${deletedAt}`);

    return {
      message: 'Your account has been deleted. Personal data has been erased. Anonymised transaction records are retained for 7 years as required by law.',
      deletedAt,
    };
  }
}
