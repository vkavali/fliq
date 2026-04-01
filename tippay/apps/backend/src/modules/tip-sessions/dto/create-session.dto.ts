import { IsString, IsOptional, IsBoolean, IsArray, IsEnum } from 'class-validator';

export enum TipModeEnum {
  SOLO = 'SOLO',
  POOL = 'POOL',
  JAR = 'JAR',
}

export class CreateSessionDto {
  @IsString()
  workerId!: string;

  @IsOptional()
  @IsEnum(TipModeEnum)
  mode?: TipModeEnum;

  @IsOptional()
  @IsString()
  occasion?: string;

  @IsOptional()
  @IsArray()
  presetSet?: number[];

  @IsOptional()
  @IsBoolean()
  anonymityRequested?: boolean;
}
