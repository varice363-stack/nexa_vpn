import { IsInt, IsOptional, IsString, Length, Max, Min } from 'class-validator';

/** Public redemption of an access code (TASK #021). */
export class RedeemCodeDto {
  /**
   * Loose bounds on purpose: the service normalises casing, spacing and
   * dashes, so rejecting formatting here would only frustrate the user.
   */
  @IsString()
  @Length(8, 32)
  code!: string;

  /** Binds the key to one device so a code cannot be shared endlessly. */
  @IsOptional()
  @IsString()
  @Length(1, 128)
  deviceId?: string;
}

/** Admin: issue a standalone key that is sold as a code. */
export class IssueCodeDto {
  @IsOptional()
  @IsString()
  @Length(1, 60)
  name?: string;

  /** Omit or 0 for a lifetime key. */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(3650)
  durationDays?: number;

  @IsOptional()
  @IsString()
  @Length(2, 20)
  protocol?: string;
}
