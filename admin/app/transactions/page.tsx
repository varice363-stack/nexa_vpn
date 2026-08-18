'use client';

import { useEffect, useState } from 'react';

import Badge from '@/components/Badge';
import PageHeader from '@/components/PageHeader';
import { api } from '@/lib/api';
import { BillingTransaction } from '@/lib/types';

export default function TransactionsPage() {
  const [txs, setTxs] = useState<BillingTransaction[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<BillingTransaction[]>('/billing/transactions/all')
      .then(setTxs)
      .catch((e) => setError(e.message));
  }, []);

  return (
    <div>
      <PageHeader title="Transactions" subtitle="Payment transactions (mock provider today)" />
      {error ? <div className="glass-card text-rose-300 mb-3">{error}</div> : null}
      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>User</th>
              <th>Plan</th>
              <th>Amount</th>
              <th>Provider</th>
              <th>Status</th>
              <th>Webhook</th>
              <th>Idempotency Key</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {txs.map((t) => (
              <tr key={t.id}>
                <td className="text-text font-medium">{t.user?.email ?? t.userId}</td>
                <td>{t.planName ?? '—'}</td>
                <td>{t.currency} {Number(t.amount).toFixed(2)}</td>
                <td>{t.provider}</td>
                <td><Badge value={t.status} /></td>
                <td>
                  {t.webhookEvent ? (
                    <Badge value={t.webhookEvent} />
                  ) : (
                    <span className="text-faint">—</span>
                  )}
                </td>
                <td className="font-mono text-xs">{t.idempotencyKey ?? '—'}</td>
                <td>{new Date(t.createdAt).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {txs.length === 0 && !error ? (
          <div className="text-muted text-sm py-4">No transactions yet.</div>
        ) : null}
      </div>
    </div>
  );
}
