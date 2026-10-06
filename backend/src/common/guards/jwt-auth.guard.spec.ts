import { JwtAuthGuard } from './jwt-auth.guard';

/**
 * Guard-«владельческий код» — единственная дверь в панель без логина.
 *
 * Проверяем ровно то, за что обычно платят прод-инцидентами:
 *  1. пустой env OWNER_CODE → заголовок не даёт прав вообще (ни в dev-сборке,
 *     ни в случае, когда секрет забыли выкатить);
 *  2. совпадение считается по нормализованному значению (пробелы/дефисы/регистр),
 *     но только полное — чужой код не «подходит частично»;
 *  3. пользователь-обход помечен viaOwnerCode и не имеет id: эндпоинты,
 *     пишущие от имени CurrentUser.id, обязаны видеть пустоту, а не выдуманный id.
 */

function makeCtx(headers: Record<string, string>) {
  const req: Record<string, unknown> = { headers, url: '/app-api/admin/dashboard' };
  const ctx = {
    switchToHttp: () => ({ getRequest: () => req, getResponse: () => ({}) }),
    getHandler: () => ({}),
    getClass: () => ({}),
  };
  return { ctx: ctx as never, req };
}
const ctxWith = (headers: Record<string, string>) => makeCtx(headers).ctx;


/**
 * Нет валидного кода → guard передаёт решение passport-стратегии, а та в
 * юнит-тесте не инициализирована (нет настоящего Http-контекста). Значит обход
 * НЕ сработал — ровно это и проверяем; пользователя при этом не подставляют.
 */
async function expectNoBypass(headers: Record<string, string>) {
  const { ctx, req } = makeCtx(headers);
  await expect(
    new JwtAuthGuard({ getAllAndOverride: () => false } as never).canActivate(ctx),
  ).rejects.toThrow(); // паспорт-стратегия не инициализирована → доверия нет
  expect(req.user).toBeUndefined(); // и пользователя guard не подставил
}

describe('JwtAuthGuard · X-Owner-Code', () => {
  const saved = process.env.OWNER_CODE;
  afterEach(() => {
    if (saved === undefined) delete process.env.OWNER_CODE;
    else process.env.OWNER_CODE = saved;
  });

  function guard(reflector: { getAllAndOverride: jest.Mock } = { getAllAndOverride: jest.fn(() => false) }) {
    return new JwtAuthGuard(reflector as never);
  }

  it('без OWNER_CODE в окружении заголовок ничего не даёт', async () => {
    delete process.env.OWNER_CODE;
    await expectNoBypass({ 'x-owner-code': 'MOROK-ANYTHING' });
  });

  it('верный код (в любом написании) даёт ADMIN-синтез без id', async () => {
    process.env.OWNER_CODE = 'MOROK-ABCD-1234';
    const g = guard();
    const ctx = ctxWith({ 'x-owner-code': ' morok_abcd1234 ' });
    await expect(g.canActivate(ctx)).resolves.toBe(true);
    const user = (ctx as never as { switchToHttp(): { getRequest(): { user: Record<string, string> } } })
      .switchToHttp()
      .getRequest().user;
    expect(user.role).toBe('ADMIN');
    expect(user.viaOwnerCode).toBe(true);
    expect(user.id).toBe('');
  });

  it('чужой или урезанный код не пускает', async () => {
    process.env.OWNER_CODE = 'MOROK-ABCD-1234';
    for (const code of ['MOROK-ABCD-123', 'MOROK-ABCD-9999', '', 'admin']) {
      await expectNoBypass({ 'x-owner-code': code });
    }
  });

  it('публичный маршрут проходит до всякой проверки кода', async () => {
    process.env.OWNER_CODE = 'MOROK-ABCD-1234';
    const reflector = { getAllAndOverride: jest.fn(() => true) };
    await expect(guard(reflector).canActivate(ctxWith({}))).resolves.toBe(true);
  });
});
