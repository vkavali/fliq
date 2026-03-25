import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length } from 'class-validator';

export class VerifyEkycOtpDto {
  @ApiProperty({
    example: 'ekyc_session_abc123',
    description: 'Session token returned by POST /ekyc/initiate',
  })
  @IsString()
  sessionToken!: string;

  @ApiProperty({
    example: '123456',
    description: '6-digit OTP sent to the Aadhaar-linked mobile number',
  })
  @IsString()
  @Length(6, 6, { message: 'OTP must be 6 digits' })
  otp!: string;
}
