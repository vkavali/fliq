import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsEnum, IsOptional, MaxLength } from 'class-validator';
import { SplitMethod } from '@fliq/shared';

export class CreateTipPoolDto {
  @ApiProperty({ example: 'Weekend Shift Pool', description: 'Pool name' })
  @IsString()
  @MaxLength(100)
  name!: string;

  @ApiPropertyOptional({ example: 'Tips split among weekend staff' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiProperty({ enum: SplitMethod, example: SplitMethod.EQUAL, default: SplitMethod.EQUAL })
  @IsEnum(SplitMethod)
  splitMethod!: SplitMethod;
}
