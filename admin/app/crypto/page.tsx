'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';

import Badge from '@/components/Badge';
import Modal from '@/components/Modal';
import PageHeader from '@/components/PageHeader';
import { api } from '@/lib/api';
import { CryptoTransaction, CryptoWallets } from '@/lib/types';

/**
 * Очередь ручных подтверждений USDT (TASK #029).
 *
 * Криптоплатёж никогда не подтверждается сам: провайдер намеренно не умеет
 * ни verifyWebhook, ни parseWebhook (иначе любой POST на /billing/webhook/crypto
 * выдавал бы подписку бесплатно). Доступ включает только человек, сверивший
 * перевод в кошельке.
 *
 * Как сверять: у каждой сделки своя сумма с уникальным хвостом (например
 * 1.390525 USDT). Покупатель кидает USDT на адрес из инвойса и присылает хэш —
 * ищем этот хэш в TRON-сканере, сумма должна совпасть до знака, адрес получателя
 * — OUR address. Совпало → «Подтвердить». Не совпало → «Отклонить» с причиной.
 */

type Scope = 'awaiting' | 'unsigned' | 'all';

const SCOPES: Array<{ id: Scope; label: string; hint: string }> = [
  { id: 'awaiting', label: 'Ждут проверки', hint: 'хэш прислан — надо сверить в кошельке' },
  { id: 'unsigned', label: 'Ждут перевод', hint: 'инвойс выдан, хэша ещё нет' },
  { id: 'all', label: 'Все криптосделки', hint: 'история платежей USDT' },
];

function shortMiddle(v: string | null, head = 8, tail = 6): string {
  if (!v) return '—';
  return v.length <= head + tail + 1 ? v : `${v.slice(0, head)}…${v.slice(-tail)}`;
}

/** Инвойс живёт CRYPTO_INVOICE_TTL_MIN; показываем, сколько осталось. */
function leftOf(expiresAt: string | null): { text: string; dead: boolean } {
  if (!expiresAt) return { text: '—', dead: false };
  const ms = new Date(expiresAt).getTime() - Date.now();
  if (ms <= 0) return { text: 'просрочен', dead: true };
  const m = Math.floor(ms / 60000);
  return { text: m >= 60 ? `${Math.floor(m / 60)} ч ${m % 60} мин` : `${m} мин`, dead: false };
}

export default function CryptoPage() {
  const [scope, setScope] = useState<Scope>('awaiting');
  const [rows, setRows] = useState<CryptoTransaction[]>([]);
  const [wallets, setWallets] = useState<CryptoWallets | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [decline, setDecline] = useState<CryptoTransaction | null>(null);
  const [reason, setReason] = useState('');
  const [note, setNote] = useState('');
  const [target, setTarget] = useState<CryptoTransaction | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const [list, cfg] = await Promise.all([
        api<CryptoTransaction[]>(`/billing/crypto/queue?scope=${scope}`),
        api<CryptoWallets>('/billing/crypto/wallets'),
      ]);
      setRows(list);
      setWallets(cfg);
    } catch (e) {
      setError((e as Error).message);
    }
  }, [scope]);

  useEffect(() => {
    void load();
  }, [load]);

  const pending = useMemo(() => rows.filter((r) => !leftOf(r.cryptoExpiresAt).dead).length, [rows]);

  async function approve(tx: CryptoTransaction) {
    setBusy(tx.id);
    try {
      await api(`/billing/crypto/${tx.id}/approve`, {
        method: 'POST',
        body: JSON.stringify({ note: note.trim() || undefined }),
      });
      setNote('');
      setTarget(null);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  async function reject(tx: CryptoTransaction) {
    setBusy(tx.id);
    try {
      await api(`/billing/crypto/${tx.id}/reject`, {
        method: 'POST',
        body: JSON.stringify({ reason: reason.trim() || 'сумма не найдена в кошельке' }),
      });
      setReason('');
      setDecline(null);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  async function expire() {
    setBusy('expire');
    try {
      await api('/billing/crypto/expire', { method: 'POST' });
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  return (
    <div>
      <PageHeader
        title="Оплата USDT"
        subtitle="Ручные подтверждения переводов на кошелёк"
        action={
          <button onClick={expire} disabled={busy === 'expire'} className="btn-ghost">
            {busy === 'expire' ? 'Чистим…' : 'Погасить просроченные'}
          </button>
        }
      />

      {error ? <div className="glass-card text-rose-300 mb-3">{error}</div> : null}

      <div className="glass p-4 mb-4 text-sm text-muted flex flex-wrap gap-x-6 gap-y-1">
        <span>
          Приём:{' '}
          <b className={wallets?.enabled ? 'text-emerald-300' : 'text-rose-300'}>
            {wallets ? (wallets.enabled ? 'включён' : 'выключен (нет адреса кошелька)') : '…'}
          </b>
        </span>
        {wallets?.enabled ? (
          <>
            <span>
              Сети: <b className="text-text">{wallets.networks.join(', ')}</b>
            </span>
            <span>
              Курс: <b className="text-text">{wallets.rateRub > 0 ? `${wallets.rateRub} ₽/USDT` : 'не пересчитывается'}</b>
            </span>
            <span>
              Скидка за крипту: <b className="text-text">{wallets.discountRub} ₽</b>
            </span>
            <span>
              Инвойс живёт: <b className="text-text">{wallets.invoiceTtlMinutes} мин</b>
            </span>
          </>
        ) : null}
      </div>

      <div className="flex flex-wrap items-center gap-2 mb-3">
        {SCOPES.map((s) => (
          <button
            key={s.id}
            onClick={() => setScope(s.id)}
            title={s.hint}
            className={`px-3 py-1.5 rounded-lg text-sm border transition ${
              scope === s.id
                ? 'bg-gradient-to-r from-accent/25 to-indigo-500/15 text-text border-accent/30'
                : 'text-muted border-white/10 hover:text-text hover:bg-white/5'
            }`}
          >
            {s.label}
          </button>
        ))}
        <span className="text-xs text-faint ml-auto">
          {scope === 'all' ? SCOPES[2].hint : SCOPES.find((s) => s.id === scope)?.hint} · активных: {pending}
        </span>
      </div>

      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Покупатель</th>
              <th>Тариф</th>
              <th>₽ → USDT</th>
              <th>Кошелёк / сеть</th>
              <th>Хэш от клиента</th>
              <th>Инвойс</th>
              <th>Статус</th>
              <th className="text-right">Действие</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((t) => {
              const left = leftOf(t.cryptoExpiresAt);
              const hasHash = !!t.cryptoTxHash;
              return (
                <tr key={t.id}>
                  <td className="text-text font-medium">
                    {t.user?.email ?? t.userId}
                    {t.user?.deviceId ? (
                      <div className="text-[11px] text-faint font-mono">{shortMiddle(t.user.deviceId, 6, 4)}</div>
                    ) : null}
                  </td>
                  <td>
                    {t.plan?.name ?? '—'}
                    <div className="text-[11px] text-faint">{t.plan ? `${t.plan.durationDays} дн.` : ''}</div>
                  </td>
                  <td>
                    <div className="font-mono">
                      {Number(t.cryptoAmount).toFixed(6).replace(/0+$/, '').replace(/\.$/, '')} USDT
                    </div>
                    <div className="text-[11px] text-faint">
                      {t.currency} {Number(t.amount).toFixed(2)}
                    </div>
                  </td>
                  <td>
                    <div className="font-mono text-xs" title={t.cryptoAddress ?? ''}>
                      {shortMiddle(t.cryptoAddress)}
                    </div>
                    <div className="text-[11px] text-faint">{t.cryptoNetwork ?? '—'}</div>
                  </td>
                  <td>
                    {hasHash ? (
                      <div className="flex items-center gap-1.5">
                        <span className="font-mono text-xs" title={t.cryptoTxHash ?? ''}>
                          {shortMiddle(t.cryptoTxHash, 10, 8)}
                        </span>
                        <button
                          onClick={() => void navigator.clipboard?.writeText(t.cryptoTxHash ?? '')}
                          className="text-[10px] text-faint hover:text-text"
                          title="Скопировать хэш (для поиска в сканере)"
                        >
                          ⧉
                        </button>
                      </div>
                    ) : (
                      <span className="text-faint">не прислан</span>
                    )}
                    {t.cryptoSubmittedAt ? (
                      <div className="text-[11px] text-faint">
                        прислан {new Date(t.cryptoSubmittedAt).toLocaleString()}
                      </div>
                    ) : null}
                    {t.cryptoReviewedNote ? (
                      <div className="text-[11px] text-amber-300/80">{t.cryptoReviewedNote}</div>
                    ) : null}
                  </td>
                  <td>
                    <span className={left.dead ? 'text-rose-300' : 'text-muted'}>{left.text}</span>
                    <div className="text-[11px] text-faint">{new Date(t.createdAt).toLocaleString()}</div>
                  </td>
                  <td>
                    <Badge value={t.status} />
                    {hasHash && t.status === 'PENDING' ? (
                      <span className="ml-1 text-[10px] text-amber-300 uppercase">проверка</span>
                    ) : null}
                  </td>
                  <td className="text-right whitespace-nowrap">
                    {t.status === 'PENDING' ? (
                      hasHash ? (
                        <>
                          <button
                            onClick={() => {
                              setTarget(t);
                              setNote('');
                            }}
                            disabled={busy === t.id}
                            className="btn-primary px-3 py-1 text-xs mr-2"
                          >
                            {busy === t.id ? '…' : 'Подтвердить'}
                          </button>
                          <button
                            onClick={() => {
                              setDecline(t);
                              setReason('');
                            }}
                            disabled={busy === t.id}
                            className="btn-ghost px-3 py-1 text-xs"
                          >
                            Отклонить
                          </button>
                        </>
                      ) : (
                        <span className="text-faint text-xs">ждём хэш</span>
                      )
                    ) : (
                      <span className="text-faint text-xs">закрыта</span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        {rows.length === 0 && !error ? (
          <div className="text-muted text-sm py-4">
            Пусто. {scope === 'awaiting' ? 'Хэшей от покупателей нет.' : 'Криптосделок нет.'}
          </div>
        ) : null}
      </div>

      {target ? (
        <Modal title="Подтвердить перевод" onClose={() => setTarget(null)}>
          <div className="text-sm text-muted space-y-2">
            <div>
              Выдать доступ <b className="text-text">{target.user?.email ?? target.userId}</b> за{' '}
              <b className="text-text">
                {Number(target.cryptoAmount).toFixed(6)} USDT
              </b>{' '}
              на {target.plan?.name ?? 'тариф'}?
            </div>
            <div className="font-mono text-xs text-faint break-all">
              hash {target.cryptoTxHash} → {target.cryptoNetwork} {target.cryptoAddress}
            </div>
            <div className="text-[11px] text-amber-300/80">
              Сверь сумму до последнего знака и адрес получателя в кошельке — постфактум откатить нельзя.
            </div>
            <input
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="Комментарий (например: TRON-сканер, сумма 1.390525 совпала)"
              className="input w-full mt-2"
            />
          </div>
          <div className="flex justify-end gap-2 mt-4">
            <button onClick={() => setTarget(null)} className="btn-ghost px-4 py-2">
              Отмена
            </button>
            <button
              onClick={() => void approve(target)}
              disabled={busy === target.id}
              className="btn-primary px-4 py-2"
            >
              {busy === target.id ? 'Подтверждаем…' : 'Подтвердить и выдать'}
            </button>
          </div>
        </Modal>
      ) : null}

      {decline ? (
        <Modal title="Отклонить перевод" onClose={() => setDecline(null)}>
          <div className="text-sm text-muted space-y-2">
            <div>
              Сделка <b className="text-text">{decline.id}</b> уйдёт в FAILED. Покупатель сможет оформить
              инвойс заново.
            </div>
            <input
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="Причина (увидит покупатель и останется в истории)"
              className="input w-full mt-2"
            />
          </div>
          <div className="flex justify-end gap-2 mt-4">
            <button onClick={() => setDecline(null)} className="btn-ghost px-4 py-2">
              Отмена
            </button>
            <button
              onClick={() => void reject(decline)}
              disabled={busy === decline.id}
              className="btn-ghost px-4 py-2 text-rose-300"
            >
              {busy === decline.id ? '…' : 'Отклонить'}
            </button>
          </div>
        </Modal>
      ) : null}
    </div>
  );
}
