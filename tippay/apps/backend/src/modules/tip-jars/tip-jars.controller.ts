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
import { RateLimitGuard, RateLimit } from '../../common/guards/rate-limit.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { TipJarsService } from './tip-jars.service';
import { CreateTipJarDto } from './dto/create-tip-jar.dto';
import { AddJarMemberDto } from './dto/add-jar-member.dto';
import { TipJarTipDto } from './dto/tip-jar-tip.dto';

@ApiTags('Tip Jars')
@Controller('tip-jars')
export class TipJarsController {
  constructor(private readonly tipJarsService: TipJarsService) {}

  // ── Authenticated endpoints ──────────────────────────────────────────────

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new tip jar' })
  async createJar(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateTipJarDto,
  ) {
    return this.tipJarsService.createJar(userId, dto);
  }

  @Get('my')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get tip jars I created and jars I am a member of' })
  async getMyJars(@CurrentUser('id') userId: string) {
    return this.tipJarsService.getMyJars(userId);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get tip jar details with contributions (members only)' })
  async getJarById(
    @Param('id') jarId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.tipJarsService.getJarById(jarId, userId);
  }

  @Post(':id/members')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Add a member to the tip jar (creator only)' })
  async addMember(
    @Param('id') jarId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: AddJarMemberDto,
  ) {
    return this.tipJarsService.addMember(jarId, userId, dto);
  }

  @Delete(':id/members/:memberId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Remove a member from the tip jar (creator only)' })
  async removeMember(
    @Param('id') jarId: string,
    @Param('memberId') memberId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.tipJarsService.removeMember(jarId, memberId, userId);
  }

  @Patch(':id/splits')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update split percentages for all members (creator only)' })
  async updateSplits(
    @Param('id') jarId: string,
    @CurrentUser('id') userId: string,
    @Body() body: { splits: Array<{ memberId: string; splitPercentage: number; roleLabel?: string }> },
  ) {
    return this.tipJarsService.updateSplits(jarId, userId, body.splits);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Close/deactivate a tip jar (creator only)' })
  async closeJar(
    @Param('id') jarId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.tipJarsService.closeJar(jarId, userId);
  }

  @Get(':id/stats')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get jar stats: total raised, per-member earnings' })
  async getJarStats(
    @Param('id') jarId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.tipJarsService.getJarStats(jarId, userId);
  }

  // ── Public endpoints (for customers tipping) ─────────────────────────────

  @Get('resolve/:shortCode')
  @ApiOperation({ summary: 'Resolve a tip jar by short code (public)' })
  async resolveJar(@Param('shortCode') shortCode: string) {
    return this.tipJarsService.resolveJar(shortCode);
  }

  @Post(':shortCode/tip')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 20, windowSeconds: 60 })
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a tip to a jar — anonymous' })
  async tipJar(
    @Param('shortCode') shortCode: string,
    @Body() dto: TipJarTipDto,
  ) {
    return this.tipJarsService.createJarTip(shortCode, dto);
  }

  @Post(':shortCode/tip/authenticated')
  @UseGuards(JwtAuthGuard, RateLimitGuard)
  @RateLimit({ limit: 20, windowSeconds: 60 })
  @ApiBearerAuth()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a tip to a jar — authenticated customer' })
  async tipJarAuthenticated(
    @Param('shortCode') shortCode: string,
    @Body() dto: TipJarTipDto,
    @CurrentUser('id') customerId: string,
  ) {
    return this.tipJarsService.createJarTip(shortCode, dto, customerId);
  }
}
