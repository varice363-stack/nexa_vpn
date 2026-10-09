import { ChildProcess, execSync, spawn } from 'node:child_process';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';

/**
 * Black-box e2e harness: builds nothing itself (run `npm run test:e2e`, which
 * builds first), migrates and seeds a dedicated test database, then starts the
 * compiled `dist/main.js` exactly as production does (NODE_ENV=production) and
 * talks to it over HTTP. Nothing here is mocked.
 */
export const BACKEND_ROOT = path.resolve(__dirname, '..', '..');
export const PORT = Number(process.env.E2E_PORT ?? 3917);
export const BASE = `http://127.0.0.1:${PORT}/app-api`;
export const ADMIN_EMAIL = 'admin@morokvpn.app';
export const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'e2e-admin-pass-123';
export const OWNER_CODE = 'MOROK-E2E-OWNER-0001';
export const XRAY_FILE = path.join(os.tmpdir(), `morok-e2e-xray-${process.pid}.json`);

export function e2eDatabaseUrl(): string {
  const url = process.env.E2E_DATABASE_URL;
  if (!url) {
    throw new Error(
      'E2E_DATABASE_URL не задан. Укажите ТЕСТОВУЮ базу (имя с test или e2e), например ' +
        'postgresql://user:pass@127.0.0.1:5432/morok_test',
    );
  }
  const dbName = decodeURIComponent(new URL(url).pathname.replace(/^\//, ''));
  if (!/(test|e2e)/i.test(dbName)) {
    throw new Error(`Отказ: имя базы «${dbName}» не похоже на тестовое (нужно test или e2e)`);
  }
  return url;
}

export function serverEnv(extra: Record<string, string> = {}): NodeJS.ProcessEnv {
  return {
    ...process.env,
    NODE_ENV: 'production',
    DATABASE_URL: e2eDatabaseUrl(),
    JWT_SECRET: 'e2e-jwt-secret-0123456789abcdef0123456789',
    OWNER_CODE,
    ADMIN_PASSWORD,
    CORS_ORIGINS: 'http://localhost',
    PORT: String(PORT),
    HOST: '127.0.0.1',
    XRAY_CLIENTS_FILE: XRAY_FILE,
    UPLOADS_DIR: os.tmpdir(),
    // Общие лимиты поднимаем, чтобы сценарии не упирались в 429 с одного IP.
    // Узкие лимиты (вход, погашение кодов, авторегистрация) тесты не превышают.
    RATE_LIMIT_MAX: '100000',
    AUTH_RATE_LIMIT_MAX: '100000',
    ...extra,
  } as NodeJS.ProcessEnv;
}

export function migrateAndSeed(): void {
  // Тестовая база: пароль админа сбрасываем на известный на каждом запуске.
  const env = serverEnv({ ADMIN_PASSWORD_FORCE: 'true' });
  // Чистая база на каждом запуске (имя проверено в e2eDatabaseUrl): иначе
  // данные прошлых сидов (например, старый демо-пользователь) портят проверки.
  execSync('npx prisma migrate reset --force --skip-seed --skip-generate', {
    cwd: BACKEND_ROOT,
    env,
    stdio: 'pipe',
  });
  execSync('node dist/seed.js', { cwd: BACKEND_ROOT, env, stdio: 'pipe' });
}

export function startServer(): Promise<ChildProcess> {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, ['dist/main.js'], {
      cwd: BACKEND_ROOT,
      env: serverEnv(),
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let log = '';
    const timer = setTimeout(() => reject(new Error('Сервер не поднялся за 90 с:\n' + log.slice(-1500))), 90000);
    const onData = (chunk: Buffer) => {
      log += chunk.toString();
      if (log.includes('API ready')) {
        clearTimeout(timer);
        resolve(child);
      }
    };
    child.stdout?.on('data', onData);
    child.stderr?.on('data', onData);
    child.on('exit', (code) => {
      clearTimeout(timer);
      reject(new Error(`Сервер завершился с кодом ${code}:\n${log.slice(-1500)}`));
    });
  });
}

export interface ApiResult {
  status: number;
  data: any;
}

export async function api(
  method: string,
  p: string,
  opts: { token?: string; body?: unknown } = {},
): Promise<ApiResult> {
  const res = await fetch(BASE + p, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(opts.token ? { Authorization: `Bearer ${opts.token}` } : {}),
    },
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
  });
  const text = await res.text();
  let data: any = text;
  try {
    data = JSON.parse(text);
  } catch {
    /* не JSON — оставляем текст */
  }
  return { status: res.status, data };
}

export async function registerUser(prefix = 'e2e'): Promise<{ token: string; id: string; email: string }> {
  const email = `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@example.com`;
  const r = await api('POST', '/auth/register', { body: { email, password: 'Passw0rd1' } });
  if (r.status !== 201 && r.status !== 200) throw new Error(`register: ${r.status} ${JSON.stringify(r.data)}`);
  const token: string = r.data.accessToken;
  const me = await api('GET', '/auth/me', { token });
  return { token, id: me.data.id, email };
}

export async function adminToken(): Promise<string> {
  const r = await api('POST', '/auth/login', { body: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD } });
  if (r.status !== 200 && r.status !== 201) throw new Error(`admin login: ${r.status}`);
  return r.data.accessToken;
}

/** Ключ попал в файл клиентов, которые получает ядро Xray. */
export function inXrayClients(keyId: string): boolean {
  const raw = fs.readFileSync(XRAY_FILE, 'utf8');
  return raw.includes(`"email": "${keyId.slice(0, 8)}"`);
}

export async function syncXray(token: string): Promise<void> {
  const r = await api('POST', '/provisioning/xray/sync', { token });
  if (r.status !== 201 && r.status !== 200) throw new Error(`xray sync: ${r.status}`);
}
