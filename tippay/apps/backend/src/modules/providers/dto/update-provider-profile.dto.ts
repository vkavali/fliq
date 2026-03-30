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

  @ApiPropertyOptional({ example: '1234567890123456', description: 'Bank account number (stored encrypted)' })
  @IsOptional()
  @IsString()
  @MaxLength(18)
  bankAccountNumber?: string;

  @ApiPropertyOptional({ example: 'SBIN0001234', description: 'IFSC code of the bank branch' })
  @IsOptional()
  @IsString()
  @Matches(/^[A-Z]{4}0[A-Z0-9]{6}$/, { message: 'Invalid IFSC code format' })
  ifscCode?: string;

  @ApiPropertyOptional({ example: 'ABCDE1234F', description: 'PAN number (stored encrypted)' })
  @IsOptional()
  @IsString()
  @Matches(/^[A-Z]{5}[0-9]{4}[A-Z]$/, { message: 'Invalid PAN format' })
  pan?: string;
}
