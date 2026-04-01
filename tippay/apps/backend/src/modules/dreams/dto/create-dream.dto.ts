import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsEnum, IsOptional, IsInt, Min, MaxLength } from 'class-validator';

export enum DreamCategoryDto {
  EDUCATION = 'EDUCATION',
  HEALTH = 'HEALTH',
  FAMILY = 'FAMILY',
  SKILL = 'SKILL',
  EMERGENCY = 'EMERGENCY',
  TRAVEL = 'TRAVEL',
  OTHER = 'OTHER',
}

export class CreateDreamDto {
  @ApiProperty({ example: "Daughter's school fees" })
  @IsString()
  @MaxLength(200)
  title!: string;

  @ApiProperty({ example: "Saving for Priya's class 10 tuition at Kendriya Vidyalaya" })
  @IsString()
  @MaxLength(500)
  description!: string;

  @ApiProperty({ enum: DreamCategoryDto, example: DreamCategoryDto.EDUCATION })
  @IsEnum(DreamCategoryDto)
  category!: DreamCategoryDto;

  @ApiProperty({ example: 5000000, description: 'Goal amount in paise (Rs 50,000 = 5000000)' })
  @IsInt()
  @Min(100)  // at least 1 rupee
  goalAmount!: number;

  @ApiPropertyOptional({ description: 'URL to dream media (image or short clip)' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  mediaUrl?: string;
}
