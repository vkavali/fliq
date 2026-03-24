import { Controller, Get, Post, Patch, Param, Body, Query, UseGuards, UseInterceptors, UploadedFile, ParseUUIDPipe } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery, ApiConsumes } from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
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

  @Post('profile/avatar')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Upload provider avatar image' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('avatar', { limits: { fileSize: 500_000 } }))
  async uploadAvatar(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.providersService.updateAvatar(userId, file);
  }

  @Get('search')
  @ApiOperation({ summary: 'Search providers by name or phone' })
  @ApiQuery({ name: 'q', required: true, type: String })
  @ApiQuery({ name: 'category', required: false, type: String })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  async searchProviders(
    @Query('q') query: string,
    @Query('category') category?: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.providersService.searchProviders(
      query,
      category,
      page ? Number(page) : 1,
      limit ? Number(limit) : 20,
    );
  }

  @Get(':id/public')
  @ApiOperation({ summary: 'Get public provider info (for tip page)' })
  async getPublicProfile(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.providersService.getPublicProfile(id);
  }
}
