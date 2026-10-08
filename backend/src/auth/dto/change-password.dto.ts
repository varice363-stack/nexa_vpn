import { IsString, Length, MinLength } from 'class-validator';

/**
 * Смена своего пароля из панели.
 *
 * Текущий пароль обязателен: без него украденный JWT превращался бы в захват
 * аккаунта. Минимум для нового — 8 символов (как куки/сессии живут долго,
 * короткий пароль в панели владельца недопустим).
 */
export class ChangePasswordDto {
  @IsString()
  @Length(1, 128)
  currentPassword!: string;

  @IsString()
  @MinLength(8, { message: 'Пароль должен быть не короче 8 символов' })
  @Length(8, 128)
  newPassword!: string;
}
