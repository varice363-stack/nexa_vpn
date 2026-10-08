import { Transform } from 'class-transformer';
import { IsNotEmpty, IsString, Length, Matches } from 'class-validator';

/**
 * Код приглашения — это код устройства пригласившего
 * (`MOROK-XXXX-XXXX-XXXX-XXXX`). Терпимо к тому, как люди копируют его из
 * мессенджера: допускаем лишние пробелы и нижний регистр, приводим к
 * каноническому виду до проверки.
 */
export class ApplyReferralDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  @IsString()
  @IsNotEmpty({ message: 'Введите код приглашения' })
  @Length(8, 40, { message: 'Код приглашения выглядит неполным' })
  @Matches(/^MOROK-[A-Z0-9-]+$/, {
    message: 'Код приглашения должен начинаться с MOROK-',
  })
  code!: string;
}
