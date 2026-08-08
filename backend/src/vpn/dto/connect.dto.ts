import { IsInt, IsString, IsUUID, Max, Min } from 'class-validator';

export class ConnectDto {
  @IsUUID()
  serverId!: string;
}

export class DisconnectDto {
  @IsUUID()
  connectionId!: string;

  @IsInt()
  @Min(0)
  durationSec!: number;

  @IsInt()
  @Min(0)
  @Max(2_000_000)
  trafficMb!: number;
}
