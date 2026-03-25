import { IsUUID, IsNumber, Min, Max, IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class AddJarMemberDto {
  @ApiProperty({ description: 'Provider user UUID to add as member' })
  @IsUUID()
  providerId!: string;

  @ApiProperty({ description: 'Split percentage (0-100)', minimum: 0, maximum: 100 })
  @IsNumber()
  @Min(0)
  @Max(100)
  splitPercentage!: number;

  @ApiProperty({ required: false, example: 'Bride' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  roleLabel?: string;
}
