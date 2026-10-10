'use client';

import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';

import { api } from '@/lib/api';
import { AccessKeyRow, IssuedKey } from '@/lib/types';

/**
 * Центр управления ключами: выдать → скопировать → продлить → изменить лимит
 * трафика → отозвать → удалить. Один компонент на две страницы (дашборд и
 * «Ключи доступа»), чтобы логика не разъезжалась.
 *
 * Про копирование отдельно: панель отдаётся по http:// (без TLS), а
 * `navigator.clipboard` в небезопасном контексте отсутствует — молча ничего не
 * делал бы. Поэтому копирование с запасным путём через скрытый textarea, и
 * всегда есть поле с текстом, которое можно выделить руками.
 */
export function copyText(text: string): Promise<boolean> {
  const fallback = () => {
    try {
      const area = document.createElement('textarea');
      area.value = text;
      area.style.position = 'fixed';
      area.style.opacity = '0';
      document.body.appendChild(area);
      area.focus();
      area.select();
      const ok = document.execCommand('copy');
      document.body.removeChild(area);
      return ok;
    } catch {
      return false;
    }
  };

  if (navigator.clipboard && window.isSecureContext) {
    return navigator.clipboard.writeText(text).then(() => true).catch(fallback);
  }
  return Promise.resolve(fallback());
}

const GB = 1024; // МБ в ГБ

function daysWord(n: number): string {
  const mod10 = n % 10;
  const mod100 = n % 100;
  if (mod10 === 1 && mod100 !== 11) return 'день';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'дня';
  return 'дней';
}

function fmtDate(iso: string | null): string {
  if (!iso) return 'бессрочно';
  return new Date(iso).toLocaleDateString('ru-RU', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

function fmtMb(mb: number | null): string {
  if (mb === null) return '—';
  if (mb < 1024) return `${mb} МБ`;
  return `${(mb / 1024).toFixed(1)} ГБ`;
}

function toLocalEndOfDay(date: string): string {
  // Продлеваем до КОНЦА выбранного дня по местному времени владельца.
  return new Date(`${date}T23:59:59`).toISOString();
}

export default function KeysManager({ compact = false }: { compact?: boolean }) {
  const [keys, setKeys] = useState<AccessKeyRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  // выдача
  const [issueName, setIssueName] = useState('');
  const [issueDays, setIssueDays] = useState('30');
  const [issueGb, setIssueGb] = useState('');
  const [issuing, setIssuing] = useState(false);
  const [issued, setIssued] = useState<IssuedKey | null>(null);

  // правка
  const [editId, setEditId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');
  const [editDate, setEditDate] = useState('');
  const [editGb, setEditGb] = useState('');
  const [editStatus, setEditStatus] = useState('ACTIVE');

  // поиск
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<'ALL' | 'ACTIVE' | 'REVOKED' | 'EXPIRED'>('ALL');

  const load = useCallback(async () => {
    try {
      const rows = await api<AccessKeyRow[]>('/provisioning/all');
      setKeys(rows);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Не удалось загрузить ключи');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const shown = useMemo(() => {
    const q = query.trim().toLowerCase();
    return keys.filter((k) => {
      if (filter !== 'ALL' && k.status !== filter) return false;
      if (!q) return true;
      return (
        (k.name || '').toLowerCase().includes(q) ||
        (k.code || '').toLowerCase().includes(q) ||
        (k.user?.email || '').toLowerCase().includes(q)
      );
    });
  }, [keys, query, filter]);

  const active = keys.filter((k) => k.status === 'ACTIVE').length;
  const soon = keys.filter(
    (k) => k.status === 'ACTIVE' && k.daysLeft !== null && k.daysLeft <= 7,
  ).length;

  /** Собирает код + готовую ссылку и кладёт в буфер, показывая подтверждение. */
  async function copyKey(key: AccessKeyRow, what: 'code' | 'uri') {
    setError(null);
    setBusyId(key.id);
    try {
      if (what === 'code') {
        if (!key.code) throw new Error('У этого ключа нет кода (создан внутри аккаунта)');
        const ok = await copyText(key.code);
        setNote(ok ? `Код ${key.code} скопирован` : `Не удалось скопировать — вот код: ${key.code}`);
        return;
      }
      // Бэкенд отдаёт ссылка в поле config.uri (см. adminContract → toContract).
      const cfg = await api<{
        code: string | null;
        config: { uri: string | null; unavailableReason?: string | null } | null;
      }>(`/provisioning/admin-config/${key.id}`);
      const uri = cfg.config?.uri;
      if (!uri) {
        throw new Error(
          cfg.config?.unavailableReason ?? 'Для этого ключа нет vless-ссылки',
        );
      }
      const ok = await copyText(uri);
      setNote(
        ok
          ? 'Ссылка vless:// скопирована — можно отправить в Hiddify/v2rayNG'
          : `Не удалось скопировать автоматически, вот ссылка: ${uri}`,
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Не удалось получить конфигурацию');
    } finally {
      setBusyId(null);
    }
  }

  async function issue(e: FormEvent) {
    e.preventDefault();
    setIssuing(true);
    setError(null);
    setIssued(null);
    try {
      const gb = Number(issueGb);
      const body: Record<string, unknown> = {
        name: issueName.trim() || 'Morok Access',
        durationDays: Math.max(0, Number(issueDays) || 0),
      };
      if (issueGb.trim() && gb > 0) body.trafficLimitMb = Math.round(gb * GB);
      const res = await api<IssuedKey>('/provisioning/issue', {
        method: 'POST',
        body: JSON.stringify(body),
      });
      setIssued(res);
      setIssueName('');
      setIssueGb('');
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Не удалось выдать ключ');
    } finally {
      setIssuing(false);
    }
  }

  /** Правка: имя, дата окончания, лимит трафика, статус — одним запросом. */
  async function submitEdit(e: FormEvent) {
    e.preventDefault();
    if (!editId) return;
    setBusyId(editId);
    setError(null);
    try {
      const body: Record<string, unknown> = {
        name: editName.trim() || undefined,
        status: editStatus,
        // Пустая дата = бессрочно; пустой лимит = без лимита.
        expiresAt: editDate ? toLocalEndOfDay(editDate) : null,
        trafficLimitMb: editGb.trim() ? Math.round(Number(editGb) * GB) : null,
      };
      await api(`/provisioning/admin-key/${editId}`, {
        method: 'PATCH',
        body: JSON.stringify(body),
      });
      setNote('Ключ обновлён');
      setEditId(null);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Не удалось сохранить');
    } finally {
      setBusyId(null);
    }
  }

  /** Продление одной кнопкой: +N дней от текущего срока (или от сегодня). */
  async function extend(key: AccessKeyRow, days: number) {
    setBusyId(key.id);
    setError(null);
    try {
      const from = key.expiresAt && new Date(key.expiresAt) > new Date()
        ? new Date(key.expiresAt)
        : new Date();
      const next = new Date(from.getTime() + days * 86_400_000);
      await api(`/provisioning/admin-key/${key.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ expiresAt: next.toISOString(), status: 'ACTIVE' }),
      });
      setNote(`«${key.name}» продлён на ${days} ${daysWord(days)} — до ${fmtDate(next.toISOString())}`);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Не удалось продлить');
    } finally {
      setBusyId(null);
    }
  }

  async function revoke(key: AccessKeyRow) {
    if (!confirm(`Отозвать ключ «${key.name}»? Доступ пропадёт, запись с кодом останется.`)) return;
    setBusyId(key.id);
    try {
      await api(`/provisioning/admin-revoke/${key.id}`, { method: 'DELETE' });
      setNote('Ключ отозван — доступ снят в ядре');
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Не удалось отозвать');
    } finally {
      setBusyId(null);
    }
  }

  async function remove(key: AccessKeyRow) {
    if (!confirm(`Удалить ключ «${key.name}» НАВСЕГДА? Запись с кодом исчезнет, отменить нельзя.`)) return;
    setBusyId(key.id);
    try {
      await api(`/provisioning/admin-key/${key.id}`, { method: 'DELETE' });
      setNote('Ключ удалён');
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Не удалось удалить');
    } finally {
      setBusyId(null);
    }
  }

  function startEdit(key: AccessKeyRow) {
    setEditId(key.id);
    setEditName(key.name);
    setEditDate(key.expiresAt ? new Date(key.expiresAt).toISOString().slice(0, 10) : '');
    setEditGb(key.trafficLimitMb ? String(Math.round((key.trafficLimitMb / GB) * 10) / 10) : '');
    setEditStatus(key.status);
  }

  return (
    <div className="space-y-4">
      {/* ── Выдача ключа ─────────────────────────────────────────────── */}
      <form onSubmit={issue} className="glass-card space-y-3">
        <div className="flex items-center justify-between">
          <h2 className="font-semibold text-text">Выдать ключ</h2>
          <span className="text-xs text-muted">
            активных {active} · истекают за 7 дней {soon}
          </span>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-[1fr_120px_140px_auto] gap-3">
          <input
            placeholder="Кому (например: Иван, 30 дней)"
            value={issueName}
            onChange={(e) => setIssueName(e.target.value)}
            className="input-base w-full"
          />
          <input
            type="number"
            min={0}
            placeholder="Дней"
            value={issueDays}
            onChange={(e) => setIssueDays(e.target.value)}
            className="input-base w-full"
          />
          <input
            type="number"
            min={0}
            placeholder="Лимит, ГБ"
            value={issueGb}
            onChange={(e) => setIssueGb(e.target.value)}
            className="input-base w-full"
          />
          <button type="submit" disabled={issuing} className="btn-primary whitespace-nowrap">
            {issuing ? 'Выдаю…' : 'Выдать'}
          </button>
        </div>
        <div className="flex gap-2 flex-wrap text-xs">
          {[7, 30, 90, 365].map((d) => (
            <button
              key={d}
              type="button"
              onClick={() => setIssueDays(String(d))}
              className="px-2 py-1 rounded border border-white/15 text-muted hover:text-text"
            >
              {d} дней
            </button>
          ))}
          <span className="text-faint self-center">
            лимит ГБ можно не заполнять — тогда без ограничения
          </span>
        </div>
        {issued ? (
          <div className="rounded-xl border border-emerald-400/30 bg-emerald-400/5 p-3 space-y-2">
            <div className="text-sm text-emerald-300">
              Ключ выдан. Дайте покупателю <b>код</b> — он вводит его в приложении.
            </div>
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-xs text-muted w-20">Код</span>
              <code className="text-text text-sm select-all">{issued.code}</code>
              <button
                type="button"
                onClick={() => copyText(issued.code ?? '').then((ok) =>
                  setNote(ok ? 'Код скопирован' : 'Скопируйте код вручную') )}
                className="px-2 py-1 rounded border border-white/15 text-xs text-muted"
              >
                Копировать код
              </button>
            </div>
            <div className="flex items-start gap-2">
              <span className="text-xs text-muted w-20 pt-1">Ссылка</span>
              <input
                readOnly
                value={issued.config?.uri ?? ''}
                onFocus={(e) => e.currentTarget.select()}
                className="input-base w-full text-xs"
              />
              <button
                type="button"
                disabled={!issued.config?.uri}
                onClick={() => copyText(issued.config?.uri ?? '').then((ok) =>
                  setNote(ok ? 'Ссылка vless:// скопирована' : 'Скопируйте ссылку вручную') )}
                className="px-2 py-1 rounded border border-white/15 text-xs text-muted whitespace-nowrap"
              >
                Копировать vless
              </button>
            </div>
            <div className="text-xs text-faint">
              Ссылку можно отправить сразу — человеку без приложения достаточно вставить её в
              Hiddify/v2rayNG. С приложением достаточно кода.
            </div>
          </div>
        ) : null}
      </form>

      {error ? <div className="text-sm text-rose-400">{error}</div> : null}
      {note ? <div className="text-sm text-emerald-400">{note}</div> : null}

      {/* ── Список ключей ───────────────────────────────────────────── */}
      <div className="glass-card space-y-3">
        <div className="flex flex-wrap items-center gap-3">
          <input
            placeholder="Поиск: имя, код, email"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="input-base w-full md:w-64"
          />
          <div className="flex gap-2 text-xs">
            {(['ALL', 'ACTIVE', 'REVOKED', 'EXPIRED'] as const).map((f) => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-2 py-1 rounded border ${
                  filter === f ? 'border-accent/60 text-accent' : 'border-white/15 text-muted'
                }`}
              >
                {f === 'ALL' ? 'Все' : f === 'ACTIVE' ? 'Активные' : f === 'REVOKED' ? 'Отозванные' : 'Истёкшие'}
              </button>
            ))}
          </div>
          <button onClick={() => load()} className="ml-auto text-xs text-muted hover:text-text">
            Обновить
          </button>
        </div>

        {loading ? (
          <div className="text-muted text-sm py-3">Загрузка…</div>
        ) : shown.length === 0 ? (
          <div className="text-muted text-sm py-3">Ключей не найдено.</div>
        ) : (
          <div className="space-y-3">
            {shown.map((k) => {
              const used = k.trafficUsedMb;
              const limit = k.trafficLimitMb;
              const pct = limit && used !== null ? Math.min(100, Math.round((used / limit) * 100)) : null;
              const expired = k.status !== 'ACTIVE';
              return (
                <div
                  key={k.id}
                  className={`rounded-xl border p-3 space-y-2 ${
                    expired ? 'border-white/10 opacity-70' : 'border-white/15'
                  }`}
                >
                  <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                    <span className="font-semibold text-text">{k.name}</span>
                    <span
                      className={`text-[11px] px-1.5 py-0.5 rounded ${
                        k.status === 'ACTIVE'
                          ? 'bg-emerald-400/15 text-emerald-300'
                          : k.status === 'REVOKED'
                            ? 'bg-rose-400/15 text-rose-300'
                            : 'bg-amber-400/15 text-amber-300'
                      }`}
                    >
                      {k.status === 'ACTIVE' ? 'активен' : k.status === 'REVOKED' ? 'отозван' : 'истёк'}
                    </span>
                    {k.published === false ? (
                      <span className="text-[11px] px-1.5 py-0.5 rounded bg-amber-400/15 text-amber-300">
                        не в ядре — обновится в течение минуты
                      </span>
                    ) : null}
                    {k.user?.email ? (
                      <span className="text-[11px] text-faint">{k.user.email}</span>
                    ) : (
                      <span className="text-[11px] text-faint">без аккаунта</span>
                    )}
                  </div>

                  <div className="flex flex-wrap items-center gap-x-5 gap-y-1 text-xs text-muted">
                    <span>
                      Код:{' '}
                      {k.code ? (
                        <code className="text-text select-all">{k.code}</code>
                      ) : (
                        <span className="text-faint">нет (ключ создан в аккаунте)</span>
                      )}
                    </span>
                    <span>
                      Срок: {fmtDate(k.expiresAt)}
                      {k.daysLeft !== null ? ` · осталось ${k.daysLeft} ${daysWord(k.daysLeft)}` : ' · бессрочно'}
                    </span>
                    <span>
                      Трафик: {fmtMb(used)} {limit ? `/ ${fmtMb(limit)}` : '/ без лимита'}
                    </span>
                    <span>
                      Устройство:{' '}
                      {k.boundDevice ? `${String(k.boundDevice).slice(0, 10)}…` : 'не привязано'}
                    </span>
                  </div>

                  {pct !== null ? (
                    <div className="h-1.5 rounded bg-white/10 overflow-hidden">
                      <div
                        className={`h-full ${pct >= 90 ? 'bg-rose-400' : pct >= 70 ? 'bg-amber-400' : 'bg-accent'}`}
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                  ) : null}

                  {editId === k.id ? (
                    <form onSubmit={submitEdit} className="grid grid-cols-1 md:grid-cols-[1fr_170px_130px_150px_auto_auto] gap-2 items-center pt-1">
                      <input
                        value={editName}
                        onChange={(e) => setEditName(e.target.value)}
                        placeholder="Имя"
                        className="input-base w-full"
                      />
                      <input
                        type="date"
                        value={editDate}
                        onChange={(e) => setEditDate(e.target.value)}
                        className="input-base w-full"
                      />
                      <input
                        type="number"
                        min={0}
                        value={editGb}
                        onChange={(e) => setEditGb(e.target.value)}
                        placeholder="Лимит, ГБ"
                        className="input-base w-full"
                      />
                      <select
                        value={editStatus}
                        onChange={(e) => setEditStatus(e.target.value)}
                        className="input-base w-full"
                      >
                        <option value="ACTIVE">активен</option>
                        <option value="REVOKED">отозван</option>
                        <option value="EXPIRED">истёк</option>
                      </select>
                      <button type="submit" disabled={busyId === k.id} className="btn-primary whitespace-nowrap">
                        Сохранить
                      </button>
                      <button
                        type="button"
                        onClick={() => setEditId(null)}
                        className="px-3 py-2 rounded-lg text-sm border border-white/15 text-muted whitespace-nowrap"
                      >
                        Отмена
                      </button>
                    </form>
                  ) : (
                    <div className="flex flex-wrap gap-2 pt-1">
                      {[7, 30, 90].map((d) => (
                        <button
                          key={d}
                          disabled={busyId === k.id}
                          onClick={() => extend(k, d)}
                          className="px-2.5 py-1 rounded-md text-xs border border-accent/40 text-accent"
                        >
                          +{d} дней
                        </button>
                      ))}
                      <button
                        disabled={busyId === k.id}
                        onClick={() => startEdit(k)}
                        className="px-2.5 py-1 rounded-md text-xs border border-white/15 text-muted"
                      >
                        Изменить
                      </button>
                      <button
                        disabled={busyId === k.id || !k.code}
                        onClick={() => copyKey(k, 'code')}
                        className="px-2.5 py-1 rounded-md text-xs border border-white/15 text-muted"
                      >
                        Копировать код
                      </button>
                      <button
                        disabled={busyId === k.id}
                        onClick={() => copyKey(k, 'uri')}
                        className="px-2.5 py-1 rounded-md text-xs border border-white/15 text-muted"
                      >
                        Копировать vless
                      </button>
                      {k.status === 'ACTIVE' ? (
                        <button
                          disabled={busyId === k.id}
                          onClick={() => revoke(k)}
                          className="px-2.5 py-1 rounded-md text-xs border border-amber-400/40 text-amber-300"
                        >
                          Отозвать
                        </button>
                      ) : null}
                      <button
                        disabled={busyId === k.id}
                        onClick={() => remove(k)}
                        className="px-2.5 py-1 rounded-md text-xs border border-rose-400/40 text-rose-300"
                      >
                        Удалить
                      </button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
        {!compact ? (
          <p className="text-xs text-faint">
            «Отозвать» снимает доступ у человека, но оставляет запись и код (можно вернуть кнопкой
            «+30 дней»). «Удалить» стирает запись навсегда — для ошибочных кодов.
          </p>
        ) : null}
      </div>
    </div>
  );
}
