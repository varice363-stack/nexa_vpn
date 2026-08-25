'use client';

import { useEffect, useState } from 'react';

import Badge from '@/components/Badge';
import PageHeader from '@/components/PageHeader';
import { api } from '@/lib/api';
import { Subscription } from '@/lib/types';

export default function SubscriptionsPage() {
  const [subs, setSubs] = useState<Subscription[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<Subscription[]>('/subscriptions')
      .then(setSubs)
      .catch((e) => setError(e.message));
  }, []);

  return (
    <div>
      <PageHeader title="Подписки" subtitle="Все активные подписки" />
      {error ? <div className="glass-card text-rose-300 mb-3">{error}</div> : null}
      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Пользователь</th>
              <th>Тариф</th>
              <th>Статус</th>
              <th>Начало</th>
              <th>Истекает</th>
            </tr>
          </thead>
          <tbody>
            {subs.map((s) => (
              <tr key={s.id}>
                <td className="text-text font-medium">{s.user?.email ?? s.userId}</td>
                <td>{s.planId}</td>
                <td><Badge value={s.status} /></td>
                <td>{new Date(s.createdAt).toLocaleDateString()}</td>
                <td>{s.expiresAt ? new Date(s.expiresAt).toLocaleDateString() : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {subs.length === 0 && !error ? (
          <div className="text-muted text-sm py-4">Подписок пока нет.</div>
        ) : null}
      </div>
    </div>
  );
}
