import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, IsEmail, MaxLength, IsIn } from 'class-validator';

export class UpdateUserDto {
  @ApiPropertyOptional({ example: 'Priya Sharma' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  name?: string;

  @ApiPropertyOptional({ example: 'priya@email.com' })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional({ example: 'hi', description: 'Language code: en, hi, ta, te, kn, mr' })
  @IsOptional()
  @IsString()
  @IsIn(['en', 'hi', 'ta', 'te', 'kn', 'mr'])
  languagePreference?: string;
}
