import { IsIn, IsInt, IsISO8601, IsOptional, IsString, Length, Min } from 'class-validator';

/**
 * Правка ключа из панели: срок, имя, лимит трафика, статус.
 *
 * Все поля необязательные — панель присылает только то, что меняет
 * (то же правило, что у баннеров: пустое поле не должно случайно стирать данные).
 */
export class AdminUpdateKeyDto {
  @IsOptional()
  @IsString()
  @Length(1, 60)
  name?: string;

  /** Новая дата окончания (ISO) или null — «бессрочно». */
  @IsOptional()
  @IsISO8601()
  expiresAt?: string | null;

  /** Лимит трафика в МБ; null или 0 — снять лимит. */
  @IsOptional()
  @IsInt()
  @Min(0)
  trafficLimitMb?: number | null;

  @IsOptional()
  @IsIn(['ACTIVE', 'REVOKED', 'EXPIRED'])
  status?: 'ACTIVE' | 'REVOKED' | 'EXPIRED';
}
