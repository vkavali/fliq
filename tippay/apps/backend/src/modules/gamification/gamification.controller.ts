import {
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { GamificationService } from './gamification.service';

@ApiTags('Gamification')
@Controller('gamification')
export class GamificationController {
  constructor(private readonly gamification: GamificationService) {}

  @Get('badges')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get all badges with earned status for current user' })
  async getBadges(@CurrentUser('id') userId: string) {
    return this.gamification.getUserBadges(userId);
  }

  @Get('streak')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current user streak info' })
  async getStreak(@CurrentUser('id') userId: string) {
    return this.gamification.getUserStreak(userId);
  }

  @Get('leaderboard')
  @ApiOperation({ summary: 'Top tippers leaderboard' })
  @ApiQuery({ name: 'period', required: false, enum: ['week', 'month'] })
  async getTippersLeaderboard(
    @Query('period') period?: string,
  ) {
    const p = period === 'month' ? 'month' : 'week';
    return this.gamification.getLeaderboard(p, 'tippers');
  }

  @Get('leaderboard/providers')
  @ApiOperation({ summary: 'Top providers leaderboard' })
  @ApiQuery({ name: 'period', required: false, enum: ['week', 'month'] })
  async getProvidersLeaderboard(
    @Query('period') period?: string,
  ) {
    const p = period === 'month' ? 'month' : 'week';
    return this.gamification.getLeaderboard(p, 'providers');
  }
}
