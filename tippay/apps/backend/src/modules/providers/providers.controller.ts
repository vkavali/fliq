import { Controller, Get, Post, Patch, Param, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ProvidersService } from './providers.service';
import { CreateProviderProfileDto } from './dto/create-provider-profile.dto';
import { UpdateProviderProfileDto } from './dto/update-provider-profile.dto';

@ApiTags('Providers')
@Controller('providers')
export class ProvidersController {
  constructor(private readonly providersService: ProvidersService) {}

  @Post('profile')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create provider profile (upgrades user to PROVIDER)' })
  async createProfile(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateProviderProfileDto,
  ) {
    return this.providersService.createProfile(userId, dto);
  }

  @Get('profile')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get own provider profile' })
  async getProfile(@CurrentUser('id') userId: string) {
    return this.providersService.getProfile(userId);
  }

  @Patch('profile')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update provider profile' })
  async updateProfile(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateProviderProfileDto,
  ) {
    return this.providersService.updateProfile(userId, dto);
  }

  @Get(':id/public')
  @ApiOperation({ summary: 'Get public provider info (for tip page)' })
  async getPublicProfile(@Param('id') id: string) {
    return this.providersService.getPublicProfile(id);
  }
}
