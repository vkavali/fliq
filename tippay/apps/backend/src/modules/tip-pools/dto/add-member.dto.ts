import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsOptional, IsNumber, Min, Max } from 'class-validator';

export class AddMemberDto {
  @ApiProperty({ example: '+919876543210', description: 'Phone number of user to add' })
  @IsString()
  phone!: string;

  @ApiPropertyOptional({ example: 'waiter', description: 'Role in the pool (e.g. waiter, chef, host)' })
  @IsOptional()
  @IsString()
  role?: string;

  @ApiPropertyOptional({ example: 25, description: 'Split percentage (0-100), used with PERCENTAGE split method' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  splitPercentage?: number;
}
