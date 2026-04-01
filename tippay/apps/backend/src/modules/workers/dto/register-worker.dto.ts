import { IsString, IsOptional, IsUUID, MinLength, MaxLength } from 'class-validator';

export class RegisterWorkerDto {
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  publicName!: string;

  @IsOptional()
  @IsUUID()
  businessId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  region?: string;

  @IsOptional()
  @IsString()
  soundPack?: string;
}
