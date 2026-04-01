import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsEnum, IsOptional, MaxLength, IsUUID } from 'class-validator';

export enum ResponseType {
  EMOJI = 'emoji',
  VOICE = 'voice',
  VIDEO = 'video',
}

export class CreateResponseDto {
  @ApiProperty({ description: 'Tip ID to respond to' })
  @IsUUID()
  tipId!: string;

  @ApiProperty({ enum: ResponseType, example: ResponseType.EMOJI })
  @IsEnum(ResponseType)
  type!: ResponseType;

  @ApiPropertyOptional({ example: '🙏', description: 'Emoji character (for emoji type)' })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  emoji?: string;

  @ApiPropertyOptional({ description: 'URL to voice/video media' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  mediaUrl?: string;
}
