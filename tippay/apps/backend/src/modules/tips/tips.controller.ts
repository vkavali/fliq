import {
  Controller,
  Post,
  Get,
  Param,
  Body,
  Query,
  UseGuards,
  UseInterceptors,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery, ApiHeader } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RateLimitGuard, RateLimit } from '../../common/guards/rate-limit.guard';
import { IdempotencyInterceptor } from '../../common/interceptors/idempotency.interceptor';
import { TipsService } from './tips.service';
import { CreateTipDto } from './dto/create-tip.dto';
import { VerifyPaymentDto } from './dto/verify-payment.dto';

@ApiTags('Tips')
@Controller('tips')
export class TipsController {
  constructor(private readonly tipsService: TipsService) {}

  @Post()
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 20, windowSeconds: 60 }) // 20 per minute per IP
  @UseInterceptors(IdempotencyInterceptor)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a tip and get Razorpay order' })
  @ApiHeader({ name: 'idempotency-key', required: false })
  async createTip(@Body() dto: CreateTipDto) {
    // Tips can be created without auth (QR code flow)
    return this.tipsService.createTip(dto);
  }

  @Post('authenticated')
  @UseGuards(JwtAuthGuard, RateLimitGuard)
  @RateLimit({ limit: 20, windowSeconds: 60 })
  @UseInterceptors(IdempotencyInterceptor)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a tip (authenticated, links to customer)' })
  @ApiHeader({ name: 'idempotency-key', required: false })
  async createTipAuthenticated(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateTipDto,
  ) {
    return this.tipsService.createTip(dto, userId);
  }

  @Post(':tipId/verify')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 10, windowSeconds: 60 })
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify payment after Razorpay checkout' })
  async verifyPayment(
    @Param('tipId') tipId: string,
    @Body() dto: VerifyPaymentDto,
  ) {
    return this.tipsService.verifyPayment(tipId, dto);
  }

  @Get('provider')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get tips received by current provider' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  async getProviderTips(
    @CurrentUser('id') userId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.tipsService.getTipsByProvider(userId, page, limit);
  }

  @Get('customer')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get tips given by current customer' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  async getCustomerTips(
    @CurrentUser('id') userId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.tipsService.getTipsByCustomer(userId, page, limit);
  }

  @Get(':tipId/impact')
  @ApiOperation({ summary: 'Get the impact of a tip — dream progress + emotional message' })
  async getTipImpact(@Param('tipId') tipId: string) {
    return this.tipsService.getTipImpact(tipId);
  }

  @Get(':tipId/status')
  @ApiOperation({ summary: 'Poll tip payment status (for UPI handoff waiting)' })
  async getTipStatus(@Param('tipId') tipId: string) {
    return this.tipsService.getTipStatus(tipId);
  }
}
