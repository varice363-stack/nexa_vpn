import { IsBoolean, IsEnum, IsInt, IsNumber, IsOptional, IsString, Length, Max, Min } from 'class-validator';
import { ServerProtocol } from '@prisma/client';

export class CreateServerDto {
  @IsString()
  @Length(2, 64)
  name!: string;

  @IsString()
  country!: string;

  @IsString()
  @Length(2, 2)
  countryCode!: string;

  @IsString()
  city!: string;

  @IsString()
  ip!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(65535)
  port?: number;

  @IsOptional()
  @IsString()
  transport?: string;

  @IsOptional()
  @IsString()
  security?: string;

  @IsOptional()
  @IsString()
  sni?: string;

  @IsOptional()
  @IsString()
  flow?: string;

  @IsOptional()
  @IsString()
  publicKey?: string;

  @IsOptional()
  @IsString()
  shortId?: string;

  @IsOptional()
  @IsEnum(ServerProtocol)
  protocol?: ServerProtocol;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  load?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  ping?: number;

  @IsOptional()
  @IsBoolean()
  premium?: boolean;
}
