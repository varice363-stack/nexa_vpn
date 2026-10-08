'use client';

import { FormEvent, useState } from 'react';

import PageHeader from '@/components/PageHeader';
import { api } from '@/lib/api';

/**
 * «Доступ к панели» — смена пароля владельца.
 *
 * Зачем страница: пароль админа задавался только сидом из переменной
 * ADMIN_PASSWORD в backend/.env, и без доступа к серверу его нельзя было
 * сменить вообще (а сид при каждом запуске возвращал прежний — «сменил
 * пароль, а он опять прежний»). Теперь это делается здесь, из браузера.
 */
export default function AccessPage() {
  const [currentPassword, setCurrent] = useState('');
  const [newPassword, setNew] = useState('');
  const [repeat, setRepeat] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setOk(null);

    if (newPassword.length < 8) {
      setError('Новый пароль должен быть не короче 8 символов.');
      return;
    }
    if (newPassword !== repeat) {
      setError('Новый пароль и повтор не совпадают.');
      return;
    }

    setBusy(true);
    try {
      await api('/auth/password', {
        method: 'PATCH',
        body: JSON.stringify({ currentPassword, newPassword }),
      });
      setOk('Пароль изменён. Запишите его: при следующем входе понадобится новый.');
      setCurrent('');
      setNew('');
      setRepeat('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Не удалось сменить пароль');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="max-w-xl">
      <PageHeader
        title="Доступ к панели"
        subtitle="Пароль владельца для этой админ-панели"
      />

      <div className="glass-card mb-4 text-sm text-muted space-y-1">
        <div>
          Логин (email): <span className="text-text font-medium">admin@morokvpn.app</span>
        </div>
        <div>
          Пароль по умолчанию лежит на сервере в{' '}
          <code className="text-text">/opt/morok_app/backend/.env</code> (строка{' '}
          <code className="text-text">ADMIN_PASSWORD</code>) — смените его здесь и держите
          только в голове.
        </div>
        <div>
          Если пароль забыт: на сервере{' '}
          <code className="text-text">
            docker compose -f backend/docker-compose.yml exec -T backend sh -c
            &quot;ADMIN_PASSWORD_FORCE=true npm run prisma:seed&quot;
          </code>{' '}
          (вернёт пароль из .env; обычный перезапуск пароль НЕ перезаписывает).
        </div>
      </div>

      <form onSubmit={submit} className="glass-card space-y-3">
        <input
          type="password"
          required
          placeholder="Текущий пароль"
          value={currentPassword}
          onChange={(e) => setCurrent(e.target.value)}
          className="input-base w-full"
        />
        <input
          type="password"
          required
          placeholder="Новый пароль (минимум 8 символов)"
          value={newPassword}
          onChange={(e) => setNew(e.target.value)}
          className="input-base w-full"
        />
        <input
          type="password"
          required
          placeholder="Повторите новый пароль"
          value={repeat}
          onChange={(e) => setRepeat(e.target.value)}
          className="input-base w-full"
        />

        {error ? <div className="text-sm text-rose-400">{error}</div> : null}
        {ok ? <div className="text-sm text-emerald-400">{ok}</div> : null}

        <button type="submit" disabled={busy} className="btn-primary w-full">
          {busy ? 'Сохранение…' : 'Сменить пароль'}
        </button>
        <p className="text-xs text-faint">
          Действующие сессии не сбрасываются: если панель открыта на другом устройстве,
          выйдите там вручную (кнопка «Выйти» внизу меню).
        </p>
      </form>
    </div>
  );
}
