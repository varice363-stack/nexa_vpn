import { IsBoolean, IsOptional, IsString, Length } from 'class-validator';

export class CreateBannerDto {
  @IsString()
  @Length(2, 120)
  title!: string;

  @IsString()
  @Length(2, 500)
  description!: string;

  @IsOptional()
  @IsString()
  imageUrl?: string;

  @IsOptional()
  @IsString()
  buttonText?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
