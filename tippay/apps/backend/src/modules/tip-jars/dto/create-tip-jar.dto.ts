import {
  IsString,
  IsOptional,
  IsEnum,
  IsInt,
  Min,
  MaxLength,
  IsISO8601,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum TipJarEventType {
  WEDDING = 'WEDDING',
  RESTAURANT = 'RESTAURANT',
  SALON = 'SALON',
  EVENT = 'EVENT',
  CUSTOM = 'CUSTOM',
}

export class CreateTipJarDto {
  @ApiProperty({ example: "Rohan & Priya's Wedding" })
  @IsString()
  @MaxLength(100)
  name!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiProperty({ enum: TipJarEventType })
  @IsEnum(TipJarEventType)
  eventType!: TipJarEventType;

  @ApiProperty({ required: false, description: 'ISO8601 expiry datetime' })
  @IsOptional()
  @IsISO8601()
  expiresAt?: string;

  @ApiProperty({ required: false, description: 'Target amount in paise' })
  @IsOptional()
  @IsInt()
  @Min(100)
  targetAmountPaise?: number;
}
