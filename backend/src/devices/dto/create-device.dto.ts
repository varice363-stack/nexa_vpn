import { IsOptional, IsString, Length } from 'class-validator';

export class CreateDeviceDto {
  @IsString()
  @Length(1, 64)
  name!: string;

  /** ios | android | windows | macos | linux | other */
  @IsOptional()
  @IsString()
  @Length(1, 32)
  platform?: string;
}
