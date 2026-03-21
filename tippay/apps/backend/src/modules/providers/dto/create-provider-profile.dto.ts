import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsEnum, IsOptional, Matches } from 'class-validator';
import { ProviderCategory } from '@fliq/shared';

export class CreateProviderProfileDto {
  @ApiProperty({ enum: ProviderCategory, example: ProviderCategory.RESTAURANT })
  @IsEnum(ProviderCategory)
  category!: ProviderCategory;

  @ApiPropertyOptional({ example: 'amit.kumar@okicici', description: 'UPI VPA for receiving payouts' })
  @IsOptional()
  @IsString()
  @Matches(/^[\w.\-]+@[\w]+$/, { message: 'Invalid UPI VPA format' })
  upiVpa?: string;
}
