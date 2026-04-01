import { IsString, IsInt, IsOptional, IsEnum, Min } from 'class-validator';

export enum IntentEnum {
  GRATITUDE = 'GRATITUDE',
  EXCEPTIONAL_SERVICE = 'EXCEPTIONAL_SERVICE',
  BIRTHDAY = 'BIRTHDAY',
  FAREWELL = 'FAREWELL',
  CELEBRATION = 'CELEBRATION',
  OTHER = 'OTHER',
}

export class SettleTipDto {
  @IsString()
  sessionId!: string;

  @IsInt()
  @Min(1)
  grossAmountPaise!: number;

  @IsOptional()
  @IsEnum(IntentEnum)
  intent?: IntentEnum;

  @IsString()
  gatewayRef!: string;
}
