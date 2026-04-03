import {
  Controller,
  Post,
  Get,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
  Res,
} from '@nestjs/common';
import { Response } from 'express';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { BusinessService } from './business.service';
import { RegisterBusinessDto } from './dto/register-business.dto';
import { InviteMemberDto } from './dto/invite-member.dto';
import { RespondInvitationDto } from './dto/respond-invitation.dto';
import { UpdateBusinessDto } from './dto/update-business.dto';

@ApiTags('Business')
@Controller('business')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class BusinessController {
  constructor(private readonly businessService: BusinessService) {}

  // ─── Business CRUD ─────────────────────────────────────────────────────────

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Register a new business (upgrades user to BUSINESS_ADMIN)' })
  async registerBusiness(
    @CurrentUser('id') userId: string,
    @Body() dto: RegisterBusinessDto,
  ) {
    return this.businessService.registerBusiness(userId, dto);
  }

  @Get('mine')
  @ApiOperation({ summary: 'Get the business I own' })
  async getMyBusiness(@CurrentUser('id') userId: string) {
    return this.businessService.getMyBusiness(userId);
  }

  @Get('memberships/mine')
  @ApiOperation({ summary: 'Get the active business memberships for the current user' })
  async getMyMemberships(@CurrentUser('id') userId: string) {
    return this.businessService.getMyMemberships(userId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get business details (members only)' })
  async getBusiness(
    @Param('id') businessId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.businessService.getBusinessById(businessId, userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update business details (owner only)' })
  async updateBusiness(
    @Param('id') businessId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateBusinessDto,
  ) {
    return this.businessService.updateBusiness(businessId, userId, dto);
  }

  // ─── Staff / Invitations ───────────────────────────────────────────────────

  @Post(':id/invite')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Invite a provider by phone number (owner/admin only)' })
  async inviteMember(
    @Param('id') businessId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: InviteMemberDto,
  ) {
    return this.businessService.inviteMember(businessId, userId, dto);
  }

  @Delete(':id/members/:memberId')
  @ApiOperation({ summary: 'Remove a staff member (owner/admin only)' })
  async removeMember(
    @Param('id') businessId: string,
    @Param('memberId') memberId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.businessService.removeMember(businessId, memberId, userId);
  }

  @Get('invitations/mine')
  @ApiOperation({ summary: 'Get pending invitations for the current user' })
  async getMyInvitations(@CurrentUser('id') userId: string) {
    return this.businessService.getMyInvitations(userId);
  }

  @Post('invitations/:id/respond')
  @ApiOperation({ summary: 'Accept or decline a business invitation' })
  async respondToInvitation(
    @Param('id') invitationId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: RespondInvitationDto,
  ) {
    return this.businessService.respondToInvitation(invitationId, userId, dto);
  }

  // ─── Dashboard ─────────────────────────────────────────────────────────────

  @Get(':id/dashboard')
  @ApiOperation({ summary: 'Business dashboard: total tips, staff count, rating, 30-day trend' })
  async getDashboard(
    @Param('id') businessId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.businessService.getDashboardStats(businessId, userId);
  }

  @Get(':id/staff')
  @ApiOperation({ summary: 'Per-staff tip breakdown with earnings and ratings' })
  async getStaffBreakdown(
    @Param('id') businessId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.businessService.getStaffBreakdown(businessId, userId);
  }

  @Get(':id/satisfaction')
  @ApiOperation({ summary: 'Customer satisfaction report: ratings + messages' })
  async getSatisfactionReport(
    @Param('id') businessId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.businessService.getSatisfactionReport(businessId, userId);
  }

  @Get(':id/qrcodes')
  @ApiOperation({ summary: 'Bulk QR codes for all active staff members' })
  async getBulkQrCodes(
    @Param('id') businessId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.businessService.getBulkQrCodes(businessId, userId);
  }

  @Get(':id/export')
  @ApiOperation({ summary: 'Export all tips as CSV' })
  async exportCsv(
    @Param('id') businessId: string,
    @CurrentUser('id') userId: string,
    @Res() res: Response,
  ) {
    const csv = await this.businessService.exportCsv(businessId, userId);
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="fliq-business-tips.csv"`);
    res.send(csv);
  }
}
