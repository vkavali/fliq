import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';

@ApiTags('Users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  // ─── Profile ────────────────────────────────────────────────────────────────

  @Get('me')
  @ApiOperation({ summary: 'Get current user profile' })
  async getMe(@CurrentUser('id') userId: string) {
    return this.usersService.findById(userId);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update current user profile' })
  async updateMe(@CurrentUser('id') userId: string, @Body() dto: UpdateUserDto) {
    return this.usersService.updateProfile(userId, dto);
  }

  // ─── DPDP Act: Right to Access / Data Export ──────────────────────────────

  @Get('me/data-export')
  @ApiOperation({
    summary: 'Export all personal data (DPDP Act — Right to Access)',
    description:
      'Returns a structured JSON export of all personal data held by Fliq, ' +
      'including profile, transactions, consents, and badges. ' +
      'Compliant with DPDP Act 2023 Section 11 and GDPR Article 15/20.',
  })
  async exportData(@CurrentUser('id') userId: string) {
    return this.usersService.exportUserData(userId);
  }

  // ─── DPDP Act: Consent Management ─────────────────────────────────────────

  @Get('me/consents')
  @ApiOperation({
    summary: 'View all consent records',
    description: 'Lists all consent purposes, whether granted or withdrawn, with timestamps.',
  })
  async getConsents(@CurrentUser('id') userId: string) {
    return this.usersService.getConsents(userId);
  }

  @Delete('me/consents/:purpose')
  @ApiOperation({
    summary: 'Withdraw consent for a specific purpose (DPDP Act)',
    description:
      'Withdraws consent for a specific data processing purpose. ' +
      'Purposes: account_creation, transaction_processing, push_notifications, communication. ' +
      'Withdrawal of account_creation consent effectively deactivates the account.',
  })
  @ApiParam({
    name: 'purpose',
    enum: ['account_creation', 'transaction_processing', 'push_notifications', 'communication'],
  })
  async withdrawConsent(
    @CurrentUser('id') userId: string,
    @Param('purpose') purpose: string,
  ) {
    return this.usersService.withdrawConsent(userId, purpose);
  }

  // ─── DPDP Act: Grievance Redressal ────────────────────────────────────────

  @Post('me/grievance')
  @ApiOperation({
    summary: 'File a data privacy grievance (DPDP Act)',
    description:
      'File a complaint with the Fliq Grievance Officer. ' +
      'Response guaranteed within 72 hours as required by DPDP Act 2023.',
  })
  async fileGrievance(
    @CurrentUser('id') userId: string,
    @Body() body: { subject: string; description: string },
  ) {
    return this.usersService.fileGrievance(userId, body.subject, body.description);
  }

  // ─── Account Deletion ────────────────────────────────────────────────────

  @Delete('me')
  @ApiOperation({
    summary: 'Delete account and erase personal data (DPDP Act — Right to Erasure)',
    description:
      'Permanently deletes all personal data (name, phone, email, KYC, tokens). ' +
      'Anonymised transaction records are retained for 7 years as required by Indian tax law. ' +
      'Pending payouts must be completed before deletion. ' +
      'Compliant with DPDP Act 2023, Apple App Store, and Google Play Store policies.',
  })
  async deleteMe(@CurrentUser('id') userId: string) {
    return this.usersService.deleteAccount(userId);
  }
}
