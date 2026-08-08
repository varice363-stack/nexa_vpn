import { Transform } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

export class AnalyticsQueryDto {
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(90)
  days?: number = 7;
}
