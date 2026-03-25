import { IsString, IsEnum, IsOptional, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { BusinessMemberRole } from '@fliq/shared';

export class InviteMemberDto {
  @ApiProperty({ example: '+919876543210', description: 'Phone number of the provider to invite' })
  @IsString()
  @MaxLength(15)
  phone!: string;

  @ApiPropertyOptional({ enum: BusinessMemberRole, default: BusinessMemberRole.STAFF })
  @IsOptional()
  @IsEnum(BusinessMemberRole)
  role?: BusinessMemberRole;
}
