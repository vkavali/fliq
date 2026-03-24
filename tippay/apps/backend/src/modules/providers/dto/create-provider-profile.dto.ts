import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsEnum, IsOptional, Matches, MaxLength } from 'class-validator';
import { ProviderCategory } from '@fliq/shared';

export class CreateProviderProfileDto {
  @ApiProperty({ example: 'Amit Kumar', description: 'Your display name' })
  @IsString()
  @MaxLength(100)
  displayName!: string;

  @ApiProperty({ enum: ProviderCategory, example: ProviderCategory.RESTAURANT })
  @IsEnum(ProviderCategory)
  category!: ProviderCategory;

  @ApiPropertyOptional({ example: 'Love making great coffee!', description: 'Short bio about yourself' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

  @ApiPropertyOptional({ example: 'amit.kumar@okicici', description: 'UPI VPA for receiving payouts' })
  @IsOptional()
  @IsString()
  @Matches(/^[\w.\-]+@[\w]+$/, { message: 'Invalid UPI VPA format' })
  upiVpa?: string;
}
