import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsOptional, IsInt, Min, MaxLength, IsBoolean } from 'class-validator';

export class UpdateDreamDto {
  @ApiPropertyOptional({ example: "Daughter's school fees — updated" })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiPropertyOptional({ example: 6000000, description: 'Updated goal amount in paise' })
  @IsOptional()
  @IsInt()
  @Min(100)
  goalAmount?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  mediaUrl?: string;

  @ApiPropertyOptional({ description: 'Deactivate / retire this dream' })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
