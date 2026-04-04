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
      include: {
        providerProfile: true,
        payouts: { where: { status: 'PROCESSING' } },
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (user.status === 'DEACTIVATED') {
      throw new BadRequestException('Account is already deleted');
    }

    // Block deletion if there are pending payouts
    if (user.payouts && user.payouts.length > 0) {
      throw new BadRequestException(
        `Cannot delete account while ${user.payouts.length} payout(s) are still processing. Please wait for them to complete.`,
      );
    }

    this.logger.warn(`[ACCOUNT DELETION] Starting deletion for user ${userId} (${user.phone || user.email})`);

    // Use a transaction to ensure atomicity
    await this.prisma.$transaction(async (tx) => {
      // 1. Delete FCM token (push notifications)
      await tx.fcmToken.deleteMany({ where: { userId } });

      // 2. Delete OTP codes
      await tx.otpCode.deleteMany({ where: { userId } });

      // 3. Delete consent records
      await tx.consentRecord.deleteMany({ where: { userId } });

      // 4. Delete badges and streaks
      await tx.userBadge.deleteMany({ where: { userId } });
      await tx.tipStreak.deleteMany({ where: { userId } });

      // 5. Delete tip pool memberships (not the pools themselves if others are in them)
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
      await tx.reputation.deleteMany({ where: { userId } });

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
        where: { ownerId: userId },
        include: { _count: { select: { members: true } } },
      });
      for (const jar of ownedJars) {
        if (jar._count.members === 0) {
          await tx.tipJar.delete({ where: { id: jar.id } });
        }
      }

      // 14. Anonymise tips (keep transaction records, remove PII link)
      // We null out customer names on tips but keep amounts/dates for tax records
      await tx.tip.updateMany({
        where: { customerId: userId },
        data: { customerName: null, customerMessage: null },
      });

      // 15. Anonymise the user record (keep the row for FK integrity on tips/payouts)
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
