import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsInt, IsUUID, Min, Max } from 'class-validator';
import { MIN_TIP_AMOUNT_PAISE, MAX_TIP_AMOUNT_PAISE } from '@fliq/shared';

export enum RecurringTipFrequency {
  WEEKLY = 'WEEKLY',
  MONTHLY = 'MONTHLY',
}

export class CreateRecurringTipDto {
  @ApiProperty({ description: 'Provider user ID' })
  @IsUUID()
  providerId!: string;

  @ApiProperty({ example: 10000, description: 'Amount in paise (Rs 100 = 10000)' })
  @IsInt()
  @Min(MIN_TIP_AMOUNT_PAISE)
  @Max(MAX_TIP_AMOUNT_PAISE)
  amountPaise!: number;

  @ApiProperty({ enum: RecurringTipFrequency, example: RecurringTipFrequency.MONTHLY })
  @IsEnum(RecurringTipFrequency)
  frequency!: RecurringTipFrequency;
}
