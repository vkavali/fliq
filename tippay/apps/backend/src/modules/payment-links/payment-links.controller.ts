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
import { RateLimitGuard, RateLimit } from '../../common/guards/rate-limit.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaymentLinksService } from './payment-links.service';
import { CreatePaymentLinkDto } from './dto/create-payment-link.dto';

@ApiTags('Payment Links')
@Controller('payment-links')
export class PaymentLinksController {
  constructor(private readonly paymentLinksService: PaymentLinksService) {}

  @Post()
  @UseGuards(JwtAuthGuard, RateLimitGuard)
  @RateLimit({ limit: 20, windowSeconds: 3600 }) // 20 per hour
  @ApiBearerAuth()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a shareable payment/tip link' })
  async createPaymentLink(
    @CurrentUser('id') userId: string,
    @Body() dto: CreatePaymentLinkDto,
  ) {
    return this.paymentLinksService.createPaymentLink(userId, dto);
  }

  @Get('my')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List my payment links' })
  async getMyPaymentLinks(@CurrentUser('id') userId: string) {
    return this.paymentLinksService.getMyPaymentLinks(userId);
  }

  @Get(':id/resolve')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 60, windowSeconds: 60 }) // 60 per minute
  @ApiOperation({ summary: 'Resolve a payment link to provider info (public)' })
  async resolvePaymentLink(@Param('id') id: string) {
    return this.paymentLinksService.resolvePaymentLink(id);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Deactivate a payment link' })
  async deletePaymentLink(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
  ) {
    return this.paymentLinksService.deletePaymentLink(userId, id);
  }
}
