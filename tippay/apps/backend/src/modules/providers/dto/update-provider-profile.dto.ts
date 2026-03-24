import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, IsEnum, Matches, MaxLength } from 'class-validator';
import { ProviderCategory, PayoutPreference } from '@fliq/shared';

export class UpdateProviderProfileDto {
  @ApiPropertyOptional({ example: 'Amit Kumar', description: 'Your display name' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  displayName?: string;

  @ApiPropertyOptional({ example: 'Love making great coffee!', description: 'Short bio about yourself' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

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
