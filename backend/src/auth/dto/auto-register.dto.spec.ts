import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';

import { AutoRegisterDto } from './auto-register.dto';

/**
 * Регрессия 08.10.2026. Верхняя граница длины deviceId стояла 24 символа, а
 * код устройства в приложении — 25 («MOROK-» + четыре группы по 4 знака).
 * Регистрация отвечала 400 на каждый реальный запуск: телефон оставался
 * гостем, пробный период не выдавался, ключ не появлялся. Тест фиксирует
 * настоящий формат клиента, а не «похожий» из предыдущих проверок.
 */
function check(payload: Record<string, unknown>): string[] {
  const dto = plainToInstance(AutoRegisterDto, payload);
  return validateSync(dto, {
    whitelist: true,
    forbidNonWhitelisted: false,
  }).flatMap((e) => Object.values(e.constraints ?? {}));
}

describe('AutoRegisterDto (реальный код устройства)', () => {
  it('принимает полный код MOROK-XXXX-XXXX-XXXX-XXXX (25 символов)', () => {
    const errors = check({
      deviceId: 'MOROK-AAAA-BBBB-CCCC-DDDD',
      platform: 'android',
      fingerprint: 'a'.repeat(64),
    });
    expect(errors).toEqual([]);
  });

  it('принимает короткий легаси-код (24 символа и меньше)', () => {
    expect(check({ deviceId: 'probetrial00000000000001' })).toEqual([]);
    expect(check({ deviceId: 'MOROK-AAAA-BBBB-CCCC-DDD' })).toEqual([]);
  });

  it('принимает код без fingerprint — старые сборки его не шлют', () => {
    expect(
      check({ deviceId: 'MOROK-AAAA-BBBB-CCCC-DDDD', platform: 'android' }),
    ).toEqual([]);
  });

  it('отбивает мусор в deviceId: пробелы, знаки, слишком короткое', () => {
    expect(check({ deviceId: 'ab' }).length).toBeGreaterThan(0);
    expect(check({ deviceId: 'MOROK-AAAA BBBB' }).length).toBeGreaterThan(0);
    expect(check({ deviceId: 'MOROK-<script>' }).length).toBeGreaterThan(0);
    expect(check({ deviceId: 'x'.repeat(64) }).length).toBeGreaterThan(0);
  });

  it('отбивает неправильный fingerprint (не hex / слишком короткий)', () => {
    const base = { deviceId: 'MOROK-AAAA-BBBB-CCCC-DDDD' };
    expect(check({ ...base, fingerprint: 'ZZZZ' }).length).toBeGreaterThan(0);
    expect(check({ ...base, fingerprint: 'abc' }).length).toBeGreaterThan(0);
  });
});
