import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '@fliq/database';
import { RegisterBusinessDto } from './dto/register-business.dto';
import { InviteMemberDto } from './dto/invite-member.dto';
import { RespondInvitationDto, InvitationResponse } from './dto/respond-invitation.dto';
import { UpdateBusinessDto } from './dto/update-business.dto';
import { UserType, BusinessMemberRole } from '@fliq/shared';

@Injectable()
export class BusinessService {
  constructor(private readonly prisma: PrismaService) {}

  // ─── Registration ──────────────────────────────────────────────────────────

  async registerBusiness(ownerId: string, dto: RegisterBusinessDto) {
    const existing = await this.prisma.business.findFirst({
      where: { ownerId, isActive: true },
    });
    if (existing) {
      throw new ConflictException('You already own an active business');
    }

    const [business] = await this.prisma.$transaction([
      this.prisma.business.create({
        data: {
          name: dto.name,
          type: dto.type as any,
          address: dto.address,
          contactPhone: dto.contactPhone,
          contactEmail: dto.contactEmail,
          gstin: dto.gstin,
          ownerId,
        },
      }),
      this.prisma.user.update({
        where: { id: ownerId },
        data: { type: UserType.BUSINESS_ADMIN as any },
      }),
    ]);

    // Auto-add owner as ADMIN member
    await this.prisma.businessMember.create({
      data: {
        businessId: business.id,
        providerId: ownerId,
        role: BusinessMemberRole.ADMIN as any,
      },
    });

    return business;
  }

  async getMyBusiness(ownerId: string) {
    const business = await this.prisma.business.findFirst({
      where: { ownerId, isActive: true },
      include: {
        members: {
          where: { isActive: true },
          include: {
            provider: {
              select: {
                id: true,
                name: true,
                phone: true,
                email: true,
                providerProfile: {
                  select: {
                    displayName: true,
                    avatarUrl: true,
                    category: true,
                    ratingAverage: true,
                    totalTipsReceived: true,
                  },
                },
              },
            },
          },
        },
        _count: { select: { members: { where: { isActive: true } } } },
      },
    });
    if (!business) throw new NotFoundException('No active business found');
    return business;
  }

  async getBusinessById(businessId: string, requesterId: string) {
    const business = await this.prisma.business.findUnique({
      where: { id: businessId },
    });
    if (!business || !business.isActive) throw new NotFoundException('Business not found');

    const isMember = await this.prisma.businessMember.findFirst({
      where: { businessId, providerId: requesterId, isActive: true },
    });
    if (!isMember && business.ownerId !== requesterId) {
      throw new ForbiddenException('Not a member of this business');
    }
    return business;
  }

  async updateBusiness(businessId: string, ownerId: string, dto: UpdateBusinessDto) {
    await this.assertOwner(businessId, ownerId);
    if (dto.logoUrl && dto.logoUrl.length > 300_000) {
      throw new BadRequestException('Logo too large (max ~200KB)');
    }
    return this.prisma.business.update({
      where: { id: businessId },
      data: { ...dto },
    });
  }

  // ─── Invitations ───────────────────────────────────────────────────────────

  async inviteMember(businessId: string, senderId: string, dto: InviteMemberDto) {
    await this.assertOwnerOrAdmin(businessId, senderId);

    // Find user by phone
    const user = await this.prisma.user.findUnique({ where: { phone: dto.phone } });

    // Check already a member
    if (user) {
      const existingMember = await this.prisma.businessMember.findFirst({
        where: { businessId, providerId: user.id, isActive: true },
      });
      if (existingMember) throw new ConflictException('User is already a member');
    }

    // Expire any old pending invite for this phone in this business
    await this.prisma.businessInvitation.updateMany({
      where: { businessId, phone: dto.phone, status: 'PENDING' },
      data: { status: 'EXPIRED' },
    });

    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    const invitation = await this.prisma.businessInvitation.create({
      data: {
        businessId,
        phone: dto.phone,
        senderId,
        recipientId: user?.id ?? null,
        role: (dto.role ?? BusinessMemberRole.STAFF) as any,
        status: 'PENDING',
        expiresAt,
      },
      include: { business: { select: { name: true } } },
    });

    return invitation;
  }

  async respondToInvitation(invitationId: string, userId: string, dto: RespondInvitationDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    const invitation = await this.prisma.businessInvitation.findFirst({
      where: {
        id: invitationId,
        status: 'PENDING',
        OR: [{ recipientId: userId }, ...(user.phone ? [{ phone: user.phone }] : [])],
      },
      include: { business: { select: { id: true, name: true } } },
    });

    if (!invitation) throw new NotFoundException('Invitation not found or already responded');
    if (invitation.expiresAt < new Date()) {
      await this.prisma.businessInvitation.update({
        where: { id: invitationId },
        data: { status: 'EXPIRED' },
      });
      throw new BadRequestException('Invitation has expired');
    }

    if (dto.response === InvitationResponse.ACCEPT) {
      await this.prisma.$transaction([
        this.prisma.businessInvitation.update({
          where: { id: invitationId },
          data: { status: 'ACCEPTED', recipientId: userId },
        }),
        this.prisma.businessMember.upsert({
          where: { businessId_providerId: { businessId: invitation.businessId, providerId: userId } },
          create: {
            businessId: invitation.businessId,
            providerId: userId,
            role: invitation.role,
            isActive: true,
          },
          update: { isActive: true, role: invitation.role },
        }),
      ]);
      return { message: `Joined business successfully` };
    } else {
      await this.prisma.businessInvitation.update({
        where: { id: invitationId },
        data: { status: 'DECLINED', recipientId: userId },
      });
      return { message: 'Invitation declined' };
    }
  }

  async getMyInvitations(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    return this.prisma.businessInvitation.findMany({
      where: {
        OR: [{ recipientId: userId }, ...(user.phone ? [{ phone: user.phone }] : [])],
        status: 'PENDING',
      },
      include: {
        business: { select: { id: true, name: true, type: true, logoUrl: true } },
        sender: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async removeMember(businessId: string, memberId: string, ownerId: string) {
    await this.assertOwnerOrAdmin(businessId, ownerId);
    const member = await this.prisma.businessMember.findFirst({
      where: { id: memberId, businessId, isActive: true },
    });
    if (!member) throw new NotFoundException('Member not found');
    if (member.providerId === ownerId) throw new BadRequestException('Cannot remove yourself as owner');

    await this.prisma.businessMember.update({
      where: { id: memberId },
      data: { isActive: false },
    });
    return { message: 'Member removed' };
  }

  // ─── Dashboard & Stats ─────────────────────────────────────────────────────

  async getDashboardStats(businessId: string, requesterId: string) {
    await this.assertMember(businessId, requesterId);

    const members = await this.prisma.businessMember.findMany({
      where: { businessId, isActive: true },
      select: { providerId: true },
    });
    const providerIds = members.map((m: any) => m.providerId);

    const [tipAggregates, ratingData, recentTips] = await Promise.all([
      // Total tips and amount for all staff
      this.prisma.tip.aggregate({
        where: {
          providerId: { in: providerIds },
          status: { in: ['PAID', 'SETTLED'] },
        },
        _sum: { amountPaise: true, netAmountPaise: true },
        _count: { id: true },
      }),
      // Average rating
      this.prisma.tip.aggregate({
        where: {
          providerId: { in: providerIds },
          status: { in: ['PAID', 'SETTLED'] },
          rating: { not: null },
        },
        _avg: { rating: true },
        _count: { rating: true },
      }),
      // Tips by day for last 30 days (trend)
      this.prisma.tip.groupBy({
        by: ['createdAt'],
        where: {
          providerId: { in: providerIds },
          status: { in: ['PAID', 'SETTLED'] },
          createdAt: { gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
        },
        _sum: { amountPaise: true },
        _count: { id: true },
        orderBy: { createdAt: 'asc' },
      }),
    ]);

    return {
      totalTipsCount: tipAggregates._count.id,
      totalAmountPaise: tipAggregates._sum.amountPaise ?? 0n,
      totalNetAmountPaise: tipAggregates._sum.netAmountPaise ?? 0n,
      averageRating: ratingData._avg.rating,
      totalRatingsCount: ratingData._count.rating,
      staffCount: providerIds.length,
      recentTipTrend: recentTips,
    };
  }

  async getStaffBreakdown(businessId: string, requesterId: string) {
    await this.assertMember(businessId, requesterId);

    const members = await this.prisma.businessMember.findMany({
      where: { businessId, isActive: true },
      include: {
        provider: {
          select: {
            id: true,
            name: true,
            phone: true,
            email: true,
            providerProfile: {
              select: {
                displayName: true,
                avatarUrl: true,
                category: true,
                ratingAverage: true,
                totalTipsReceived: true,
                qrCodeUrl: true,
              },
            },
          },
        },
      },
    });

    const providerIds = members.map((m: any) => m.providerId);

    const tipsByProvider = await this.prisma.tip.groupBy({
      by: ['providerId'],
      where: {
        providerId: { in: providerIds },
        status: { in: ['PAID', 'SETTLED'] },
      },
      _sum: { amountPaise: true, netAmountPaise: true },
      _count: { id: true },
      _avg: { rating: true },
    });

    const statsMap = new Map(tipsByProvider.map((t: any) => [t.providerId, t]));

    return members.map((m: any) => {
      const stats = statsMap.get(m.providerId);
      return {
        memberId: m.id,
        role: m.role,
        joinedAt: m.joinedAt,
        provider: m.provider,
        tips: {
          count: stats?._count.id ?? 0,
          totalAmountPaise: stats?._sum.amountPaise ?? 0n,
          netAmountPaise: stats?._sum.netAmountPaise ?? 0n,
          averageRating: stats?._avg.rating ?? null,
        },
      };
    });
  }

  async getSatisfactionReport(businessId: string, requesterId: string) {
    await this.assertMember(businessId, requesterId);

    const members = await this.prisma.businessMember.findMany({
      where: { businessId, isActive: true },
      select: { providerId: true },
    });
    const providerIds = members.map((m: any) => m.providerId);

    const tips = await this.prisma.tip.findMany({
      where: {
        providerId: { in: providerIds },
        status: { in: ['PAID', 'SETTLED'] },
        OR: [{ rating: { not: null } }, { message: { not: null } }],
      },
      select: {
        id: true,
        providerId: true,
        rating: true,
        message: true,
        amountPaise: true,
        createdAt: true,
        provider: { select: { name: true, providerProfile: { select: { displayName: true } } } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });

    const ratingDistribution = [1, 2, 3, 4, 5].map((star) => ({
      star,
      count: tips.filter((t: any) => t.rating === star).length,
    }));

    return {
      tips,
      ratingDistribution,
      totalWithRating: tips.filter((t: any) => t.rating !== null).length,
      totalWithMessage: tips.filter((t: any) => t.message).length,
    };
  }

  async exportCsv(businessId: string, requesterId: string): Promise<string> {
    await this.assertMember(businessId, requesterId);

    const members = await this.prisma.businessMember.findMany({
      where: { businessId, isActive: true },
      select: { providerId: true },
    });
    const providerIds = members.map((m: any) => m.providerId);

    const tips = await this.prisma.tip.findMany({
      where: {
        providerId: { in: providerIds },
        status: { in: ['PAID', 'SETTLED'] },
      },
      select: {
        id: true,
        providerId: true,
        amountPaise: true,
        commissionPaise: true,
        netAmountPaise: true,
        rating: true,
        message: true,
        source: true,
        status: true,
        createdAt: true,
        provider: {
          select: {
            name: true,
            phone: true,
            providerProfile: { select: { displayName: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const headers = [
      'TipId',
      'Date',
      'ProviderName',
      'ProviderPhone',
      'AmountINR',
      'CommissionINR',
      'NetAmountINR',
      'Rating',
      'Message',
      'Source',
      'Status',
    ];

    const rows = tips.map((t: any) => [
      t.id,
      t.createdAt.toISOString(),
      t.provider.providerProfile?.displayName ?? t.provider.name ?? '',
      t.provider.phone,
      (Number(t.amountPaise) / 100).toFixed(2),
      (Number(t.commissionPaise) / 100).toFixed(2),
      (Number(t.netAmountPaise) / 100).toFixed(2),
      t.rating ?? '',
      (t.message ?? '').replace(/,/g, ';'),
      t.source,
      t.status,
    ]);

    return [headers.join(','), ...rows.map((r: any) => r.join(','))].join('\n');
  }

  async getBulkQrCodes(businessId: string, requesterId: string) {
    await this.assertMember(businessId, requesterId);

    const members = await this.prisma.businessMember.findMany({
      where: { businessId, isActive: true },
      include: {
        provider: {
          select: {
            id: true,
            name: true,
            providerProfile: {
              select: {
                displayName: true,
                avatarUrl: true,
                qrCodeUrl: true,
                qrCodes: {
                  where: { isActive: true },
                  select: { id: true, qrImageUrl: true, locationLabel: true, upiUrl: true },
                  take: 5,
                },
              },
            },
          },
        },
      },
    });

    return members
      .filter((m: any) => m.provider.providerProfile)
      .map((m: any) => ({
        memberId: m.id,
        providerId: m.providerId,
        displayName: m.provider.providerProfile?.displayName ?? m.provider.name,
        avatarUrl: m.provider.providerProfile?.avatarUrl,
        qrCodes: m.provider.providerProfile?.qrCodes ?? [],
      }));
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  private async assertOwner(businessId: string, userId: string) {
    const business = await this.prisma.business.findUnique({ where: { id: businessId } });
    if (!business || !business.isActive) throw new NotFoundException('Business not found');
    if (business.ownerId !== userId) throw new ForbiddenException('Only the business owner can do this');
    return business;
  }

  private async assertOwnerOrAdmin(businessId: string, userId: string) {
    const business = await this.prisma.business.findUnique({ where: { id: businessId } });
    if (!business || !business.isActive) throw new NotFoundException('Business not found');
    if (business.ownerId === userId) return business;

    const member = await this.prisma.businessMember.findFirst({
      where: { businessId, providerId: userId, isActive: true, role: { in: ['ADMIN', 'MANAGER'] as any } },
    });
    if (!member) throw new ForbiddenException('Insufficient permissions');
    return business;
  }

  private async assertMember(businessId: string, userId: string) {
    const business = await this.prisma.business.findUnique({ where: { id: businessId } });
    if (!business || !business.isActive) throw new NotFoundException('Business not found');
    if (business.ownerId === userId) return business;

    const member = await this.prisma.businessMember.findFirst({
      where: { businessId, providerId: userId, isActive: true },
    });
    if (!member) throw new ForbiddenException('Not a member of this business');
    return business;
  }
}
