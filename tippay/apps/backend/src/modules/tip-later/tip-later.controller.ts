import {
  Controller,
  Post,
  Get,
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
import { TipLaterService } from './tip-later.service';
import { CreateDeferredTipDto } from './dto/create-deferred-tip.dto';

@ApiTags('Tip Later')
@Controller('tip-later')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class TipLaterController {
  constructor(private readonly tipLaterService: TipLaterService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Promise a tip — creates a deferred tip due in 24h' })
  async createDeferredTip(
    @CurrentUser('id') customerId: string,
    @Body() dto: CreateDeferredTipDto,
  ) {
    return this.tipLaterService.createDeferredTip(customerId, dto);
  }

  @Get('my')
  @ApiOperation({ summary: 'List my promised tips (as customer)' })
  async getMyDeferredTips(@CurrentUser('id') customerId: string) {
    return this.tipLaterService.getMyDeferredTips(customerId);
  }

  @Get('provider')
  @ApiOperation({ summary: 'List promised tips for me (as provider)' })
  async getProviderPromises(@CurrentUser('id') providerId: string) {
    return this.tipLaterService.getProviderPromises(providerId);
  }

  @Post(':id/pay')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Pay a deferred tip — creates a real tip + Razorpay order' })
  async payDeferredTip(
    @Param('id') deferredTipId: string,
    @CurrentUser('id') customerId: string,
  ) {
    return this.tipLaterService.payDeferredTip(deferredTipId, customerId);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Cancel a deferred tip promise' })
  async cancelDeferredTip(
    @Param('id') deferredTipId: string,
    @CurrentUser('id') customerId: string,
  ) {
    return this.tipLaterService.cancelDeferredTip(deferredTipId, customerId);
  }
}
