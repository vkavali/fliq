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
import { RateLimitGuard, RateLimit } from '../../common/guards/rate-limit.guard';
import { RecurringTipsService } from './recurring-tips.service';
import { CreateRecurringTipDto } from './dto/create-recurring-tip.dto';

@ApiTags('Recurring Tips')
@Controller('recurring-tips')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class RecurringTipsController {
  constructor(private readonly recurringTipsService: RecurringTipsService) {}

  @Post()
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 10, windowSeconds: 60 })
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Set up a recurring tip (UPI Autopay mandate)' })
  async create(
    @CurrentUser('id') customerId: string,
    @Body() dto: CreateRecurringTipDto,
  ) {
    return this.recurringTipsService.createRecurringTip(dto, customerId);
  }

  @Get()
  @ApiOperation({ summary: 'List my recurring tips (as customer)' })
  async listMine(@CurrentUser('id') customerId: string) {
    return this.recurringTipsService.getRecurringTipsByCustomer(customerId);
  }

  @Get('provider')
  @ApiOperation({ summary: 'List active recurring tips received (as provider)' })
  async listForProvider(@CurrentUser('id') providerId: string) {
    return this.recurringTipsService.getRecurringTipsByProvider(providerId);
  }

  @Patch(':id/pause')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Pause a recurring tip' })
  async pause(
    @Param('id') id: string,
    @CurrentUser('id') customerId: string,
  ) {
    return this.recurringTipsService.pauseRecurringTip(id, customerId);
  }

  @Patch(':id/resume')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Resume a paused recurring tip' })
  async resume(
    @Param('id') id: string,
    @CurrentUser('id') customerId: string,
  ) {
    return this.recurringTipsService.resumeRecurringTip(id, customerId);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Cancel a recurring tip' })
  async cancel(
    @Param('id') id: string,
    @CurrentUser('id') customerId: string,
  ) {
    return this.recurringTipsService.cancelRecurringTip(id, customerId);
  }
}
