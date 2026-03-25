import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsIn, MaxLength } from 'class-validator';

export class RegisterFcmTokenDto {
  @ApiProperty({ example: 'fMzX...abc', description: 'Firebase Cloud Messaging device token' })
  @IsString()
  @MaxLength(500)
  token!: string;

  @ApiProperty({ example: 'android', enum: ['android', 'ios'] })
  @IsString()
  @IsIn(['android', 'ios'])
  platform!: string;
}
