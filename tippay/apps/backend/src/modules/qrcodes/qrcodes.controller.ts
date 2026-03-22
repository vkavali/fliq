import {
  Controller,
  Post,
  Get,
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
import { QrCodesService } from './qrcodes.service';
import { CreateQrCodeDto } from './dto/create-qrcode.dto';

@ApiTags('QR Codes')
@Controller('qrcodes')
export class QrCodesController {
  constructor(private readonly qrCodesService: QrCodesService) {}

  @Post()
  @UseGuards(JwtAuthGuard, RateLimitGuard)
  @RateLimit({ limit: 10, windowSeconds: 3600 }) // 10 per hour
  @ApiBearerAuth()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Generate a new QR code for provider' })
  async createQrCode(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateQrCodeDto,
  ) {
    return this.qrCodesService.createQrCode(userId, dto);
  }

  @Get('my')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get all QR codes for current provider' })
  async getMyQrCodes(@CurrentUser('id') userId: string) {
    return this.qrCodesService.getQrCodesByProvider(userId);
  }

  @Get(':id/resolve')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 60, windowSeconds: 60 }) // 60 per minute
  @ApiOperation({ summary: 'Resolve a QR code to provider info (public, used by scanner)' })
  async resolveQrCode(@Param('id') qrCodeId: string) {
    return this.qrCodesService.resolveQrCode(qrCodeId);
  }
}
