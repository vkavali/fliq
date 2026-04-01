import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsEnum, IsOptional, IsInt, Min, Max, IsUUID, MaxLength } from 'class-validator';
import { TipSource, TipIntent } from '@fliq/shared';
import {
  MIN_TIP_AMOUNT_PAISE,
  MAX_TIP_AMOUNT_PAISE,
} from '@fliq/shared';

export class CreateTipDto {
  @ApiProperty({ description: 'Provider user ID' })
  @IsUUID()
  providerId!: string;

  @ApiProperty({ example: 5000, description: 'Tip amount in paise (Rs 50 = 5000)' })
  @IsInt()
  @Min(MIN_TIP_AMOUNT_PAISE)
  @Max(MAX_TIP_AMOUNT_PAISE)
  amountPaise!: number;

  @ApiProperty({ enum: TipSource, example: TipSource.QR_CODE })
  @IsEnum(TipSource)
  source!: TipSource;

  @ApiPropertyOptional({ enum: TipIntent, example: TipIntent.KINDNESS, description: 'Reason for appreciation' })
  @IsOptional()
  @IsEnum(TipIntent)
  intent?: TipIntent;

  @ApiPropertyOptional({ example: 'Great service!' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;

  @ApiPropertyOptional({ example: 5, description: 'Rating 1-5' })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  rating?: number;
}

