import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches } from 'class-validator';

export class SendOtpDto {
  @ApiProperty({ example: '+919876543210', description: 'Phone number in E.164 format (+91 India or +1 US)' })
  @IsString()
  @Matches(/^\+(91[6-9]\d{9}|1[2-9]\d{9})$/, { message: 'Phone must be a valid E.164 number with +91 (India) or +1 (US) prefix' })
  phone!: string;
}
