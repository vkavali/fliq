import { Controller, Post, Get, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RateLimit } from '../../common/guards/rate-limit.guard';
import { EkycService } from './ekyc.service';
import { InitiateEkycDto } from './dto/initiate-ekyc.dto';
import { VerifyEkycOtpDto } from './dto/verify-ekyc-otp.dto';

@ApiTags('eKYC')
@Controller('ekyc')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class EkycController {
  constructor(private readonly ekycService: EkycService) {}

  @Post('initiate')
  @RateLimit({ limit: 5, windowSeconds: 300 }) // 5 attempts per 5 minutes per IP
  @ApiOperation({
    summary: 'Initiate Aadhaar eKYC — triggers OTP to Aadhaar-linked mobile',
  })
  initiateEkyc(
    @CurrentUser('id') userId: string,
    @Body() dto: InitiateEkycDto,
  ) {
    return this.ekycService.initiateEkyc(userId, dto);
  }

  @Post('verify-otp')
  @RateLimit({ limit: 5, windowSeconds: 300 })
  @ApiOperation({
    summary: 'Verify Aadhaar OTP — completes eKYC and pre-fills provider profile',
  })
  verifyEkycOtp(
    @CurrentUser('id') userId: string,
    @Body() dto: VerifyEkycOtpDto,
  ) {
    return this.ekycService.verifyEkycOtp(userId, dto);
  }

  @Get('status')
  @ApiOperation({ summary: 'Get current KYC verification status for provider' })
  getKycStatus(@CurrentUser('id') userId: string) {
    return this.ekycService.getKycStatus(userId);
  }
}
