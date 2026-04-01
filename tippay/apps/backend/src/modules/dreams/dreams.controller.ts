import {
  Controller,
  Post,
  Get,
  Put,
  Delete,
  Param,
  Body,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { DreamsService } from './dreams.service';
import { CreateDreamDto } from './dto/create-dream.dto';
import { UpdateDreamDto } from './dto/update-dream.dto';

@ApiTags('Dreams')
@Controller('dreams')
export class DreamsController {
  constructor(private readonly dreamsService: DreamsService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a dream (worker only, max 1 active)' })
  async createDream(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateDreamDto,
  ) {
    return this.dreamsService.createDream(userId, dto);
  }

  @Get('active')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get own active dream with recent contributions' })
  async getActiveDream(@CurrentUser('id') userId: string) {
    return this.dreamsService.getActiveDream(userId);
  }

  @Get('all')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get all own dreams (active + retired)' })
  async getAllDreams(@CurrentUser('id') userId: string) {
    return this.dreamsService.getWorkerDreams(userId);
  }

  @Get('worker/:workerId')
  @ApiOperation({ summary: 'Get active dream for a worker (public, tipper-facing)' })
  async getPublicDream(
    @Param('workerId', new ParseUUIDPipe()) workerId: string,
  ) {
    return this.dreamsService.getPublicDream(workerId);
  }

  @Put(':dreamId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update own dream' })
  async updateDream(
    @CurrentUser('id') userId: string,
    @Param('dreamId', new ParseUUIDPipe()) dreamId: string,
    @Body() dto: UpdateDreamDto,
  ) {
    return this.dreamsService.updateDream(userId, dreamId, dto);
  }

  @Delete(':dreamId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Retire / deactivate a dream' })
  async retireDream(
    @CurrentUser('id') userId: string,
    @Param('dreamId', new ParseUUIDPipe()) dreamId: string,
  ) {
    return this.dreamsService.retireDream(userId, dreamId);
  }
}
