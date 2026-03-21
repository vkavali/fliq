import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { QrCodeType } from '@tippay/shared';

export class CreateQrCodeDto {
  @ApiPropertyOptional({ enum: QrCodeType, default: QrCodeType.STATIC })
  @IsOptional()
  @IsEnum(QrCodeType)
  type?: QrCodeType;

  @ApiPropertyOptional({ example: 'Front Desk', description: 'Location label for this QR' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  locationLabel?: string;
}
