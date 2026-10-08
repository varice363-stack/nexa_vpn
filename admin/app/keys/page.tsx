'use client';

import { Fragment, FormEvent, useCallback, useEffect, useState } from 'react';

import Badge from '@/components/Badge';
import PageHeader from '@/components/PageHeader';
import { api, apiBase, getToken } from '@/lib/api';
import { AdminAccessKey } from '@/lib/types';

/**
 * Ключи доступа.
 *
 * До этой правки страница была витриной: только таблица. Выдать ключ можно
 * было лишь из мобильного приложения (экран /admin/keys с X-Owner-Code), а
 * отзыв вообще не работал ниоткуда — панель звала бы пользовательский
 * DELETE /provisioning/:id, который режет по userId и на чужом ключе отдаёт
 * 404. Теперь выдача идёт через POST /provisioning/issue (JWT админа),
 * отзыв — через DELETE /provisioning/admin-revoke/:id, который после правки
 * ядра синхронизирует список клиентов с ядром.
 */
export default function AccessKeysPage() {
  const [keys, setKeys] = useState<AdminAccessKey[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [name, setName] = useState('');
  const [days, setDays] = useState('30');
  const [issued, setIssued] = useState<{
    code: string;
    name: string;
    uri: string | null;
  } | null>(null);
  // ключ id -> текст, скопированный/показанный прямо в таблице
  const [uriOf, setUriOf] = useState<Record<string, string>>({});
  const [copied, setCopied] = useState<string | null>(null);

  const load = useCallback(() => {
    setError(null);
    api<AdminAccessKey[]>('/provisioning/all')
      .then(setKeys)
      .catch((e) => setError(e instanceof Error ? e.message : 'Не удалось загрузить ключи'));
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy('issue');
    setError(null);
    try {
      // durationDays, а не days: лишние поля ValidationPipe(whitelist) молча
      // вырезает, и «days: 30» превращался в бессрочный ключ без ошибки.
      const durationDays = Math.max(0, Math.trunc(Number(days) || 0));
      const res = await api<{
        code: string;
        name: string;
        config?: { uri: string | null } | null;
      }>('/provisioning/issue', {
        method: 'POST',
        body: JSON.stringify({
          name: name.trim() || 'Morok Access',
          durationDays,
        }),
      });
      setIssued({ code: res.code, name: res.name, uri: res.config?.uri ?? null });
      setName('');
      setShowForm(false);
      load();
    } catch (e2) {
      setError(e2 instanceof Error ? e2.message : 'Не выдалось создать ключ');
    } finally {
      setBusy(null);
    }
  }

  /**
   * Готовый ключ: код + vless://. Один клик — и есть что отправить человеку,
   * которому не нужно приложение (или который ставит его сейчас).
   */
  async function copyKey(k: AdminAccessKey) {
    setBusy(k.id);
    setError(null);
    try {
      let uri = uriOf[k.id];
      if (!uri) {
        const token = getToken();
        const res = await fetch(`${apiBase()}/provisioning/admin-config/${k.id}`, {
          headers: token ? { Authorization: `Bearer ${token}` } : {},
        });
        if (!res.ok) {
          const body = await res.json().catch(() => null);
          throw new Error(
            body?.message
              ? (Array.isArray(body.message) ? body.message.join('; ') : body.message)
              : `HTTP ${res.status}`,
          );
        }
        const cfg = (await res.json()) as { config?: { uri: string | null } };
        uri = cfg.config?.uri ?? '';
        if (!uri) throw new Error('Конфигурация недоступна: проверьте сервер в разделе «Серверы»');
        setUriOf((prev) => ({ ...prev, [k.id]: uri }));
      }
      try {
        await navigator.clipboard.writeText(uri);
        setCopied(k.id);
        setTimeout(() => setCopied((c) => (c === k.id ? null : c)), 2500);
      } catch {
        // HTTP-страница без HTTPS часто режет clipboard API — показываем текст
        setUriOf((prev) => ({ ...prev, [k.id]: uri }));
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Не удалось получить конфигурацию');
    } finally {
      setBusy(null);
    }
  }

  async function revoke(k: AdminAccessKey) {
    if (!confirm(`Отозвать «${k.name}» (${k.code ?? k.id.slice(0, 8)})? Трафик на этом ключе встанет в течение минуты.`)) {
      return;
    }
    setBusy(k.id);
    try {
      const token = getToken();
      const res = await fetch(`${apiBase()}/provisioning/admin-revoke/${k.id}`, {
        method: 'DELETE',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
      });
      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(
          body?.message
            ? (Array.isArray(body.message) ? body.message.join('; ') : body.message)
            : `HTTP ${res.status}`,
        );
      }
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Не удалось отозвать ключ');
    } finally {
      setBusy(null);
    }
  }

  return (
    <div>
      <PageHeader
        title="Ключи доступа"
        subtitle="Все выпущенные ключи"
        action={
          <button
            type="button"
            className="btn-primary"
            onClick={() => setShowForm((v) => !v)}
          >
            {showForm ? 'Свернуть' : 'Выдать ключ'}
          </button>
        }
      />

      {issued ? (
        <div className="glass-card mb-3 flex items-center justify-between gap-3">
          <div>
            <div className="text-xs text-muted">
              Ключ «{issued.name}» создан. Код — для ввода в приложении, строка ниже — готовый конфиг:
            </div>
            <div className="font-mono text-lg text-teal-300">{issued.code}</div>
            {issued.uri ? (
              <div className="mt-1 font-mono text-[11px] text-muted break-all">{issued.uri}</div>
            ) : (
              <div className="mt-1 text-[11px] text-amber-300">
                Конфигурация не собралась: ключ появится в ядре, но URI выдастся
                только после того, как ключ привязан к активному серверу.
              </div>
            )}
          </div>
          <button type="button" className="btn-ghost" onClick={() => setIssued(null)}>
            Скрыть
          </button>
        </div>
      ) : null}

      {showForm ? (
        <form onSubmit={submit} className="glass-card mb-3 grid gap-2 sm:grid-cols-[1fr_120px_auto]">
          <input
            className="input-base"
            placeholder="Название (например, «Иван, 3 мес»)"
            value={name}
            onChange={(e) => setName(e.target.value)}
            maxLength={60}
          />
          <input
            className="input-base"
            type="number"
            min={0}
            max={3650}
            placeholder="Дней"
            value={days}
            onChange={(e) => setDays(e.target.value)}
            title="0 = бессрочно"
          />
          <button type="submit" className="btn-primary" disabled={busy === 'issue'}>
            {busy === 'issue' ? 'Создаём…' : 'Выдать'}
          </button>
        </form>
      ) : null}

      {error ? <div className="glass-card text-rose-300 mb-3">{error}</div> : null}

      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Пользователь</th>
              <th>Название</th>
              <th>Код</th>
              <th>Протокол</th>
              <th>Статус</th>
              <th>Назначенный сервер</th>
              <th>Устройство</th>
              <th title="Есть ли UUID ключа в конфиге ядра прямо сейчас">В ядре</th>
              <th>Ключ подключения</th>
              <th>Создан</th>
              <th>Истекает</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {keys.map((k) => (
              <Fragment key={k.id}>
              <tr>
                <td className="text-text font-medium">{k.user?.email ?? k.userId ?? '—'}</td>
                <td>{k.name}</td>
                <td className="font-mono text-xs">{k.code ?? '—'}</td>
                <td>{k.protocol}</td>
                <td><Badge value={k.status} /></td>
                <td>{k.server ? `${k.server.name} (${k.server.city})` : '—'}</td>
                <td className="font-mono text-xs">
                  {k.deviceId ? k.deviceId.slice(0, 8) : k.boundDevice ? `${k.boundDevice.slice(0, 10)}…` : '—'}
                </td>
                <td>
                  {k.published === null ? (
                    <span className="text-muted">—</span>
                  ) : k.published ? (
                    <span className="text-emerald-300">да</span>
                  ) : (
                    <span className="text-rose-300" title="ядро не пустит: список клиентов не обновлён">нет</span>
                  )}
                </td>
                <td>
                  <button
                    type="button"
                    className="btn-ghost text-xs"
                    disabled={busy === k.id || k.status !== 'ACTIVE'}
                    title={
                      k.status === 'ACTIVE'
                        ? 'Скопировать vless:// — эту строку можно отдать человеку вместе с кодом'
                        : 'Конфигурация есть только у активного ключа'
                    }
                    onClick={() => copyKey(k)}
                  >
                    {copied === k.id ? 'Скопировано' : busy === k.id ? 'Читаем…' : uriOf[k.id] ? 'Показан' : 'Скопировать'}
                  </button>
                </td>
                <td>{new Date(k.createdAt).toLocaleDateString()}</td>
                <td>{k.expiresAt ? new Date(k.expiresAt).toLocaleDateString() : '∞'}</td>
                <td>
                  {k.status === 'ACTIVE' ? (
                    <button
                      type="button"
                      className="btn-ghost text-rose-300"
                      disabled={busy === k.id}
                      onClick={() => revoke(k)}
                    >
                      {busy === k.id ? 'Отозываем…' : 'Отозвать'}
                    </button>
                  ) : null}
                </td>
              </tr>
              {uriOf[k.id] ? (
                <tr>
                  <td colSpan={12} className="font-mono text-[11px] break-all">
                    {uriOf[k.id]}
                  </td>
                </tr>
              ) : null}
              </Fragment>
            ))}
          </tbody>
        </table>
        {keys.length === 0 && !error ? (
          <div className="text-muted text-sm py-4">Ключей доступа пока нет.</div>
        ) : null}
      </div>
    </div>
  );
}
