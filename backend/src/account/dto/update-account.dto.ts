import { IsOptional, IsString, Length } from 'class-validator';

export class UpdateAccountDto {
  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;

  /** Required when [newPassword] is provided. */
  @IsOptional()
  @IsString()
  currentPassword?: string;

  @IsOptional()
  @IsString()
  @Length(8, 72)
  newPassword?: string;
}
