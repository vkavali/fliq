import { IsUUID, IsInt, Min, Max, IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateDeferredTipDto {
  @ApiProperty({ description: 'Provider user UUID' })
  @IsUUID()
  providerId!: string;

  @ApiProperty({ description: 'Promised amount in paise', minimum: 100 })
  @IsInt()
  @Min(100)
  @Max(10000000)
  amountPaise!: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;

  @ApiProperty({ required: false, minimum: 1, maximum: 5 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  rating?: number;
}
