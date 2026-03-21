import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, IsEnum, Matches } from 'class-validator';
import { ProviderCategory, PayoutPreference } from '@tippay/shared';

export class UpdateProviderProfileDto {
  @ApiPropertyOptional({ enum: ProviderCategory })
  @IsOptional()
  @IsEnum(ProviderCategory)
  category?: ProviderCategory;

  @ApiPropertyOptional({ example: 'amit.kumar@okicici' })
  @IsOptional()
  @IsString()
  @Matches(/^[\w.\-]+@[\w]+$/, { message: 'Invalid UPI VPA format' })
  upiVpa?: string;

  @ApiPropertyOptional({ enum: PayoutPreference })
  @IsOptional()
  @IsEnum(PayoutPreference)
  payoutPreference?: PayoutPreference;
}
