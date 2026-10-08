import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
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
   * Действие баннера. Либо внешний http(s)-адрес (открывается в браузере),
   * либо служебное значение `share:referral` — тогда приложение показывает
   * своё окно «Пригласить друга» (готовое сообщение + «Поделиться»).
   *
   * Свободные схемы по-прежнему запрещены: приложение открывает только
   * http(s), всё остальное считает недействительным. Регулярка ниже это
   * фиксирует и на сервере — иначе админка получала бы 400 на share:referral.
   */
  @IsOptional()
  @IsString()
  @Matches(/^(https?:\/\/[^\s]+|share:referral)$/, {
    message:
      'targetUrl: нужна http(s)-ссылка либо share:referral (приглашение друга)',
  })
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
