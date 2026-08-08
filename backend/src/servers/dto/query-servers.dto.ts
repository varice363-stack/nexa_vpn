import { Transform } from 'class-transformer';
import { IsBoolean, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class QueryServersDto {
  /** Filter by country (case-insensitive substring). */
  @IsOptional()
  @IsString()
  country?: string;

  /** Filter by premium tier: 'true' | 'false'. */
  @IsOptional()
  @Transform(({ value }) => (value === 'true' ? true : value === 'false' ? false : undefined))
  @IsBoolean()
  premium?: boolean;

  /** Sort: 'ping' (default) | 'load'. */
  @IsOptional()
  @IsString()
  sortBy?: 'ping' | 'load';

  /** Max rows. */
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}
