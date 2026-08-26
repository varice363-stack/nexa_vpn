import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  Length,
  Min,
} from 'class-validator';

/** Slots a banner can be rendered in. */
export const BANNER_PLACEMENTS = ['home', 'premium'] as const;
export type BannerPlacement = (typeof BANNER_PLACEMENTS)[number];

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

  /**
   * External URL opened when the CTA is tapped. Only http(s) is accepted —
   * custom schemes could be abused to launch arbitrary intents on device.
   * Use this for referral links (e.g., registration with referral code).
   */
  @IsOptional()
  @IsUrl({ protocols: ['http', 'https'], require_protocol: true })
  targetUrl?: string;

  /**
   * Referral code for tracking (optional).
   */
  @IsOptional()
  @IsString()
  referralCode?: string;

  @IsOptional()
  @IsIn(BANNER_PLACEMENTS)
  placement?: BannerPlacement;

  /**
   * Duration (seconds) the banner stays visible in the carousel.
   * Defaults to 30s. Must be between 5 and 300 seconds.
   */
  @IsOptional()
  @IsInt()
  @Min(5)
  @Max(300)
  displayDuration?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
