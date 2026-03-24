import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsEnum, IsOptional, MaxLength } from 'class-validator';
import { SplitMethod } from '@fliq/shared';

export class UpdateTipPoolDto {
  @ApiPropertyOptional({ example: 'Updated Pool Name' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional({ example: 'Updated description' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiPropertyOptional({ enum: SplitMethod })
  @IsOptional()
  @IsEnum(SplitMethod)
  splitMethod?: SplitMethod;
}
