import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, Min } from 'class-validator';
import { PayoutMode, MIN_PAYOUT_AMOUNT_PAISE } from '@tippay/shared';

export class RequestPayoutDto {
  @ApiProperty({ example: 50000, description: 'Payout amount in paise (Rs 500 = 50000)' })
  @IsInt()
  @Min(MIN_PAYOUT_AMOUNT_PAISE)
  amountPaise!: number;

  @ApiPropertyOptional({ enum: PayoutMode, example: PayoutMode.IMPS })
  @IsOptional()
  @IsEnum(PayoutMode)
  mode?: PayoutMode;
}
