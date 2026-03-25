import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches, Length } from 'class-validator';

export class InitiateEkycDto {
  /**
   * 12-digit Aadhaar number or 16-digit Virtual ID.
   * We accept either; UIDAI recommends VID for privacy.
   */
  @ApiProperty({
    example: '9876 5432 1098',
    description: '12-digit Aadhaar number or 16-digit Virtual ID (spaces stripped server-side)',
  })
  @IsString()
  @Matches(/^(\d{12}|\d{16})$/, {
    message: 'Must be a 12-digit Aadhaar number or 16-digit Virtual ID (no spaces)',
  })
  aadhaarOrVid!: string;
}
