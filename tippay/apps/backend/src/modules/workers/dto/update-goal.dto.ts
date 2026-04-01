import { IsString, IsOptional, IsBoolean, IsInt, Min, MaxLength } from 'class-validator';

export class CreateGoalDto {
  @IsString()
  @MaxLength(200)
  title!: string;

  @IsInt()
  @Min(1)
  targetAmountPaise!: number;

  @IsOptional()
  @IsBoolean()
  publicFlag?: boolean;
}
