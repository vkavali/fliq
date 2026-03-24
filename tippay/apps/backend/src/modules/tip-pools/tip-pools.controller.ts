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
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { TipPoolsService } from './tip-pools.service';
import { CreateTipPoolDto } from './dto/create-tip-pool.dto';
import { UpdateTipPoolDto } from './dto/update-tip-pool.dto';
import { AddMemberDto } from './dto/add-member.dto';

@ApiTags('Tip Pools')
@Controller('tip-pools')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class TipPoolsController {
  constructor(private readonly tipPoolsService: TipPoolsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new tip pool' })
  async createPool(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateTipPoolDto,
  ) {
    return this.tipPoolsService.createPool(userId, dto);
  }

  @Get('my')
  @ApiOperation({ summary: 'Get pools I own and pools I am a member of' })
  async getMyPools(@CurrentUser('id') userId: string) {
    return this.tipPoolsService.getMyPools(userId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get pool details with members' })
  async getPoolById(
    @Param('id') poolId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.tipPoolsService.getPoolById(poolId, userId);
  }

  @Post(':id/members')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Add a member to the pool (owner only)' })
  async addMember(
    @Param('id') poolId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: AddMemberDto,
  ) {
    return this.tipPoolsService.addMember(poolId, userId, dto);
  }

  @Delete(':id/members/:memberId')
  @ApiOperation({ summary: 'Remove a member from the pool (owner only)' })
  async removeMember(
    @Param('id') poolId: string,
    @Param('memberId') memberId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.tipPoolsService.removeMember(poolId, memberId, userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update pool name, description, or split method (owner only)' })
  async updatePool(
    @Param('id') poolId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateTipPoolDto,
  ) {
    return this.tipPoolsService.updatePool(poolId, userId, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Deactivate a pool (owner only)' })
  async deactivatePool(
    @Param('id') poolId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.tipPoolsService.deactivatePool(poolId, userId);
  }

  @Get(':id/earnings')
  @ApiOperation({ summary: 'Get pool earnings summary with per-member breakdown' })
  async getPoolEarnings(
    @Param('id') poolId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.tipPoolsService.getPoolEarnings(poolId, userId);
  }
}
