import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, IsInt, IsBoolean, Min, Max, MaxLength } from 'class-validator';

export class CreatePaymentLinkDto {
  @ApiPropertyOptional({ example: 'Waiter', description: 'Your role (e.g. Waiter, Driver, Barber)' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  role?: string;

  @ApiPropertyOptional({ example: 'Cafe Mocha', description: 'Workplace name' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  workplace?: string;

  @ApiPropertyOptional({ example: 'Tips for great service', description: 'Description shown on the tip page' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  description?: string;

  @ApiPropertyOptional({ example: 5000, description: 'Suggested amount in paise (Rs 50 = 5000)' })
  @IsOptional()
  @IsInt()
  @Min(1000)
  @Max(1000000)
  suggestedAmountPaise?: number;

  @ApiPropertyOptional({ example: true, description: 'Allow customer to enter custom amount (default true)' })
  @IsOptional()
  @IsBoolean()
  allowCustomAmount?: boolean;
}
