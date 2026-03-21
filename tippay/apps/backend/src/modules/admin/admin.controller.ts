import {
  Controller,
  Get,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserType } from '@fliq/shared';
import { AdminService } from './admin.service';

@ApiTags('Admin')
@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserType.ADMIN)
@ApiBearerAuth()
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('stats')
  @ApiOperation({ summary: 'Get platform-wide statistics' })
  async getStats() {
    return this.adminService.getPlatformStats();
  }

  @Get('tips')
  @ApiOperation({ summary: 'List all tips (admin)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'status', required: false, type: String })
  async listTips(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('status') status?: string,
  ) {
    return this.adminService.listTips(page, limit, status);
  }

  @Get('providers')
  @ApiOperation({ summary: 'List all providers (admin)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  async listProviders(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.adminService.listProviders(page, limit);
  }

  @Get('payouts')
  @ApiOperation({ summary: 'List all payouts (admin)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'status', required: false, type: String })
  async listPayouts(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('status') status?: string,
  ) {
    return this.adminService.listPayouts(page, limit, status);
  }

  @Get('wallets')
  @ApiOperation({ summary: 'Get platform wallet balances' })
  async getPlatformWallets() {
    return this.adminService.getPlatformWallets();
  }

  @Post('payouts/batch')
  @ApiOperation({ summary: 'Trigger batch payout processing' })
  async triggerBatchPayouts() {
    return this.adminService.triggerBatchPayouts();
  }
}
