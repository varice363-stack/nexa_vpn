import { IsOptional, IsString, Length } from 'class-validator';

export class AutoRegisterDto {
  /// Device Identity code (e.g. NEXA-XXXX-XXXX-XXXX-XXXX).
  @IsString()
  @Length(20, 24)
  deviceId!: string;

  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;

  @IsOptional()
  @IsString()
  platform?: string;

  @IsOptional()
  @IsString()
  modelName?: string;
}
