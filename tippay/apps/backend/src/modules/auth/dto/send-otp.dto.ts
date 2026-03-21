import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches } from 'class-validator';

export class SendOtpDto {
  @ApiProperty({ example: '+919876543210', description: 'Indian phone number with +91 prefix' })
  @IsString()
  @Matches(/^\+91[6-9]\d{9}$/, { message: 'Phone must be a valid Indian mobile number with +91 prefix' })
  phone!: string;
}
