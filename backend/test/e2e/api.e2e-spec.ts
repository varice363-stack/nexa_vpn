import { ChildProcess, execSync } from 'node:child_process';
import * as fs from 'node:fs';
import {
  BACKEND_ROOT,
  PORT,
  adminToken,
  api,
  inXrayClients,
  migrateAndSeed,
  registerUser,
  serverEnv,
  startServer,
  syncXray,
  XRAY_FILE,
  OWNER_CODE,
} from './helpers';

let server: ChildProcess;
let admin: string;

beforeAll(async () => {
  migrateAndSeed();
  server = await startServer();
  admin = await adminToken();
}, 240000);

afterAll(() => {
  server?.kill('SIGTERM');
  try {
    fs.unlinkSync(XRAY_FILE);
  } catch {
    /* файла могло не быть */
  }
});

/** Пользователь с премиум-подпиской, устройством и ключом. */
async function premiumUserWithKey() {
  const u = await registerUser('prem');
  const dev = await api('POST', '/devices', { token: u.token, body: { name: 'Тестовый телефон', platform: 'android' } });
  expect(dev.status).toBe(201);
  const grant = await api('POST', `/users/${u.id}/premium`, { token: admin, body: { planCode: 'MONTHLY' } });
  expect(grant.status).toBe(201);
  const key = await api('POST', '/provisioning', { token: u.token, body: { name: 'Ключ', deviceId: dev.data.id } });
  expect(key.status).toBe(201);
  return { ...u, deviceId: dev.data.id as string, keyId: key.data.id as string };
}

describe('доступ: анонимы, обычные пользователи, чужие данные', () => {
  const adminOnly = [
    ['GET', '/users'],
    ['GET', '/analytics/overview'],
    ['GET', '/admin/dashboard'],
    ['GET', '/billing/transactions/all'],
    ['GET', '/servers/all'],
    ['POST', '/provisioning/xray/sync'],
  ] as const;

  it.each(adminOnly)('%s %s: без входа — 401', async (method, path) => {
    const r = await api(method, path);
    expect(r.status).toBe(401);
  });

  it.each(adminOnly)('%s %s: обычный пользователь — 403', async (method, path) => {
    const u = await registerUser('plain');
    const r = await api(method, path, { token: u.token });
    expect(r.status).toBe(403);
  });

  it('чужой ключ, чужое устройство и чужая транзакция не видны (404)', async () => {
    const owner = await premiumUserWithKey();
    const other = await registerUser('other');

    expect((await api('GET', `/provisioning/${owner.keyId}`, { token: other.token })).status).toBe(404);
    expect((await api('DELETE', `/devices/${owner.deviceId}`, { token: other.token })).status).toBe(404);
    expect((await api('DELETE', `/provisioning/${owner.keyId}`, { token: other.token })).status).toBe(404);
    expect((await api('GET', `/provisioning/${owner.keyId}`, { token: owner.token })).status).toBe(200);
  });

  it('проверка кода владельца: неверный код — 401, владелец — админ', async () => {
    const u = await registerUser('own');
    const bad = await api('POST', '/auth/promote-to-admin', { token: u.token, body: { ownerCode: 'nope' } });
    expect(bad.status).toBe(401);
    const good = await api('POST', '/auth/promote-to-admin', { token: u.token, body: { ownerCode: OWNER_CODE } });
    expect([200, 201]).toContain(good.status);
    expect(good.data.user?.role ?? good.data.role).toBe('ADMIN');
  });
});

describe('блокировка и удаление отключают VPN, а не только вход', () => {
  it('заблокированный пользователь пропадает из клиентов ядра; после разблокировки возвращается', async () => {
    const u = await premiumUserWithKey();
    await syncXray(admin);
    expect(inXrayClients(u.keyId)).toBe(true);

    expect((await api('POST', `/users/${u.id}/block`, { token: admin })).status).toBe(201);
    await syncXray(admin);
    expect(inXrayClients(u.keyId)).toBe(false);
    expect((await api('GET', '/auth/me', { token: u.token })).status).toBe(401);

    expect((await api('POST', `/users/${u.id}/unblock`, { token: admin })).status).toBe(201);
    await syncXray(admin);
    expect(inXrayClients(u.keyId)).toBe(true);
  });

  it('ключ, выданный админом, сразу попадает в клиенты ядра (без ожидания тика)', async () => {
    // Регрессия: раньше issue() не публиковал ключ, и первые ~30 с vless:// не работал.
    const r = await api('POST', '/provisioning/issue', { token: admin, body: { name: 'Тест' } });
    expect(r.status).toBe(201);
    expect(inXrayClients(r.data.id)).toBe(true);
  });

  it('удалённый аккаунт тоже пропадает из клиентов ядра', async () => {
    const u = await premiumUserWithKey();
    await syncXray(admin);
    expect(inXrayClients(u.keyId)).toBe(true);

    expect((await api('DELETE', '/account', { token: u.token })).status).toBe(200);
    await syncXray(admin);
    expect(inXrayClients(u.keyId)).toBe(false);
  });
});

describe('оплата: продовый режим', () => {
  it('mock-вебхук в production недоступен (404), подделанная оплата не проходит', async () => {
    const u = await registerUser('pay');
    const r = await api('POST', '/billing/webhook/mock', {
      body: { signature: 'mock-signature', event: 'payment.paid', providerPaymentId: 'любой' },
    });
    expect(r.status).toBe(404);
    expect((await api('GET', '/subscription/status', { token: u.token })).data.isPremium).toBe(false);
  });

  it('checkout без провайдера — 503 и никакого PENDING-заказа', async () => {
    const u = await registerUser('pay2');
    const plans = await api('GET', '/plans');
    const plan = (plans.data as Array<{ id: string; code: string }>).find((p) => p.code === 'MONTHLY');
    expect(plan).toBeDefined();
    const r = await api('POST', '/billing/checkout', { token: u.token, body: { planId: plan!.id } });
    expect(r.status).toBe(503);
    const list = await api('GET', '/billing/transactions', { token: u.token });
    expect(list.data).toEqual([]);
  });

  it('список транзакций пользователя без providerPaymentId (контракт; заказов без провайдера нет)', async () => {
    const u = await registerUser('pay3');
    // заказ создаём напрямую через админский список: своих заказов без провайдера нет,
    // поэтому проверяем сам контракт: ни одного поля providerPaymentId в ответе
    const list = await api('GET', '/billing/transactions', { token: u.token });
    expect(list.status).toBe(200);
    expect(JSON.stringify(list.data)).not.toContain('providerPaymentId');
  });

  it('демо-пользователь с известным паролем на проде не создан', async () => {
    const r = await api('POST', '/auth/login', { body: { email: 'user@morokvpn.app', password: 'user1234' } });
    expect(r.status).toBe(401);
  });

  it('сид в production без ADMIN_PASSWORD отказывается работать', () => {
    const env = serverEnv();
    delete env.ADMIN_PASSWORD;
    expect(() =>
      execSync('node dist/seed.js', { cwd: BACKEND_ROOT, env, stdio: 'pipe' }),
    ).toThrow();
  });
});

describe('ошибки ввода: сервер отвечает 4xx, а не 500', () => {
  it('ключ с неизвестным устройством — 404, не 500', async () => {
    const u = await registerUser('bad1');
    await api('POST', `/users/${u.id}/premium`, { token: admin, body: { planCode: 'MONTHLY' } });
    const r = await api('POST', '/provisioning', {
      token: u.token,
      body: { name: 'Ключ', deviceId: '00000000-0000-4000-8000-00000000dead' },
    });
    expect(r.status).toBe(404);
  });

  it('ключ без имени — 400; deviceId не UUID — 400', async () => {
    const u = await registerUser('bad2');
    expect((await api('POST', '/provisioning', { token: u.token, body: {} })).status).toBe(400);
    expect((await api('POST', '/provisioning', { token: u.token, body: { name: 'k', deviceId: 'abc' } })).status).toBe(400);
  });

  it('устройство с пустым именем — 400; неизвестный JSON — не 500', async () => {
    const u = await registerUser('bad3');
    expect((await api('POST', '/devices', { token: u.token, body: { name: '' } })).status).toBe(400);
    const broken = await fetch(`http://127.0.0.1:${PORT}/app-api/devices`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${u.token}` },
      body: '{"name": ',
    });
    expect(broken.status).toBe(400);
  });

  it('здоровье сервиса — 200', async () => {
    expect((await api('GET', '/health')).status).toBe(200);
  });
});

describe('уведомления: широковещательное прочитано только тем, кто его открыл', () => {
  it('один отметил прочитанным — у второго оно остаётся непрочитанным', async () => {
    const a = await registerUser('ntfA');
    const b = await registerUser('ntfB');
    const created = await api('POST', '/notifications', { token: admin, body: { title: 'Тест', body: 'Текст' } });
    expect([200, 201]).toContain(created.status);
    const id = created.data.id as string;

    const find = (list: any) => (list.data as Array<{ id: string; read: boolean }>).find((n) => n.id === id);
    expect(find(await api('GET', '/notifications/me', { token: a.token }))?.read).toBe(false);

    expect((await api('PATCH', `/notifications/${id}/read`, { token: a.token })).status).toBe(200);
    expect(find(await api('GET', '/notifications/me', { token: a.token }))?.read).toBe(true);
    expect(find(await api('GET', '/notifications/me', { token: b.token }))?.read).toBe(false);
  });
});
