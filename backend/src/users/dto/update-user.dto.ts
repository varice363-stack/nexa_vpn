import { IsEnum, IsOptional, IsString, Length } from 'class-validator';
import { Role, UserStatus } from '@prisma/client';

export class UpdateUserDto {
  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @IsOptional()
  @IsEnum(UserStatus)
  status?: UserStatus;

  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;
}
