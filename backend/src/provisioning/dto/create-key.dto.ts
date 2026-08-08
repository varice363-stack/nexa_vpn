import { IsOptional, IsString, IsUUID, Length } from 'class-validator';

export class CreateKeyDto {
  @IsString()
  @Length(1, 64)
  name!: string;

  /** Optional binding to a registered device. */
  @IsOptional()
  @IsUUID()
  deviceId?: string;

  /** Reserved for the future: VLESS | WIREGUARD. Defaults to VLESS. */
  @IsOptional()
  @IsString()
  protocol?: string;
}
