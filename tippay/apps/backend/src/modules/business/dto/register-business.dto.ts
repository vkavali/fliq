import { IsString, IsEnum, IsOptional, MaxLength, Matches } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { BusinessType } from '@fliq/shared';

export class RegisterBusinessDto {
  @ApiProperty({ example: 'The Grand Hotel' })
  @IsString()
  @MaxLength(200)
  name!: string;

  @ApiProperty({ enum: BusinessType, example: BusinessType.HOTEL })
  @IsEnum(BusinessType)
  type!: BusinessType;

  @ApiPropertyOptional({ example: '12 MG Road, Bengaluru, Karnataka 560001' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  address?: string;

  @ApiPropertyOptional({ example: '+919876543210' })
  @IsOptional()
  @IsString()
  @MaxLength(15)
  contactPhone?: string;

  @ApiPropertyOptional({ example: 'manager@grandhotel.com' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  contactEmail?: string;

  @ApiPropertyOptional({ example: '29AABCU9603R1ZM' })
  @IsOptional()
  @IsString()
  @MaxLength(15)
  @Matches(/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/, {
    message: 'Invalid GSTIN format',
  })
  gstin?: string;
}
