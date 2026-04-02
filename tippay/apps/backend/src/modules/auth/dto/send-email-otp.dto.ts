import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty } from 'class-validator';

export class SendEmailOtpDto {
  @ApiProperty({ example: 'business@example.com', description: 'Email address of the business user' })
  @IsEmail()
  @IsNotEmpty()
  email!: string;
}
