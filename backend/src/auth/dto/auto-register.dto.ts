import { IsOptional, IsString, Length, Matches } from 'class-validator';

export class AutoRegisterDto {
  /// Device Identity code (e.g. MOROK-XXXX-XXXX-XXXX-XXXX).
  ///
  /// Раньше здесь стояло `@Length(20, 24)`, а код устройства в приложении —
  /// 25 символов («MOROK-» + четыре группы по 4 знака). Из-за одной цифры
  /// регистрация не проходила НИ С ОДНОГО телефона: сервер отвечал 400,
  /// приложение оставалось гостем, и пробный период физически не мог быть
  /// выдан — его некому было выдать. Теперь длину задаём по факту, а от
  /// мусора защищает проверка допустимых символов.
  @IsString()
  @Length(8, 40)
  @Matches(/^[A-Za-z0-9-]+$/, {
    message: 'deviceId: допустимы латинские буквы, цифры и дефис',
  })
  deviceId!: string;

  /// Обезличенный признак устройства (SHA-256 от ANDROID_ID), приходит только
  /// от новых сборок. Переживает удаление приложения, поэтому по нему сервер
  /// не выдаёт второй пробный период после переустановки. Необязателен:
  /// старая сборка его не шлёт, и это не должно ломать регистрацию.
  @IsOptional()
  @IsString()
  @Matches(/^[a-f0-9]{16,128}$/, {
    message: 'fingerprint: ожидается hex-строка',
  })
  fingerprint?: string;

  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;

  @IsOptional()
  @IsString()
  platform?: string;

  @IsOptional()
  @IsString()
  modelName?: string;
}
